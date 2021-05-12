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
		This solution uses batch Apex to move the intensive operation into
		a separate execution context
	*/
	public static void afterInsertOpportunityFutureSupport(
		List<Opportunity> newList, Map<ID, Opportunity> newMap)
	{
		if(system.isFuture())
		{
			// This scenario is a problem - see text for discussion
		}
		addMissingContactRoles(newMap.keyset());
	}

	@future
	public static void addMissingContactRoles(Set<ID> opids)
	{
		List<Opportunity> insertedOps = [Select ID, AccountID, (Select ID, IsPrimary from OpportunityContactRoles) from Opportunity where Id in :opids];

		List<Opportunity> opsToProcess = new List<Opportunity>();
		for(Opportunity op: insertedOps) if(op.OpportunityContactRoles.size()==0 && op.AccountId!=null) opsToProcess.add(op);

		if(opsToProcess.size()==0) return;	// Nothing to do

		// We want to find the contact on each account with the most activities
		// Get a list of account
		Set<ID> accountIds = new Set<ID>();
		for(Opportunity op: opsToProcess) if(op.AccountID!=null) accountIDs.add(op.AccountID);
		
		Map<ID, Contact> possibleContacts = new Map<ID, Contact>([Select ID, AccountID from Contact where AccountID in :accountIds]);
		// How do we count activities on all contacts on all accounts?

		List<AggregateResult> counts = [Select count(Id) taskCount, whoID theContactID from Task where WhoID in :possibleContacts.keyset() Group By WhoID];

		// Find the contact with the most activities for each account
		Map<ID, AggregateResult> bestContactByAccount = new Map<ID, AggregateResult>();
		for(AggregateResult ar: counts) 
		{
			ID accountID = possibleContacts.get((ID)(ar.get('theContactID'))).AccountID;
			if(!bestContactByAccount.containsKey(accountID)) 
			{
				bestContactByAccount.put(accountID, ar);
			}
			else 
			{
				AggregateResult currentAr = bestContactByAccount.get(accountID);
				if((Integer)currentAr.get('taskCount') < (Integer)ar.get('taskCount')) bestContactByAccount.put(accountID, ar);
			}
		}
		
		List<OpportunityContactRole> ocrsToInsert = new List<OpportunityContactRole>();
		for(Opportunity op: opsToProcess) 
		{
			AggregateResult currentAr = bestContactByAccount.get(op.AccountId);
			if(currentAr==null) continue; 	// No contacts on the account
			ocrsToInsert.add(new OpportunityContactRole(OpportunityID = op.id, ContactID = (ID)(currentAr.get('theContactID')), IsPrimary = true));
		}

		if(ocrsToInsert.size()>0) insert ocrsToInsert;

	}

	// Don't allow deletetion of primary contact role
	public static void beforeDeleteOpportunityContactRoleSupport(
		List<OpportunityContactRole> oldList)
	{
		for(OpportunityContactRole ocr: oldList)
		{
			if(ocr.isPrimary) ocr.addError('You may not delete a primary contact. Choose another primary contact first.');
		}
	} 

	public Class OcrException extends Exception	{}

	// Don't allow update of a primary contact role to non-primary unless another is being set to primary
	public static void beforeUpdateOpportunityContactRoleSupport(
		List<OpportunityContactRole> newList, Map<ID, OpportunityContactRole> oldMap) 
	{
		// We need to group the contact roles by opportunity
		Map<ID, List<OpportunityContactRole>> ocrsByOp = new Map<ID, List<OpportunityContactRole>>(); 
		for(OpportunityContactRole ocr: newList)
		{
			ID opId = ocr.OpportunityID;
			if(!ocrsByOp.containsKey(opId)) ocrsByOp.put(opId, new List<OpportunityContactRole>());
			ocrsByOp.get(opid).add(ocr);
		}
		for(ID opID: ocrsByOp.keyset())
		{
			// Just make sure there's at least one primary opportunity contact role if the primary changed
			Boolean primaryChanged = false;
			Boolean primaryFound = false;
			for(OpportunityContactRole ocr: ocrsByOp.get(opID))
			{
				if(!ocr.isPrimary && oldMap.get(ocr.id).isPrimary) primaryChanged = true;
				if(ocr.isPrimary) { primaryFound = true; break; }
			}
			if(!primaryFound && primaryChanged) throw new OcrException('Attempting to remove a primary contact without replacement');
		}

	}


}

