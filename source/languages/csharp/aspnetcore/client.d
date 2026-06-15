module coalescence.languages.csharp.aspnetcore.client;

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

public void generateHttpClient(StringBuilder builder, HttpService s, ushort tabLevel)
{
	auto ext = s.getAspNetCoreHttpExtension();

	// Generate Query classes
	builder.appendLine();
	foreach(m; s.methods) {
		if (m.query.length == 0 || m.queryAsParams) continue;
		builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"2.0.0.0\")]");
		builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
		builder.tabs(tabLevel).appendLine(i"public class $(m.name)Query : ICoalescenceParameters");
		builder.tabs(tabLevel++).appendLine("{");
		foreach(smp; m.query) {
			builder.tabs(tabLevel).appendLine(i"public $(generateType(smp, false, false)) $(smp.name) { get; }");
		}
		builder.appendLine();
		builder.tabs(tabLevel++).append(i"public $(m.name)Query(");
		foreach(smp; m.query) {
			builder.append(i"$(generateType(smp, false, false)) $(smp.name), ");
		}
		builder.remove(builder.length-2, 2);
		builder.appendLine(") {");
		foreach(smp; m.query) {
			builder.tabs(tabLevel).appendLine(i"this.$(smp.name) = $(smp.name);");
		}
		builder.tabs(--tabLevel).appendLine("}");
		builder.appendLine();
		builder.tabs(tabLevel++).appendLine("IDictionary<string, IEnumerable<string>> ICoalescenceParameters.GetParameters() {");
		builder.tabs(tabLevel).appendLine("var rl = new Dictionary<string, IEnumerable<string>>();");
		foreach(smp; m.query) {
			if (smp.type.mode == TypeMode.Collection) {
				builder.tabs(tabLevel).appendLine(i"rl.Add(\"$(smp.name)\", $(smp.name).Select(a => Convert.ToString(a)));");
			} else if (smp.type.mode == TypeMode.Primitive) {
				builder.tabs(tabLevel).appendLine(i"rl.Add(\"$(smp.name)\", new[] { Convert.ToString($(smp.name)) });");
			}
		}
		builder.tabs(tabLevel).appendLine("return rl;");
		builder.tabs(--tabLevel).appendLine("}");
		builder.tabs(--tabLevel).appendLine("}");
	}

	// Generate Header classes
	builder.appendLine();
	foreach(m; s.methods) {
		if (m.header.length == 0) continue;
		builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"2.0.0.0\")]");
		builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
		builder.tabs(tabLevel).appendLine(i"public class $(m.name)Header : ICoalescenceParameters");
		builder.tabs(tabLevel++).appendLine("{");
		foreach(smp; m.header) {
			builder.tabs(tabLevel).appendLine(i"public $(generateType(smp, false, true)) $(smp.name) { get; }");
		}
		builder.appendLine();
		builder.tabs(tabLevel++).append(i"public $(m.name)Header(");
		foreach(smp; m.header) {
			builder.append(i"$(generateType(smp, false, true)) $(smp.name), ");
		}
		builder.remove(builder.length-2, 2);
		builder.appendLine(") {");
		foreach(smp; m.header) {
			builder.tabs(tabLevel).appendLine(i"this.$(smp.name) = $(smp.name);");
		}
		builder.tabs(--tabLevel).appendLine("}");
		builder.appendLine();
		builder.tabs(tabLevel++).appendLine("IDictionary<string, IEnumerable<string>> ICoalescenceParameters.GetParameters() {");
		builder.tabs(tabLevel).appendLine("var rl = new Dictionary<string, IEnumerable<string>>();");
		foreach(smp; m.header) {
			if (smp.type.mode == TypeMode.Collection) {
				builder.tabs(tabLevel).appendLine(i"rl.Add(\"$(smp.name)\", $(smp.name).Select(a => Convert.ToString(a)));");
			} else if (smp.type.mode == TypeMode.Primitive) {
				builder.tabs(tabLevel).appendLine(i"rl.Add(\"$(smp.name)\", new[] { Convert.ToString($(smp.name)) });");
			}
		}
		builder.tabs(tabLevel).appendLine("return rl;");
		builder.tabs(--tabLevel).appendLine("}");
		builder.tabs(--tabLevel).appendLine("}");
	}

	builder.appendLine();
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"2.0.0.0\")]");
	builder.tabs(tabLevel).appendLine(i"$(s.isPublic ? "public" : "internal") interface I$(s.name)");
	builder.tabs(tabLevel++).appendLine("{");
	foreach(m; s.methods) {
		generateClientInterfaceMethod(builder, m, cast(ushort)(tabLevel));
	}
	builder.tabs(--tabLevel).appendLine("}");
	builder.appendLine();
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"2.0.0.0\")]");
	builder.tabs(tabLevel).appendLine(i"$(s.isPublic ? "public" : "internal") sealed partial class $(s.name) : I$(s.name)");
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel).appendLine("private readonly ICoalescenceRequestFactory requests;");
	if (s.scheme != string.init) builder.tabs(tabLevel).appendLine(i"private readonly string defaultAuthenticationScheme = \"$(s.scheme)\";");
	builder.appendLine();
	builder.tabs(tabLevel).appendLine(i"public $(s.name)(ICoalescenceRequestFactory requests)");
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel).appendLine("this.requests = requests;");
	builder.tabs(--tabLevel).appendLine("}");
	builder.appendLine();

	foreach(m; s.methods) {
		generateClientMethod(builder, s, m, cast(ushort)(tabLevel));
	}
	builder.tabs(--tabLevel).appendLine("}");
}

