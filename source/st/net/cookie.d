///////////////////////////////////////////////////////////////////////////////
//
// Rapira SCGI Project
//
// HTTP cookies support module
// ---------------------------------------------
// RFC6265 [http://tools.ietf.org/html/rfc6265]
//
module st.net.cookie;


import std.algorithm;
import std.conv;
import std.datetime;
import std.stdio;
import std.string;

import st.net.http;
import st.net.scgi;


///////////////////////////////////////////////////////////////////////////////
class HttpCookie
{
  string name;
  string value;
  
  SysTime expires;
  ulong   max_age;
  string  domain;
  string  path;
  bool    secure;
  bool    http_only;
  string  extensions; 
  
  this(string name, string value)
  {
    this.name = name;
    this.value = std.uri.decodeComponent(value);
  }
  
  override string toString()
  {
  	string result = format("%s=%s", name, std.uri.encodeComponent(value)); 
  	
  	if( expires != SysTime() ) result ~= "; Expires=" ~ toStringRFC822(expires);
  	if( max_age > 0          ) result ~= "; Max-Age=" ~ to!string(max_age);
  	if( domain != ""         ) result ~= "; Domain="  ~ domain; 
  	if( path != ""           ) result ~= "; Path="    ~ path;
  	if( secure               ) result ~= "; Secure";
  	if( http_only            ) result ~= "; HttpOnly";
  	if( extensions           ) result ~= "; "         ~ extensions;
    return result;
  }
  
  void mark_for_remove()
  {
  	expires = Clock.currTime;
  	expires.roll!"hours"(-expires.hour);
  	max_age = 0;
  }

  void mark_as_persistent()
  {
  	expires = Clock.currTime;
  	expires.roll!"years"(10);
  	max_age = 60 * 24 * 365 * 10;
  }
  
  void mark_for_this_session()
  {
  	expires = SysTime();
  	max_age = 0;
  }
}


///////////////////////////////////////////////////////////////////////////////
mixin template HttpCookiesMixin()
{
  HttpCookie[string] cookies;   
  
  HttpCookie new_cookie(string name, string value) { return this.cookies[name] = new HttpCookie(name, value); }; 
}


///////////////////////////////////////////////////////////////////////////////
class HttpCookiesTween: Tween
{
  override void preprocess(Request request, Response response)
  {
    if( request.meta_variables.get("HTTP_COOKIE", "") == "" ) return;
    
    foreach(cookie; request.meta_variables["HTTP_COOKIE"].split("; "))
    {
      auto cookie_parts = cookie.split("=");
      if( cookie_parts.length == 2 ) request.cookies[cookie_parts[0]] = new HttpCookie(cookie_parts[0], cookie_parts[1]);
    } 
  };
  
  override void postprocess(Request request, Response response) 
  {
    response.headers["Set-Cookie"] = new string[response.cookies.length];
    uint i = 0;
    foreach(c; response.cookies) response.headers["Set-Cookie"][i++] = c.toString();
  };  
}

///////////////////////////////////////////////////////////////////////////////
class HttpCookiesEnforceSecureTween: Tween
{
  override void postprocess(Request request, Response response) 
  {
    foreach(c; response.cookies) c.secure = true;
  };  
}


