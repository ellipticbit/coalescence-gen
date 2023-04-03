module restforge.languages.csharp.aspnetcore.signalr.server;

import restforge.types;
import restforge.model;
import restforge.globals;
import restforge.stringbuilder;

import restforge.languages.csharp.aspnetcore.generator;
import restforge.languages.csharp.aspnetcore.extensions;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.stdio;
import std.string;

public void generateWebsocketServer(StringBuilder builder, WebsocketService s, ushort tabLevel)
{
	builder.appendLine();
	builder.appendLine("{0}{2} interface I{1}Server", generateTabs(tabLevel), s.name, s.isPublic ? "public" : "internal");
	builder.appendLine("{0}{", generateTabs(tabLevel));
	foreach(ns; s.namespaces) {
		foreach(m; ns.server) {
			generateInterfaceMethod(builder, m, ns.name, cast(ushort)(tabLevel+1));
		}
	}
	builder.appendLine("{0}}", generateTabs(tabLevel));

    if (s.hasClient()) {
		builder.appendLine();
        builder.appendLine("{0}{2} interface I{1}Client", generateTabs(tabLevel), s.name, s.isPublic ? "public" : "internal");
        builder.appendLine("{0}{", generateTabs(tabLevel));
		foreach(ns; s.namespaces) {
			foreach(m; ns.client) {
				generateInterfaceMethod(builder, m, ns.name, cast(ushort)(tabLevel+1));
			}
		}
        builder.appendLine("{0}}", generateTabs(tabLevel));
    }

	builder.appendLine();
	auto ext = s.getAspNetCoreWebsocketExtension();
	generateAuthorization(builder, ext !is null ? ext.getAuthorization() : null, s.authenticate, false, tabLevel);

    if (s.hasClient()) {
        builder.appendLine("{0}{2} abstract class {1}HubBase : Hub<I{1}{3}>, I{1}{4}", generateTabs(tabLevel), s.name, s.isPublic ? "public" : "internal", serverGen ? "Client" : "Server", serverGen ? "Server" : "Client");
    } else {
        builder.appendLine("{0}{2} abstract class {1}HubBase : Hub, I{1}{3}", generateTabs(tabLevel), s.name, s.isPublic ? "public" : "internal", serverGen ? "Server" : "Client");
    }
    builder.appendLine("{0}{", generateTabs(tabLevel));
	foreach(ns; s.namespaces) {
		foreach(m; ns.server) {
			generateMethod(builder, m, ns.name, cast(ushort)(tabLevel+1));
		}
	}
    builder.appendLine("{0}}", generateTabs(tabLevel));
}

private void generateInterfaceMethod(StringBuilder builder, WebsocketServiceMethod sm, string namespace, ushort tabLevel) {
	builder.append(generateTabs(tabLevel));
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

private void generateMethod(StringBuilder builder, WebsocketServiceMethod sm, string namespace, ushort tabLevel) {
    auto ext = sm.getAspNetCoreWebsocketMethodExtension();
	generateAuthorization(builder, ext !is null ? ext.getAuthorization() : null, sm.authenticate, sm.parent.authenticate, tabLevel);

	if (namespace !is null && namespace != string.init) {
		builder.appendLine("{0}[HubMethodName(\"{1}.{2}\")]", generateTabs(tabLevel), cleanName(namespace), cleanName(sm.name));
	}
    builder.append("{0}public abstract ", generateTabs(tabLevel));
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