private void generateClientInterfaceMethod(StringBuilder builder, HttpServiceMethod sm, ushort tabLevel)
{
	auto ext = sm.getAspNetCoreHttpExtension();
	bool isSync = (ext !is null && ext.sync);

	if(!isSync) {
		builder.tabs(tabLevel).append("Task");
		if(sm.returns.length == 1) {
			builder.append(i"<$(generateType(sm.returns[0]))>");
		} else if (sm.returns.length > 1) {
			builder.append("<(");
			foreach (rp; sm.returns) {
				builder.append(i"$(generateType(rp)) $(cleanName(rp.name)), ");
			}
			builder.remove(builder.length-2, 2);
			builder.append(")>");
		}
	}
	else {
		if (sm.returns.length == 1) {
			builder.tabs(tabLevel).append(generateType(sm.returns[0], false));
		} else if (sm.returns.length > 1) {
			builder.tabs(tabLevel).append("(");
			foreach (rp; sm.returns) {
				builder.append(i"$(generateType(rp)) $(cleanName(rp.name)), ");
			}
			builder.remove(builder.length-2, 2);
			builder.append(")");
		}
	}
	builder.append(i" $(cleanName(sm.name))(");
	generateClientMethodParams(builder, sm);
	builder.appendLine(");");
}

private void generateClientMethod(StringBuilder builder, HttpService s, HttpServiceMethod sm, ushort tabLevel)
{
	auto ext = sm.getAspNetCoreHttpExtension();
	bool isSync = (ext !is null && ext.sync);

	builder.appendLine();
	if(!isSync) {
		builder.tabs(tabLevel).append("public async Task");
		if (sm.returns.length == 1) {
			builder.append(i"<$(generateType(sm.returns[0]))>");
		} else if (sm.returns.length > 1) {
			builder.append("<(");
			foreach (rp; sm.returns) {
				builder.append(i"$(generateType(rp)) $(cleanName(rp.name)), ");
			}
			builder.remove(builder.length-2, 2);
			builder.append(")>");
		}
	}
	else {
		builder.tabs(tabLevel).append("public");
		if (sm.returns.length == 1) {
			builder.append(i" $(generateType(sm.returns[0], false))");
		} else if (sm.returns.length > 1) {
			builder.append(" (");
			foreach (rp; sm.returns) {
				builder.append(i"$(generateType(rp)) $(cleanName(rp.name)), ");
			}
			builder.remove(builder.length-2, 2);
			builder.append(")");
		}
	}
	builder.append(i" $(cleanName(sm.name))(");
	generateClientMethodParams(builder, sm);
	builder.appendLine(")");
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel++).appendLine(i"await using var response = await requests.CreateRequest($(getRequestParameters(sm))).$(to!string(sm.verb).capitalize())()");

	if (s.route.length > 0) {
		builder.tabs(tabLevel).appendLine(i".Path(\"$(s.route.join("\", \""))\")");
	}

	if (sm.routeParts.length > 0) {
		if (sm.route.length > 0) {
			foreach(pp; sm.routeParts) {
				auto ptc = sm.getRouteType(pp);
				if (ptc is null) {
					builder.tabs(tabLevel).appendLine(i".Path(\"$(pp)\")");
				} else {
					builder.tabs(tabLevel).appendLine(i".Path($(pp))");
				}
			}
		} else {
			builder.tabs(tabLevel).appendLine(i".Path(\"$(sm.routeParts.join("\", \""))\")");
		}
	}

	if (sm.query.length > 0) {
		if (!sm.queryAsParams) {
			builder.tabs(tabLevel).appendLine(".Query(query)");
		} else {
			foreach (smp; sm.query) {
				builder.tabs(tabLevel).appendLine(i".Query(\"$(smp.name)\", $(smp.name))");
			}
		}
	}

	if (sm.header.length > 0) {
		builder.tabs(tabLevel).appendLine(".Header(headers)");
	}
	if (sm.requestEncoding != string.init) {
		builder.tabs(tabLevel).appendLine(i".RequestContentEncoding(\"$(sm.requestEncoding)\")");
	}
	if (sm.responseEncoding != string.init) {
		builder.tabs(tabLevel).appendLine(i".ResponseContentEncoding(\"$(sm.responseEncoding)\")");
	}

	if (sm.authenticate && sm.scheme != string.init) {
		builder.tabs(tabLevel).appendLine(i".Authentication(\"$(sm.scheme)\")");
	} else if (sm.authenticate) {
		builder.tabs(tabLevel).appendLine(".Authentication()");
	}

	if (sm.timeout > 0) builder.tabs(tabLevel).append(i".Timeout(TimeSpan.FromSeconds($(to!string(sm.timeout))))");

	if (!sm.retry) builder.tabs(tabLevel).append(".NoRetry()");

	if (sm.content.length == 1) {
		TypeComplex tc = sm.content[0];
		if (typeid(tc.type) == typeid(TypeByteArray)) {
			builder.tabs(tabLevel).appendLine(i".ByteArray($(tc.name))");
		}
		else if (typeid(tc.type) == typeid(TypeStream)) {
			builder.tabs(tabLevel).appendLine(i".Stream($(tc.name))");
		}
		else if (typeid(tc.type) == typeid(TypeContent)) {
			builder.tabs(tabLevel).appendLine(i".Content($(tc.name))");
		}
		else if (typeid(tc.type) == typeid(TypePrimitive) && (cast(TypePrimitive)tc.type).primitive == TypePrimitives.String) {
			builder.tabs(tabLevel).appendLine(i".Text($(tc.name))");
		}
		else if (typeid(tc.type) == typeid(TypeFormUrlEncoded)) {
			builder.tabs(tabLevel).appendLine(i".FormUrlEncoded($(tc.name))");
		}
		else {
			builder.tabs(tabLevel).appendLine(i".Serialized($(tc.name))");
		}
	} else if (sm.content.length > 1) {
		builder.tabs(tabLevel++).appendLine(i".Multipart$(sm.bodyForm ? "Form" : string.init)()");
		if (sm.bodySubtype != string.init) builder.tabs(tabLevel).appendLine(i".Subtype(\"$(sm.bodySubtype)\")");
		if (sm.bodySubtype != string.init) builder.tabs(tabLevel).appendLine(i".Boundary(\"$(sm.bodyBoundary)\")");
		foreach (tc; sm.content) {
			if (typeid(tc.type) == typeid(TypeByteArray) || typeid(tc.type) == typeid(TypeStream)) {
				builder.tabs(tabLevel).appendLine(i".File($(tc.name))");
			}
			else if (typeid(tc.type) == typeid(TypeContent)) {
				builder.tabs(tabLevel).appendLine(i".Content($(tc.name))");
			}
			else if (typeid(tc.type) == typeid(TypePrimitive) && (cast(TypePrimitive)tc.type).primitive == TypePrimitives.String) {
				builder.tabs(tabLevel).appendLine(i".Text($(tc.name))");
			}
			else if (typeid(tc.type) == typeid(TypeFormUrlEncoded)) {
				builder.tabs(tabLevel).appendLine(i".FormUrlEncoded($(tc.name))");
			}
			else {
				builder.tabs(tabLevel).appendLine(i".Serialized($(tc.name))");
			}
		}
		builder.tabs(tabLevel).appendLine(".Compile()");
		tabLevel--;
	}

	builder.tabs(--tabLevel).appendLine(".Send();");

	if (sm.returns.length > 0) {
		builder.appendLine();
		if (sm.returns.length == 1) {
			TypeComplex tc = sm.returns[0];
			builder.tabs(tabLevel++).appendLine("return await response");
			if (sm.noThrow) builder.tabs(tabLevel).appendLine(".ThrowOnFailureResponse()");
			if (typeid(tc.type) == typeid(TypeByteArray)) {
				builder.tabs(tabLevel--).appendLine(".AsByteArray();");
			}
			else if (typeid(tc.type) == typeid(TypeStream)) {
				builder.tabs(tabLevel--).appendLine(".AsStream();");
			}
			else if (typeid(tc.type) == typeid(TypeContent)) {
				builder.tabs(tabLevel--).appendLine(".AsContent();");
			}
			else if (typeid(tc.type) == typeid(TypePrimitive) && (cast(TypePrimitive)tc.type).primitive == TypePrimitives.String) {
				builder.tabs(tabLevel--).appendLine(".AsString();");
			}
			else if (typeid(tc.type) == typeid(TypeFormUrlEncoded)) {
				builder.tabs(tabLevel--).appendLine(".AsFormUrlEncoded();");
			}
			else {
				builder.tabs(tabLevel--).appendLine(i".AsDeserialized<$(generateType(tc))>();");
			}
		} else {
			//TODO: Multipart returns not implemented in client library.
		}
	}

	builder.tabs(--tabLevel).appendLine("}");
}

