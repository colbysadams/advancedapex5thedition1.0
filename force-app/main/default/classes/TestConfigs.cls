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
public class TestConfigs {

    @istest
    public static void testCustomSettings()
    {
        // Validate defaults
        system.assertEquals(true, AppCustomSetting.appEnabled);
        system.assertEquals(true, AppCustomSetting.diagnosticsEnabled);
        // Validate ability of unit test to change configuration
        AppCustomSetting.testConfig.EnableDiagnostics__c = false;
        system.assertEquals(false, AppCustomSetting.diagnosticsEnabled);
    }


    @istest
    public static void testCustomMetadata()
    {
        // Validate defaults
        system.assertEquals(true, ConfigCustomMetadata.BooleanSetting);
        system.assertEquals(null, ConfigCustomMetadata.TextSetting);
        // Validate ability of unit test to change configuration
        ConfigCustomMetadata.testConfig.TextSetting__c = 'test';
        system.assertEquals('test', ConfigCustomMetadata.TextSetting);
    }




}
