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
// Sharing can be enforced because the user inserting the record always has permissions on it

public with sharing class QueueableApex2 implements Queueable, Database.AllowsCallouts, Finalizer {

    @testvisible
    private static Boolean fakeException = false;
    @testvisible
    private static Boolean errorsProcessed = false;

    private Set<ID> workOrdersToUpdate; // Used by the queueable

    private Set<ID> workOrdersRemaining; // Used by the finalizer

    public void execute(QueueableContext context)
    {
    	if(!AppCustomSetting.appEnabled) return; // On/off switch
    	
        QueueableApex2 finalizer = new QueueableApex2();
        system.attachFinalizer(finalizer);
        finalizer.workOrdersRemaining = workOrdersToUpdate.clone();

		List<WorkOrder> workOrders = 
			[SELECT ID, Description, DescriptionSpanish__c 
			from WorkOrder where ID in :workOrdersToUpdate];

    	Integer allowedCallouts = Limits.getLimitCallouts() - Limits.getCallouts();

        for(WorkOrder wo: workOrders)
		{
            if(allowedCallouts==0) break;
		    wo.DescriptionSpanish__c = SimulatedTranslator.translate(wo.Description);
            finalizer.workOrdersRemaining.remove(wo.id);    // Remove from the todo list as they are processed
            allowedCallouts-=1;
		}

		Update(workOrders);

        if(fakeException) {
            Integer x = 0; Integer y = 5/x;
        }
        
		if(workOrdersRemaining.size()> 0)
        {
            ID newQueueable;
			try
			{
				newQueueable = StartQueueable(workOrdersRemaining);
			} catch(Exception ex) {}
            // If newQueueable is null, possibly try alternate chaining mechanism
        }
    }    

    public static void handleTriggerWithQueueable(List<WorkOrder> workOrderList, 
        Map<ID, WorkOrder> newMap, Map<ID, WorkOrder> oldMap, TriggerOperation operation)
    {
        Set<ID> recordsToTranslate = new Set<ID>();

        for(WorkOrder wo:workOrderList)
        {
            if(operation == TriggerOperation.AFTER_INSERT || wo.Description!= oldMap.get(wo.id).Description) 
            {
               recordsToTranslate.add(wo.id);
            }
        }
        system.debug(recordsToTranslate);
        if(recordsToTranslate.size()>0) StartQueueable(recordsToTranslate);        
    }    

	private static ID StartQueueable(Set<ID> pendingRecords)
	{
        if (Limits.GetLimitQueueableJobs() - Limits.GetQueueableJobs() > 0)
        {
            QueueableApex2 qa = new QueueableApex2();
            qa.workOrdersToUpdate = pendingRecords;
			return system.EnqueueJob(qa);
        }
        else return null; // This is a problem
	}

    public void execute(FinalizerContext ctx)
    {
        System.ParentJobResult result = ctx.getResult();
        if(result== ParentJobResult.UNHANDLED_EXCEPTION)
        {
            Exception ex = ctx.getException();
            system.debug(ex.getTypeName());
            system.debug(ex.getMessage());
            system.debug(workOrdersRemaining);
            errorsProcessed = true;

            // You can create a queueable here as well!
        }
    }
}
