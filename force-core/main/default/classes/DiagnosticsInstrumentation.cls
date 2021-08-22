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
public with sharing class DiagnosticsInstrumentation {

	public static Boolean diagnosticsEnabled = AppCustomSetting.diagnosticsEnabled;
	
	private static List<DiagnosticEntry> diagnosticLog;
	private static Integer currentLevel = 0;

	private static List<String> stackTrace = new List<String>();
	public static string exceptionTrace = '';

	private class DiagnosticEntry
	{
		Integer level;
		String description;
		
		public diagnosticEntry(string entryDescription)
		{
			level = currentLevel;
			description = entryDescription;
		}
	}

	public static void push(String functionName)
	{
		debug('Entering: ' + functionName);
		currentLevel+=1;
		stacktrace.add(functionName);
	}
	
	public static void debug(String debugString)
	{
		if(!diagnosticsEnabled) return;
		if(diagnosticLog==null) diagnosticLog = new List<DiagnosticEntry>();
		diagnosticLog.add(new DiagnosticEntry(debugString));
	}
	
	public static void pop()
	{
        system.debug(loggingLevel.info, 'Pop from level ' + currentLevel);
		if(currentLevel>0) currentLevel-=1;
		if(currentLevel==0) System.Debug(LoggingLevel.Info, 
			'Diagnostic Log\n' + currentLog());
		if(stackTrace.size()>0) 
			stackTrace.remove(stackTrace.size()-1);
	}
	
	public static void popAll()
	{
		while(currentLevel>0) pop();
	}
	
	public static String currentLog()
	{
		if(diagnosticLog == null) return null;
		String spaces = '                                                                        ';
		String result = '';
		for(DiagnosticEntry de: diagnosticLog)
		{
			Integer endIndex = 3 * de.level;
			if(endIndex >= spaces.length()) endIndex = spaces.length()-1;
			result += spaces.substring(0,endIndex) + de.description + '\n';
		}
		return result;
	}
	

}
