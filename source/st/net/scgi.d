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
import st.net.forms;


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
  
	mixin HttpCookiesMixin;
	mixin FormDataMixin;
  
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

///////////////////////////////////////////////////////////////////////////////
class Response {
  string[][string] headers;
  string output;

  mixin HttpCookiesMixin;
  
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
class SCGIServer(RequestT = Request, ResponseT = Response) 
  if( is(RequestT : Request) && is(ResponseT : Response) )
{
  protected Socket server;
  
  RouteEntry[] routes;
  Tween[] tweens;
  
	this(int port = 8080)
	{
    tweens = [ 
      cast(Tween)new HttpCookiesTween(),
      cast(Tween)new SessionTween(),
      cast(Tween)new HTMLFormDataParserTween(),
    ];
    
    server = new TcpSocket();
    server.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
    server.bind(new InternetAddress(8080));
    server.listen(1);
 
		//this.headers["Content-Type"] = content_type;
    
	}

	class InvalidSCGIRequest: Exception
	{
		this(string message)
		{
			super(message);
		}
	}
	
	bool parse_scgi_request(string buffer, out string header, out string content)
	{
		if( buffer.length == 0 ) return false;

		// Найти в буфере первое вхождение символа ':'
		size_t netstr_length = 0;
		size_t header_start = 0;
		foreach(size_t i, char c; buffer)
			if( c == ':' ) {
				// Попытаться предыдущую часть массива преобразовать к значению типа size_t,
				// если при конвертации возникла ошибка, то выкинуть исключени о недопустимости такого запроса.
				try { netstr_length = to!size_t(buffer[0 .. i]); } catch(ConvException e) { throw new InvalidSCGIRequest("Invalid netstring length literal!"); }
				
				// Используя полученное значение проверить, что в буфере содержиться вся строка типа netstring, если нет вернуть False
				if( buffer.length < i + 1 + netstr_length + 1 ) return false;
				if( buffer[i + 1 + netstr_length] != ',' ) throw new InvalidSCGIRequest("Broken netstring!");
				
				// Выделить содержимое заголовка из строки типа netstring в отдельный массив типа char[]
				header_start = i + 1;
				header = buffer[header_start .. header_start + netstr_length];
								 
				break;
			} 
		// Если не удалось найти его, и размер данных в буфера уже достаточен, чтобы вместить литерал максимального значения
		// типа size_t и символ ':', то выкинуть исключение о недопустимости такого запроса.
		if( netstr_length == 0 && buffer.length >= to!string(size_t.max).length + 1 ) throw new InvalidSCGIRequest("Broken netstring or length literal too long");  
		
		
		// Убедиться что в начале заголовка присутсnвует поле с именем CONTENT_LENGTH, если нет выкинуть исключение о недопустимости
		// такого запроса.
		if( header[0 .. "CONTENT_LENGTH".length] != "CONTENT_LENGTH" ) throw new InvalidSCGIRequest("CONTENT_LENGTH field must be first!");
				
		// Считать значение поле CONTENT_LENGTH в формате (^CONTENT_LENGTH\0\d+\0) и попытаться преобразовать к значению типа size_t
		// если при конвертации возникла ошибка, то выкинуть исключени о недопустимости такого запроса.
		size_t content_length = 0;
		bool content_length_valid = false;
		foreach(size_t i, char c; header["CONTENT_LENGTH\0".length .. $])
			if( c == '\0' ) {
				try{ content_length = to!size_t(header["CONTENT_LENGTH\0".length .. "CONTENT_LENGTH\0".length + i]); } catch(ConvException e) { throw new InvalidSCGIRequest("Invalid CONTENT_LENGTH value literal!"); }				
				content_length_valid = true;
				break;
			}
		if( !content_length_valid ) throw new InvalidSCGIRequest("Invalid CONTENT_LENGTH value literal!");

		// Зная длинну заголовка в формате строки netstring и получив значение размера контента убедиться, что в буфере находятся
		// все данные запроса, если нет вернуть False.
		auto content_start = header_start + netstr_length + 1; 
		if( buffer.length < content_start + content_length ) return false; 
		
		// Выделить данные контента из буфера и вернуть True.    
		content = buffer[content_start .. content_start + content_length];		 
		return true;
	}

  void run()
  { 
    while(true) {
      Socket client = server.accept();
      
      auto buffer = appender!(char[])();
      buffer.reserve(4096);
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
	      if( received == -1 ) { } // ошибку обработать надо бы.
        buffer.put(chunk[0..received]);
      	
      	string header;
      	string content;              

	      if( parse_scgi_request(cast(string)buffer.data, header, content) ) {
          writefln("%s\n-------------", header);
          writefln("%s", content);
          
          auto request  = new RequestT(header, content);
          auto response = new ResponseT();
  
          foreach(tween; tweens) tween.preprocess(request, response);            
          route_request(request, response);            
          foreach(tween; tweens) tween.postprocess(request, response);

          client.send(response.buffer);
          
          break;
	      } 	      
      } while( received > 0 );
                      
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