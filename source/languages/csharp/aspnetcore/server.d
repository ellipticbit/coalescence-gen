module coalescence.languages.csharp.aspnetcore.server;

import coalescence.types;
import coalescence.schema;
import coalescence.globals;
import phobos.text.stringbuilder;
import coalescence.utility;

import coalescence.languages.csharp.extensions;
import coalescence.languages.csharp.language;
import coalescence.languages.csharp.generator;

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
		builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"2.0.0.0\")]");
		builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
		builder.tabs(tabLevel).appendLine(i"public class $(m.name)Query");
		builder.tabs(tabLevel++).appendLine("{");
		foreach(q; m.query) {
			builder.tabs(tabLevel).appendLine(i"public $(generateType(q, false, true)) $(q.name) { get; }");
		}
		builder.appendLine();
		builder.tabs(tabLevel++).appendLine(i"internal $(m.name)Query(Microsoft.AspNetCore.Http.IQueryCollection query) {");
		int c = 1;
		foreach (smp; m.query) {
			if (smp.type.mode == TypeMode.Collection) {
				builder.tabs(tabLevel).appendLine(i"if (query.TryGetValue(\"$(smp.name)\", out StringValues values$(to!string(c)))) this.$(smp.name) = values$(to!string(c)).Select(a => $(getStringConversion(smp, "a"))).ToList();");
			} else if (smp.type.mode == TypeMode.Primitive) {
				builder.tabs(tabLevel).appendLine(i"if (query.TryGetValue(\"$(smp.name)\", out StringValues values$(to!string(c)))) this.$(smp.name) = $(getStringConversion(smp, "values" ~ to!string(c) ~ ".First()"));");
			}
			c++;
		}
		builder.tabs(--tabLevel).appendLine("}");
		builder.tabs(--tabLevel).appendLine("}");
	}

	//Generate Header classes
	builder.appendLine();
	foreach(m; s.methods) {
		if (m.header.length == 0) continue;
		builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"2.0.0.0\")]");
		builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
		builder.tabs(tabLevel).appendLine(i"public class $(m.name)Headers");
		builder.tabs(tabLevel++).appendLine("{");
		foreach(q; m.header) {
			builder.tabs(tabLevel).appendLine(i"public $(generateType(q, false, true)) $(q.name) { get; }");
		}
		builder.appendLine();
		builder.tabs(tabLevel++).appendLine(i"internal $(m.name)Headers(Microsoft.AspNetCore.Http.IHeaderDictionary headers) {");
		int c = 1;
		foreach (smp; m.header) {
			if (smp.type.mode == TypeMode.Collection) {
				builder.tabs(tabLevel).appendLine(i"if (headers.TryGetValue(\"$(smp.name)\", out StringValues values$(to!string(c)))) this.$(smp.name) = values$(to!string(c)).Select(a => $(getStringConversion(smp, "a"))).ToList();");
			} else if (smp.type.mode == TypeMode.Primitive) {
				builder.tabs(tabLevel).appendLine(i"if (headers.TryGetValue(\"$(smp.name)\", out StringValues values$(to!string(c)))) this.$(smp.name) = $(getStringConversion(smp, "values" ~ to!string(c) ~ ".First()"));");
			}
			c++;
		}
		builder.tabs(--tabLevel).appendLine("}");
		builder.tabs(--tabLevel).appendLine("}");
	}

	builder.appendLine();
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"2.0.0.0\")]");
	builder.tabs(tabLevel).appendLine(i"public interface I$(s.name)");
	builder.tabs(tabLevel++).appendLine("{");
	foreach(m; s.methods) {
		builder.tabs(tabLevel).append(i"Task<IActionResult> $(m.name)(");
		generateServerMethodParams(builder, m, true);
		builder.appendLine(");");
	}
	builder.tabs(--tabLevel).appendLine("}");
	builder.appendLine();
	if (ext !is null && ext.hasArea()) {
		builder.tabs(tabLevel).appendLine(i"[Area(\"$(ext.area)\")]");
	}
	if (s.route.length > 0) {
		builder.tabs(tabLevel).appendLine(i"[Route(\"$(s.route.join("/"))\")]");
	}
	generateAuthorization(builder, ext !is null ? ext.getAuthorization() : null, s.authenticate, false, tabLevel);
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"2.0.0.0\")]");
	builder.tabs(tabLevel).appendLine(i"public abstract partial class $(s.name)Base : CoalescenceControllerBase, I$(s.name)");
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel).appendLine(i"protected $(s.name)Base(IEnumerable<ICoalescenceSerializer> serializers) : base(serializers) {}");
	builder.appendLine();
	foreach(sm; s.methods) {
		generateMethodServer(builder, sm, cast(ushort)(tabLevel));
	}
	builder.tabs(--tabLevel).appendLine("}");
}

