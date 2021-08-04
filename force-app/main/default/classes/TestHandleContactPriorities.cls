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
public class TestHandleContactPriorities {
    
    @TestSetup
	public static void initTestObjects()
    {
		Account testact = new Account(Name = 'testaccount');
		insert testact;

		List<Contact>cts = new List<Contact>();    
		for(Integer x=0;x<5;x++)    
		{      
			cts.add(new Contact(AccountID = testact.id, LastName = 'cttest_' + String.valueOf(x)));
		}
		
		insert cts;

		List<Opportunity> newOpportunities = new List<Opportunity>();

		for(Integer x=0; x<10; x++)
		{
			newOpportunities.add(
				new Opportunity(AccountID = testact.id, CloseDate = Date.Today().addDays(5), 
						Name = 'optest_' + String.valueOf(x), 
						StageName = 'Prospecting',
                        Amount = 10000 ));	
		}

		insert newOpportunities;

        List<OpportunityContactRole> ocrs = new List<OpportunityContactRole>();
        for(Integer x=0; x<10; x++)
        {
            ocrs.add(New OpportunityContactRole(OpportunityID = newOpportunities[x].id, ContactID = cts[(Integer)(x/2)].id, IsPrimary = true ));
        }
        insert ocrs;

    }


    // Note here the challenge of testing the insertion condition in this case 

    @istest
    static void TestAddPriority()
    {

        List<Contact> cts = [Select ID from Contact];

        Test.startTest();
        system.debug('Starting test');

        for(Contact ct: cts) ct.Contact_Priority__c = 6;

        update cts;

        Test.stopTest();

        List<Contact> contactResults = [Select ID, Contact_Priority__c from Contact where ID in :cts];
        List<Opportunity> opportunityResults = [Select ID, Contact_Priority__c from Opportunity];

        List<Task> tasks = [Select ID from Task where OwnerID = :UserInfo.getUserId() And Type='Other' And Subject = 'Hot Opportunity!'];

        System.assertEquals(opportunityResults.size(), tasks.size());
        for(Opportunity op: opportunityResults) system.assertEquals(6, op.Contact_Priority__c);
    }
}
