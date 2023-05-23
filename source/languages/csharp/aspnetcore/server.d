module hwgen.languages.csharp.aspnetcore.server;

import hwgen.types;
import hwgen.schema;
import hwgen.globals;
import hwgen.stringbuilder;
import hwgen.utility;

import hwgen.languages.csharp.extensions;
import hwgen.languages.csharp.generator;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.stdio;
import std.string;

public void generateHttpServer(StringBuilder builder, HttpService s, ushort tabLevel) {
	auto ext = s.getAspNetCoreHttpExtension();

	//Generate Query classes
	builder.appendLine();
	foreach(m; s.methods) {
		if (m.query.length == 0) continue;
		builder.tabs(tabLevel).appendLine("public class {0}Query", m.name);
		builder.tabs(tabLevel++).appendLine("{");
		foreach(q; m.query) {
			builder.tabs(tabLevel).appendLine("public {1} {0} { get; }", q.name, generateType(q, false, true));
		}
		builder.appendLine();
		builder.tabs(tabLevel++).appendLine("internal {0}Query(Microsoft.AspNetCore.Http.IQueryCollection query) {", m.name);
		foreach (smp; m.query) {
			if (smp.type.mode == TypeMode.Collection) {
				builder.tabs(tabLevel).appendLine("if (query.TryGetValue(\"{0}\", out StringValues values)) this.{0} = values.Select(a => {1}).ToList();", smp.name, getStringConversion(smp, "a"));
			} else if (smp.type.mode == TypeMode.Primitive) {
				builder.tabs(tabLevel).appendLine("if (query.TryGetValue(\"{0}\", out StringValues values)) this.{0} = {1};", smp.name, getStringConversion(smp, "values.First()"));
			}
		}
		builder.tabs(--tabLevel).appendLine("}");
		builder.tabs(--tabLevel).appendLine("}");
	}

	//Generate Header classes
	builder.appendLine();
	foreach(m; s.methods) {
		if (m.header.length == 0) continue;
		builder.tabs(tabLevel).appendLine("public class {0}Headers", m.name);
		builder.tabs(tabLevel++).appendLine("{");
		foreach(q; m.header) {
			builder.tabs(tabLevel).appendLine("public {1} {0} { get; }", q.name, generateType(q, false, true));
		}
		builder.appendLine();
		builder.tabs(tabLevel++).appendLine("internal {0}Headers(Microsoft.AspNetCore.Http.IHeaderDictionary headers) {", m.name);
		foreach (smp; m.header) {
			if (smp.type.mode == TypeMode.Collection) {
				builder.tabs(tabLevel).appendLine("if (headers.TryGetValue(\"{0}\", out StringValues values)) this.{0} = values.Select(a => {1}).ToList();", smp.name, getStringConversion(smp, "a"));
			} else if (smp.type.mode == TypeMode.Primitive) {
				builder.tabs(tabLevel).appendLine("if (headers.TryGetValue(\"{0}\", out StringValues values)) this.{0} = {1};", smp.name, getStringConversion(smp, "values.First()"));
			}
		}
		builder.tabs(--tabLevel).appendLine("}");
		builder.tabs(--tabLevel).appendLine("}");
	}

	builder.appendLine();
	builder.tabs(tabLevel).appendLine("public interface I{0}", s.name);
	builder.tabs(tabLevel++).appendLine("{");
	foreach(m; s.methods) {
		builder.tabs(tabLevel).append("Task<IActionResult> {0}(", m.name);
		generateServerMethodParams(builder, m, true);
		builder.appendLine(");");
	}
	builder.tabs(--tabLevel).appendLine("}");
	builder.appendLine();
	if (ext !is null && ext.hasArea()) {
		builder.tabs(tabLevel).appendLine("[Area(\"{0}\")]", ext.area);
	}
	if (s.route != string.init) {
		builder.tabs(tabLevel).appendLine("[Route(\"{0}\")]", s.route);
	}
	generateAuthorization(builder, ext !is null ? ext.getAuthorization() : null, s.authenticate, false, tabLevel);
	builder.tabs(tabLevel).appendLine("public abstract partial class {0}Base : HotwireControllerBase, I{0}", s.name);
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel).appendLine("protected {0}Base(IEnumerable<IHotwireSerializer> serializers) : base(serializers) {}", s.name);
	builder.appendLine();
	foreach(sm; s.methods) {
		generateMethodServer(builder, sm, cast(ushort)(tabLevel));
	}
	builder.tabs(--tabLevel).appendLine("}");
}

