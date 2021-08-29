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
public class TestForPackages {
    
    public static testMethod void recordTypeTest() {
    	// This will fail to work on any org that doesn't have record types defined on leads
    	// List<Lead> rtypes = [Select ID, RecordTypeID from Lead Limit 1];

		Boolean leadHasRecordType = 
			Schema.Sobjecttype.Lead.Fields.getMap().containskey('recordtypeid');
		
		String fieldString = 'ID ';
		if(leadHasRecordType) fieldString += ', RecordTypeID ';
		List<Lead> rtypes = 
			Database.Query('Select ' + fieldstring + ' from Lead Limit 1');
		if(rtypes.size()>0 && leadHasRecordType)
		{
			// Don't use rtypes[0].RecordTypeId;
			system.debug(rtypes[0].get('RecordTypeID'));
		}    	
    	system.debug(fieldString + ' ' + rtypes);
    }

	@istest
    public static void isNamespace()
    {
        system.debug(getNamespacePrefix());
    }
    
	// You'll normally have this static variable and the getNamespacePrefix function in a regular class,
	// not a test class. We just have it here for convenience in this example
	private static string storedPrefix = null;

	// Note - to test this function, add a namespace to your sfdx-project.json file.
	// See the scripts in the scripts directory for CLI commands to create scratch orgs with and without namespaces.
    public static String getNamespacePrefix()
    {
		if(storedPrefix!=null) return storedPrefix;
        Schema.DescribeFieldResult testField = Schema.sObjectType.Contact.fields.Level2__c;
        Integer theposition = testField.getName().length() - testField.getLocalName().length();
        if(theposition==0)
        {
            storedPrefix = ''; return storedPrefix;
        }
        // Subtract another 2 for the __ after the prefix
        storedprefix = testField.getName().substring(0, theposition-2);
        return storedPrefix;
    }

	@istest
    public static void testCorporateCurrency()
	{
		String corporate = corporateCurrency;
		System.assert(!Userinfo.isMultiCurrencyOrganization() || corporateCurrency!=null);
	}

	private static Map<String,double> 
		cachedCurrencyConversionMap = null;
	
	private static string m_CorporateCurrency = null;
	
	public static string corporateCurrency {
		get {
			getCurrencyConversionMap();
			return m_corporateCurrency;
		}
	}
	
	public static Map<String, double> getCurrencyConversionMap()
	{
		Boolean currencyTestMode = false;

		if(cachedCurrencyConversionMap!=null) 
			return cachedCurrencyConversionMap;

		if(Test.isRunningTest() && 
			!userinfo.isMultiCurrencyOrganization()) 
			currencyTestMode = true;
		if(!userinfo.isMultiCurrencyOrganization() && 
			!currencyTestMode) return null;

		List <SObject> ctypes = null;
		if(!currencyTestMode) ctypes  = 
			database.query('Select conversionrate, isocode, iscorporate from currencytype');

		Map<String, double> isoMap = new Map<String, double>();
		if(!currencyTestMode)
		{
			for(SObject ct: ctypes)
			{
				string ctCode = string.ValueOf(ct.get('isocode'));
				if(Boolean.valueOf(ct.get('iscorporate'))) 
				{
					m_CorporateCurrency = ctCode;
				}
				double conversionRate = double.valueOf(ct.get('conversionrate'));
				if(conversionRate!=0) isoMap.put(ctcode, 1/conversionRate);
			}
		}
		cachedCurrencyConversionMap = (currencyTestMode)? null: isoMap;
		return cachedCurrencyConversionMap;	
	}	
}

