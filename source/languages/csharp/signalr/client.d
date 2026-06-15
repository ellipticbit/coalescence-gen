module coalescence.languages.csharp.signalr.client;

import coalescence.types;
import coalescence.schema;
import coalescence.globals;
import phobos.text.stringbuilder;
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
			builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.5.0.0\")]");
			builder.tabs(tabLevel).appendLine(i"$(s.isPublic ? "public" : "internal") interface I$(cleanName(s.name))$(cleanName(ns.name))Server");
			builder.tabs(tabLevel++).appendLine("{");
			foreach(m; ns.server) {
				generateInterfaceMethod(builder, m, tabLevel);
			}
			builder.tabs(--tabLevel).appendLine("}");
			builder.appendLine();

			builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.5.0.0\")]");
			builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
			builder.tabs(tabLevel).appendLine(i"$(s.isPublic ? "public" : "internal") class $(cleanName(s.name))$(cleanName(ns.name))Server : I$(cleanName(s.name))$(cleanName(ns.name))Server");
			builder.tabs(tabLevel++).appendLine("{");
			builder.tabs(tabLevel).appendLine("private readonly HubConnection _hub;");
			builder.appendLine();
			builder.tabs(tabLevel++).appendLine(i"public $(cleanName(s.name))$(cleanName(ns.name))Server(ICoalescenceSignalRRepository repo) {");
			if (ext.clientConnection !is null && ext.clientConnection != string.init) {
				builder.tabs(tabLevel).appendLine(i"_hub = repo.Get(\"$(ext.clientConnection)\");");
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
			builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.5.0.0\")]");
			builder.tabs(tabLevel).appendLine(i"$(s.isPublic ? "public" : "internal") interface I$(cleanName(s.name))$(cleanName(ns.name))Client");
			builder.tabs(tabLevel++).appendLine("{");
			foreach(m; ns.client) {
				generateInterfaceMethod(builder, m, tabLevel);
			}
			builder.tabs(--tabLevel).appendLine("}");
		}
	}

	builder.appendLine();
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.5.0.0\")]");
	builder.tabs(tabLevel).appendLine(i"$(s.isPublic ? "public" : "internal") static class $(cleanName(s.name))ClientExtensions");
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel).append(i"public static void Register$(cleanName(s.name))ClientServices<");
	foreach (ns; s.namespaces) {
		if (ns.client.length != 0) builder.append(i"T$(cleanName(ns.name))Client, ");
	}
	if (s.namespaces.length != 0) builder.remove(builder.length-2, 2);
	builder.appendLine(">(this IServiceCollection services)");
	foreach (ns; s.namespaces) {
		if (ns.client.length != 0) builder.tabs(tabLevel+1).appendLine(i"where T$(cleanName(ns.name))Client : class, I$(cleanName(s.name))$(cleanName(ns.name))Client");
	}
	builder.tabs(tabLevel++).appendLine("{");
	foreach (ns; s.namespaces) {
		if (ns.server.length != 0) builder.tabs(tabLevel).appendLine(i"services.TryAddTransient<I$(cleanName(s.name))$(cleanName(ns.name))Server, $(cleanName(s.name))$(cleanName(ns.name))Server>();");
		if (ns.client.length != 0) builder.tabs(tabLevel).appendLine(i"services.TryAddTransient<I$(cleanName(s.name))$(cleanName(ns.name))Client, T$(cleanName(ns.name))Client>();");
	}
	builder.tabs(--tabLevel).appendLine("}");
	builder.appendLine();
	builder.tabs(tabLevel++).appendLine(i"public static IEnumerable<IDisposable> Register$(cleanName(s.name))ClientMethods(this HubConnection connection, IServiceProvider services) {");
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
		builder.append(i"$(generateType(smp, false)) $(cleanName(smp.name)), ");
		hasParams = true;
	}

	if (hasParams) builder.remove(builder.length-2, 2);
}

