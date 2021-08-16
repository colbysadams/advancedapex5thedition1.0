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
public class TestChangeDataCapture {

	@istest
	public static void testOneWorkOrder()
	{
		testWorkOrdersInsert(1);
	}

	@istest
	public static void testManyWorkOrders()
	{
		// Batch unit tests are limited to a single execute
		testWorkOrdersInsert(200);
	}

   private static void testWorkOrdersInsert(Integer recordCount) {
 		
 		List<WorkOrder> wos = new List<WorkOrder>();
 		
 		for(Integer x = 0; x<recordCount; x++)
    	{
    		wos.add(
    			new WorkOrder(
    				Subject='work order ' + String.valueOf(x), 
    				Description = 'This is work order # ' + String.ValueOf(x) ));
    	}

		try {
			Test.StartTest();

		   insert wos;
   
		   Test.StopTest();
           Test.getEventBus().deliver();    // Need to deliver platform event!
		} catch (Exception ex) {
			system.debug(ex.getMessage());
		}
 
 		Map<ID, WorkOrder> wosmap = new Map<ID, WorkOrder>(wos);
 		
 		List<WorkOrder> results = 
 			[Select ID, Description, DescriptionSpanish__c, TranslationPending__c 
 			from WorkOrder where ID in :wosmap.keyset()];
 		Integer pending = 0;
		Integer translated = 0;
		for(WorkOrder wo: results) 
		{
 			if(wo.DescriptionSpanish__c!=null && wo.DescriptionSpanish__c.contains(' No callouts')) {
				translated+=1;
			}
			else pending++;
		}
		system.assertEquals(results.size(), pending + translated);
		system.assert(translated > 0);	// Make sure at least one was translated
    }


}
