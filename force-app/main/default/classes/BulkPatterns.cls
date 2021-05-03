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

	/* Bad implementation. Not included in the book - just used for limits comparison
        and to demonstrate what an Apex beginner who did not receive a proper education might do...
        If you decide to run it, reduce the number of objects by setting the data initialization in bulkOpportuniityTest to:
        initTestObjects(ops, 50, 10, 10, 20); 
        And the opportunity count in createTaskTest to 50.
		When testing, set the Apex debug log level to 'Error', the Profiling level to 'Info', and the to 'None'
        
        In one sample run, the results I saw for bulkOpportunityTest were:
        Number of SOQL queries: 100 out of 100 ******* CLOSE TO LIMIT
        Number of query rows: 16000 out of 50000
        Number of SOSL queries: 0 out of 20
        Number of DML statements: 51 out of 150
        Number of DML rows: 100 out of 10000
        Maximum CPU time: 1269 out of 10000

        And for createTaskTest:
        Number of SOQL queries: 100 out of 100 ******* CLOSE TO LIMIT
        Number of query rows: 0 out of 50000
        Number of SOSL queries: 0 out of 20
        Number of DML statements: 51 out of 150
        Number of DML rows: 100 out of 10000
        Maximum CPU time: 973 out of 10000
    */

	public static void afterUpdateOpportunityAwful(
		List<Opportunity> newList, Map<ID, Opportunity> oldMap)
	{
		// Pattern 1 - terrible implementation
		
		// Get OpportunityContactRoles
		for(Opportunity op: newList)
		{
			if(op.StageName == oldMap.get(op.id).StageName) continue;	// Only process changes to stagename
			
            // SOQL inside of a loop! Horrific!
			List<OpportunityContactRole> ocrs = 
                [Select ID, ContactID, IsPrimary from OpportunityContactRole where OpportunityID = :op.id];
			
			if(ocrs.size()==0)
			{
				// No associated contacts at all - 
				// create a new task for the owner to create said contact
				// Is task already set?
				List<Task> tasks = 
					[SELECT ID, OwnerID, WhatID, Status, Subject, Type 
						from Task 
						where OwnerID = :op.OwnerID 
						And Type='Other' 
						And WhatID = :op.ID 
						And IsClosed = False 
						And Subject = 'Assign Primary Contact'   ];
				if(tasks.size()>0) continue;	// Already set
				
				Task t = new Task(OwnerID = op.OwnerID, 
							Type='Other', WhatID = op.ID, 
							Subject = 'Assign Primary Contact', 
							ActivityDate = Date.Today().AddDays(3) );
				insert t;   // DML inside of a loop! Just as bad!
				continue;
			}
			
			// If primary exists, we're done
			Boolean primaryFound = false;
			for(OpportunityContactRole ocr: ocrs)
			{
				if(ocr.IsPrimary)
				{
					primaryFound = true;
					break;
				}
				
			}
			if(primaryFound) continue;
			
			// Get a list of the contacts
			List<ID> contactIdsForOps = new List<ID>();
			for(OpportunityContactRole ocr: ocrs)
			{
				contactIdsForOps.add(ocr.ContactID);
			}
			
			// Now query the contacts with their OpportunityContactRoles
			Map<ID, Contact> contactsForOps = 
				new Map<ID, Contact>(
					[Select ID, 
						(Select ID, IsPrimary from OpportunityContactRoles) 
						from Contact where ID in :contactIdsForOps]);

			// Now figure out which of the OpportunityContactRoles should be set to primary
			OpportunityContactRole bestOcr = null;
			Integer bestContactAllOcrCount = 0;
			Integer bestContactPrimaryOcrCount = 0;
			
			for(OpportunityContactRole ocr: ocrs)
			{
				Contact currentContact = contactsForOps.get(ocr.ContactID);
				Integer primaryCount = 0;
				for(OpportunityContactRole testOcr: currentContact.OpportunityContactRoles)
				{
					if(testOcr.IsPrimary) primaryCount ++;
				}
				if(bestOcr == null || 
					primaryCount > bestContactPrimaryOcrCount ||
					(primaryCount == bestContactAllOcrCount && 
						currentContact.OpportunityContactRoles.size()> bestContactAllOcrCount))
				{
					bestOcr = ocr;
					bestContactAllOcrCount = currentContact.OpportunityContactRoles.size();
					bestContactPrimaryOcrCount = primaryCount;
				}
			}
			bestocr.IsPrimary = true;
			update bestOcr; // Another DML inside of a loop
		}

		
	}


}
