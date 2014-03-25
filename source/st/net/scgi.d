///////////////////////////////////////////////////////////////////////////////
//
// Rapira SCGI Project
//
// Simple Common Gatewey Interface server implementation
// -----------------------------------------------------
// SCGI protocol [http://python.ca/scgi/protocol.txt]
//
module st.net.scgi;

import std.array;
import std.algorithm;
import std.exception;
import std.conv;
import std.stdio;
import std.socket;
import std.stream;
import std.process;
import std.regex;
import std.uri;
import st.net.http;
import st.net.cookie;


///////////////////////////////////////////////////////////////////////////////
class Request {
  string header_data;
  string content_data;

  string[string] meta_variables_data;
  @property string[string] meta_variables() { return meta_variables_data; }

  static string predefined_meta_vars(string[] meta_variables_list)
	{
		string result;
		foreach(var; meta_variables_list)
			result ~= `@property string meta_` ~ var ~`() { return this.meta_variables_data.get("` ~ var ~ `", ""); };`;
		return result;
	}
  
	mixin(
		predefined_meta_vars([
			"AUTH_TYPE", "CONTENT_LENGTH", "CONTENT_TYPE", "GATEWAY_INTERFACE", "PATH_INFO", 
			"PATH_TRANSLATED", "QUERY_STRING", "REMOTE_ADDR", "REMOTE_HOST", "REMOTE_IDENT",
			"REMOTE_USER", "REQUEST_METHOD", "SCRIPT_NAME", "SERVER_NAME", "SERVER_PORT", 
			"SERVER_PROTOCOL", "SERVER_SOFTWARE"
		])
	);

	private   string path_data; // PATH_INFO
	@property string path() { return path_data; }

	private   string[string] params_data; // QUERY_STRING
	@property string[string] params() { return params_data; }
  
//  mixin Cookies;
  
	this(string header_data, string content_data)
	{
    this.header_data = header_data;
    this.content_data = content_data;

    string[] header_data_splitted = header_data.split('\0');        
    for(auto i = 0; i < header_data_splitted.length - 1; i += 2) 
      meta_variables_data[header_data_splitted[i]] = header_data_splitted[i+1];       

    static auto cgi_spec_pattern = regex(r"^CGI/(?P<major>\d+)\.(?P<minor>\d+)$");
    auto m = match(meta_GATEWAY_INTERFACE, cgi_spec_pattern);    		
		enforce(
      m && to!uint(m.captures["major"]) == 1 && to!uint(m.captures["minor"]) == 1, 
      "Unknown CGI protocol version, must be CGI/1.1"
    );

		path_data = decodeComponent(meta_PATH_INFO);

		foreach(param; meta_QUERY_STRING.split('&')) {
			auto param_parts = map!((x){ return decodeComponent(x); })(param.split('='));
			params_data[param_parts[0]] = param_parts.length == 1 ? "" : join(param_parts[1..$], "=");
		}
	}
}

class RequestCookie: Request
{
  mixin Cookies;

	this(string header_data, string content_data) { super(header_data, content_data); }
}

///////////////////////////////////////////////////////////////////////////////
class Response {
  string[][string] headers;
  string output;

  mixin Cookies;
  
  this(string content_type = "text/html; charset=utf-8")
  {
    headers["Content-Type"] = [content_type];
    status_code(HTTPStatusCode.OK);
  }

	string form_headers_string()
	{
    string result;
		foreach(key, values; headers) 
      foreach(value; values)
      {
        result ~= key ~ ": " ~ value ~ "\r\n";
      }
    
		return result;    
	}

	@property {
		void status_code(int code)
		in {
			assert(code > 99 && code < 1000);
		}
		body {
			headers["Status"] = [to!string(code)];
		}

		int status_code()
		{
			if( "Status" in this.headers ) 
				return to!int(this.headers["Status"][0]);
			else
				return HTTPStatusCode.OK; // RFC3875 6.2.1 -- status 200 'OK' is assumed if it is omitted.
		}
	}  
    
  @property char[] buffer() { 
    return cast(char[])(form_headers_string() ~ "\r\n" ~ output); 
  }
}


