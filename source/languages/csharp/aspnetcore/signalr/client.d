module restforge.languages.csharp.aspnetcore.signalr.client;

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

public void generateWebsocketClient(StringBuilder builder, WebsocketService s, ushort tabLevel)
{
	auto ext = s.getAspNetCoreWebsocketExtension();

	foreach(ns; s.namespaces) {
		if (ns.server.length != 0) {
			builder.appendLine();
			builder.appendLine("{0}{3} interface I{1}{2}Server", generateTabs(tabLevel), cleanName(s.name), cleanName(ns.name), s.isPublic ? "public" : "internal");
			builder.appendLine("{0}{", generateTabs(tabLevel));
			foreach(m; ns.server) {
				generateInterfaceMethod(builder, m, cast(ushort)(tabLevel+1));
			}
			builder.appendLine("{0}}", generateTabs(tabLevel));
			builder.appendLine();

			builder.appendLine("{0}{3} class {1}{2}Server : I{1}{2}Server", generateTabs(tabLevel), cleanName(s.name), cleanName(ns.name), s.isPublic ? "public" : "internal");
			builder.appendLine("{0}{", generateTabs(tabLevel));
			builder.appendLine("{0}private readonly HubConnection _hub;", generateTabs(tabLevel+1));
			builder.appendLine();
			builder.appendLine("{0}public {1}{2}Server(IHotwireSignalRRepository repo) {", generateTabs(tabLevel+1), cleanName(s.name), cleanName(ns.name));
			if (ext.clientConnection !is null && ext.clientConnection != string.init) {
				builder.appendLine("{0}_hub = repo.Get(\"{1}\");", generateTabs(tabLevel+2), ext.clientConnection);
			} else {
				builder.appendLine("{0}_hub = repo.Get();", generateTabs(tabLevel+2));
			}
			builder.appendLine("{0}}", generateTabs(tabLevel+1));
			builder.appendLine();
			foreach(m; ns.server) {
				generateServerMethod(builder, m, ns.name, cast(ushort)(tabLevel+1));
			}
			builder.appendLine("{0}}", generateTabs(tabLevel));
		}

		if (ns.client.length != 0) {
			builder.appendLine();
			builder.appendLine("{0}{3} interface I{1}{2}Client", generateTabs(tabLevel), cleanName(s.name), cleanName(ns.name), s.isPublic ? "public" : "internal");
			builder.appendLine("{0}{", generateTabs(tabLevel));
			foreach(m; ns.client) {
				generateInterfaceMethod(builder, m, cast(ushort)(tabLevel+1));
			}
			builder.appendLine("{0}}", generateTabs(tabLevel));
		}
	}

	builder.appendLine();
	builder.appendLine("{0}{2} static class {1}ClientExtensions", generateTabs(tabLevel), cleanName(s.name), s.isPublic ? "public" : "internal");
	builder.appendLine("{0}{", generateTabs(tabLevel));
	builder.append("{0}public static void Register{1}ClientServices<", generateTabs(tabLevel+1), cleanName(s.name));
	foreach (ns; s.namespaces) {
		if (ns.client.length != 0) builder.append("T{0}Client, ", cleanName(ns.name));
	}
	if (s.namespaces.length != 0) builder.removeRight(2);
	builder.appendLine(">(this IServiceCollection services)");
	foreach (ns; s.namespaces) {
		if (ns.client.length != 0) builder.appendLine("{0}where T{2}Client : class, I{1}{2}Client", generateTabs(tabLevel+2), cleanName(s.name), cleanName(ns.name));
	}
	builder.appendLine("{0}{", generateTabs(tabLevel+1));
	foreach (ns; s.namespaces) {
		if (ns.server.length != 0) builder.appendLine("{0}services.TryAddTransient<I{1}{2}Server, {1}{2}Server>();", generateTabs(tabLevel+2), cleanName(s.name), cleanName(ns.name));
		if (ns.client.length != 0) builder.appendLine("{0}services.TryAddTransient<I{1}{2}Client, T{2}Client>();", generateTabs(tabLevel+2), cleanName(s.name), cleanName(ns.name));
	}
	builder.appendLine("{0}}", generateTabs(tabLevel+1));
	builder.appendLine();
	builder.appendLine("{0}public static void Register{1}ClientMethods(this HubConnection connection, IServiceProvider services) {", generateTabs(tabLevel+1), cleanName(s.name));
	foreach(ns; s.namespaces) {
		foreach(m; ns.client) {
			generateClientMethod(builder, m, ns.name, cast(ushort)(tabLevel+2));
		}
	}
	builder.appendLine("{0}}", generateTabs(tabLevel+1));
	builder.appendLine("{0}}", generateTabs(tabLevel));
}

private void generateMethodParameters(StringBuilder builder, TypeComplex[] smpl)
{
	bool hasParams = false;
	foreach (smp; smpl) {
		if (smp.type is null) continue;
		builder.append("{0} {1}, ", generateType(smp, false, true), cleanName(smp.name));
		hasParams = true;
	}

	if (hasParams) builder.removeRight(2);
}

private void generateInterfaceMethod(StringBuilder builder, WebsocketServiceMethod sm, ushort tabLevel) {
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
	builder.append(" {0}(", cleanName(sm.name));
	generateMethodParameters(builder, sm.parameters);
	builder.appendLine(");");
}

public void generateServerMethod(StringBuilder builder, WebsocketServiceMethod sm, string namespace, ushort tabLevel) {
	builder.append("{0}public ", generateTabs(tabLevel));
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
	builder.append(" {0}(", cleanName(sm.name));
	generateMethodParameters(builder, sm.parameters);
	builder.appendLine(") {");
	builder.append("{0}return this._hub.InvokeCoreAsync", generateTabs(tabLevel+1));
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
	if (namespace !is null && namespace != string.init) {
		builder.append("(\"{0}.{1}\", new object[] { ", cleanName(namespace), cleanName(sm.name));
	} else {
		builder.append("(\"{0}\", new object[] { ", cleanName(sm.name));
	}
	foreach (smp; sm.parameters) {
		builder.append("{0}, ", smp.name);
	}
	if (sm.parameters.length > 0) builder.removeRight(2);
	builder.appendLine(" });");
	builder.appendLine("{0}}", generateTabs(tabLevel));
}

public void generateClientMethod(StringBuilder builder, WebsocketServiceMethod sm, string namespace, ushort tabLevel) {
	if (namespace !is null && namespace != string.init) {
		builder.append("{0}connection.On(\"{1}.{2}\", (", generateTabs(tabLevel), cleanName(namespace), cleanName(sm.name));
	} else {
		builder.append("{0}connection.On(\"{1}\", (", generateTabs(tabLevel), cleanName(sm.name));
	}
	foreach (smp; sm.parameters) {
		builder.append("{0} {1}, ", generateType(smp, false), smp.name);
	}
	if (sm.parameters.length > 0) builder.removeRight(2);
	builder.appendLine(") => {");
	builder.appendLine("{0}var t = ActivatorUtilities.GetServiceOrCreateInstance<I{1}{2}Client>(services);", generateTabs(tabLevel+1), cleanName(sm.parent.name), cleanName(namespace));
	builder.append("{0}return t.{1}(", generateTabs(tabLevel+1), cleanName(sm.name));
	foreach (smp; sm.parameters) {
		builder.append("{0}, ", smp.name);
	}
	if (sm.parameters.length > 0) builder.removeRight(2);
	builder.appendLine(");");
	builder.appendLine("{0}});", generateTabs(tabLevel));
}
