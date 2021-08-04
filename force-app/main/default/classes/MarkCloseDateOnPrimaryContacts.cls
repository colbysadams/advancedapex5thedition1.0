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
public inherited sharing class MarkCloseDateOnPrimaryContacts implements TriggerAPI.ITriggerHandler {

    public void HandleTrigger(TriggerOperation TrigType, List<SObject> newSObjectList, Map<Id, SObject> newSObjectMap, 
    List<SObject> oldSObjectList, Map<ID, SObject> oldSObjectMap)
    {
        // Cast to the correct type
        List<Opportunity> newList = (List<Opportunity>)newSObjectList;
        Map<ID, Opportunity> oldMap = (Map<ID, Opportunity>)oldSObjectMap;

        Set<ID> OpsThatMayNeedContactUpdate = new Set<ID>();
		for(Opportunity op: newList)
		{
			if(TrigType == TriggerOperation.AFTER_INSERT || 
                op.CloseDate != oldMap.get(op.id).CloseDate )
            {
				OpsThatMayNeedContactUpdate.add(op.id);
            }
		}

        // Get the contacts for these opportunity
        List<OpportunityContactRole> thesePrimaries = [Select ID, ContactID, Opportunity.CloseDate from OpportunityContactRole where OpportunityID in :OpsThatMayNeedContactUpdate And IsPrimary = True];

        // Set the last op close date for each contact
        Map<ID, Date> contactToCloseDates = new Map<ID, Date>();
        for(OpportunityContactRole ocr: thesePrimaries)
        {
            ID contactID = ocr.ContactID;
            if(!contactToCloseDates.containsKey(contactID) || contactToCloseDates.get(contactID) < ocr.Opportunity.CloseDate)
                contactToCloseDates.put(contactID, ocr.Opportunity.CloseDate);
        }

        // Prepare update list
        List<Contact> contactsToUpdate = new List<Contact>();
        for(ID contactID: contactToCloseDates.keyset()) contactsToUpdate.add(new Contact(ID = contactID, Last_Close_Date__c = contactToCloseDates.get(contactID)));

        update contactsToUpdate;

    }


}
