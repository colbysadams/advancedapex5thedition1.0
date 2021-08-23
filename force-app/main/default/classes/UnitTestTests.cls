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
public class UnitTestTests {
    
    @istest
    public static void TestOpportunityCreation()
    {
        List<Opportunity> newopportunities = createOpportunities1('optest_', 10);
		for(Opportunity op: newOpportunities)
		{
			op.CloseDate = Date.Today().addDays(5);
			op.StageName = 'Prospecting';
		}
		
		// Insert the test opportunities
		insert newOpportunities;

    }

    @istest
    public static void TestLeadCreation()
    {
        List<Lead> newLeads = createLeads('ldtest_', 10);
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        dml.DuplicateRuleHeader.runAsCurrentUser = false;
        database.insert(newLeads, dml);
    }

    @istest
    public static void TestLeadCreation2()
    {
        List<Lead> newLeads = Test.loadData(Lead.getSObjectType(), 'LeadData');

        List<Lead> results = [Select FirstName, LastName, Company, EMail from Lead];
        system.debug(results);
    }

	@istest
	public static void TestExceptionHandler()
	{
		List<Opportunity> newopportunities = createOpportunities1('optest_', 10);
		for(Opportunity op: newOpportunities)
		{
			op.CloseDate = Date.Today().addDays(5);
			op.StageName = 'Prospecting';
		}

		TestingApex.fakeException = true;
		TestingApex.InsertOpportunities(newopportunities);
	}

    // Simple version - no defaults
    public static List<Opportunity> createOpportunities1
    	(String baseName, Integer count)
    {
    	List<Opportunity> results = new List<Opportunity>();
    	for(Integer x = 0; x< count; x++)
    	{
			results.add(new Opportunity(Name = baseName + String.valueOf(x) ));
    	}
        // Demonstrates setting default fields using a static resource
        setDefaultFields('Opportunity', results);

		return results;	
    }

    // Initialize default field values
    public static List<Opportunity> createOpportunities2
    	(String baseName, Integer count)
    {
    	List<Opportunity> results = new List<Opportunity>();
    	for(Integer x = 0; x< count; x++)
    	{
			Opportunity op = (Opportunity)Opportunity.sObjectType.newSObject(null, true);
			op.Name = baseName + String.valueOf(x);
			results.add(op);
    	}

        // Demonstrates setting default fields using a static resource
        setDefaultFields('Opportunity', results);

		return results;	
    }

    public static List<Lead> createLeads(String baseName, Integer count)
    {
        List<Lead> results = new List<Lead>();
        for(Integer x = 0; x< count; x++)
        {
            String xs = String.valueOf(x);
            results.add(new Lead(FirstName = 'Jose', LastName = basename+xs, Company = basename, email = basename+xs+'@test.com'));
        }
        return results;
    }

	public static Boolean setDefaultFields(String objectType, List<SObject> theObjects)
    {
    	List<StaticResource> resources = 
    		[Select Body from StaticResource 
    		where Name = 'DefaultFieldValues' ];
    	if(resources.size()==0) return false;
    	String contents = resources[0].Body.ToString();
    	if(contents==null) return false;
    	List<String> lines = contents.split('\\n');
    	for(String line:lines)
    	{
    		List<String> entries = line.split(':');
    		try
    		{
    			if(entries[0]==objectType)
    			{
    				List<String> fieldinfo = entries[1].split('=');
    				for(SObject obj: theObjects)
    				{
						// Implemented only for strings
    					obj.put(fieldinfo[0], fieldinfo[1]);	
    				}
    			}
    		}
    		catch(Exception ex){}
    	}
    	return false;
    }   

}
