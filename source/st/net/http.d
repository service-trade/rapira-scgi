///////////////////////////////////////////////////////////////////////////////
//
// Rapira SCGI Project
//
// HTTP common definitions
//
module st.net.http;

import std.string;
import std.datetime;
import std.format;
import std.conv;

enum HTTPStatusCode { 
	OK = 200, 
	FOUND = 302, 
	BAD_REQUEST = 400, 
	NOT_FOUND = 404,
	INTERNAL_SERVER_ERROR = 500,
	NOT_IMPLEMENTED = 501
}

///////////////////////////////////////////////////////////////////////////////
//
// Convert to "Sun, 06 Nov 1994 08:49:37 GMT" standard representation defined in RFC822 
// See: 
// 		http://tools.ietf.org/html/rfc822#section-5.1
// 		http://tools.ietf.org/html/rfc2616#section-3.3.1
//
string toStringRFC822(SysTime dt)
{
  	dt = dt.toUTC;
  	return format(
  		"%s, %02d %s %04d %02d:%02d:%02d GMT", 
  		capitalize(to!string(dt.dayOfWeek)), dt.day, capitalize(to!string(cast(Month)dt.month)), dt.year, 
  		dt.hour, dt.minute, dt.second
		);	
}