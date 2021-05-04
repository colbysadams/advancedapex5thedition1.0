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
		This is a common solution - what you might expect to see from a moderately experienced Apex developer

		Sample results (TestBulkPatterns.initTestObjects(ops, 100, 15, 15, 40)):
		bulkOpportunityTest - 
		Number of SOQL queries: 2 out of 100
		Number of query rows: 3265 out of 50000
		Number of SOSL queries: 0 out of 20
		Number of DML statements: 2 out of 150
		Number of DML rows: 200 out of 10000
		Maximum CPU time: 1735 out of 10000

		createTaskTest
		Number of SOQL queries: 2 out of 100
		Number of query rows: 0 out of 50000
		Number of SOSL queries: 0 out of 20
		Number of DML statements: 2 out of 150
		Number of DML rows: 200 out of 10000
		Maximum CPU time: 151 out of 10000    
	*/

	public static void afterUpdateOpportunityCommon(
		List<Opportunity> newList, Map<ID, Opportunity> newMap, 
		Map<ID, Opportunity> oldMap)
	{
		// Pattern 2 - Straightforward common implementation
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
		Set<ID> primaryFound = new Set<ID>();
		Set<ID> anyFound = new Set<ID>();
		
		for(OpportunityContactRole ocr: ocrs)
		{
			if(ocr.IsPrimary) primaryFound.add(ocr.OpportunityID);
			anyFound.add(ocr.OpportunityID);
		}

		// Build list of opportunities with no contact role, 
		// and list with contact role but no primary contact role
		// Use maps because it's an easy way to get the keyset for later queries
		Map<ID, Opportunity> opsWithNoContactRoles = new Map<ID, Opportunity>();
		Map<ID, Opportunity> opsWithNoPrimary = new Map<ID, Opportunity>();

		for(ID opid: opportunityIDsWithStagenameChanges)
		{
			if(!primaryFound.contains(opid))
			{
				if(anyFound.contains(opid)) 
					opsWithNoPrimary.put(opid, newMap.get(opid));
				else 
					opsWithNoContactRoles.put(opid, newMap.get(opid));
			}
		}
		
		// First deal with any opportunities without contact roles
		if(opsWithNoContactRoles.size()>0)
		{
			// Find out which ones have existing tasks
			List<Task> tasks = 
				[SELECT ID, OwnerID, WhatID, Status, Subject, Type 
				from Task 
				where Type='Other' 
				And WhatID in :OpsWithNoContactRoles.keyset() 
				And IsClosed = False 
				And Subject = 'Assign Primary Contact'   ];

			// Don't loop through opportunities - waste of time. 
			// Loop through tasks to build set of IDs with tasks
			Set<ID> opsWithTasks = new Set<ID>();
			for(Task t: tasks)
			{
				// Get the opportunity
				Opportunity op = opsWithNoContactRoles.get(t.WhatID);	
				// Make sure it's assigned to the right person
				if(t.OwnerID == op.OwnerID) opsWithTasks.add(op.ID);	
			}
			// Now create new tasks
			List<Task> newTasks = new List<Task>();
			for(Opportunity op: opsWithNoContactRoles.values())
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

		if(opsWithNoPrimary.size()>0)
		{			
			// Get a list of the contacts
			List<ID> contactIdsForOps = new List<ID>();
			for(OpportunityContactRole ocr: ocrs)
			{
				if(opsWithNoPrimary.containskey(ocr.OpportunityID)) 
					contactIdsForOps.add(ocr.ContactID);
			}
			
			// Now query the contacts with their OpportunityContactRoles
			Map<ID, Contact> contactsForOps = 
				new Map<ID, Contact>(
					[Select ID, 
					(Select ID, IsPrimary, OpportunityID from OpportunityContactRoles) 
					from Contact where ID in :contactIdsForOps]);

			// Now figure out which of the OpportunityContactRoles should be set to primary
			// Map of opportunity ID to the best OCR for that ID
			Map<ID,OpportunityContactRole> bestOcrs = new Map<ID, OpportunityContactRole>();
			// Map of opportunity to Total # OCRs on the current best opportunity contact
			Map<ID,Integer> bestContactAllOcrCount = new Map<ID,Integer>();
			
			// Map of opportunity to Total # primary OCRs on the current best opportunity contact
			Map<ID,Integer> bestContactPrimaryOcrCount = new Map<ID, Integer>();
			
			for(OpportunityContactRole ocr: ocrs)
			{
				if(!opsWithNoPrimary.containskey(ocr.OpportunityID)) continue;
				Contact currentContact = contactsForOps.get(ocr.ContactID);
				Integer primaryCount = 0;
				for(OpportunityContactRole testOcr: currentContact.OpportunityContactRoles)
				{
					if(testocr.IsPrimary) primaryCount++;
				}
				if(!bestOcrs.containskey(ocr.OpportunityID) || 
					primaryCount > bestContactPrimaryOcrCount.get(ocr.OpportunityID) ||
					(primaryCount == bestContactAllOcrCount.get(ocr.OpportunityID) && 
					currentContact.OpportunityContactRoles.size()> bestContactAllOcrCount.get(ocr.OpportunityID)))
				{
					bestOcrs.put(ocr.OpportunityID, ocr);
					bestContactAllOcrCount.put(ocr.OpportunityID, currentContact.OpportunityContactRoles.size());
					bestContactPrimaryOcrCount.put(ocr.OpportunityID, primaryCount);
				}
			}
			
			for(OpportunityContactRole best: bestOcrs.values()) best.IsPrimary = true;
			update bestOcrs.values();
		}
		
	}

}
