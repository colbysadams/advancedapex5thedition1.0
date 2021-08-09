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
public without sharing class AppCustomSetting {
	
    @testvisible
    private static AppConfig__c testConfig = null;
	
	public static AppConfig__c getAppConfig()
	{
		if(Test.isRunningTest() && testConfig!=null) return testConfig;
		
		AppConfig__c theobject = AppConfig__c.getInstance('default');
		if(theObject==null || Test.isRunningTest()) 
		{
			theObject = new AppConfig__c();
			theObject.name = 'default';
			theObject.EnableDiagnostics__c = (Test.isRunningTest())? true: false;
			theObject.AppEnabled__c = true;
			if(!Test.isRunningTest()) Database.Insert(theobject);
			else testconfig = theObject;
		}
		return theObject;
	}

	public static Boolean diagnosticsEnabled
	{ 
		get
		{
			return GetAppConfig().EnableDiagnostics__c;
		}
	}
	
	public static Boolean appEnabled
	{
		get
		{
			return GetAppConfig().AppEnabled__c;
		}
	}
}
