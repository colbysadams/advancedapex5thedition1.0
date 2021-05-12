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
    public static void PrimaryOcrDeletionTest() {
        List<Opportunity> ops = new List<Opportunity>();
        // Note, you may need to adjust these numbers
		initTestObjects(ops, 100, 15, 15, 40, true);
        Test.StartTest();
        // Requery to get the opportunity contact roles
		List<OpportunityContactRole> ocrs = [Select ID, IsPrimary from OpportunityContactRole
											where IsPrimary=True And Opportunityid in :ops];
        // Delete them
		Boolean deleteFailed = false;
		try {
			delete ocrs;
		} catch (Exception ex) {
			deleteFailed = true;
		}
        Test.StopTest();
		// Make sure it failed
        system.assert(deleteFailed);
    }

    @istest
    public static void PrimaryOcrReplacementTestPositive() {
        List<Opportunity> ops = new List<Opportunity>();
        // Note, you may need to adjust these numbers
		initTestObjects(ops, 100, 0, 3, 100, true);
        Test.StartTest();
        // Requery to get the opportunity contact roles for each opportunity
		List<Opportunity> opswithocrs = [Select ID, (Select ID, IsPrimary from OpportunityContactRoles) from Opportunity
											where id in :ops];
        // Change primary to non-primary - no other change
		Map<ID, OpportunityContactRole> ocrsToUpdate = new Map<ID, OpportunityContactRole>();
		for(Opportunity op: opswithocrs) {
			for(OpportunityContactRole ocr: op.OpportunityContactRoles) 
			{
				if(ocr.isPrimary)
				{
					ocr.isPrimary = false;
					ocrsToUpdate.put(ocr.id, ocr);
				}
			}
		}
		Boolean replaceFailed = false;

		try {
			update ocrsToUpdate.Values();
		} catch (Exception ex) {
			replaceFailed = true;
		}
        Test.StopTest();
		System.assert(replaceFailed);
    }

    @istest
    public static void PrimaryOcrReplacementTestNegative() {
        List<Opportunity> ops = new List<Opportunity>();
        // Note, you may need to adjust these numbers
		initTestObjects(ops, 100, 0, 2, 100, true);
        Test.StartTest();
        // Requery to get the opportunity contact roles for each opportunity
		List<Opportunity> opswithocrs = [Select ID, (Select ID, IsPrimary from OpportunityContactRoles) from Opportunity
											where id in :ops];
        // Change primary to non-primary - no other change
		Map<ID, OpportunityContactRole> ocrsToUpdate = new Map<ID, OpportunityContactRole>();
		for(Opportunity op: opswithocrs) {
			for(OpportunityContactRole ocr: op.OpportunityContactRoles) 
			{
				if(ocr.isPrimary)
				{
					ocr.isPrimary = false;
					ocrsToUpdate.put(ocr.id, ocr);
				}
			}
		}
		for(Opportunity op: opswithocrs) {
			for(OpportunityContactRole ocr: op.OpportunityContactRoles) 
			{
				if(!ocr.isPrimary && !ocrsToUpdate.containsKey(ocr.id))
				{
					ocr.isPrimary = true;
					ocrsToUpdate.put(ocr.id, ocr);
				}
			}
		}

		Boolean replaceFailed = false;

		try {
			update ocrsToUpdate.Values();
		} catch (Exception ex) {
			replaceFailed = true;
		}
        Test.StopTest();
		System.assert(!replaceFailed);
    }	

    @istest
    public static void bulkOpportunityWithAccountsTest() {
        List<Opportunity> ops = initTestObjectsWithAccounts(100, 100, 40);
        Test.StartTest();
        insert ops;
        Test.StopTest();
        
        validateOCRs(ops);
        
    }

	// Prepare the specified number of opportunities, with contact roles on each.
	// The contact roles are distributed evenly among the number of contacts specified.
    public static void initTestObjects(List<Opportunity> newOpportunities, 
    	Integer numberOfOpportunities, Integer numberOfOtherOpportunities, 
    	Integer contactRolesPerOp, Integer numberOfContacts)
    {
		initTestObjects(newOpportunities, numberOfOpportunities, numberOfOtherOpportunities,
						contactRolesPerOp, numberOfContacts, false);
	}

	public static void initTestObjects(List<Opportunity> newOpportunities, 
    	Integer numberOfOpportunities, Integer numberOfOtherOpportunities, 
    	Integer contactRolesPerOp, Integer numberOfContacts, Boolean addPrimaryContactRole)
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
									isPrimary = (ocrNumber==0),
									ContactID = cts[contactNumber].id));
				contactNumber++;
				if(contactNumber >= numberOfContacts) contactNumber = 0;
			}
			
		}
		insert ocrList;
    }


	public static List<Opportunity> initTestObjectsWithAccounts(
		Integer numberOfOpportunities, Integer numberOfContacts, Integer maxActivitiesPerAccount)
    {
		Account testact = new Account(Name = 'testaccount');
		insert testact;

		List<Contact>cts = new List<Contact>();    
		for(Integer x=0;x<numberOfContacts;x++)    
		{      
			cts.add(new Contact(AccountID = testact.id, LastName = 'cttest_' + String.valueOf(x)));
		}
		
		insert cts;

		List<Task> tasks = new List<Task>();
		Integer taskcount = maxActivitiesPerAccount;
		for(Contact ct: cts) 
		{
			for(Integer t= 0 ; t< taskcount; t++)
			{
				tasks.add(new Task(WhoID = ct.id, Subject = ct.LastName + string.ValueOf(t)));
			}
			taskcount = (taskcount>maxActivitiesPerAccount)? 1: taskcount+1;
		}
		insert tasks;

		List<Opportunity> newOpportunities = new List<Opportunity>();

		for(Integer x=0; x<numberOfOpportunities; x++)
		{
			newOpportunities.add(
				new Opportunity(AccountID = testact.id, CloseDate = Date.Today().addDays(5), 
						Name = 'optest_' + String.valueOf(x), 
						StageName = 'Prospecting' ));	
		}

		// Don't insert the test opportunities - the unit test will do that
		return (newOpportunities);

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
