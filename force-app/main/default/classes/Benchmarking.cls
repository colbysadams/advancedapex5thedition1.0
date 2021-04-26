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
public class Benchmarking {
    
    private static Integer referenceStartTime;
    private static Integer referenceEndTime;
    private static Integer targetStartTime;
    private static Integer targetEndTime;

    private static void markReferenceStartTime()
    {
        referenceStartTime = Limits.getCpuTime();
    }

    private static void markReferenceEndTime()
    {
        referenceEndTime = Limits.getCpuTime();
    }

    private static void markTargetStartTime()
    {
        targetStartTime = Limits.getCpuTime();
    }

    // Also called by reportResults - so this doesn't have to be called explicitely
    private static void markTargetEndTime()
    {
        targetEndTime = Limits.getCpuTime();
    }


    private static void reportResults(Integer loops)
    {
        if(targetEndTime==null) markTargetEndTime();
        Integer referenceDuration = referenceEndTime - referenceStartTime;
        Integer targetDuration = targetEndTime - targetStartTime;
        Integer benchmarkResults = targetDuration - referenceDuration;
        // Time in microseconds is duration * 1000 / loops
        Decimal eachItem = benchmarkResults * 1000;
        eachItem /= loops;
        eachItem.setScale(2);
        system.debug(LoggingLevel.Error, 'Reference Duration: ' + referenceDuration + ' Target duration: ' +
            targetDuration + ' Benchmark Results: ' + benchmarkResults + 'ms or ' + eachItem + ' us per operation');
    }

    // Benchmark a simple integer increment
   @istest
    public static void primitiveTests()
    {
        Integer v = 0;
        markReferenceStartTime();
        for(Integer x = 0; x<1000000; x++)
        {
        }
        markReferenceEndTime();
        markTargetStartTime();
        for(Integer x = 0; x<1000000; x++)
        {
            v += 5;
        }
        reportResults(1000000);
    }

    // Benchmark a call to an empty function
    @istest
    public static void testFunctionCall()
    {
        markReferenceStartTime();
        for(Integer x = 0; x<1000000; x++)
        {
        }
        markReferenceEndTime();
        markTargetStartTime();
        for(Integer x = 0; x<1000000; x++)
        {
            emptyFunction();
        }
        reportResults(1000000);
    }

    private static void emptyFunction(){}

    // Benchmark allocation of an array with one element
    @istest
    public static void testNewAllocate()
    {
        List<List<Integer>> numbers = new List<List<Integer>>();
        List<Integer> emptyList = new List<Integer>();
        markReferenceStartTime();
        for(Integer x = 0; x<1000000; x++)
        {
            numbers.add(emptyList); // Add existing list (no allocation)
        }
        markReferenceEndTime();
        markTargetStartTime();
        for(Integer x = 0; x<1000000; x++)
        {
            numbers.add(new List<Integer>{x});  // Add a new list
        }
        reportResults(1000000);
    }

    // Benchmark the getGlobalDescribe first operation and cached operations
    @istest
    public static void testGlobalDescribe()
    {
        markReferenceStartTime();
        for(Integer x = 0; x<1; x++)
        {
            Map<String, Schema.SObjectType> describeInfo = Schema.getGlobalDescribe();
        }
        markReferenceEndTime();
        // Because it was already called once, the following will measure the internal cacheing
        markTargetStartTime();
        for(Integer x = 0; x<1000; x++)
        {
            Map<String, Schema.SObjectType> describeInfo = Schema.getGlobalDescribe();
        }
        reportResults(1000);
    }

    private static Set<String> spamList = new Set<String>{'@yahoo.com','@gmail.com','@hotmail.com','@whitehouse.gov','@test.com','@nobody.com',
    '@abc.com','@spam.com','@xyz.com','@ignoreme.com'};

    private static Set<String> spamDomainsList = new Set<String>{'yahoo.com','gmail.com','hotmail.com','whitehouse.gov','test.com','nobody.com',
    'abc.com','spam.com','xyz.com','ignoreme.com'};


