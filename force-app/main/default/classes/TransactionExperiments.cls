public with sharing class TransactionExperiments {

    public static void CreateTestRecords()
    {
        Boolean enabled = AppCustomSetting.appEnabled;  // Make sure app is on
        if(!enabled) system.debug('Please enable the application to perform these tests');
        List<WorkOrder> wos = new List<WorkOrder>();
 		
        for(Integer x = 0; x<2; x++)
       {
           wos.add(
               new WorkOrder(
                   Subject='work order ' + String.valueOf(x), 
                   Description = 'This is work order # ' + String.ValueOf(x) ));
       }
       insert wos;
    }

    public static void CreateManyRequest()
    {
        for(Integer x = 0; x<20; x++) system.EnqueueJob(new QueueableApex());
    }


}
