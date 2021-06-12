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

public with sharing class TestAutoProgressStage {
    @TestSetup
    static void makeData(){
        List<Opportunity> newops = new List<Opportunity>();

        for(Integer x=0; x<10; x++)
        {
            newops.add(
                new Opportunity(CloseDate = Date.Today().addDays(5), 
                        Name = 'optest_' + String.valueOf(x), 
                        StageName = 'Prospecting' ));	
        }
        insert newops;
    }

    @istest
    static void TestAutoProgression()
    {
        List<Opportunity> ops = [Select ID, StageName from Opportunity];
        Test.startTest();
        double currentAmount = 40000;
        for(Opportunity op: ops)
        {
            op.Amount = currentAmount;
            currentAmount += 10000;
        }
        update ops;
        Test.stopTest();

        List<Opportunity> opsResults = [Select ID, Amount, StageName from Opportunity];

        for(Opportunity op: opsResults)
        {
            system.assertEquals((op.Amount<50000)? 'Prospecting': 'Qualification', op.StageName);
        }

        // Add this (integration test vs. unit tests)

        // How many are now qualified?
        Integer qualificationCount = 0;
        for(Opportunity op: opsResults)
        {
            if(op.StageName == 'Qualification') qualificationCount+=1;
        }

        List<Task> tasks = [Select ID from Task where OwnerID = :UserInfo.getUserId() And Type='Other' And Subject = 'Assign Primary Contact'];
        System.assertEquals(qualificationCount, tasks.size());


    }
}
