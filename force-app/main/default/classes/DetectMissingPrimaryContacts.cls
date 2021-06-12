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

public inherited sharing class DetectMissingPrimaryContacts {

    // If changing stages and no primary contact exists, create a new task to create one
    public static void beforeOpportunityUpdate(TriggerOperation triggerType, List<Opportunity> newList, Map<ID, Opportunity> newMap, Map<Id, Opportunity> oldMap)
    {
		Map<ID, Opportunity> opportunityIDsWithStagenameChanges = new Map<ID, Opportunity>();
		
		// Get OpportunityContactRoles
		for(Opportunity op: newList)
		{
			if(op.StageName != oldMap.get(op.id).StageName) 
				opportunityIDsWithStagenameChanges.put(op.id, op);
		}
		
		// Quick exit if no processing required
		if(opportunityIDsWithStagenameChanges.size()==0) return;	
			
		// Query for all related OpportunityContactRole
		List<OpportunityContactRole> ocrs = 
			[Select ID, ContactID, IsPrimary, OpportunityID 
			from OpportunityContactRole 
			where OpportunityID in :opportunityIDsWithStagenameChanges.keyset() And IsPrimary = True];

		// Remove the opportunities with primary contacts from the list
		for(OpportunityContactRole ocr: ocrs)
		{
            // Note - because our query only captures primary contact roles, and there can only be one primary contact role
            // on an opportunity, this will never try to remove the same opportunity twice
			if(ocr.IsPrimary) opportunityIDsWithStagenameChanges.remove(ocr.OpportunityID);
		}

		// If no opportunities are left, exit right away
		if(opportunityIDsWithStagenameChanges.size()==0) return;

        // Find out which ones have existing tasks
        List<Task> tasks = 
            [SELECT ID, OwnerID, WhatID, Status, Subject, Type 
            from Task 
            where Type='Other' 
            And WhatID in :opportunityIDsWithStagenameChanges.keyset() 
            And IsClosed = False 
            And Subject = 'Assign Primary Contact'   ];

        // Loop through tasks to build set of opportunity IDs with tasks
        Set<ID> opsWithTasks = new Set<ID>();
        for(Task t: tasks)
        {
            // Get the opportunity
            Opportunity op = opportunityIDsWithStagenameChanges.get(t.WhatID);	
            // Make sure it's assigned to the right person
            if(t.OwnerID == op.OwnerID) opsWithTasks.add(op.ID);	
        }
        // Now create new tasks
        List<Task> newTasks = new List<Task>();
        for(Opportunity op: opportunityIDsWithStagenameChanges.values())
        {
            if(!opsWithTasks.contains(op.id))
            {
                newTasks.add(
                    new Task(OwnerID = op.OwnerID, Type='Other', 
                    WhatID = op.ID, Subject = 'Assign Primary Contact', 
                    ActivityDate = Date.Today().AddDays(3) ));
            }				
        }
        if(newTasks.size()>0) insert newTasks;
    }

}
