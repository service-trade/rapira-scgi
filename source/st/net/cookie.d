///////////////////////////////////////////////////////////////////////////////
//
// Rapira SCGI Project
//
// HTTP cookies support module
// ---------------------------------------------
// RFC6265 [http://tools.ietf.org/html/rfc6265]
//
module st.net.cookie;

import std.string;
import st.net.scgi;


///////////////////////////////////////////////////////////////////////////////
class Cookie
{
  string name;
  string value;
  
  string expires;
  string max_age;
  string domain;
  string path;
  string secure;
  string httponly;
  string extension;
  
  this(string name, string value)
  {
    this.name = name;
    this.value = std.uri.decodeComponent(value);
  }
  
  override string toString() //!требует доработки!
  {
    return format("%s=%s", name, std.uri.encodeComponent(value));
  }
}


///////////////////////////////////////////////////////////////////////////////
mixin template Cookies()
{
  private   Cookie[string] cookies_data;
  @property Cookie[string] cookies() { return cookies_data; }
  Cookie set_cookie(string name, string value) { return cookies_data[name] = new Cookie(name, value); }
}


///////////////////////////////////////////////////////////////////////////////
class HTTPCookiesTween: Tween
{
  override void preprocess(Request request, Response response)
  {
    RequestCookie requestc = cast(RequestCookie)request;
    
    foreach(cookie; requestc.meta_variables["HTTP_COOKIE"].split("; "))
    {
      auto cookie_parts = cookie.split("=");
      requestc.set_cookie(cookie_parts[0], cookie_parts[1]);
      response.set_cookie(cookie_parts[0], cookie_parts[1]);
    } 
  };
  
  override void postprocess(Request request, Response response) 
  {
    response.headers["Set-Cookie"] = [];
    foreach(cookie; response.cookies)
      response.headers["Set-Cookie"] ~= cookie.toString();
  };  
}

