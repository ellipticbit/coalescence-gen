module coalescence.languages.csharp.signalr.client;

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

public void generateWebsocketClient(StringBuilder builder, WebsocketService s, ushort tabLevel)
{
	auto ext = s.getAspNetCoreWebsocketExtension();

	foreach(ns; s.namespaces) {
		if (ns.server.length != 0) {
			builder.appendLine();
			builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Hotwire.Generator\", \"2.0.0.0\")]");
			builder.tabs(tabLevel).appendLine("{2} interface I{0}{1}Server", cleanName(s.name), cleanName(ns.name), s.isPublic ? "public" : "internal");
			builder.tabs(tabLevel++).appendLine("{");
			foreach(m; ns.server) {
				generateInterfaceMethod(builder, m, tabLevel);
			}
			builder.tabs(--tabLevel).appendLine("}");
			builder.appendLine();

			builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Hotwire.Generator\", \"2.0.0.0\")]");
			builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
			builder.tabs(tabLevel).appendLine("{2} class {0}{1}Server : I{0}{1}Server", cleanName(s.name), cleanName(ns.name), s.isPublic ? "public" : "internal");
			builder.tabs(tabLevel++).appendLine("{");
			builder.tabs(tabLevel).appendLine("private readonly HubConnection _hub;");
			builder.appendLine();
			builder.tabs(tabLevel++).appendLine("public {0}{1}Server(IHotwireSignalRRepository repo) {", cleanName(s.name), cleanName(ns.name));
			if (ext.clientConnection !is null && ext.clientConnection != string.init) {
				builder.tabs(tabLevel).appendLine("_hub = repo.Get(\"{0}\");", ext.clientConnection);
			} else {
				builder.tabs(tabLevel).appendLine("_hub = repo.Get();");
			}
			builder.tabs(--tabLevel).appendLine("}");
			builder.appendLine();
			foreach(m; ns.server) {
				generateServerMethod(builder, m, ns.name, tabLevel);
			}
			builder.tabs(--tabLevel).appendLine("}");
		}

		if (ns.client.length != 0) {
			builder.appendLine();
			builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Hotwire.Generator\", \"2.0.0.0\")]");
			builder.tabs(tabLevel).appendLine("{2} interface I{0}{1}Client", cleanName(s.name), cleanName(ns.name), s.isPublic ? "public" : "internal");
			builder.tabs(tabLevel++).appendLine("{");
			foreach(m; ns.client) {
				generateInterfaceMethod(builder, m, tabLevel);
			}
			builder.tabs(--tabLevel).appendLine("}");
		}
	}

	builder.appendLine();
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Hotwire.Generator\", \"2.0.0.0\")]");
	builder.tabs(tabLevel).appendLine("{1} static class {0}ClientExtensions", cleanName(s.name), s.isPublic ? "public" : "internal");
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel).append("public static void Register{0}ClientServices<", cleanName(s.name));
	foreach (ns; s.namespaces) {
		if (ns.client.length != 0) builder.append("T{0}Client, ", cleanName(ns.name));
	}
	if (s.namespaces.length != 0) builder.removeRight(2);
	builder.appendLine(">(this IServiceCollection services)");
	foreach (ns; s.namespaces) {
		if (ns.client.length != 0) builder.tabs(tabLevel+1).appendLine("where T{1}Client : class, I{0}{1}Client", cleanName(s.name), cleanName(ns.name));
	}
	builder.tabs(tabLevel++).appendLine("{");
	foreach (ns; s.namespaces) {
		if (ns.server.length != 0) builder.tabs(tabLevel).appendLine("services.TryAddTransient<I{0}{1}Server, {0}{1}Server>();", cleanName(s.name), cleanName(ns.name));
		if (ns.client.length != 0) builder.tabs(tabLevel).appendLine("services.TryAddTransient<I{0}{1}Client, T{1}Client>();", cleanName(s.name), cleanName(ns.name));
	}
	builder.tabs(--tabLevel).appendLine("}");
	builder.appendLine();
	builder.tabs(tabLevel++).appendLine("public static IEnumerable<IDisposable> Register{0}ClientMethods(this HubConnection connection, IServiceProvider services) {", cleanName(s.name));
	builder.tabs(tabLevel++).appendLine("var rl = new List<IDisposable> {");
	foreach(ns; s.namespaces) {
		foreach(m; ns.client) {
			generateClientMethod(builder, m, ns.name, tabLevel);
		}
	}
	builder.tabs(--tabLevel).appendLine("};");
	builder.tabs(tabLevel).appendLine("return rl;");
	builder.tabs(--tabLevel).appendLine("}");
	builder.tabs(--tabLevel).appendLine("}");
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
	builder.append(" {0}(", cleanName(sm.name));
	generateMethodParameters(builder, sm.parameters);
	builder.appendLine(");");
}

public void generateServerMethod(StringBuilder builder, WebsocketServiceMethod sm, string namespace, ushort tabLevel) {
	builder.tabs(tabLevel++).append("public Task");
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
	builder.tabs(tabLevel).append("return this._hub.InvokeCoreAsync");
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
		builder.append("(\"{0}.{1}\", new object[] { ", cleanName(namespace), cleanName(sm.socketName));
	} else {
		builder.append("(\"{0}\", new object[] { ", cleanName(sm.socketName));
	}
	foreach (smp; sm.parameters) {
		builder.append("{0}, ", smp.name);
	}
	if (sm.parameters.length > 0) builder.removeRight(2);
	builder.appendLine(" });");
	builder.tabs(--tabLevel).appendLine("}");
}

public void generateClientMethod(StringBuilder builder, WebsocketServiceMethod sm, string namespace, ushort tabLevel) {
	if (namespace !is null && namespace != string.init) {
		builder.tabs(tabLevel++).append("connection.On(\"{0}.{1}\", (", cleanName(namespace), cleanName(sm.socketName));
	} else {
		builder.tabs(tabLevel++).append("connection.On(\"{0}\", (", cleanName(sm.socketName));
	}
	foreach (smp; sm.parameters) {
		builder.append("{0} {1}, ", generateType(smp, false), smp.name);
	}
	if (sm.parameters.length > 0) builder.removeRight(2);
	builder.appendLine(") => {");
	builder.tabs(tabLevel).appendLine("var t = ActivatorUtilities.GetServiceOrCreateInstance<I{0}{1}Client>(services);", cleanName(sm.parent.name), cleanName(namespace));
	builder.tabs(tabLevel).append("return t.{0}(", cleanName(sm.name));
	foreach (smp; sm.parameters) {
		builder.append("{0}, ", smp.name);
	}
	if (sm.parameters.length > 0) builder.removeRight(2);
	builder.appendLine(");");
	builder.tabs(--tabLevel).appendLine("}),");
}