private void generateClientMethodParams(StringBuilder builder, HttpServiceMethod sm)
{
	// Generate required parameters
	foreach (smp; sm.route) {
		if (smp.hasDefault()) continue;
		builder.append(i"$(generateType(smp, true, false)) $(cleanName(smp.name)), ");
	}

	foreach (smp; sm.content) {
		if (smp.hasDefault()) continue;
		builder.append(i"$(generateType(smp, false, false)) $(cleanName(smp.name)), ");
	}

	if (sm.query.length != 0 && sm.queryAsParams) {
		foreach (smp; sm.query) {
			if (smp.hasDefault()) continue;
			builder.append(i"$(generateType(smp, true, false)) $(cleanName(smp.name)), ");
		}
	}

	// Generate optional parameters
	foreach (smp; sm.route) {
		if (!smp.hasDefault()) continue;
		builder.append(i"$(generateType(smp, true, false)) $(cleanName(smp.name)) = $(getDefaultValue(smp)), ");
	}

	if (sm.query.length != 0) {
		if (!sm.queryAsParams) {
			builder.append(i"$(sm.name)Query query = null, ");
		} else {
			foreach (smp; sm.query) {
				if (!smp.hasDefault()) continue;
				builder.append(i"$(generateType(smp, true, false)) $(cleanName(smp.name)) = $(getDefaultValue(smp)), ");
			}
		}
	}

	if (sm.header.length != 0) {
		builder.append(i"$(sm.name)Header headers = null, ");
	}

	foreach (smp; sm.content) {
		if (!smp.hasDefault()) continue;
		builder.append(i"$(generateType(smp, false, false)) $(cleanName(smp.name)) = $(getDefaultValue(smp)), ");
	}

	if (sm.multitenant || sm.parent.multitenant) {
		builder.append("string _tenantId = null  ");
	}

	if ((sm.route.length + sm.query.length + sm.header.length + sm.content.length) > 0 || sm.multitenant || sm.parent.multitenant) builder.remove(builder.length-2, 2);
}

public string getRequestParameters(HttpServiceMethod sm) {
	string params = string.init;

	if (sm.parent.requestName !is null && sm.parent.requestName != string.init) {
		params ~= text(i"\"$(sm.parent.requestName)\"");
	} else if (sm.parent.requestParameterId !is null && sm.parent.requestParameterId != string.init) {
		params ~= text(i"$(sm.parent.requestParameterId).ToString()");
	}

	if ((sm.multitenant || sm.parent.multitenant) && params == string.init) {
		params ~= "null, _tenantId";
	} else if (sm.multitenant || sm.parent.multitenant) {
		params ~= ", _tenantId";
	}

	return params;
}