///////////////////////////////////////////////////////////////////////////////
struct RouteEntry
{
	string group;
  void function(Request, Response, string[string] context) handler;
  Regex!char path_pattern;
}


///////////////////////////////////////////////////////////////////////////////
class Tween {
  void preprocess(Request request, Response response) {};
  void postprocess(Request request, Response response) {};
}


///////////////////////////////////////////////////////////////////////////////
class SessionTween: Tween
{
}


///////////////////////////////////////////////////////////////////////////////
class HTMLFormDataParserTween: Tween
{
}


///////////////////////////////////////////////////////////////////////////////
class SCGIServer(RequestT = RequestCookie, ResponseT = Response) 
  if( is(RequestT : Request) && is(ResponseT : Response) )
{
  protected Socket server;
  
  RouteEntry[] routes;
  Tween[] tweens;
  
	this(int port = 8080)
	{
    tweens = [ 
      cast(Tween)new HTTPCookiesTween(),
      cast(Tween)new SessionTween(),
      cast(Tween)new HTMLFormDataParserTween(),
    ];
    
    server = new TcpSocket();
    server.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
    server.bind(new InternetAddress(8080));
    server.listen(1);
 
		//this.headers["Content-Type"] = content_type;
    
	}

  void run()
  {
    while(true) {
      Socket client = server.accept();

      char[] buffer = new char[0];
      char[4096] chunk;
      auto received = 0;
      
      static auto header_pattern = 
        regex(
          r"^(?P<header_len>\d+):"
        ~ r"CONTENT_LENGTH\x00(?P<content_len>\d+)\x00"
        ~ r"[\x00-\xFF]*SCGI\x001\x00[\x00-\xFF]*"
        );

      do {
        received = client.receive(chunk);
        buffer ~= chunk[0..received];
        
        // Проверяем, что полученные в буфер данные похожи на SCGI запрос,
        // и извлекаем данные о длинах заголовка и контента, 
        // иначе повторяем чтение из сокета для получения остальных данных.
        if( auto m = match(buffer, header_pattern) ) {
          uint header_len  = to!uint(m.captures["header_len"]);
          uint content_len = to!uint(m.captures["content_len"]);
          
          // Если размер полученных данных в буфере соответствует указанным длинам заголовка и контента,
          // выпиливаем соответствующие части из буфера и продолжаем обработку запроса далее, 
          // иначе повторяем чтение из сокета для получения остальных данных.
          if( buffer.length == (m.captures["header_len"].length + 1 + header_len + 1 + content_len) ) {
            uint i = 0;
            
            while( buffer[i++] != ':') {}              
            auto header_data = cast(string)buffer[i .. i + header_len];
            
            i += header_len + 1;
            auto content_data = cast(string)buffer[i .. i + content_len];
            
            writefln("%s\n-------------", header_data);
            writefln("%s", content_data);
            
            auto request  = new RequestT(header_data, content_data);
            auto response = new ResponseT();
    
            foreach(tween; tweens) tween.preprocess(request, response);            
            route_request(request, response);            
            foreach(tween; tweens) tween.postprocess(request, response);

            client.send(response.buffer);
            
            buffer.length = 0;
            break;
          }             
        }
        
        static const max_uint_literal_len = to!string(uint.max).length;
        
        if( buffer.length >= max_uint_literal_len + 1 ) 
          enforce( match(buffer, r"^\d+:[\x00-\xFF]*"), "Invalid request!"); 
        
        if( buffer.length >= max_uint_literal_len + 1 + "CONTENT_LENGTH:".length + 1 + max_uint_literal_len ) 
          enforce( match(buffer, r"^\d+:[\x00-\xFF]*"), "Invalid request!"); 
        
      } 
      while( true );
      
      client.shutdown(SocketShutdown.BOTH);
      client.close();
    }
  }
  
  bool route_request(RequestT request, ResponseT response)
  {
    bool route_match_found = false;
    
    foreach(route; routes)
      if( auto m = match(request.path, route.path_pattern) ) {
        route_match_found = true;
        
        string[string] context;
        foreach(name; route.path_pattern.namedCaptures) context[name] = m.captures[name];
        
        route.handler(request, response, context);
        
        break;
      }
    
    return route_match_found;
  }
}