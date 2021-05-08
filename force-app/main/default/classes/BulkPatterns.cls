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

public with sharing class BulkPatterns {


	/*
		This solution uses future calls to move the intensive operation into
		a separate execution context
	*/
	@future
	public static void futureUpdateOpportunities(Set<ID> opportunitiyIds)
	{
		Map<ID, Opportunity> newMap = 
			new Map<ID, Opportunity>(
				[SELECT ID, OwnerID from Opportunity where ID in :opportunitiyIds]);
		afterUpdateOpportunityFutureSupport(newMap.values(), newMap, null);
	}
	private static Boolean futureCalled = false;

	public static void afterUpdateOpportunityFutureSupport(
		List<Opportunity> newList, Map<ID, Opportunity> newMap, 
		Map<ID, Opportunity> oldMap)
	{
		// Pattern 6 - with future support
		
		Set<ID> opportunityIDsWithStagenameChanges = new Set<ID>();
		
		// Get OpportunityContactRoles
		if(!System.isFuture())
		{
			for(Opportunity op: newList)
			{
				if(op.StageName != oldMap.get(op.id).StageName) 
					opportunityIDsWithStagenameChanges.add(op.id);
			}
			if(newList.size()>50)
			{
				if(!futureCalled) 
					futureUpdateOpportunities(opportunityIDsWithStagenameChanges);
				futureCalled = true;
				return;
			}
		}
		else opportunityIDsWithStagenameChanges.addall(newMap.keyset());
		
		// Quick exit if no processing required
		if(opportunityIDsWithStagenameChanges.size()==0) return;	
			
			
		// Query for all related OpportunityContactRole
		List<OpportunityContactRole> ocrs = 
			[Select ID, ContactID, IsPrimary, OpportunityID 
			from OpportunityContactRole 
			where OpportunityID in :opportunityIDsWithStagenameChanges];

		// Look for primary, or for no OCR on opportunities
		Set<ID> opsWithNoPrimaryWithContactRoles = opportunityIDsWithStagenameChanges.Clone();
		Set<ID> opsWithNoContactRoles = opportunityIDsWithStagenameChanges.Clone();
		
		for(OpportunityContactRole ocr: ocrs)
		{
			if(ocr.IsPrimary) opsWithNoPrimaryWithContactRoles.remove(ocr.OpportunityID);
			opsWithNoContactRoles.remove(ocr.OpportunityID);
		}
		opsWithNoPrimaryWithContactRoles.RemoveAll(opsWithNoContactRoles);

		// First deal with any opportunities without contact roles
		if(opsWithNoContactRoles.size()>0)
		{
			// Find out which ones have existing tasks
			List<Task> tasks = 
				[SELECT ID, OwnerID, WhatID, Status, Subject, Type 
				from Task where Type='Other' 
				And WhatID in :opsWithNoContactRoles And IsClosed = False 
				And Subject = 'Assign Primary Contact'   ];

			// Don't loop through opportunities - waste of time. 
			// Loop through tasks to build set of IDs with tasks
			Set<ID> opsWithoutTasks = opsWithNoContactRoles.clone();
			for(Task t: tasks)
			{
				Opportunity op = newMap.get(t.WhatID);	// Get the opportunity
				// Make sure it's assigned to the right person
				if(t.OwnerID == op.OwnerID) opsWithoutTasks.remove(op.ID);	
			}
			// Now create new tasks
			List<Task> newTasks = new List<Task>();
			for(ID opid: opsWithoutTasks)
			{
				Opportunity op = newMap.get(opid);
				newTasks.add(new Task(OwnerID = op.OwnerID, Type='Other', 
					WhatID = op.ID, Subject = 'Assign Primary Contact', 
					ActivityDate = Date.Today().AddDays(3) ));
			}
			if(newTasks.size()>0) insert newTasks;
			
		}
		if(opsWithNoPrimaryWithContactRoles.size()>0)
		{			
			// Get a list of the contacts
			List<ID> contactIdsForOps = new List<ID>();
			for(OpportunityContactRole ocr: ocrs)
			{
				if(opsWithNoPrimaryWithContactRoles.contains(ocr.OpportunityID)) 
					contactIdsForOps.add(ocr.ContactID);
			}
			
			// Now get the totals count and primary count for each contact by 
			// using aggregate functions and grouping by contact
			List<AggregateResult> ocrsByContact = 
				[Select ContactID, Count(ID) total 
				from OpportunityContactRole 
				where ContactID in :contactIdsForOps 
				Group By ContactID];
			List<AggregateResult> primaryOcrsByContact = 
				[Select ContactID, Count(ID) total 
				from OpportunityContactRole where IsPrimary=true 
				and ContactID in :contactIdsForOps Group By ContactID];

			// Let's get the totals by contact for a faster loop
			Map<ID, Integer> totalsByContact = new Map<ID, Integer>();
			Map<ID, Integer> primaryByContact = new Map<ID, Integer>();
			for(AggregateResult ar: ocrsByContact) 
				totalsByContact.put((ID)ar.get('ContactID'), 
				Integer.ValueOf(ar.get('total')));
			for(AggregateResult ar: primaryOcrsByContact) 
				primaryByContact.put((ID)ar.get('ContactID'), 
				Integer.ValueOf(ar.get('total')));

			List<Opportunity> opportunitiesWithoutPrimary = 
				[Select ID ,(Select ID, ContactID, IsPrimary 
				from OpportunityContactRoles) from Opportunity 
				where ID in :opsWithNoPrimaryWithContactRoles];
			List<OpportunityContactRole> ocrsToUpdate = 
				new List<OpportunityContactRole>();
			
			for(Opportunity op: opportunitiesWithoutPrimary)
			{
				OpportunityContactRole bestOcr = null;
				Integer primaryCount = 0;
				Integer totalCount = 0;
				for(OpportunityContactRole opOcrs: op.OpportunityContactRoles)
				{
					// Use intermediate variables to reduce # of map accesses in loop
					Integer primaryCountForThisContact = primaryByContact.get(opocrs.Contactid);
					Integer totalCountForThisContact = totalsByContact.get(opocrs.contactId);

					if(bestOcr==null || 
						primaryCountForThisContact > primaryCount ||
					(primaryCountForThisContact == totalCount && 
						totalCountForThisContact > totalCount )) {
					primaryCount = primaryCountForThisContact;
					totalCount = totalCountForThisContact;
					bestOcr = opOcrs;
					}
				}
				bestOcr.IsPrimary = true;
				ocrsToUpdate.add(bestOcr);
			}
			update ocrsToUpdate;
		}		
	}
}

