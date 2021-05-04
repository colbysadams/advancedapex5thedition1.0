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

@istest
public class TestBulkPatterns {
    
    @istest
    public static void bulkOpportunityTest() {
        List<Opportunity> ops = new List<Opportunity>();
        // Note, you may need to adjust these numbers
		initTestObjects(ops, 100, 15, 15, 40);
        //initTestObjects(ops, 50, 10, 10, 20);   // for the awful example
        Test.StartTest();
        for(Opportunity op: ops) op.StageName = 'Qualification';
        update ops;
        Test.StopTest();
        
        validateOCRs(ops);
        
    }

    @istest
    static void createTaskTest()
    {
    	Integer numberOfOpportunities = 100;
    	//Integer numberOfOpportunities = 50; // for the awful example
        List<Opportunity> ops = new List<Opportunity>();
		for(Integer x=0; x<numberOfOpportunities; x++)
		{
			ops.add(new Opportunity(
				CloseDate = Date.Today().addDays(5), 
				Name = 'optest_' + String.valueOf(x), 
				StageName = 'Prospecting' ));	
		}
		
		insert ops;

        Test.StartTest();
        for(Opportunity op: ops) op.StageName = 'Qualification';
        update ops;
        Test.StopTest();

		List<Task> tasks = 
			[SELECT ID, OwnerID, WhatID, Status, Subject, Type 
				from Task 
				where OwnerID = :UserInfo.getUserID() 
				And Type='Other' And IsClosed = False 
				And Subject = 'Assign Primary Contact' ];
		system.assertEquals(NumberOfOpportunities, tasks.size());
    	
    } 

	// Prepare the specified number of opportunities, with contact roles on each.
	// The contact roles are distributed evenly among the number of contacts specified.
    public static void initTestObjects(List<Opportunity> newOpportunities, 
    	Integer numberOfOpportunities, Integer numberOfOtherOpportunities, 
    	Integer contactRolesPerOp, Integer numberOfContacts)
    {
    	if(numberOfContacts < contactRolesPerOp) 
    		numberOfContacts = contactRolesPerOp;

		List<Contact>cts = new List<Contact>();    
		for(Integer x=0;x<numberOfContacts;x++)    
		{      
			cts.add(new Contact(LastName = 'cttest_' + String.valueOf(x)));
		}
		
		insert cts;

		newOpportunities.clear();
		for(Integer x=0; x<numberOfOpportunities; x++)
		{
			newOpportunities.add(
				new Opportunity(CloseDate = Date.Today().addDays(5), 
						Name = 'optest_' + String.valueOf(x), 
						StageName = 'Prospecting' ));	
		}

		// Insert the test opportunities
		insert newOpportunities;
		
		List<Opportunity> otherOpportunities = new List<Opportunity>();
		for(Integer x=0; x<numberOfOtherOpportunities; x++)
		{
			otherOpportunities.add(
				new Opportunity(CloseDate = Date.Today().addDays(5), 
				Name = 'otherops_' + String.valueOf(x + NumberOfOpportunities), 
				StageName = 'Prospecting' ));	
		}
		
		insert otherOpportunities;
		// Combine the two for creating OpportunityContactRoles
		otherOpportunities.addall(newOpportunities);	
		
		// Now insert contact roles
		List<OpportunityContactRole> ocrList = new List<OpportunityContactRole>();
		Integer contactNumber = 0;
		for(Opportunity op: otherOpportunities)
		{
			for(Integer ocrNumber = 0; ocrNumber < contactRolesPerOp; ocrNumber++)
			{
				ocrList.add(
					new OpportunityContactRole(OpportunityID = op.id, 
									ContactID = cts[contactNumber].id));
				contactNumber++;
				if(contactNumber >= numberOfContacts) contactNumber = 0;
			}
			
		}
		insert ocrList;
    }

    public static void validateOCRs(List<Opportunity> ops)
    {
    	// Get map for IDs
    	Map<ID, Opportunity> opMap = new Map<ID, Opportunity>(ops);
    	
    	// Query for primary Contacts
    	List<OpportunityContactRole> ocrs = 
    		[SELECT ID, OpportunityID from OpportunityContactRole 
    			where OpportunityID in :opMap.keyset() 
    			And IsPrimary= true];
    	
    	// Create set of opportunity IDs with primary contacts
    	Set<ID> opportunitiesWithPrimaryContact = new Set<ID>();
    	for(OpportunityContactRole ocr: ocrs) 
    		opportunitiesWithPrimaryContact.add(ocr.OpportunityID);
    	
    	// Now make sure every opportunity has a primary contact role
    	for(Opportunity op: ops) 
    		System.Assert(opportunitiesWithPrimaryContact.contains(op.id));

		// Here's another approach that accomplishes the same validation with a single query
		List<Opportunity> opResults = 
			[SELECT ID, 
				(SELECT ID from OpportunityContactRoles 
					where IsPrimary = true) 
				from opportunity where ID in :opmap.keyset() ];
    	
    	for(Opportunity op: opResults) 
    		System.Assert(op.OpportunityContactRoles.size()==1);	
    }
}
