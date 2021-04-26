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
public with sharing class TestSOQLQueryLimits {

    // Demonstration of using a single query for an object and related object to reduce SOQL calls
    // First examples shows a straightforward approach:
    
    @istest
    static void testContactsWithAccountRevenueTwoQueries() {
        // Set up a dummy account and contact
        Account newact = new Account(Name = 'testaccount');
        insert newact;
        Contact newct = new Contact(LastName = 'testcontactln');
        newct.AccountId = newact.id;
        insert newct;
        
        Test.startTest();
        
        // Query for contact info
        // The where term represents the criteria you are using to choose contacts to work with
        List<Contact> cts = [SELECT ID, AccountID from Contact where Name = 'testcontactln'];
        
        // Some code that operates on the contacts here....
        
        // Get list of account IDs.
        Set<ID> accountIds = new Set<ID>();
        for(Contact ct: cts) 
        	if(ct.AccountID!=null) accountIds.add(ct.AccountID);
        
        if(accountIds.size()>0)
        {
        	List<Account> accounts = [Select ID, AnnualRevenue from Account where ID in :accountids];
        	for(Account accountfound: accounts) 
        		if(accountfound.AnnualRevenue == null) accountfound.AnnualRevenue = 500;
        	update accounts;
        }
        
        Test.stopTest();
        
        // Make sure it worked
       	if(accountIds.size()>0)
		{
       		List<Account> accounts2 = [Select ID, AnnualRevenue from Account where ID in :accountids];
       		for(Account accountFound: accounts2) system.assertEquals(500, accountFound.AnnualRevenue);
		}
        
        
    }
    
	// Second example shows how you can use a related query
    @istest
    static void testContactsWithAccountRevenueRelatedQuery() {
        // Set up a dummy account and contact
        Account newact = new Account(Name = 'testaccount');
        insert newact;
        Contact newct = new Contact(LastName = 'testcontactln');
        newct.AccountId = newact.id;
        insert newct;
        
        Test.startTest();
        
        // Query for contact info and annual revenue on account in a single query
        // The where term represents the criteria you are using to choose contacts to work with
        List<Contact> cts = [SELECT ID, AccountID, Account.ID, Account.AnnualRevenue from Contact where Name = 'testcontactln'];

        // Some code that operates on the contacts here....
        
        Map<ID, Account> accountsToUpdate = new Map<ID,Account>();
        
        for(Contact ct: cts)
        {
        	if (ct.Account.AnnualRevenue == null) 
        	{
        		ct.Account.AnnualRevenue = 500;
        		accountsToUpdate.put(ct.AccountID, ct.Account);
        	}
        }
        
		if(accountsToUpdate.size()>0) 
			update accountsToUpdate.values();
        
        Test.stopTest();
        
        // Make sure it worked
       	if(accountsToUpdate.size()>0)
		{
       		List<Account> accounts2 = [Select ID, AnnualRevenue from Account where ID in :accountstoupdate.keyset()];
       		for(Account accountFound: accounts2) system.assertEquals(500, accountFound.AnnualRevenue);
		}
        
        
    }   

    // Third example shows an improved version of the two query approach
    @istest
    static void testContactsWithAccountRevenueTwoQueryImproved() {
        // Set up a dummy account and contact
        Account newact = new Account(Name = 'testaccount');
        insert newact;
        Contact newct = new Contact(LastName = 'testcontactln');
        newct.AccountId = newact.id;
        insert newct;
        
        Test.startTest();
        
        // Query for contact info
        // The where term represents the criteria you are using to choose contacts to work with
        List<Contact> cts = [SELECT ID, AccountID from Contact where Name = 'testcontactln'];
        
        // Some code that operates on the contacts here....
        
        // Get list of account IDs.
        Set<ID> accountIds = new Set<ID>();
        for(Contact ct: cts) 
        	if(ct.AccountID!=null) accountIds.add(ct.AccountID);
        
        if(accountIds.size()>0)
        {
        	List<Account> accounts = [Select ID, AnnualRevenue from Account where ID in :accountids];
        	List<Account> accountsToUpdate = new List<Account>();

            for(Account accountFound: accounts) 
        		if(accountFound.AnnualRevenue == null) 
                {
                    accountFound.AnnualRevenue = 500;
                    accountsToUpdate.add(accountFound);
                }
        	if(accountsToUpdate.size()>0) update accountsToUpdate;
        }
        
        Test.stopTest();
        
        // Make sure it worked
       	if(accountIds.size()>0)
		{
       		List<Account> accounts2 = [Select ID, AnnualRevenue from Account where ID in :accountids];
       		for(Account accountFound: accounts2) system.assertEquals(500, accountFound.AnnualRevenue);
		}
        
        
    }
    


}
