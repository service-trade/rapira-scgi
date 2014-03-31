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
import std.conv;
import std.datetime;
import std.stdio;
import std.string;

import st.net.http;
import st.net.scgi;


///////////////////////////////////////////////////////////////////////////////
class HTMLFormDataParserTween: Tween
{
  override void preprocess(Request request, Response response)
  {
  	
  }
}