    // Dynamic field, test against each entry
    private static List<Lead> checkForSpam1(List<Lead> leads, String emailField)
    {
        List<Lead> results = new List<Lead>();
        for(Lead ld: leads)
        {
            for(string spamDomain: spamList)
                if(ld.get(emailField)!=null && ((String)ld.get(emailField)).endsWithIgnoreCase(spamDomain)) results.add(ld);
        }
        return results;
    }

    // Use a static field reference and endsWithIgnoreCase
    private static List<Lead> checkForSpam2(List<Lead> leads, String emailField)
    {
        List<Lead> results = new List<Lead>();
        for(Lead ld: leads)
        {
            switch on emailField
            {
                when 'email' {
                    for(string spamDomain: spamList)
                        if(ld.email!=null && ld.email.endsWithIgnoreCase(spamDomain)) results.add(ld);
                }
                when else {
                    for(string spamDomain: spamList)
                        if(ld.get(emailField)!=null && ((String)ld.get(emailField)).endsWithIgnoreCase(spamDomain)) results.add(ld);
                }
            }
        }
        return results;
    }

    // Use a temporary variable and endsWithIgnoreCase
    private static List<Lead> checkForSpam3(List<Lead> leads, String emailField)
    {
        List<Lead> results = new List<Lead>();
        Boolean useStaticEmail = (emailField=='email');
        for(Lead ld: leads)
        {
            String email = (useStaticEmail)? ld.email: (String)ld.get(emailField);
            if(email!=null)
            {
                for(string spamDomain: spamList)
                    if(email.endsWithIgnoreCase(spamDomain)) results.add(ld);
            }
        }
        return results;
    }

    // Use a temporary variable and convert to lower case explicitly
    private static List<Lead> checkForSpam4(List<Lead> leads, String emailField)
    {
        List<Lead> results = new List<Lead>();
        Boolean useStaticEmail = (emailField=='email');
        for(Lead ld: leads)
        {
            String email = (useStaticEmail)? ld.email: (String)ld.get(emailField);
            if(email!=null)
            {
                email = email.toLowerCase();
                for(string spamDomain: spamList)
                    if(email.endsWith(spamDomain)) results.add(ld);
            }
        }
        return results;
    }

    // Use a temporary variable and a set lookup
    private static List<Lead> checkForSpam5(List<Lead> leads, String emailField)
    {
        List<Lead> results = new List<Lead>();
        Boolean useStaticEmail = (emailField=='email');
        for(Lead ld: leads)
        {
            String email = (useStaticEmail)? ld.email: (String)ld.get(emailField);
            String emaildomain = email?.substringafter('@')?.toLowerCase();
            if(emaildomain!=null)
            {
                if(spamDomainsList.contains(emaildomain)) results.add(ld);
            }
            /*
                I could have used the same spamList set as the other functions and the following code to extract the domain:
                String emaildomain = email?.substring(email?.indexof('@'))?.toLowerCase();
                But it parses the string twice, and is thus somewhat slower
            */
        }
        return results;
    }


    @istest
    public static void testCheckForSpam()
    {
        List<Lead> leads = new List<Lead>();
        for(Integer x = 0; x<10000; x++) leads.add(new Lead(LastName ='test', Email = 'someone@myemail.com'));
        markReferenceStartTime();
        checkForSpam1(leads, 'email');
        markReferenceEndTime();
        markTargetStartTime();
        checkForSpam2(leads, 'email');
        markTargetEndTime();    // Must be explicit to override previous value
        system.debug(logginglevel.error, 'Target uses static field reference');
        reportResults(100000);
        markTargetStartTime();
        checkForSpam3(leads, 'email');
        markTargetEndTime();    // Must be explicit to override previous value
        system.debug(logginglevel.error, 'Target uses temporary variables');
        reportResults(100000);
        markTargetStartTime();
        checkForSpam4(leads, 'email');
        markTargetEndTime();    // Must be explicit to override previous value
        system.debug(logginglevel.error, 'Target uses temp variables and explicit lower case conversion');
        reportResults(100000);
        markTargetStartTime();
        checkForSpam5(leads, 'email');
        markTargetEndTime();    // Must be explicit to override previous value
        system.debug(logginglevel.error, 'Target uses temp variables and set lookup');
        reportResults(100000);

    }


