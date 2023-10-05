module coalescence.languages.csharp.signalr.server;

import coalescence.types;
import coalescence.schema;
import coalescence.globals;
import coalescence.stringbuilder;
import coalescence.utility;

import coalescence.languages.csharp.generator;
import coalescence.languages.csharp.extensions;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.stdio;
import std.string;

public void generateWebsocketServer(StringBuilder builder, WebsocketService s, ushort tabLevel)
{
	builder.appendLine();
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Hotwire.Generator\", \"2.0.0.0\")]");
	builder.tabs(tabLevel).appendLine("{1} interface I{0}Server", s.name, s.isPublic ? "public" : "internal");
	builder.tabs(tabLevel++).appendLine("{");
	foreach(ns; s.namespaces) {
		foreach(m; ns.server) {
			generateInterfaceMethod(builder, m, ns.name, tabLevel);
		}
	}
	builder.tabs(--tabLevel).appendLine("}");

    if (s.hasClient()) {
		builder.appendLine();
		builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Hotwire.Generator\", \"2.0.0.0\")]");
        builder.tabs(tabLevel).appendLine("{1} interface I{0}Client", s.name, s.isPublic ? "public" : "internal");
        builder.tabs(tabLevel++).appendLine("{");
		foreach(ns; s.namespaces) {
			foreach(m; ns.client) {
				generateInterfaceMethod(builder, m, ns.name, tabLevel);
			}
		}
        builder.tabs(--tabLevel).appendLine("}");
    }

	builder.appendLine();
	auto ext = s.getAspNetCoreWebsocketExtension();
	generateAuthorization(builder, ext !is null ? ext.getAuthorization() : null, s.authenticate, false, tabLevel);

	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Hotwire.Generator\", \"2.0.0.0\")]");
	builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
    if (s.hasClient()) {
        builder.tabs(tabLevel).appendLine("{1} abstract class {0}HubBase : Hub<I{0}Client>, I{0}Server", s.name, s.isPublic ? "public" : "internal");
    } else {
        builder.tabs(tabLevel).appendLine("{1} abstract class {0}HubBase : Hub, I{0}Server", s.name, s.isPublic ? "public" : "internal");
    }
	builder.tabs(tabLevel++).appendLine("{");
	foreach(ns; s.namespaces) {
		foreach(m; ns.server) {
			generateMethod(builder, m, ns.name, tabLevel);
		}
	}
	builder.tabs(--tabLevel).appendLine("}");
}

private void generateInterfaceMethod(StringBuilder builder, WebsocketServiceMethod sm, string namespace, ushort tabLevel) {
	builder.tabs(tabLevel).append("Task");
	if(sm.returns.length == 1) {
		if (sm.returns[0].type.mode != TypeMode.Void) {
			builder.append("<{0}>", generateType(sm.returns[0], false));
		}
	} else if (sm.returns.length > 1) {
		builder.append("<(");
		foreach (smp; sm.returns) {
			builder.append("{0} {1}, ", smp.name, generateType(smp, false));
		}
		builder.removeRight(2);
		builder.append(")>");
	}
    builder.append(" {0}{1}(", cleanName(namespace), cleanName(sm.name));
    generateMethodParameters(builder, sm.parameters);
    builder.appendLine(");");
}

private void generateMethod(StringBuilder builder, WebsocketServiceMethod sm, string namespace, ushort tabLevel) {
    auto ext = sm.getAspNetCoreWebsocketMethodExtension();
	generateAuthorization(builder, ext !is null ? ext.getAuthorization() : null, sm.authenticate, sm.parent.authenticate, tabLevel);

	if (namespace !is null && namespace != string.init) {
		builder.tabs(tabLevel).appendLine("[HubMethodName(\"{0}.{1}\")]", cleanName(namespace), cleanName(sm.socketName));
	} else {
		builder.tabs(tabLevel).appendLine("[HubMethodName(\"{0}\")]", cleanName(sm.socketName));
	}
    builder.tabs(tabLevel).append("public abstract ");
	builder.append("Task");
	if(sm.returns.length == 1) {
		if (sm.returns[0].type.mode != TypeMode.Void) {
			builder.append("<{0}>", generateType(sm.returns[0], false));
		}
	} else if (sm.returns.length > 1) {
		builder.append("<(");
		foreach (smp; sm.returns) {
			builder.append("{0} {1}, ", smp.name, generateType(smp, false));
		}
		builder.removeRight(2);
		builder.append(")>");
	}
    builder.append(" {0}{1}(", cleanName(namespace), cleanName(sm.name));
    generateMethodParameters(builder, sm.parameters);
    builder.appendLine(");");
}

private void generateMethodParameters(StringBuilder builder, TypeComplex[] smpl)
{
    bool hasParams = false;
    foreach (smp; smpl) {
        if (smp.type is null) continue;
        builder.append("{0} {1}, ", generateType(smp, false), cleanName(smp.name));
        hasParams = true;
    }

    if (hasParams) builder.removeRight(2);
}
