module restforge.languages.csharp.aspnetcore.http.server;

import restforge.types;
import restforge.model;
import restforge.globals;
import restforge.stringbuilder;

import restforge.languages.csharp.aspnetcore.extensions;
import restforge.languages.csharp.aspnetcore.generator;

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
		builder.appendLine("{0}public class {1}Query", generateTabs(tabLevel), m.name);
		builder.appendLine("{0}{", generateTabs(tabLevel));
		foreach(q; m.query) {
			builder.appendLine("{0}public {2} {1} { get; }", generateTabs(tabLevel+1), q.name, generateType(q, false, true));
		}
		builder.appendLine();
		builder.appendLine("{0}internal {1}Query(Microsoft.AspNetCore.Http.IQueryCollection query) {", generateTabs(tabLevel+1), m.name);
		foreach (smp; m.query) {
			if (smp.type.mode == TypeMode.Collection) {
				builder.appendLine("{0}if (query.TryGetValue(\"{1}\", out StringValues values)) this.{1} = values.Select(a => {2}).ToList();", generateTabs(tabLevel+2), smp.name, getStringConversion(smp, "a"));
			} else if (smp.type.mode == TypeMode.Primitive) {
				builder.appendLine("{0}if (query.TryGetValue(\"{1}\", out StringValues values)) this.{1} = {2};", generateTabs(tabLevel+2), smp.name, getStringConversion(smp, "values.First()"));
			}
		}
		builder.appendLine("{0}}", generateTabs(tabLevel+1));
		builder.appendLine("{0}}", generateTabs(tabLevel));
	}

	//Generate Header classes
	builder.appendLine();
	foreach(m; s.methods) {
		if (m.header.length == 0) continue;
		builder.appendLine("{0}public class {1}Headers", generateTabs(tabLevel), m.name);
		builder.appendLine("{0}{", generateTabs(tabLevel));
		foreach(q; m.header) {
			builder.appendLine("{0}public {2} {1} { get; }", generateTabs(tabLevel+1), q.name, generateType(q, false, true));
		}
		builder.appendLine();
		builder.appendLine("{0}internal {1}Headers(Microsoft.AspNetCore.Http.IHeaderDictionary headers) {", generateTabs(tabLevel+1), m.name);
		foreach (smp; m.header) {
			if (smp.type.mode == TypeMode.Collection) {
				builder.appendLine("{0}if (headers.TryGetValue(\"{1}\", out StringValues values)) this.{1} = values.Select(a => {2}).ToList();", generateTabs(tabLevel+2), smp.name, getStringConversion(smp, "a"));
			} else if (smp.type.mode == TypeMode.Primitive) {
				builder.appendLine("{0}if (headers.TryGetValue(\"{1}\", out StringValues values)) this.{1} = {2};", generateTabs(tabLevel+2), smp.name, getStringConversion(smp, "values.First()"));
			}
		}
		builder.appendLine("{0}}", generateTabs(tabLevel+1));
		builder.appendLine("{0}}", generateTabs(tabLevel));
	}

	builder.appendLine();
	builder.appendLine("{0}public interface I{1}", generateTabs(tabLevel), s.name);
	builder.appendLine("{0}{", generateTabs(tabLevel));
	foreach(m; s.methods) {
		builder.append("{0}Task<IActionResult> {1}(", generateTabs(tabLevel+1), m.name);
		generateServerMethodParams(builder, m, true);
		builder.appendLine(");");
	}
	builder.appendLine("{0}}", generateTabs(tabLevel));
	builder.appendLine();
	if (ext !is null && ext.hasArea()) {
		builder.appendLine("{0}[Area(\"{1}\")]", generateTabs(tabLevel), ext.area);
	}
	if (s.route != string.init) {
		builder.appendLine("{0}[Route(\"{1}\")]", generateTabs(tabLevel), s.route);
	}
	generateAuthorization(builder, ext !is null ? ext.getAuthorization() : null, s.authenticate, false, tabLevel);
	builder.appendLine("{0}public abstract partial class {1}Base : HotwireControllerBase, I{1}", generateTabs(tabLevel), s.name);
	builder.appendLine("{0}{", generateTabs(tabLevel));
	builder.appendLine("{0}protected {1}Base(IEnumerable<IHotwireSerializer> serializers, IEnumerable<IHotwireAuthentication> authenticators) : base(serializers) {}", generateTabs(tabLevel+1), s.name);
	builder.appendLine();
	foreach(sm; s.methods) {
		generateMethodServer(builder, sm, cast(ushort)(tabLevel+1));
	}
	builder.appendLine("{0}}", generateTabs(tabLevel));
}

public void generateMethodServer(StringBuilder builder, HttpServiceMethod sm, ushort tabLevel) {

	builder.appendLine();
	auto routeTemplate = generateServerRoute(sm.route);
	if (routeTemplate == string.init) {
		builder.appendLine("{0}[Http{1}]",
			generateTabs(tabLevel),
			to!string(sm.verb));
	}
	else {
		builder.appendLine("{0}[Http{1}(\"{2}\")]", generateTabs(tabLevel), to!string(sm.verb), routeTemplate);
	}

	auto ext = sm.getAspNetCoreHttpExtension();
	generateAuthorization(builder, ext !is null ? ext.getAuthorization() : null, sm.authenticate, sm.parent.authenticate, tabLevel);

	if (ext !is null && ext.hasArea) {
		builder.appendLine("{0}[Area(\"{1}\")]", generateTabs(tabLevel), ext.area);
	}

	builder.append("{0}public Task<IActionResult> {1}Base(", generateTabs(tabLevel), cleanName(sm.name));
	generateServerMethodParams(builder, sm, false);
	builder.appendLine(")");
	builder.appendLine("{0}{", generateTabs(tabLevel));

	if (sm.query.length != 0) builder.appendLine("{0}var query = new {1}Query(HttpContext.Request.Query);", generateTabs(tabLevel+1), cleanName(sm.name));
	if (sm.header.length != 0) builder.appendLine("{0}var headers = new {1}Headers(HttpContext.Request.Headers);", generateTabs(tabLevel+1), cleanName(sm.name));

	builder.append("{0}return {1}(", generateTabs(tabLevel+1), cleanName(sm.name));

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
	builder.appendLine("{0}}", generateTabs(tabLevel));

	builder.append("{0}public abstract Task<IActionResult> {1}(", generateTabs(tabLevel), sm.name);
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
