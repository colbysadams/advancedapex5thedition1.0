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

public without sharing class ScheduledApex implements ScheduledDispatcher.IScheduleDispatched {

    public void execute(SchedulableContext sc)
    {
        // Perform any tasks that you want scheduled

        // Always abort the job on completion
        // system.abortJob(sc.getTriggerID());	
    } 

    public static String getSchedulerExpression(Datetime dt) {
    	// Don't try to schedule Apex before current time + buffer
    	if(dt < DateTime.Now().AddMinutes(1)) 
    		dt = DateTime.Now().AddMinutes(1);
        return ('' + dt.second() + ' ' + dt.minute() + ' ' + 
        	dt.hour() + ' ' + dt.day() + ' ' + 
        	dt.month() + ' ? ' + dt.year());
    }
        
    public static void startScheduler(DateTime scheduledTime, String jobName)
    {
        
        // Is the job already running?
        List<CronTrigger> jobs = 
        	[SELECT Id, CronJobDetail.Name, State, NextFireTime
             FROM CronTrigger 
             WHERE CronJobDetail.Name= :jobName];
    	if(jobs.size()>0 && jobs[0].state!='COMPLETED' && 
           jobs[0].state!='ERROR' && jobs[0].state!='DELETED')
    	{
            // It's already running/scheduled
			
			// Depending on your design you might want to exit,
			// or abort and reschedule if the requested start time 
			// is earlier
			return;            
        }

        // If the job exists, it needs to be deleted
        if(jobs.size()>0) system.abortJob(jobs[0].id);


        try
        {
	        System.schedule(jobName, 
	                        getSchedulerExpression(scheduledTime), 
	                        new ScheduledDispatcher());
        } catch(Exception ex)
        {
        	system.Debug(ex.getMessage());
        	// Log the error?
        	// Or throw the error to the caller?
        }
    }

    @future
    public static void StartScheduleFuture(DateTime scheduledTime, String jobname)
    {
        startScheduler(scheduledTime, jobName);
    }

}
