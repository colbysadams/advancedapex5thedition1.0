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

public without sharing class QueueableApex implements Queueable, Database.AllowsCallouts, Finalizer {

    @testvisible
    private static Boolean fakeException = false;
    @testvisible
    private static Boolean errorsProcessed = false;

    private Set<ID> workOrdersBeingUpdated = new Set<ID>();

    public void execute(QueueableContext context)
    {
    	if(!AppCustomSetting.appEnabled) return; // On/off switch
    	
        QueueableApex finalizer = new QueueableApex();
        system.attachFinalizer(finalizer);

    	Integer allowedCallouts = Limits.getLimitCallouts() - Limits.getCallouts();
   		
		if(allowedCallouts<=0) return;
		List<WorkOrder> workOrdersToUpdate = 
			[SELECT ID, Description, DescriptionSpanish__c 
			from WorkOrder 
			where LastModifiedDate > :DateTime.Now().addHours(-24) 
			And TranslationPending__c = true LIMIT :allowedCallouts];
		
        for(WorkOrder wo: workOrdersToUpdate)
		{
            finalizer.workOrdersBeingUpdated.add(wo.id);
			wo.DescriptionSpanish__c = SimulatedTranslator.translate(wo.Description);
			wo.TranslationPending__c = false;
		}
		Update(workOrdersToUpdate);

        if(fakeException) {
            Integer x = 0; Integer y = 5/x;
        }
        
		if(workOrdersToUpdate.size()== allowedCallouts)
        {
            ID newQueueable;
			try
			{
				newQueueable = StartQueueable();
			} catch(Exception ex) {}
            // If newQueueable is null, possibly try alternate chaining mechanism
        }
    }    

    public static void handleTriggerWithQueueable(List<WorkOrder> workOrderList, 
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
        if(translationNeeded) StartQueueable();        
    }    

	private static ID StartQueueable()
	{
        if (Limits.GetLimitQueueableJobs() - Limits.GetQueueableJobs() > 0)
			return system.EnqueueJob(new QueueableApex());
        else return null;
	}

    public void execute(FinalizerContext ctx)
    {
        System.ParentJobResult result = ctx.getResult();
        if(result== ParentJobResult.UNHANDLED_EXCEPTION)
        {
            Exception ex = ctx.getException();
            system.debug(ex.getTypeName());
            system.debug(ex.getMessage());
            system.debug(workOrdersBeingUpdated);
            errorsProcessed = true;

            // You can create a queueable here as well!
        }
    }

}
