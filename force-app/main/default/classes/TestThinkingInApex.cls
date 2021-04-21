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
public with sharing class TestThinkingInApex {
    
    @istest
    public static void TestSetFirstContactName() {
        List<Account> accounts = new List<Account>{
            new Account(name='a1'), new Account(name='a2')};
        insert accounts;
        test.startTest();
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName='c1',Email='c1@c1.com', AccountId = accounts[0].id), 
            new Contact(LastName='c2',Email='c2@c2.com', AccountId = accounts[1].id)};
        insert contacts;
        test.StopTest();

        Map<ID,Account> actResults = new Map<ID, Account>(
            [Select ID, First_Contact_Name__c, First_Contact_Email__c from Account]);

        // Verify the accounts for each contact
        for(Contact ct: contacts)
        {
            Account actToTest = actResults.get(ct.accountId);
            // We only used the last name in this test
            system.assertEquals(ct.LastName, actToTest.First_Contact_Name__c);
            system.assertEquals(ct.Email, actToTest.First_Contact_Email__c);
        }
    }

   @istest
    public static void TestSetFirstContactNameException() {
        List<Account> accounts = new List<Account>{
            new Account(name='a1'), new Account(name='a2')};
        insert accounts;
        test.startTest();
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName='c1',Email='c1@c1.com', AccountId = accounts[0].id), 
            new Contact(LastName='c2',Email='c2@c2.com', AccountId = accounts[1].id)};
        
        ThinkingInApex.fakeAccountInsertionException = true;
        insert contacts;
        test.StopTest();

        Map<ID,Account> actResults = new Map<ID, Account>(
            [Select ID, First_Contact_Name__c, First_Contact_Email__c from Account]);

        // Verify the accounts for each contact
        for(Contact ct: contacts)
        {
            Account actToTest = actResults.get(ct.accountId);
            // We only used the last name in this test
            system.assertNotEquals(ct.LastName, actToTest.First_Contact_Name__c);
            system.assertNotEquals(ct.Email, actToTest.First_Contact_Email__c);
        }
    }    
}
