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
public with sharing class ConfigSettingController {

    // Return 2 copies of the same object - one to track as the original value
    @auraEnabled
    public static List<AppConfig__c> getCSListObject(String settingName)
    {
        List<AppConfig__c> settings = [Select ID, Name, AppEnabled__c, EnableDiagnostics__c from AppConfig__c where Name = :settingName];
        List<AppConfig__c> results = new List<AppConfig__c>();
        results.add((settings.size()==0)? new AppConfig__c(Name = settingName, AppEnabled__c = false, EnableDiagnostics__c = null): settings[0]);
        results.add(results[0].clone(true, false, false, false));
        return results;
    }

    @auraEnabled
    public static void saveCSListObject(AppConfig__c configObject, AppConfig__c originalObject, String settingName)
    {
        if(configObject == null || originalObject == null)
            throw new AuraHandledException('No data provided to save');
        AppConfig__c currentValue = getCSListObject(settingName)[0];
        Boolean concurrencyError = false;
        // If it's a new object, the existing value must also be null
        if(configObject.id != currentValue.id) concurrencyError = true;
        if(!concurrencyError && configObject.id!=null )
        {
            if(originalObject.AppEnabled__c != currentValue.AppEnabled__c ||
                originalObject.EnableDiagnostics__c != currentValue.EnableDiagnostics__c) concurrencyError = true;
        }
        if(concurrencyError) throw new AuraHandledException('The setting you are trying to save has been modified - restoring original values');

        upsert configObject;
    }


}