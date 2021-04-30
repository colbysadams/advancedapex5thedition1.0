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

public with sharing class Caching {

    private static Long referenceStartTime;
    private static Long referenceEndTime;
    private static Long targetStartTime;
    private static Long targetEndTime;
    private static Integer referenceStartCPUTime;
    private static Integer referenceEndCPUTime;
    private static Integer targetStartCPUTime;
    private static Integer targetEndCPUTime;

    private static void markReferenceStartTime()
    {
        referenceStartCPUTime = Limits.getCpuTime();
        referenceStartTime = System.currentTimeMillis();
    }

    private static void markReferenceEndTime()
    {
        referenceEndCPUTime = Limits.getCpuTime();
        referenceEndTime = System.currentTimeMillis();
    }

    private static void markTargetStartTime()
    {
        targetStartCPUTime = Limits.getCpuTime();
        targetStartTime = System.currentTimeMillis();
    }

    // Also called by reportResults - so this doesn't have to be called explicitely
    private static void markTargetEndTime()
    {
        targetEndCPUTime = Limits.getCpuTime();
        targetEndTime = System.currentTimeMillis();
    }


    private static void reportResults(Integer loops)
    {
        if(targetEndTime==null) markTargetEndTime();
        Integer referenceDuration = (Integer)(referenceEndTime - referenceStartTime);
        Integer referenceCPUDuration = referenceEndCPUTime - referenceStartCPUTime;
        Integer targetDuration = (Integer)(targetEndTime - targetStartTime);
        Integer targetCPUDuration = targetEndCPUTime - targetStartCPUTime;
        Integer benchmarkResults = targetDuration - referenceDuration;
        Integer benchmarkCPUResults = targetCPUDuration - referenceCPUDuration;
        // Time in microseconds is duration * 1000 / loops
        Decimal eachItem = benchmarkResults * 1000;
        Decimal eachCPUItem = benchmarkCPUResults * 1000;
        eachItem /= loops;
        eachCPUItem /= loops;
        eachItem.setScale(2);
        system.debug(LoggingLevel.Error, 'Reference elapsed Duration: ' + referenceDuration + ' Target elapsed duration: ' +
            targetDuration + ' Benchmark elapsed Results: ' + benchmarkResults + 'ms or ' + eachItem + ' us per operation');
            system.debug(LoggingLevel.Error, 'Reference CPU Duration: ' + referenceCPUDuration + ' Target duration: ' +
            targetCPUDuration + ' Benchmark CPU Results: ' + benchmarkCPUResults + 'ms or ' + eachCPUItem + ' us per operation');
    }

    public static void InitializeCache()
    {
        // This removal is technically unnecessary - however it's done here just in case the cache is smart about updating
        // existing entries to the same values.
        cache.org.remove('describeinfo');
        cache.org.remove('userinfo');
        cache.org.remove('numberslist');
        cache.org.remove('numbersstring');
        Cache.org.put('describeinfo', Schema.getGlobalDescribe());
        User u = [Select ID, IsActive, Name from User where ID = :userinfo.getUserId()];
        cache.org.put('userinfo', u);

        List<String> numbers = new List<String>();
        for(Integer x = 0; x<10000; x++) numbers.add(string.valueOf(x));
        cache.org.put('numberslist', numbers);
        cache.org.put('numbersstring', string.join(numbers,','));
    }

    public static void MeasurePerformance()
    {
        System.debug(LoggingLevel.Error,'Single Global Describe');
        markReferenceStartTime();
        Map<String, Schema.SObjectType> describeinfo = Schema.getGlobalDescribe();
        markReferenceEndTime();
        markTargetStartTime();
        describeinfo = (Map<String, Schema.SObjectType>)Cache.org.get('describeinfo');
        markTargetEndTime();
        reportResults(1);

        System.debug(LoggingLevel.Error,'Single User object');
        markReferenceStartTime();
        User u = [Select ID, IsActive, Name from User where ID = :userinfo.getUserId()];
        markReferenceEndTime();
        markTargetStartTime();
        u = (User)Cache.org.get('userinfo');
        markTargetEndTime();
        reportResults(1);

        System.debug(LoggingLevel.Error,'List of numbers vs numbers string');
        markReferenceStartTime();
        List<String> numbers = (List<String>)cache.org.get('numberslist');
        markReferenceEndTime();
        markTargetStartTime();
        String numbersstring = (String)Cache.org.get('numbersstring');
        //List<String> numstringlist = numbersstring.split(','); // If you uncomment this, the time almost exactly matches the numberslist
        markTargetEndTime();
        reportResults(25000);
    }


}
