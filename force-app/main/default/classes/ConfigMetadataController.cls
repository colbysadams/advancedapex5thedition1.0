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

public with sharing class ConfigMetadataController {

    @AuraEnabled
    public static List<MDSetting__mdt> getCustomMetadataObjects(String MDName)
    {
        List<MDSetting__mdt> settings = [Select DeveloperName, MasterLabel, BooleanSetting__c, TextSetting__c from MDSetting__mdt where DeveloperName = :MDName];
        List<MDSetting__mdt> results = new List<MDSetting__mdt>();
        results.add((settings.size()==0)? new MDSetting__mdt(DeveloperName = MDName, Label = MDName, BooleanSetting__c = false, TextSetting__c = null): settings[0]);
        results.add(results[0].clone(true, false, false, false));
        return results;
    }

    @auraEnabled
    public static String saveCustomMetadataObject(MDSetting__mdt configObject, MDSetting__mdt originalObject, String MDName)
    {
        if(configObject == null || originalObject == null)
            throw new AuraHandledException('No data provided to save');

        // See if it exists?
        MDSetting__mdt currentObject = MDSetting__mdt.getInstance(MDName);
        Metadata.CustomMetadata customMetadataRecord;

        if(currentObject!=null)
        {
            system.debug(originalObject);
            system.debug(currentObject);
            // If one already exists, see if any of the values have changed
            if(originalObject.BooleanSetting__c != currentObject.BooleanSetting__c ||
                originalObject.TextSetting__c != currentObject.TextSetting__c) 
            {
                throw new AuraHandledException('The setting you are trying to save has been modified - restoring original values');
            }
            // Get the existing object as metadata
            List<String> componentNameList = new List<String>{'MDSetting__mdt.' + MDName};
            List<Metadata.Metadata> components = Metadata.Operations.retrieve(Metadata.MetadataType.CustomMetadata, componentNameList);
            customMetadataRecord = (Metadata.CustomMetadata)components.get(0);
        }
        else {
           // It's a new object
           customMetadataRecord = new Metadata.CustomMetadata();
           customMetadataRecord.fullName = 'MDSetting__mdt.' + MDName;
           customMetadataRecord.label = MDName;
        }
        // Set the field values
        setFieldValue(customMetadataRecord.values, 'BooleanSetting__c', configObject.BooleanSetting__c);
        setFieldValue(customMetadataRecord.values, 'TextSetting__c', configObject.TextSetting__c);

        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
        mdContainer.addMetadata(customMetadataRecord);
        ID jobID = Metadata.Operations.enqueueDeployment(mdContainer, new MDCallback());
        return String.valueOf(jobID);
    }




    private static void setFieldValue(List<Metadata.CustomMetadataValue> values, String fieldName, Object fieldValue)
    {
        // Check for existing field
        for(Metadata.CustomMetadataValue cmvalue: values)
        {
            if(cmvalue.field == fieldName)
            {
                cmvalue.value = fieldValue;
                return;
            }
        }
        Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
        customField.field = fieldName;
        customField.value = fieldValue;
        values.add(customField);
    }

    public class MDCallback implements metadata.DeployCallback
    {
        public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context)
        {
            MetadataDeployComplete__e mdevent = new MetadataDeployComplete__e();
            mdevent.Success__c = result.success;
            mdevent.JobID__c = result.id;
            mdevent.Status__c = string.valueOf(result.status);
            if(!result.success) 
            {
                if(result.errorMessage!=null)
                {
                    mdevent.ErrorMessage__c = result.errorMessage;
                }
                else  {
                   List<Metadata.DeployMessage> errors = result.details.componentFailures;
                   mdevent.ErrorMessage__c = errors[0].problem;
                }
            }
    
            Database.SaveResult eventResult = EventBus.publish(mdevent);
            if(!eventResult.success)
            {
                system.debug('Failed to publish event');
            }
        }
    }

}
