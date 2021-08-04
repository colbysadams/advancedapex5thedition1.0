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

/*
    Base class for individual static manager implementations
    When a static is set - use StoreValue to store the current value (associated with the current trigger time)
*/

public with sharing abstract class StaticManager {

    private class ValueHistory
    {
        public String name;         // Name of this value
        public Object value;        // Holds the value at the time it was set
        public Integer valueTime;   // Holds the set time for that value

        public ValueHistory(String objname, Object objValue)
        {
            name = objname;
            value = objValue;
            valueTime = StaticManager.triggerTime;
        }
    }

    private static List<StaticManager> callbacks = new List<StaticManager>();
    private static Integer previousTime = 0;
    private static Integer triggerTime = 0;

    // Called at the main trigger entry point
    public static void onTrigger()
    {
        triggerTime = Limits.getCPUTime();
        if(triggerTime < previousTime )
        {
            // The CPU time will drop on a failed partial DML
            // Notify any callback classes
            for(StaticManager sm: callbacks) sm.popValuesAndRevert(triggerTime);
        }
        previousTime = triggerTime;
    }

    // Can be used to retrieve the CPU time of the start of the previous trigger
    public static Integer triggerCPUTime { get { return triggerTime; }}

    // Member properties and methods

    private String callbackName;
    private List<valueHistory> values;
        
    protected StaticManager(String name) {
        callbackName = name;
        callbacks.add(this);    // Add to the callback list
        values = new List<valueHistory>();
    }

    protected void popValuesAndRevert(Integer trigerTime) 
    {
        // Pop from the list (stack) any values that are later than the current TriggerTime
        for(Integer idx = values.size()-1; idx>=0; idx--)
        {
            if(values[idx].valueTime > triggerTime) values.remove(idx);
        }
        // Call the virtual revert;
        Revert(previousTime);
    }

    // Derived instances may implement Revert if it wants notification
    protected virtual void Revert(Integer previousTime) {}

    // Stores a static variable with the current trigger's timestamp.
    // Note - don't store large arrays.
    // If you store an array or map, clone the values
    protected void StoreValue(String objname, Object obj)
    {
        ValueHistory v = new ValueHistory(objname, obj);
        // See if there is a current value
        for(Integer idx = values.size()-1; idx>=0; idx--)
        {
            ValueHistory existingv = values[idx];
            if(existingv.valueTime < StaticManager.triggerTime) break; // We've looked back as far as necessary
            if(existingv.name == objname) // Replace the current value
            {
                values[idx] = v;
                return;
            }
        }
        values.add(v);
    }

    // Retrieves the latest value of the static variable
    protected Object RetrieveValue(String objname) 
    {
        for(Integer idx = values.size()-1; idx>=0; idx--)
        {
            if(values[idx].name == objname) return values[idx].value;
        }
        return null;
    }


 
}
