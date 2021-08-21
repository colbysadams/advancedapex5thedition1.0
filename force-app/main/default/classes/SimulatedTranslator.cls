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

@RestResource(urlMapping='/Translate/')
global class SimulatedTranslator {

	@HttpPost
	global static string doPost(String source)
	{
		return(source + ' in Spanish ');
	}

	private class PostClass {
		String source;
	}


	public static String translate(String sourceText)
	{
		if(sourcetext==null) return null;
		HttpRequest req = new HttpRequest();
		req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/apexrest/Translate/');
		req.setHeader('Authorization', 'Bearer ' + Userinfo.getSessionId());
		req.setHeader('Content-Type', 'application/json');
		req.setMethod('POST');
		PostClass p = new PostClass();
		p.source = sourceText;
		req.setBody(JSON.serialize(p));
		HttpResponse result = new Http().send(req);
		return result.getBody();
	}

	public class MockTranslator implements HttpCalloutMock
	{
		public HTTPResponse respond(HTTPRequest req)
		{
			String requestBodyJSON = req.getBody();
			String requestBody = ((PostClass)JSON.deserialize(requestBodyJSON, postClass.class)).source;
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'text');
			res.setBody(requestBody + ' in Spanish');
			res.setStatusCode(200);
			return res;
		}
	}

}
