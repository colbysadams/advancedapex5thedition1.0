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
		This solution uses aggregate queries to dramatically reduce CPU time

		Sample results (TestBulkPatterns.initTestObjects(ops, 100, 15, 15, 40)):
		bulkOpportunityTest - 
		Number of SOQL queries: 4 out of 100
		Number of query rows: 3140 out of 50000
		Number of SOSL queries: 0 out of 20
		Number of DML statements: 2 out of 150
		Number of DML rows: 200 out of 10000
		Maximum CPU time: 167 out of 10000
	*/
	public static void afterUpdateOpportunityBetterQueries(
		List<Opportunity> newList, Map<ID, Opportunity> newMap, 
		Map<ID, Opportunity> oldMap)
	{
		// Pattern 4 - Implementation with SOQL aggregates
		
		Set<ID> opportunityIDsWithStagenameChanges = new Set<ID>();
		
		// Get OpportunityContactRoles
		for(Opportunity op: newList)
		{
			if(op.StageName != oldMap.get(op.id).StageName) 
				opportunityIDsWithStagenameChanges.add(op.id);
		}
		
		// Quick exit if no processing required
		if(opportunityIDsWithStagenameChanges.size()==0) return;	
			
			
		// Query for all related OpportunityContactRole
		List<OpportunityContactRole> ocrs = 
			[Select ID, ContactID, IsPrimary, OpportunityID 
			from OpportunityContactRole 
			where OpportunityID in :opportunityIDsWithStagenameChanges];

		// Look for primary, or for no OCR on opportunities
		// This is a slightly different approach than the one you saw in the previous example, in that it uses
		// set operations to remove entries that have no primary contact role, or no contact roles at all
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

	/*
		This solution uses aggregate queries and sets to reduce CPU time even further

		Sample results (TestBulkPatterns.initTestObjects(ops, 100, 15, 15, 40)):
		bulkOpportunityTest - 
		Number of SOQL queries: 3 out of 100
		Number of query rows: 1540 out of 50000
		Number of SOSL queries: 0 out of 20
		Number of DML statements: 2 out of 150
		Number of DML rows: 200 out of 10000
		Maximum CPU time: 157 out of 10000
	*/
	public static void afterUpdateOpportunityBetterQueries2(
		List<Opportunity> newList, Map<ID, Opportunity> newMap, 
		Map<ID, Opportunity> oldMap)
	{
		// Pattern 5 - Implementation with SOQL aggregates #2
		
		Set<ID> opportunityIDsWithStagenameChanges = new Set<ID>();
		
		// Get OpportunityContactRoles
		for(Opportunity op: newList)
		{
			if(op.StageName != oldMap.get(op.id).StageName) 
				opportunityIDsWithStagenameChanges.add(op.id);
		}
		
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

			// Let's get the totals by contact for faster loop
			Map<ID, Integer> totalsByContact = new Map<ID, Integer>();
			Map<ID, Integer> primaryByContact = new Map<ID, Integer>();
			for(AggregateResult ar: ocrsByContact) 
				totalsByContact.put((ID)ar.get('ContactID'), 
				Integer.ValueOf(ar.get('total')));
			for(AggregateResult ar: primaryOcrsByContact) 
				primaryByContact.put((ID)ar.get('ContactID'), 
				Integer.ValueOf(ar.get('total')));

			// Instead of requerying opportunties with a subquery of contact roles
			// Build a map from opportunity ID to related contact roles
			// for opportunties without primary contact roles
			Map<ID, List<OpportunityContactRole>> opportunitiesWithoutPrimary = 
				new Map<ID, List<OpportunityContactRole>>();
			for(OpportunityContactRole ocr: ocrs)
			{
				ID opid = ocr.OpportunityID;	// Use temp variable for speed
				if(opsWithNoPrimaryWithContactRoles.contains(opid))
				{
					if(!opportunitiesWithoutPrimary.containsKey(opid))
						opportunitiesWithoutPrimary.put(opid, new List<OpportunityContactRole>());
					opportunitiesWithoutPrimary.get(opid).add(ocr);
				}
			}
			
			
			List<OpportunityContactRole> ocrsToUpdate = 
				new List<OpportunityContactRole>();
			
			for(ID opid: opportunitiesWithoutPrimary.keyset())
			{
				OpportunityContactRole bestOcr = null;
				Integer primaryCount = 0;
				Integer totalCount = 0;
				for(OpportunityContactRole opOcrs: opportunitiesWithoutPrimary.get(opid))
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

