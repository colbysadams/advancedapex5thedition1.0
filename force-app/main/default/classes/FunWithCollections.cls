
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
public class FunWithCollections {

    // The quickSet example demonstrates querying using sets and maps. The sample code here includes the
    // benchmarking code demonstrating that the map approach is faster.
    // Remember to set your debug log levels for ApexCode to Error in order to obtain accurate results
    // Increase the number of loops from 100 to 1000 for better accuracy
	@istest
    public static void quickSet()
	{
        // Initialize data
		List<Contact>cts = new List<Contact>();    
		for(Integer x=0;x<50;x++)    
		{      
			cts.add(new Contact(LastName = 'cttest_' + String.valueOf(x)));
		}
		
		insert cts;
		
        // Actual sample starts here

        Set<ID> contactIds;

        Integer starttime = Limits.getCpuTime();
        for(Integer repeat = 0; repeat < 100; repeat++)
        {
            contactIds = new Set<ID>();
            for(Contact ct: cts) contactIds.add(ct.id);
        }
        system.debug(LoggingLevel.error, 'Total time loops: ' + String.valueOf(Limits.getCpuTime() - starttime));

		List<Task> tasks = 
			[Select ID from Task 
			where Whoid in :contactIds Limit 500];
		
        Map<ID, Contact> contactMap;

        starttime = Limits.getCpuTime();
        for(Integer repeat = 0; repeat<100; repeat++)
        {
		    contactMap = new Map<ID, Contact>(cts);
        }
        system.debug(LoggingLevel.error, 'Total time maps: ' + string.valueOf(Limits.getCpuTime() - starttime));
		
		List<Task> tasks2 = 
			[Select ID from Task 
			where Whoid in :contactMap.keyset() Limit 500];
		
	}

    @istest
	public static void groupingObjects()
	{
        // Initialize data
		List<Contact>cts = new List<Contact>();    
		for(Integer x=0;x<50;x++)    
		{      
			cts.add(new Contact(LastName = 'cttest_' + String.valueOf(x)));
		}
		
		insert cts;
		
		List<Task> newTasks = new List<Task>();
		for(Integer x=0; x<50; x++)
		{
			newTasks.add(
				new Task(WhoID = cts[x].id, 
						ActivityDate = Date.Today().addDays(x), 
						Description='some task', Type='Call'));			
		}
		insert newTasks;
		
        // Actual sample starts here

		// cts is the list of input contacts
		Map<ID, Contact> contactMap = new Map<ID, Contact>(cts);
		
		List<Task> tasks = 
			[Select ID, ActivityDate, Description 
			from Task where Whoid in :contactMap.keyset() Order 
			By ActivityDate Desc Limit 500];
		
		Map<Date, List<Task>> tasksByWeek = new Map<Date, List<Task>>();
		
		for(Task t: tasks)
		{
			// Perform global task operation here
			
			
			// Group by week
			Date weekStart = t.ActivityDate.toStartOfWeek();
			if(tasksByWeek.get(weekStart)==null) 
				tasksByWeek.put(weekStart, new List<Task>());
			tasksByWeek.get(weekStart).add(t);
			
			// Perform week related operation here
		}
		
		system.debug(tasksByWeek);
		
	}

	@istest
	public static void caseSensitivity()
	{
		Map<String,Integer> intMap = new Map<String,Integer>{'A'=>0, 'b'=>1, 'C'=>2};
		system.assert(!intMap.containskey('a'));
		system.assert(!intMap.containskey('B'));

	}

    @istest
	public static void caseOnDescribe() {
        // Get global describe
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        
        System.Assert(gd.ContainsKey('CampaignMember'));
        System.Assert(gd.ContainsKey('campaignmember'));
        System.Assert(gd.ContainsKey('CAMPAIGNMEMBER'));
        system.debug(gd);

        System.Assert(gd.keyset().Contains('campaignmember'));
        System.Assert(!gd.keyset().Contains('CampaignMember'));
        System.Assert(!gd.keyset().Contains('CAMPAIGNMEMBER'));
        
    }

