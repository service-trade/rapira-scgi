module st.net.cgi;

import std.array;
import std.exception;
import std.conv;
import std.stdio;
import std.process;
import st.net.http;
/*
immutable string unknown_CGI_version_message = "Unknown CGI protocol version, must be CGI/1.1";

struct CGIVersionInfo
{
	uint major;
	uint minor;
}

struct CGIRequest {
	@property string[string] meta_variables() { return environment.toAA(); }

	static string predefined_meta_vars(string[] meta_variables_list)
	{
		string result;
		foreach(var; meta_variables_list)
			result ~= "@property static string meta_" ~ var ~"() { return environment.get(\"" ~ var ~ "\", ""); };";
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

	private   static CGIVersionInfo cgi_version_data;  // GATEWAY_INTERFACE
	@property static CGIVersionInfo cgi_version() { return cgi_version_data; }

	private   static string path_data; // PATH_INFO
	@property static string path() { return path_data; }

	private   static string[string] params_data; // QUERY_STRING
	@property static string[string] params() { return params_data; }

	static this() 
	{
		// Parse and check CGI protocol version.
		string[] x = meta_GATEWAY_INTERFACE.split("/");
		enforce(x.length == 2 && x[0] == "CGI", unknown_CGI_version_message);

		x = x[1].split('.');
		enforce(x.length == 2, unknown_CGI_version_message);

		cgi_version_data.major = to!uint(x[0]);
		cgi_version_data.minor = to!uint(x[1]);
		
		enforce(cgi_version_data.major == 1 && this.cgi_version_data.minor == 1, unknown_CGI_version_message);

		// Parse request query path
		path_data = std.uri.decodeComponent(meta_PATH_INFO);

		// Parse request query parameters
		foreach(param; meta_QUERY_STRING.split('&')) {
			auto param_parts = std.algorithm.map!( (x){ return std.uri.decodeComponent(x); } )( param.split('=') );
			params_data[param_parts[0]] = param_parts.length == 1 ? "" : std.array.join(param_parts[1..$], "=");
		}
	}
}

struct RouteEntry
{
	string group;

}

class CGIApp 
{
	private bool headers_sent = false;

	string[string] headers;

	CGIRequest request;


	@property 
	string[string] request_meta_variables()
	{
		return environment.toAA();
	}

	this(string content_type = "text/html")
	{
		this.headers["Content-Type"] = content_type;
	}

	void send_headers()
	in {
		assert( !this.headers_sent, "Response headers already sent!");
	}
	body {
		scope(success) this.headers_sent = true;

		foreach(key, value; headers) {
			write(key ~ ": " ~ value ~ "\r\n");
		}
		write("\r\n");
	}

	@property {
		void status_code(int code)
		in {
			assert(code > 99 && code < 1000);
		}
		body {
			headers["Status"] = to!string(code);
		}

		int status_code()
		{
			if( "Status" in this.headers ) 
				return to!int(this.headers["Status"]);
			else
				return HTTPStatusCode.OK; // RFC3875 6.2.1 -- status 200 'OK' is assumed if it is omitted.
		}
	}
}
*/