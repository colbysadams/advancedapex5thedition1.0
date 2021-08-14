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

    private ID currentAsyncRequestId;

    public void execute(QueueableContext context)
    {
    	if(!AppCustomSetting.appEnabled) return; // On/off switch
    	
        QueueableApex finalizer = new QueueableApex();
        system.attachFinalizer(finalizer);

    	List<AsyncRequest__c> requests;
    	try
    	{
	    	requests = [Select ID, AsyncType__c, Params__c 
	    		from AsyncRequest__c 
	    		where Error__c = false And
	    		CreatedById = :UserInfo.getUserId() 
	    		Limit 1 for update];
    	}
    	catch(Exception ex) { return; }
    	if(requests.size()==0 ) return;
    	
    	AsyncRequest__c currentRequest = requests[0];
        finalizer.currentAsyncRequestId = currentRequest.id;

        Boolean success = true;

    	try
    	{
    		if(currentRequest.AsyncType__c=='Translate Work Order') 
    			success = translate(currentRequest);
    		
    		// Add more here
    		
    		if(success)
            {

                // The following code will prevent the delete errors
                /*List<AsyncRequest__c> relockRequests = [Select ID, AsyncType__c, Params__c 
	    		from AsyncRequest__c 
	    		where Error__c = false And ID = :currentRequest.id for update];
                if(relockRequests.size()==0) 
                {
                    // You may have to do other things here
                    return;
                }
                */

                delete currentRequest;
                // Optional
                database.emptyRecycleBin(new List<ID>{currentRequest.id}); 
            }
    		
    	}
    	catch(Exception ex)
    	{
    		currentRequest.Error__c = true;
    		currentRequest.Error_Message__c = ex.getMessage();
    		update currentRequest;
    	}

        if(fakeException) {
            Integer x = 0; Integer y = 5/x;
        }
        
        if(!isAsyncRequestPending(currentRequest.id)) return;
    	
		try
		{
			StartQueueable(context.getJobId());
		}
		catch(Exception ex)
		{
			tryToQueue();
		}
    }    

    // Determine if another asynch request is pending - which means we should chain
    private static Boolean isAsyncRequestPending(ID currentRequestId)
    {
        
    	List<AsyncRequest__c> moreRequests = [Select ID, AsyncType__c, Params__c 
    		from AsyncRequest__c 
    		where Error__c = false 
    		and ID <> :currentRequestId 
    		and	CreatedById = :UserInfo.getUserId() 
    		Limit 1 ];
        return (moreRequests.size()>0);
        
    }

    @future
    private static void tryToQueue()
    {
        if(!AppCustomSetting.appEnabled) return; // On/off switch
        try {
            startQueueable(null);
        }
        catch(Exception ex)
        {
            // Wait for someone else to make a request...
            // Or maybe use scheduled Apex?
        }
    }    

    public Boolean translate(AsyncRequest__c request)
    {
    	Integer allowedCallouts = Limits.getLimitCallouts() - Limits.getCallouts();
		if(allowedCallouts<=0) return false;
		
		List<ID> idsAfterSplit = request.Params__c.split(',');
		
		List<WorkOrder> workOrdersToUpdate = 
			[SELECT ID, Description, DescriptionSpanish__c 
			from WorkOrder 
			where ID in :idsAfterSplit 
			LIMIT :allowedCallouts];
		for(WorkOrder wo: workOrdersToUpdate)
		{
			wo.DescriptionSpanish__c = 
				SimulatedTranslator.translate(wo.Description);
			wo.TranslationPending__c = false;
		}
		update workOrdersToUpdate;
        return true;
    }


    public static void handleTriggerWithQueueable(List<WorkOrder> workOrderList, 
        Map<ID, WorkOrder> newMap, Map<ID, WorkOrder> oldMap, TriggerOperation operation)
    {
        List<AsyncRequest__c> newAsyncRequests = new List<AsyncRequest__c>();
		List<String> textChangedIds = new List<ID>();
        Integer maxIdsPerRequest = 100;

        for(WorkOrder wo:workOrderList)
        {
            if(operation == TriggerOperation.AFTER_INSERT || wo.Description!= oldMap.get(wo.id).Description) 
            {
                textChangedIds.add(wo.id);
            }
            if(textChangedIds.size()>maxIdsPerRequest)
            {
                newAsyncRequests.add(
                    new AsyncRequest__c(AsyncType__c = 'Translate Work Order',
                            Params__c = string.Join(textChangedIds,',')));
                textChangedIds.clear();
            }
        }
		if(textChangedIds.size()>0)
			newAsyncRequests.add(
				new AsyncRequest__c(AsyncType__c = 'Translate Work Order',
							Params__c = string.Join(textChangedIds,',')));

		if(newAsyncRequests.size()>0) insert newAsyncRequests;
    }    

	public static ID StartQueueable(ID currentJobID)
	{
		List<AsyncApexJob> jobs = [Select ID, Status, ExtendedStatus from AsyncApexJob 
					where JobType = 'Queueable' And (status='Queued'  Or Status='Holding') 
					and CreatedById = :userinfo.getUserID() and 
					ApexClass.Name='QueueableApex'];
		if(jobs.size()>=1 || (jobs.size()==1 && jobs[0].id != currentJobID)) return(null);	// Already have one queued by this user - don't need another

//        if (Limits.GetLimitQueueableJobs() - Limits.GetQueueableJobs() > 0)
//			return system.EnqueueJob(new QueueableApex());
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
            system.debug(currentAsyncRequestId);    // Think about what you can do with this!
            errorsProcessed = true;

            // You can create a queueable here as well! - So if any requests are pending, you can process them
        }
    }

}
