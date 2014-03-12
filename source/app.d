module main;

import std.conv;
import std.array;
import std.string;
import std.stdio;
import std.process;
import mustache;
import st.net.scgi;
import st.net.http;
import std.uri;
import std.regex;

string escapeHTML(string unsafe)
{
	return unsafe
		.replace("&", "&amp;")
		.replace("<", "&lt;")
		.replace(">", "&gh;")
		.replace("\"", "&quot;")
		.replace("'", "&#039;");			    
}

void index_view(CGIRequest request, CGIResponse response, string[string] context)
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
	</body>
</html>`.strip();


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

	response.output ~= html_tpl ~ "\r\n";
}

void main(string[] args)
{
	auto cgiapp = new SCGIApp();

  cgiapp.routes = [
    RouteEntry("default", &index_view, regex(r"^/rapira/test/(?P<testid>\d+)/*$")),
    RouteEntry("default", &index_view, regex(r"^.*$"))
  ];
  
  cgiapp.run();
}