public void generateMethodServer(StringBuilder builder, HttpServiceMethod sm, ushort tabLevel) {

	builder.appendLine();
	auto routeTemplate = generateServerRoute(sm);
	if (routeTemplate == string.init) {
		builder.tabs(tabLevel).appendLine(i"[Http$(to!string(sm.verb))]");
	}
	else {
		builder.tabs(tabLevel).appendLine(i"[Http$(to!string(sm.verb))(\"$(routeTemplate)\")]");
	}

	auto ext = sm.getAspNetCoreHttpExtension();
	generateAuthorization(builder, ext !is null ? ext.getAuthorization() : null, sm.authenticate, sm.parent.authenticate, tabLevel);

	if (ext !is null && ext.hasArea) {
		builder.tabs(tabLevel).appendLine(i"[Area(\"$(ext.area)\")]");
	}

	builder.tabs(tabLevel).append(i"public Task<IActionResult> $(cleanName(sm.name))Base(");
	generateServerMethodParams(builder, sm, false);
	builder.appendLine(")");
	builder.tabs(tabLevel++).appendLine("{");

	if (sm.query.length != 0) builder.tabs(tabLevel).appendLine(i"var query = new $(cleanName(sm.name))Query(HttpContext.Request.Query);");
	if (sm.header.length != 0) builder.tabs(tabLevel).appendLine(i"var headers = new $(cleanName(sm.name))Headers(HttpContext.Request.Headers);");

	builder.tabs(tabLevel).append(i"return $(cleanName(sm.name))(");

	// Generate required parameters
	foreach (smp; sm.route) {
		if (smp.hasDefault()) continue;
		if (smp.type.mode == TypeMode.Primitive && (cast(TypePrimitive)smp.type).primitive == TypePrimitives.Base64ByteArray) builder.append(i"$(smp.name).ArrayFromUrlBase64(), ");
		else if (smp.type.mode == TypeMode.Primitive && (cast(TypePrimitive)smp.type).primitive == TypePrimitives.Base64String) builder.append(i"$(smp.name).StringFromUrlBase64Utf8(), ");
		else builder.append(i"$(cleanName(smp.name)), ");
	}

	foreach (smp; sm.content) {
		if (smp.hasDefault()) continue;
		builder.append(i"$(cleanName(smp.name)), ");
	}

	// Generate optional parameters
	foreach (smp; sm.route) {
		if (!smp.hasDefault()) continue;
		if (smp.type.mode == TypeMode.Primitive && (cast(TypePrimitive)smp.type).primitive == TypePrimitives.Base64ByteArray) builder.append(i"$(smp.name).ArrayFromUrlBase64()");
		else if (smp.type.mode == TypeMode.Primitive && (cast(TypePrimitive)smp.type).primitive == TypePrimitives.Base64String) builder.append(i"$(smp.name).StringFromUrlBase64Utf8()");
		else builder.append(i"$(cleanName(smp.name)), ");
	}

	if (sm.query.length != 0) {
		builder.append("query, ");
	}

	if (sm.header.length != 0) {
		builder.append("headers, ");
	}

	foreach (smp; sm.content) {
		if (!smp.hasDefault()) continue;
		builder.append(i"$(cleanName(smp.name)), ");
	}

	if ((sm.route.length + sm.query.length + sm.header.length + sm.content.length) > 0) builder.remove(builder.length-2, 2);
	builder.appendLine(");");
	builder.tabs(--tabLevel).appendLine("}");

	builder.tabs(tabLevel).append(i"public abstract Task<IActionResult> $(sm.name)(");
	generateServerMethodParams(builder, sm, true);
	builder.appendLine(");");
}

private void generateServerMethodParams(StringBuilder builder, HttpServiceMethod sm, bool isAbstract) {
	// Generate required parameters
	foreach (smp; sm.route) {
		if (smp.hasDefault()) continue;
		builder.append(i"$(generateType(smp, isAbstract, false)) $(cleanName(smp.name)), ");
	}

	foreach (smp; sm.content) {
		if (smp.hasDefault()) continue;
		builder.append(i"$(!isAbstract ? "[FromBody] " : string.init)$(generateType(smp, isAbstract, false)) $(cleanName(smp.name)), ");
	}

	// Generate optional parameters
	foreach (smp; sm.route) {
		if (!smp.hasDefault()) continue;
		builder.append(i"$(generateType(smp, isAbstract, false)) $(cleanName(smp.name)) = $(getDefaultValue(smp)), ");
	}

	// These parameters are only required in the abstract signature
	if (isAbstract) {
		if (sm.query.length != 0) {
			builder.append(i"$(sm.name)Query query = null, ");
		}

		if (sm.header.length != 0) {
			builder.append(i"$(sm.name)Headers headers = null, ");
		}
	}

	foreach (smp; sm.content) {
		if (!smp.hasDefault()) continue;
		builder.append(i"$(!isAbstract ? "[FromBody] " : string.init)$(generateType(smp, isAbstract, false)) $(cleanName(smp.name)) = $(getDefaultValue(smp)), ");
	}

	if (isAbstract && (sm.route.length + sm.query.length + sm.header.length + sm.content.length) > 0) builder.remove(builder.length-2, 2);
	else if (!isAbstract && (sm.route.length + sm.content.length) > 0) builder.remove(builder.length-2, 2);
}

private string generateServerRoute(HttpServiceMethod sm) {
	string route = string.init;
	foreach(rp; sm.routeParts) {
		auto rpt = sm.getRouteType(rp);
		if(rpt !is null) {
			if (rpt.type.mode == TypeMode.Enum || rpt.isPrimitiveType(TypePrimitives.String) || rpt.isPrimitiveType(TypePrimitives.Base64String) || rpt.isPrimitiveType(TypePrimitives.Base64ByteArray)) {
				route ~= text(i"{$(cleanName(rp))}/");
			} else {
				route ~= text(i"{$(cleanName(rp)):$(generateType(rpt, false, rpt.hasDefault))}/");
			}
		}
		else {
			route ~= text(i"$(cleanName(rp))/");
		}
	}
	return route.strip("/");
}