    @istest
	public static void objectKeys()
    {
		List<Contact>cts = new List<Contact>();    
		for(Integer x=0;x<5;x++)    
		{      
			cts.add(new Contact(LastName = 'cttest_' + String.valueOf(x)));
		}
		
		insert cts;

		// Create a map keyed on contacts
		Map<Contact, Integer> contactMap = new Map<Contact, Integer>();
		
		for(Integer x = 0; x< 5; x++)
		{
			contactMap.put(cts[x], x);
		}

		system.assertEquals(contactMap.size(),5);
		
		// Create another list to reference these
		List<Contact> sameContacts = new List<Contact>(cts);

		for(Integer x = 0; x< 5; x++)
		{
			samecontacts[x].AssistantName = 'person' + string.ValueOf(x);
			system.assertEquals(cts[x].AssistantName ,sameContacts[x].AssistantName);
			system.assertNotEquals(contactMap.get(cts[x]), x);
			contactMap.put(sameContacts[x], x);
		}
		system.debug('Size after adding the same contacts' + contactMap.size());
		system.assertNotEquals(contactMap.size(),5);
    }

    @istest
	public static void objectSets()
    {
		List<Contact>cts = new List<Contact>();    
		for(Integer x=0;x<5;x++)    
		{      
			cts.add(new Contact(LastName = 'cttest_' + String.valueOf(x)));
		}
		
		insert cts;

		// Create a map keyed on contacts
		Set<Contact> contactSet = new Set<Contact>();
		
		for(Integer x = 0; x< 5; x++)
		{
			contactSet.add(cts[x]);
		}

		system.assertEquals(contactSet.size(),5);
		
		// Create another list to reference these
		List<Contact> sameContacts = new List<Contact>(cts);

		for(Integer x = 0; x< 5; x++)
		{
			sameContacts[x].AssistantName = 'person' + string.ValueOf(x);
			system.assertEquals(cts[x].AssistantName ,sameContacts[x].AssistantName);
			system.assert(!contactSet.contains(cts[x]));
			contactSet.add(sameContacts[x]);
		}
		system.debug('Size after adding the same contacts' + contactSet.size());
		system.assertNotEquals(contactSet.size(),5);
		
    	
    }
    
    @istest
	public static void objectKeysCorrect()
    {
		List<Contact>cts = new List<Contact>();    
		for(Integer x=0;x<5;x++)    
		{      
			cts.add(new Contact(LastName = 'cttest_' + String.valueOf(x)));
		}
		
		insert cts;

		// Create a map keyed on contacts
		Map<ID, Integer> contactMap = new Map<ID, Integer>();
		
		for(Integer x = 0; x< 5; x++)
		{
			contactMap.put(cts[x].id, x);
		}

		system.assertEquals(contactMap.size(),5);
		
		// Create another list to reference these
		List<Contact> sameContacts = new List<Contact>(cts);

		for(Integer x = 0; x< 5; x++)
		{
			sameContacts[x].AssistantName = 'person' + string.ValueOf(x);
			system.assertEquals(cts[x].AssistantName ,sameContacts[x].AssistantName);
			system.assertEquals(contactMap.get(cts[x].id), x);
			contactMap.put(sameContacts[x].id, x);
		}
		system.assertEquals(contactMap.size(),5);
		
    	
    }   

	@istest
	public static void LimitUpdates()
	{
		List<Contact>cts = new List<Contact>();    
		for(Integer x=0;x<50;x++)    
		{      
			cts.add(new Contact(LastName = 'cttest_' + String.valueOf(x)));
		}
		
		insert cts;
		
		Map<ID,Contact> contactsToUpdate = new Map<ID, Contact>();
		
		// First set of operations
		for(Contact ct: cts)
		{
			// Do various operations
			// If an update is needed:
			contactsToUpdate.put(ct.id, ct);
			
		}
		
		// Second set of operations
		for(Contact ct: cts)
		{
			// Do various operations
			// If an update is needed:
			contactsToUpdate.put(ct.id, ct);
			
		}

		if(contactsToUpdate.size()>0) update contactsToUpdate.values();
		
		
	}

