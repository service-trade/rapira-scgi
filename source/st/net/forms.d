///////////////////////////////////////////////////////////////////////////////
//
// Rapira SCGI Project
//
// HTTP forms support module
// ---------------------------------------------
// RFC [http://tools.ietf.org/html/rfc]
//
module st.net.forms;


import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.stdio;
import std.string;
import std.uri;

import st.net.http;
import st.net.scgi;

///////////////////////////////////////////////////////////////////////////////
mixin template FormDataMixin()
{
  string[string] form_data;   
}

///////////////////////////////////////////////////////////////////////////////
class HTMLFormDataParserTween: Tween
{
  override void preprocess(Request request, Response response)
  {
    if( request.meta_variables.get("REQUEST_METHOD", "") != "POST" ) return;  	
    if( request.content_data.length == 0 ) return;  	
    if( request.meta_variables.get("CONTENT_TYPE", "") == "" ) return;  	
  	
  	string ct_str = toLower(request.meta_variables["CONTENT_TYPE"]);
  	
  	if( ct_str.startsWith("text/plain") ) {
  		foreach(line; request.content_data.split("\r\n")) {
  			string[] splitted = line.split('=');
  			if( !splitted.length ) continue;
  			request.form_data[splitted[0]] = splitted.length > 1 ? join(splitted[1 .. $], "=") : "";  
  		}
	} else if( ct_str.startsWith("application/x-www-form-urlencoded") ) {
  		foreach(line; request.content_data.replace("+", " ").split('&')) {
  			string[] splitted = line.split('=');
  			if( !splitted.length ) continue;
  			request.form_data[decodeComponent(splitted[0])] = splitted.length > 1 ? decodeComponent(join(splitted[1 .. $], "=")) : "";  
  		}
	} else if( ct_str.startsWith("multipart/form-data") ) {
		string[] boundary_kv = (request.meta_variables["CONTENT_TYPE"].split("; ")[1]).split('=');
		string boundary = toLower(boundary_kv[0]) == "boundary" ? boundary_kv[1] : "";		
	} else {
		assert(false, "Unknown CONTENT_TYPE!");
	}
  }
}

