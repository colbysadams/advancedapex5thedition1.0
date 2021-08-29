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
public class TestPersonAccount {
 
    static testMethod void testWithContacts() {
        List<Contact> contacts = createContacts('patst', 3);
        contacts[0].LeadSource='Web';
        contacts[1].LeadSource='Phone Inquiry';
        contacts[2].LeadSource='Other';
        Test.StartTest();
        insert contacts;
        Test.StopTest();
        // Seealldata is false, so we'll get the same 3 contacts
        Map<ID, Contact> contactMap = 
        	new Map<ID, Contact>([Select ID, Level2__c from Contact]);
       	system.assertEquals(contactMap.get(contacts[0].id).Level2__c,'Primary');
       	system.assertEquals(contactMap.get(contacts[1].id).Level2__c,'Primary');
       	system.assertEquals(contactMap.get(contacts[2].id).Level2__c,'Secondary');
    }
    
    static testMethod void testWithAccounts() {
        List<Contact> contacts = createContacts('patst', 3);
        List<Account> accounts = createAccounts('patest', 3);
        contacts[0].LeadSource='Web';
        contacts[1].LeadSource='Phone Inquiry';
        contacts[2].LeadSource='Other';
        insert contacts;
        String leadSourceAlias = PersonAccountSupport.getPersonAccountAlias('LeadSource');
	    String levelAlias = PersonAccountSupport.getPersonAccountAlias('Level2__c');
        if(PersonAccountSupport.isPersonAccountOrg())
        {
            accounts[0].put(leadSourceAlias,'Web');
            accounts[1].put(leadSourceAlias,'Phone Inquiry');
            accounts[2].put(leadSourceAlias,'Other');
        }
        else {
            PersonAccountSupport.fakePersonContactIDs = new List<ID>();
            PersonAccountSupport.fakePersonAccountDuringTest = true;
            for(Contact ct: contacts) 
        	    PersonAccountSupport.fakePersonContactIDs.add(ct.id);
        }
        Test.StartTest();
        insert accounts;
        Test.StopTest();
        // Seealldata is false, so we'll get the same 3 contacts
        Map<ID, Contact> contactMap = 
        	new Map<ID, Contact>(
        		[Select ID, Level2__c from Contact]);
       	system.assertEquals('Primary', contactMap.get(contacts[0].id).Level2__c);
       	system.assertEquals('Primary', contactMap.get(contacts[1].id).Level2__c);
       	system.assertEquals('Secondary',contactMap.get(contacts[2].id).Level2__c);
        if(PersonAccountSupport.isPersonAccountOrg())
        {

            Map<ID, Account> accountMap = 
        	new Map<ID, Account>(
        		(List<Account>)Database.query('Select ID, ' + levelAlias +' from Account'));
            system.assertEquals('Primary', accountMap.get(accounts[0].id).get(levelAlias));
            system.assertEquals('Primary', accountMap.get(accounts[1].id).get(levelAlias));
            system.assertEquals('Secondary',accountMap.get(accounts[2].id).get(levelAlias));
        }
    }  

    public static List<Contact> createContacts(String baseName, Integer count)
    {
    	List<Contact> results = new List<Contact>();
    	
    	for(Integer x = 0; x< count; x++)
    	{
			results.add(new Contact(LastName = baseName + String.valueOf(x) ));
    	}
		
		return results;	
    	
    }

    // This will create regular accounts on a standard org and person accounts on
    // a person account org
    public static List<Account> createAccounts(String baseName, Integer count)
    {
        String recordTypeId = null;
        if(PersonAccountSupport.isPersonAccountOrg())
        {
            List<RecordType> personRecordTypes =
                Database.query('Select ID from RecordType where IsPersonType = true Limit 1');
            if(personRecordTypes.size()>0) recordTypeId = personRecordTypes[0].id;
        }
    	List<Account> results = new List<Account>();
    	
    	for(Integer x = 0; x< count; x++)
    	{
            Account act = new Account();
            String Name = baseName + String.valueOf(x);
            if(recordTypeId!=null) 
            {   
                act.put('RecordTypeId', recordTypeId);
                // Person account has LastName, not Name
                act.put('LastName', Name);
            }
            else act.Name = Name;
			results.add(act);
    	}
		
		return results;	
    }

}
