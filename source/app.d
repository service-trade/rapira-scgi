module main;

import std.conv;
import std.array;
import std.string;
import std.stdio;
import std.process;
//import mustache;
import st.net.scgi;
import st.net.http;
import std.uri;
import std.regex;
import std.datetime;
import st.net.cookie;
import st.net.forms;

string escapeHTML(string unsafe)
{
	return unsafe
		.replace("&", "&amp;")
		.replace("<", "&lt;")
		.replace(">", "&gh;")
		.replace("\"", "&quot;")
		.replace("'", "&#039;");			    
}

FileData[][string] form_files_data; 

void index_view(Request request, Response response, string[string] context)
{
	string html_tpl =
`
<!DOCTYPE html>
<html lang="ru">
	<head>
		<title>Рапира SCGI</title>
	</head>
	<body>
		<h1>РАПИРА SCGI</h1>
		<table>
			{{ meta_vars }}
		</table>
		<h2>params</h2>
		<table>
			{{ params }}
		</table>
		<h2>context</h2>
		<table>
			{{ context }}
		</table>
		<h2>form_data</h2>
		<table>
			{{ form_data }}
		</table>
	</body>
</html>`.strip();

	form_files_data = request.form_files_data;
	
  	string env = "";
	foreach(varname, varval; request.meta_variables)
		if( varname != "QUERY_STRING" )
			env ~= "<tr><td>" ~ varname ~ "</td><td><pre>" ~ escapeHTML(varval) ~ "</pre></td></tr>\n";
		else
		env ~= "<tr><td>" ~ varname ~ "</td><td><pre>" ~ escapeHTML(decode(varval)) ~ "</pre></td></tr>\n";


	html_tpl = html_tpl.replace("{{ meta_vars }}", env);

	string params;
	foreach(pname, pval; request.params)
		params ~= "<tr><td>" ~ pname ~ "</td><td><pre>" ~ escapeHTML(pval) ~ "</pre></td></tr>\n";

	html_tpl = html_tpl.replace("{{ params }}", params);

	string ctx;
	foreach(pname, pval; context)
		ctx ~= "<tr><td>" ~ pname ~ "</td><td><pre>" ~ escapeHTML(pval) ~ "</pre></td></tr>\n";

	html_tpl = html_tpl.replace("{{ context }}", ctx);

	string form_data;
	foreach(pname, pvals; request.form_data)
		foreach(pval; pvals)
			form_data ~= "<tr><td>" ~ pname ~ "</td><td><pre>" ~ escapeHTML(pval) ~ "</pre></td></tr>\n";

	html_tpl = html_tpl.replace("{{ form_data }}", form_data);

	response.output ~= html_tpl ~ "\r\n";
	
	foreach(filename, files_data; request.form_files_data)
		foreach(file_data; files_data)
			writeln(filename, ": (", file_data.content_type, "): ", file_data.data);
		
  (response.new_cookie("test_cookie", "new_test_value111")).mark_as_persistent();
  
  //response.set_cookie("test_cookie2", "test_value2");
  //response.set_cookie("test_cookie3", "test_value3");
}

void files_view(Request request, Response response, string[string] context)
{
	string filename = context.get("filename", "");
	if( filename !in form_files_data ) {
		response.status_code(HTTPStatusCode.NOT_FOUND);
		response.output = "<b>Файл '%s' не найден!".format(filename);
		return;
	}   
	
	response.headers["Content-Type"] = [form_files_data[filename][0].content_type];
	response.output = cast(string)form_files_data[filename][0].data;
}

void main(string[] args)
{
	auto srv = new SCGIServer!();

  srv.routes = [
  	RouteEntry("files",   &files_view, regex(r"^/rapira/file/(?P<filename>(\w|\.)+)/*$")),
    RouteEntry("default", &index_view, regex(r"^/rapira/test/(?P<testid>\d+)/*$")),
    RouteEntry("default", &index_view, regex(r"^.*$"))
  ];
  
  writeln("Rapira SCGI started.");

  srv.run();
}

