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
struct FileData {
	string content_type;
	byte[] data;
}
///////////////////////////////////////////////////////////////////////////////
mixin template FormDataMixin()
{
  string[][string]   form_data;
  FileData[][string] form_files_data;
}

///////////////////////////////////////////////////////////////////////////////
class HTMLFormDataParserTween: Tween
{
  override void preprocess(Request request, Response response)
  {
    if( request.meta_variables.get("REQUEST_METHOD", "") != "POST" ) return;  	
    if( request.content_data.length == 0 ) return;  	
    if( request.meta_variables.get("CONTENT_TYPE", "") == "" ) return;  	
  	
  	string content_type = toLower(request.meta_variables["CONTENT_TYPE"]);
  	
  	// http://www.w3.org/TR/html5/forms.html#attr-fs-enctype
  	if( content_type.startsWith("text/plain") ) {
  		foreach(line; request.content_data.split("\r\n")) {
  			string[] splitted = line.split('=');
  			if( !splitted.length ) continue;
  			string name = splitted[0];
  			if( name !in request.form_data ) request.form_data[name] = [];
  			request.form_data[name] ~= splitted.length > 1 ? join(splitted[1 .. $], "=") : "";  
  		}
	} else if( content_type.startsWith("application/x-www-form-urlencoded") ) {
  		foreach(line; request.content_data.replace("+", " ").split('&')) {
  			string[] splitted = line.split('=');
  			if( !splitted.length ) continue;
  			string name = decodeComponent(splitted[0]); 
  			if( name !in request.form_data ) request.form_data[name] = [];
  			request.form_data[name] ~= splitted.length > 1 ? decodeComponent(join(splitted[1 .. $], "=")) : "";  
  		}
	} else if( content_type.startsWith("multipart/form-data") ) { // http://tools.ietf.org/html/rfc2388
		string[] boundary_kv = (request.meta_variables["CONTENT_TYPE"].split("; ")[1]).split('=');
		string boundary = toLower(boundary_kv[0]) == "boundary" ? boundary_kv[1] : "";
		if( boundary[0] == boundary[$-1] && (boundary[0] == '"' || boundary[0] == '\'') ) boundary = boundary[1 .. $-1];

		if( !request.content_data.startsWith("--" ~ boundary ~ "\r\n") ) return;		
		string[] parts = request.content_data[("--" ~ boundary ~ "\r\n").length .. $].split("\r\n--" ~ boundary ~ "\r\n");
		parts = parts[0 .. $-1] ~ parts[$-1].split("\r\n--" ~ boundary ~ "--\r\n")[0];
				
		foreach(part; parts) {
			string[] part_lines = part.split("\r\n");
			if( part_lines[0].startsWith("Content-Disposition: form-data;") ) {
				string[] params = part_lines[0].split("; ")[1 .. $];
				string[] param_kv = params[0].split("=");
				string name;
				string filename;
				if( param_kv[0] == "name" ) {
					name = join(param_kv[1 .. $], "=")[1 .. $-1];				
					if( name !in request.form_data ) request.form_data[name] = [];
					if( params.length > 1 ) {
						param_kv = params[1].split("=");
						if( param_kv[0] == "filename") filename = join(param_kv[1 .. $], "=")[1 .. $-1];															
						request.form_data[name] ~= filename;
						if( filename != "" && part_lines[1].startsWith("Content-Type: ") ) {
							if( name !in request.form_files_data ) request.form_files_data[name] = []; 							
							request.form_files_data[name] ~= FileData( 
								part_lines[1]["Content-Type: ".length .. $],
								cast(byte[])join(part_lines[3 .. $], "\r\n")
							);
						}
					} else {
						if( part_lines[1] != "" ) continue;
						request.form_data[name] ~= join(part_lines[2 .. $], "\r\n");						
					}					
				}
			}
		}
		
	} else {
		assert(false, "Unknown CONTENT_TYPE!");
	}
  }
}