	// Remember to set the debug log level to debug or less before running this test to ensure
	// accurate results!
	@istest
	public static void ListOrSet()
	{
		List<Integer> listsLong = new List<Integer>();
		Set<Integer> setsLong = new Set<Integer>();
		List<Integer> listsShort = new List<Integer>();
		Set<Integer> setsShort = new Set<Integer>();
		for(Integer i = 0; i<10000; i++)
		{
			listsLong.add(i);
			setsLong.add(i);
		}
		for(Integer i = 0; i<100; i++)
		{
			listsShort.add(i);
			setsShort.add(i);
		}
		Test.startTest();
		Integer startTime = limits.getCpuTime();
		Boolean result;
		for(Integer i = 0; i< 10000; i++)
			result = listsLong.contains(i);
		System.debug(LoggingLevel.error, 'Long list contains: ' + String.valueOf(Limits.getCpuTime()-startTime));

		startTime = limits.getCpuTime();
		for(Integer i = 0; i< 10000; i++) result = setsLong.contains(i);
		System.debug(LoggingLevel.error, 'Long set contains: ' + String.valueOf(Limits.getCpuTime()-startTime));

		startTime = limits.getCpuTime();
		for(Integer y = 0; y<500; y++)
		{
			for(Integer i = 0; i< 100; i++)
				result = listsShort.contains(i);
		}
		System.debug(LoggingLevel.error, 'Short list contains: ' + String.valueOf(Limits.getCpuTime()-startTime));

		startTime = limits.getCpuTime();
		for(Integer y = 0; y<500; y++)
		{
			for(Integer i = 0; i< 100; i++)
				result = setsShort.contains(i);
		}
		System.debug(LoggingLevel.error, 'Short set contains: ' + String.valueOf(Limits.getCpuTime()-startTime));



	}


	// Remember to set the debug log level to debug or less before running this test to ensure
	// accurate results!
	// Similar test with strings instead. Note # of loops is less due to increased demand on each loop
	// Also this test includes the conversion from list to set in the outer loop.
	@istest
	public static void ListOrSetWithString()
	{
		List<String> listsLong = new List<String>();
		List<String> listsShort = new List<String>();
		for(Integer i = 0; i<10000; i++)
		{
			listsLong.add('test' + string.valueof(i));
		}
		for(Integer i = 0; i<100; i++)
		{
			listsShort.add('test' + string.valueof(i));
		}
		Test.startTest();
		Integer startTime = limits.getCpuTime();
		Boolean result;
		for(Integer y = 0; y<2; y++)
		{
			for(Integer i = 0; i< 10000; i++)
				result = listsLong.contains('test' + string.valueof(i));
		}
		System.debug(LoggingLevel.error, 'Long list contains: ' + String.valueOf(Limits.getCpuTime()-startTime));

		startTime = limits.getCpuTime();
		for(Integer y = 0; y<2; y++)
		{
			Set<String> setsLong = new Set<String>(listsLong);
			for(Integer i = 0; i< 10000; i++)
				result = setsLong.contains('test' + string.valueof(i));
		}
		System.debug(LoggingLevel.error, 'Long set contains: ' + String.valueOf(Limits.getCpuTime()-startTime));

		startTime = limits.getCpuTime();
		for(Integer y = 0; y<200; y++)
		{
			for(Integer i = 0; i< 100; i++)
				result = listsShort.contains('test' + string.valueof(i));
		}
		System.debug(LoggingLevel.error, 'Short list contains: ' + String.valueOf(Limits.getCpuTime()-startTime));

		startTime = limits.getCpuTime();
		for(Integer y = 0; y<200; y++)
		{
			Set<String> setsShort = new Set<String>(listsShort);
			for(Integer i = 0; i< 100; i++)
				result = setsShort.contains('test' + string.valueof(i));
		}
		System.debug(LoggingLevel.error, 'Short set contains: ' + String.valueOf(Limits.getCpuTime()-startTime));

	}

	@istest
	public static void eliminateDuplicateFields()
	{

		List<String> fieldList = new List<String>{'ID', 'Id', 'lastmodifieddate', 'LastModifiedDate'};

		// We don't actually need any data to verify the query
		List<Lead> leads;
		
		try {
			leads = Database.query('Select ' + string.join(fieldList, ',') + ' From Lead Limit 1');
		} catch (Exception ex) {
			system.debug('Query failure ' + ex.getMessage());
		}

		/* This approach may be marginally faster */
		/*
		Set<String> fieldSet = new Set<String>();
		String fields = string.join(fieldList,',');
		fieldSet.addAll(fields.toLowerCase().split(','));
		fieldList = new List<String>(fieldSet);
		*/
		

		Set<String> fieldSet = new Set<String>();
		String ourprefix = 'xyz' + '__';
		for(String f: fieldList)
		{
			f = f.toLowerCase();
			
			// Strip off your own namespace here if necessary
			if(!String.isEmpty(ourprefix) && f.startsWith(ourprefix)) f = f.replace(ourprefix,'');
			
			// Optionally test for presense of the field using describe info (not shown here)
			
			fieldSet.add(f);
		}
		fieldList = new List<String>(fieldSet);

		try {
			leads = Database.query('Select ' + string.join(fieldList, ',') + ' From Lead Limit 1');
			system.debug('This time it works');
		} catch (Exception ex) {
			system.debug('Query failure ' + ex.getMessage());
		}

	

	}



}
