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

public with sharing class ThinkingInApex {

	private static Boolean userCacheLoaded = false;
	private static Boolean userIsSpecial = false;
	private static String userTimeZone = null;	

	public static Boolean isUserSpecial()
	{
		if(userCacheLoaded) return userIsSpecial;
		cacheUserInfo();
		return userIsSpecial;	
	}

	public static String userTimeZone()
	{
		if(userCacheLoaded) return userTimeZone;
		cacheUserInfo();
		return userTimeZone;	
	}

	
	private static void cacheUserInfo()
	{
		if(userCacheLoaded) return;
		User u = [Select UserIsSpecial__c, TimeZoneSidKey from User where ID = :UserInfo.getUserId()];
    	userIsSpecial = u.UserIsSpecial__c;
    	userTimeZone = u.TimeZoneSidKey;
		userCacheLoaded = true;
	}

	@testvisible
	private static Boolean fakeAccountInsertionException = false;

	public static Boolean disableContactTriggers = false;

	public static void afterInsertContact(List<Contact> contacts)
	{
		Set<ID> accountIDs = new Set<ID>();	// Get all of the account IDs for the contacts

		for(Contact ct: contacts) if(ct.accountId!=null) accountIDs.add(ct.AccountId);

		// Only query those accounts for the contacts that do not yet have First_Contact_Name set
		Map<ID, Account> accounts = 
			new Map<ID, Account>(
				[Select ID, First_Contact_Email__c, First_Contact_Name__c 
				from Account where ID in :accountIDs And First_Contact_Name__c = null ]);
		// Exit if there are no accounts to set
		if(accounts.size()==0) return;

		// We don't need to keep track of those that need to be updated, as by definition
		// all of these accounts have a new first contact

		for(Contact ct: contacts) 
			if(ct.accountId!=null)
			{
				Account act = accounts.get(ct.accountId);
				// Note, contact name property is not yet available in the after insert trigger
				act.First_Contact_Name__c = ((ct.FirstName!=null)?ct.FirstName + ' ':'') + ct.LastName;
				act.First_Contact_Email__c = ct.Email;
			}

		try 
		{
			if(fakeAccountInsertionException) accounts.values().get(0).First_Contact_Email__c = 'hello';
			update accounts.values();
		} catch(Exception ex)
		{
			// Code to report an error!
			system.debug('An exception occurred ' + ex.getMessage());
		}

	}

}