    // Compare a reference to a static field (setting the value) to a simple variable
    @istest
    public static void testStaticFieldAccess()
    {
        List<Lead> leads = new List<Lead>();
        for(Integer x = 0; x<200; x++)
        {
            leads.add(new Lead(FirstName = 'a'+ string.valueOf(x) + 'name', LastName = 'b'+ string.valueOf(x) + 'name'));
        }
        String dummyString = '';
        Decimal dummydec;
        markReferenceStartTime();
        for(Integer iteration = 0; iteration<100; iteration++)
        {
            String i = string.valueOf(iteration) + '-';
            for(Integer x = 0; x<200; x++)
            {
                // Access lead field 10 times
                Lead ld = leads[x];
                String v = i + string.ValueOf(x);   // String that varies
                dummyString = dummyString + v;    // Field accessed twice
                dummyString = dummyString + v;  // Field accessed twice
                dummydec = 50;
                dummyString = 'place' + v;
                dummyString = 'company' + v;
                dummyString = 'duns' + v;
                dummyString = 'test lead';
                dummyString = 'email' + v + '@email.com';
            }
        }
        markReferenceEndTime();
        markTargetStartTime();
        for(Integer iteration = 0; iteration<100; iteration++)
        {
            String i = string.valueOf(iteration) + '-';
            for(Integer x = 0; x<200; x++)
            {
                // Access lead field 10 times
                Lead ld = leads[x];
                String v = i + string.ValueOf(x);   // String that varies
                ld.FirstName = ld.FirstName + v;    // Field accessed twice
                ld.LastName = ld.LastName + v;  // Field accessed twice
                ld.AnnualRevenue = 50;
                ld.City = 'place' + v;
                ld.Company = 'company' + v;
                ld.CompanyDunsNumber = 'duns' + v;
                ld.Description = 'test lead';
                ld.Email = 'email' + v + '@email.com';
            }
        }

        // Total fields is about 200 x 100 x 10 = 200,000 field accesses
        reportResults(200000);
    }


    // Compare a reference to a dynamic field (setting the value) to a simple variable
    @istest
    public static void testDynamicFieldAccess()
    {
        List<Lead> leads = new List<Lead>();
        for(Integer x = 0; x<200; x++)
        {
            leads.add(new Lead(FirstName = 'a'+ string.valueOf(x) + 'name', LastName = 'b'+ string.valueOf(x) + 'name'));
        }
        String dummyString = '';
        Decimal dummydec;
        markReferenceStartTime();
        for(Integer iteration = 0; iteration<100; iteration++)
        {
            String i = string.valueOf(iteration) + '-';
            for(Integer x = 0; x<200; x++)
            {
                // Access lead field 10 times
                Lead ld = leads[x];
                String v = i + string.ValueOf(x);   // String that varies
                dummyString = dummyString + v;    // Field accessed twice
                dummyString = dummyString + v;  // Field accessed twice
                dummydec = 50;
                dummyString = 'place' + v;
                dummyString = 'company' + v;
                dummyString = 'duns' + v;
                dummyString = 'test lead';
                dummyString = 'email' + v + '@email.com';
            }
        }
        markReferenceEndTime();
        markTargetStartTime();
        for(Integer iteration = 0; iteration<100; iteration++)
        {
            String i = string.valueOf(iteration) + '-';
            for(Integer x = 0; x<200; x++)
            {
                // Access lead field 10 times
                Lead ld = leads[x];
                String v = i + string.ValueOf(x);   // String that varies
                ld.put('FirstName', (string)ld.get('FirstName') + v);    // Field accessed twice
                ld.put('LastName', (string)ld.get('LastName') +  v);  // Field accessed twice
                ld.put('AnnualRevenue', 50);
                ld.put('City','place' + v);
                ld.put('Company','company' + v);
                ld.put('CompanyDunsNumber', 'duns' + v);
                ld.put('Description', 'test lead');
                ld.put('Email', 'email' + v + '@email.com');
            }
        }        
        // Total fields is about 200 x 100 x 10 = 200,000 field accesses
        reportResults(200000);
    }


}
