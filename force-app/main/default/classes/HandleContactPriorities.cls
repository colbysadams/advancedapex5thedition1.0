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

// Handles opportunity after-update and opportunity after-insert

public inherited sharing class HandleContactPriorities implements TriggerAPI.ITriggerHandler {

    public static void handleTrigger(TriggerOperation TrigType, List<SObject> newSObjectList, Map<Id, SObject> newSObjectMap, 
    List<SObject> oldSObjectList, Map<ID, SObject> oldSObjectMap)
    {
        // Cast to the correct type
        List<Contact> newList = (List<Contact>)newSObjectList;
        Map<ID, Contact> oldMap = (Map<ID, Contact>)oldSObjectMap;
        Map<ID, Contact> newMap = (Map<ID, Contact>)newSObjectMap;

        // Look for change in contact priority
        List<Contact> ContactsWithChangedPriority5 = new List<Contact>();
        for(Contact ct: newList)
        {
            if(ct.Contact_Priority__c != oldMap.get(ct.id).Contact_Priority__c && ct.Contact_Priority__c > 5)
            {
                ContactsWithChangedPriority5.add(ct);
            }
        }
        // Grab the contact roles if any
        List<OpportunityContactRole> ocrs = [Select Id, ContactID, OpportunityID from OpportunityContactRole where ContactId in :ContactsWithChangedPriority5 And IsPrimary= True];

        // Now get the Opportunities
        // Remeber, there can be more than one opportunity for a contact
        Map<ID, ID> OpportunityIdsToPrimaryContactIds = new Map<ID, ID>();
        for(OpportunityContactRole ocr: ocrs) OpportunityIdsToPrimaryContactIds.put(ocr.OpportunityID, ocr.ContactID);

        // Get the opportunities
        List<Opportunity> ops = [Select ID, Contact_Priority__c from Opportunity where ID in :OpportunityIdsToPrimaryContactIds.keyset()];

        // Build list of ops to update
        List<Opportunity> opsToUpdate = new List<Opportunity>();

        // Build list of new tasks
        List<Task> newTasks = new List<Task>();

        // Update the priorities
        for(Opportunity op: ops)
        {
            Contact theContact = newMap.get(OpportunityIdsToPrimaryContactIds.get(op.id));
            Decimal newPriority = theContact.Contact_Priority__c;
            if(op.Contact_Priority__c == null || op.Contact_Priority__c < theContact.Contact_Priority__c)
            {
                op.Contact_Priority__c = newPriority;
                opsToUpdate.add(op);
                newTasks.add(
                    new Task(OwnerID = theContact.OwnerID, Type='Other', 
                    WhatID = op.ID, Subject = 'Hot Opportunity!', 
                    WhoID = TheContact.id,
                    ActivityDate = Date.Today().AddDays(1) ));
            }
        }

        if(newTasks.size()>0) insert newTasks;

        if(opsToUpdate.size()>0) update opsToUpdate;

    }

    public Boolean CaptureInternalDMLTriggers() { return false; }

    public Boolean HandleAllTriggers() { return false; }

    public Boolean IgnoreApplicationTriggers() { return false; }

    public void InternalTrigger(String objectType, TriggerOperation triggerType, List<SObject> newList, Map<Id, SObject> newMap, 
        List<SObject> oldList, Map<ID, SObject> oldMap) {}
    
}
