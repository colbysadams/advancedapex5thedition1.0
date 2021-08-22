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

public inherited sharing class TriggerDispatcher {

    public static void handleTrigger(String objectType, TriggerOperation triggerType, List<SObject> newList, Map<Id, SObject> newMap, 
                                List<SObject> oldList, Map<ID, SObject> oldMap)
    {
        DiagnosticsInstrumentation.push('Trigger ' + triggerType.name() + ' On object ' + objectType);
        try {
            List<String> classNames = new List<String>();
            List<TriggerAPI.ITriggerHandler> handlers = getTriggerHandlers(objectType, triggerType, classNames);
            for(Integer handlerIndex = 0; handlerIndex<handlers.size(); handlerIndex++)
            {
                TriggerAPI.ITriggerHandler handler = handlers[handlerIndex];
                DiagnosticsInstrumentation.push('Invoking handler ' + classNames[handlerIndex]);
                handler.HandleTrigger(triggerType, newList, newMap, oldList, oldMap);
                DiagnosticsInstrumentation.pop();
            }
            DiagnosticsInstrumentation.pop();
        } catch (Exception ex) {
            DiagnosticsInstrumentation.debugException(ex);
            DiagnosticsInstrumentation.popAll();
        }

    }

    private static List<TriggerAPI.ITriggerHandler> getTriggerHandlers(String objectType, TriggerOperation triggerType, List<String>classNames) 
    {
        String operationType = triggerType.name();
        if(classNames!=null) classNames.clear();

        // At publication time you must include the order field in the query with custom metadata
        List<Trigger_Handler__mdt> handlers = [Select Apex_Class__c, Priority__c from Trigger_Handler__mdt where 
            Object_Type__c = :objectType And Trigger_Type__c = :operationType Order By Priority__c Asc];
        // Validate the classes
        List<TriggerAPI.ITriggerHandler> results = new List<TriggerAPI.ITriggerHandler>();

        for(Trigger_Handler__mdt handler: handlers) 
        {
            System.Type thetype = Type.forName(handler.Apex_Class__c);
			if(thetype==null) thetype = Type.forName('',handler.Apex_Class__c);	// Try resolving local class
            if(thetype!=null) 
            {
                Object theClass = thetype.newInstance();
                if(theClass instanceof TriggerAPI.ITriggerHandler) 
                {
                    results.add((TriggerAPI.ITriggerHandler)theClass);
                    classNames.add(handler.Apex_Class__c);
                }
            }
        }

        return results;
    }

}