public void generateMethodServer(StringBuilder builder, HttpServiceMethod sm, ushort tabLevel) {

	builder.appendLine();
	auto routeTemplate = generateServerRoute(sm.route);
	if (routeTemplate == string.init) {
		builder.tabs(tabLevel).appendLine("[Http{0}]", to!string(sm.verb));
	}
	else {
		builder.tabs(tabLevel).appendLine("[Http{0}(\"{1}\")]", to!string(sm.verb), routeTemplate);
	}

	auto ext = sm.getAspNetCoreHttpExtension();
	generateAuthorization(builder, ext !is null ? ext.getAuthorization() : null, sm.authenticate, sm.parent.authenticate, tabLevel);

	if (ext !is null && ext.hasArea) {
		builder.tabs(tabLevel).appendLine("[Area(\"{0}\")]", ext.area);
	}

	builder.tabs(tabLevel).append("public Task<IActionResult> {0}Base(", cleanName(sm.name));
	generateServerMethodParams(builder, sm, false);
	builder.appendLine(")");
	builder.tabs(tabLevel++).appendLine("{");

	if (sm.query.length != 0) builder.tabs(tabLevel).appendLine("var query = new {0}Query(HttpContext.Request.Query);", cleanName(sm.name));
	if (sm.header.length != 0) builder.tabs(tabLevel).appendLine("var headers = new {0}Headers(HttpContext.Request.Headers);", cleanName(sm.name));

	builder.tabs(tabLevel).append("return {0}(", cleanName(sm.name));

	// Generate required parameters
	foreach (smp; sm.route) {
		if (smp.hasDefault()) continue;
		if ((cast(TypePrimitive)smp.type).primitive == TypePrimitives.Base64ByteArray) builder.append("{0}.ArrayFromUrlBase64(), ", smp.name);
		else if ((cast(TypePrimitive)smp.type).primitive == TypePrimitives.Base64String) builder.append("{0}.StringFromUrlBase64Utf8(), ", smp.name);
		else builder.append("{0}, ", cleanName(smp.name));
	}

	foreach (smp; sm.content) {
		if (smp.hasDefault()) continue;
		builder.append("{0}, ", cleanName(smp.name));
	}

	// Generate optional parameters
	foreach (smp; sm.route) {
		if (!smp.hasDefault()) continue;
		if ((cast(TypePrimitive)smp.type).primitive == TypePrimitives.Base64ByteArray) builder.append("{0}.ArrayFromUrlBase64()", smp.name);
		else if ((cast(TypePrimitive)smp.type).primitive == TypePrimitives.Base64String) builder.append("{0}.StringFromUrlBase64Utf8()", smp.name);
		else builder.append("{0}, ", cleanName(smp.name));
	}

	if (sm.query.length != 0) {
		builder.append("query, ");
	}

	if (sm.header.length != 0) {
		builder.append("headers, ");
	}

	foreach (smp; sm.content) {
		if (!smp.hasDefault()) continue;
		builder.append("{0}, ", cleanName(smp.name));
	}

	if ((sm.route.length + sm.query.length + sm.header.length + sm.content.length) > 0) builder.removeRight(2);
	builder.appendLine(");");
	builder.tabs(--tabLevel).appendLine("}");

	builder.tabs(tabLevel).append("public abstract Task<IActionResult> {0}(", sm.name);
	generateServerMethodParams(builder, sm, true);
	builder.appendLine(");");
}

private void generateServerMethodParams(StringBuilder builder, HttpServiceMethod sm, bool isAbstract) {
	// Generate required parameters
	foreach (smp; sm.route) {
		if (smp.hasDefault()) continue;
		builder.append("{0} {1}, ", generateType(smp, isAbstract, false), cleanName(smp.name));
	}

	foreach (smp; sm.content) {
		if (smp.hasDefault()) continue;
		builder.append("{0}{1} {2}, ", !isAbstract ? "[FromBody] " : string.init, generateType(smp, isAbstract, false), cleanName(smp.name));
	}

	// Generate optional parameters
	foreach (smp; sm.route) {
		if (!smp.hasDefault()) continue;
		builder.append("{0} {1} = {2}, ", generateType(smp, isAbstract, false), cleanName(smp.name), getDefaultValue(smp));
	}

	// These parameters are only required in the abstract signature
	if (isAbstract) {
		if (sm.query.length != 0) {
			builder.append("{0}Query query = null, ", sm.name);
		}

		if (sm.header.length != 0) {
			builder.append("{0}Header headers = null, ", sm.name);
		}
	}

	foreach (smp; sm.content) {
		if (!smp.hasDefault()) continue;
		builder.append("{0}{1} {2} = {3}, ", !isAbstract ? "[FromBody] " : string.init, generateType(smp, isAbstract, false), cleanName(smp.name), getDefaultValue(smp));
	}

	if (isAbstract && (sm.route.length + sm.query.length + sm.header.length + sm.content.length) > 0) builder.removeRight(2);
	else if (!isAbstract && (sm.route.length + sm.content.length) > 0) builder.removeRight(2);
}

private string generateServerRoute(TypeComplex[] routeParams) {
	string route = string.init;
	foreach(rp; routeParams) {
		if(rp.type !is null) {
			route ~= "{" ~ cleanName(rp.name) ~ ":" ~ generateType(rp, false, rp.hasDefault) ~ "}";
		}
		else {
			route ~= cleanName(rp.name) ~ "/";
		}
	}
	return route.strip("/");
}
