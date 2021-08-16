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

public without sharing class ChangeDataCaptureApex {

    public static void handleChangeEvent(List<WorkOrderChangeEvent> events)
    {

        Integer availableCallouts = Limits.getLimitCallouts();
        List<WorkOrder> WorkOrdersToUpdate = new List<WorkOrder>();

        for(WorkOrderChangeEvent event: events)
        {
            if(availableCallouts==0)
            {
                Eventbus.TriggerContext.currentContext().setResumeCheckpoint(event.replayId);
                break;
            }
            EventBus.ChangeEventHeader header = event.ChangeEventHeader;
            // Is it a change we care about?
            if(header.changeType=='CREATE' ||
                header.changeType=='UPDATE' && header.changedFields.contains('Description'))
            {
                String translation = event.Description + ' - No callouts from triggers';
                availableCallouts-=1;
                for(ID workOrderId: header.recordids)
                {
                    Workorder updatedWorkorder = new WorkOrder(id = workOrderId, DescriptionSpanish__c = translation);
                    WorkOrdersToUpdate.add(updatedWorkorder);
                }
            }
        }

        if(WorkOrdersToUpdate.size()>0) update WorkOrdersToUpdate;

    }

}
