/*Copyright (c) 2021, Daniel Appleman

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, 
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation 
and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors 
may be used to endorse or promote products derived from this software without 
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND 
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF 
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
// Sharing is bypassed as presumably you want to translate all workorders regardless of owner

public without sharing class BatchApex implements 
    Database.Batchable<SObject>, Database.AllowsCallouts, Database.RaisesPlatformEvents
{
    @testvisible
    private static Boolean fakeException = false;
    @testvisible
    private static Boolean errorsProcessed = false;

	public Database.Querylocator start(Database.BatchableContext bc)
	{
		return Database.getQueryLocator('SELECT ID, Description, DescriptionSpanish__c From WorkOrder Where TranslationPending__c = true');
	}

	public void execute(Database.BatchableContext BC, List<WorkOrder> scope)
	{
		for(WorkOrder wo: scope)
		{
			try {
				wo.DescriptionSpanish__c = SimulatedTranslator.translate(wo.Description);
				wo.TranslationPending__c = false;
			} catch (Exception ex) {}
		}
        try
        {
		    Update(scope);
        } catch(Exception ex)
        {
            // Add error handling here
        }
        if(fakeException) {
            Integer x = 0; Integer y = 5/x;
        }
		
	}

	public void finish(Database.BatchableContext BC)
	{
        AsyncApexJob thisJob = [Select Id, CreatedDate from AsyncApexJob where id = :BC.getJobId()];
		List<WorkOrder> stillPending = 
			[SELECT ID From WorkOrder 
			Where TranslationPending__c = true And LastModifiedDate> :thisJob.CreatedDate Limit 1];
		if(stillPending.size()>0) StartBatch(BC.getJobId());
	}

	private static Boolean batchRequested = false;

	public static void handleTriggerWithBatchApex(List<WorkOrder> workOrderList, 
		Map<ID, WorkOrder> newMap, Map<ID, WorkOrder> oldMap, TriggerOperation operation)
	{
		Boolean translationNeeded = false;

		for(WorkOrder wo:workOrderList)
		{
			if(operation == TriggerOperation.BEFORE_INSERT || wo.Description!= oldMap.get(wo.id).Description) 
			{
				wo.TranslationPending__c = true; 
				translationNeeded = true;
			}
		}
		if(translationNeeded) StartBatch(null);        
    }    

	private static void StartBatch(ID excludeCurrentBatchID)
	{
		if(batchRequested || isBatchActive('BatchApex', excludeCurrentBatchID)) return;
		
		BatchApex ba = new BatchApex();
		Integer batchSize = Limits.getLimitCallouts();
		if(batchSize>200) batchSize = 200;
		Database.executeBatch(ba, batchSize);
		batchRequested = true;
	}

	public static Boolean isBatchActive(String classname, ID excludeCurrentBatchID)
	{
		List<String> inactiveStatuses = 
			new List<String>{'Completed','Aborted','Failed'};
		AsyncApexJob[] activeJobs = 
			[select id, CompletedDate, Status, ExtendedStatus, ApexClassID 
			from AsyncApexJob where 
            ApexClass.Name = :classname 
            And ID != :excludeCurrentBatchID
			And JobType='BatchApex' 
			And Status Not in :inactiveStatuses 
			Order By CreatedDate Desc Limit 1];
		return activeJobs.size() >0;
	}

    public static void handleBatchApexErrorEvents(List<BatchApexErrorEvent> events)
    {
		Set<ID> asyncApexJobIds = new Set<ID>();

		for(BatchApexErrorEvent evt: events) asyncApexJobIds.add(evt.AsyncApexJobId);
		
		Map<Id,AsyncApexJob> jobs = new Map<Id,AsyncApexJob>([SELECT id, ApexClass.Name FROM AsyncApexJob 
			WHERE Id IN :asyncApexJobIds]);

        for(BatchApexErrorEvent evt: events)
        {
			if(jobs.get(evt.AsyncApexJobId).ApexClass.Name != 'BatchApex') continue;	// Only look at this class
            system.debug('Exception type ' + evt.ExceptionType);
            system.debug('Job scope (records) ' + evt.JobScope);
            system.debug('Error message ' + evt.Message);
            system.debug('Phase ' + evt.Phase);
            errorsProcessed = true;
        }

    }

}