private void generateInterfaceMethod(StringBuilder builder, WebsocketServiceMethod sm, ushort tabLevel) {
	builder.tabs(tabLevel).append("Task");
	if(sm.returns.length == 1) {
		if (sm.returns[0].type.mode != TypeMode.Void) {
			builder.append(i"<$(generateType(sm.returns[0], false))>");
		}
	} else if (sm.returns.length > 1) {
		builder.append("<(");
		foreach (smp; sm.returns) {
			builder.append(i"$(smp.name) $(generateType(smp, false)), ");
		}
		builder.remove(builder.length-2, 2);
		builder.append(")>");
	}
	builder.append(i" $(cleanName(sm.name))(");
	generateMethodParameters(builder, sm.parameters);
	builder.appendLine(");");
}

public void generateServerMethod(StringBuilder builder, WebsocketServiceMethod sm, string namespace, ushort tabLevel) {
	builder.tabs(tabLevel++).append("public Task");
	if(sm.returns.length == 1) {
		if (sm.returns[0].type.mode != TypeMode.Void) {
			builder.append(i"<$(generateType(sm.returns[0], false))>");
		}
	} else if (sm.returns.length > 1) {
		builder.append("<(");
		foreach (smp; sm.returns) {
			builder.append(i"$(smp.name) $(generateType(smp, false)), ");
		}
		builder.remove(builder.length-2, 2);
		builder.append(")>");
	}
	builder.append(i" $(cleanName(sm.name))(");
	generateMethodParameters(builder, sm.parameters);
	builder.appendLine(") {");
	builder.tabs(tabLevel).append("return this._hub.InvokeCoreAsync");
	if(sm.returns.length == 1) {
		if (sm.returns[0].type.mode != TypeMode.Void) {
			builder.append(i"<$(generateType(sm.returns[0], false))>");
		}
	} else if (sm.returns.length > 1) {
		builder.append("<(");
		foreach (smp; sm.returns) {
			builder.append(i"$(smp.name) $(generateType(smp, false)), ");
		}
		builder.remove(builder.length-2, 2);
		builder.append(")>");
	}
	if (namespace !is null && namespace != string.init) {
		builder.append(i"(\"$(cleanName(namespace)).$(cleanName(sm.socketName))\", new object[] { ");
	} else {
		builder.append(i"(\"$(cleanName(sm.socketName))\", new object[] { ");
	}
	foreach (smp; sm.parameters) {
		builder.append(i"$(smp.name), ");
	}
	if (sm.parameters.length > 0) builder.remove(builder.length-2, 2);
	builder.appendLine(" });");
	builder.tabs(--tabLevel).appendLine("}");
}

public void generateClientMethod(StringBuilder builder, WebsocketServiceMethod sm, string namespace, ushort tabLevel) {
	if (namespace !is null && namespace != string.init) {
		builder.tabs(tabLevel++).append(i"connection.On(\"$(cleanName(namespace)).$(cleanName(sm.socketName))\", (");
	} else {
		builder.tabs(tabLevel++).append(i"connection.On(\"$(cleanName(sm.socketName))\", (");
	}
	foreach (smp; sm.parameters) {
		builder.append(i"$(generateType(smp, false)) $(smp.name), ");
	}
	if (sm.parameters.length > 0) builder.remove(builder.length-2, 2);
	builder.appendLine(") => {");
	builder.tabs(tabLevel).appendLine(i"var t = ActivatorUtilities.GetServiceOrCreateInstance<I$(cleanName(sm.parent.name))$(cleanName(namespace))Client>(services);");
	builder.tabs(tabLevel).append(i"return t.$(cleanName(sm.name))(");
	foreach (smp; sm.parameters) {
		builder.append(i"$(smp.name), ");
	}
	if (sm.parameters.length > 0) builder.remove(builder.length-2, 2);
	builder.appendLine(");");
	builder.tabs(--tabLevel).appendLine("}),");
}
