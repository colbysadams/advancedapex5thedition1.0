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
public inherited sharing class ExecutiveOutreach implements TriggerAPI.ITriggerHandler {

    /*
    public class LocalStaticsClass Extends StaticManager
    {
        public Set<ID> executedOnce {
            get { 
                Set<ID> currentSet = (Set<ID>)RetrieveValue('executedOnce');
                return (currentSet.clone());    // We don't want to modify the stored values directly
            }
            set{ StoreValue('executedOnce', value); }
        }

        public LocalStaticsClass() {
            super('ExecutiveOutreach');
            executedOnce = new Set<ID>();
        }
    }

    private static LocalStaticsClass LocalStatics = new LocalStaticsClass();
    */

    public static void handleTrigger(TriggerOperation TrigType, List<SObject> newSObjectList, Map<Id, SObject> newSObjectMap, 
    List<SObject> oldSObjectList, Map<ID, SObject> oldSObjectMap)
    {
        //Set<ID> executedOnce = LocalStatics.executedOnce;

        // Cast to the correct type
        List<Contact> newList = (List<Contact>)newSObjectList;
        Map<ID, Contact> oldMap = (Map<ID, Contact>)oldSObjectMap;

        // Look for change in contact priority
        List<Contact> ContactsWithChangedHighValue = new List<Contact>();
        for(Contact ct: newList)
        {
            if(ct.High_Value_Opportunities__c != oldMap.get(ct.id).High_Value_Opportunities__c && ct.High_Value_Opportunities__c >= 2 
                // && ct.Admin_Automation_Update__c == oldMap.get(ct.id).Admin_Automation_Update__c
                )
            {
                ContactsWithChangedHighValue.add(ct);
            }
        }
        if(ContactsWithChangedHighValue.size()==0) return;

        // Build list of new tasks
        List<Task> newTasks = new List<Task>();

        // Update the priorities
        for(Contact ct: ContactsWithChangedHighValue)
        {
            //if(executedOnce.contains(ct.id)) continue;
            //executedOnce.add(ct.id);
            newTasks.add(
                new Task(OwnerID = ct.OwnerID, Type='Other', 
                    Subject = 'Executive outreach!', 
                    WhoID = ct.id,
                    ActivityDate = Date.Today().AddDays(1) ));

        }

        //LocalStatics.executedOnce = executedOnce;   // Update the static list

        insert newTasks;
    }

    public Boolean CaptureInternalDMLTriggers() { return false; }

    public Boolean HandleAllTriggers() { return false; }

    public Boolean IgnoreApplicationTriggers() { return false; }

    public void InternalTrigger(String objectType, TriggerOperation triggerType, List<SObject> newList, Map<Id, SObject> newMap, 
        List<SObject> oldList, Map<ID, SObject> oldMap) {}
    

}
