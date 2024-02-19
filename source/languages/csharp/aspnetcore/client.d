module coalescence.languages.csharp.aspnetcore.client;

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

public void generateHttpClient(StringBuilder builder, HttpService s, ushort tabLevel)
{
	auto ext = s.getAspNetCoreHttpExtension();

	// Generate Query classes
	builder.appendLine();
	foreach(m; s.methods) {
		if (m.query.length == 0 || m.queryAsParams) continue;
		builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.2.4.0\")]");
		builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
		builder.tabs(tabLevel).appendLine("public class {0}Query : ICoalescenceParameters", m.name);
		builder.tabs(tabLevel++).appendLine("{");
		foreach(smp; m.query) {
			builder.tabs(tabLevel).appendLine("public {1} {0} { get; }", smp.name, generateType(smp, false, false));
		}
		builder.appendLine();
		builder.tabs(tabLevel++).append("public {0}Query(", m.name);
		foreach(smp; m.query) {
			builder.append("{1} {0}, ", smp.name, generateType(smp, false, false));
		}
		builder.removeRight(2);
		builder.appendLine(") {");
		foreach(smp; m.query) {
			builder.tabs(tabLevel).appendLine("this.{0} = {0};", smp.name);
		}
		builder.tabs(--tabLevel).appendLine("}");
		builder.appendLine();
		builder.tabs(tabLevel++).appendLine("IDictionary<string, IEnumerable<string>> ICoalescenceParameters.GetParameters() {");
		builder.tabs(tabLevel).appendLine("var rl = new Dictionary<string, IEnumerable<string>>();");
		foreach(smp; m.query) {
			if (smp.type.mode == TypeMode.Collection) {
				builder.tabs(tabLevel).appendLine("rl.Add(\"{0}\", {0}.Select(a => Convert.ToString(a)));", smp.name);
			} else if (smp.type.mode == TypeMode.Primitive) {
				builder.tabs(tabLevel).appendLine("rl.Add(\"{0}\", new[] { Convert.ToString({0}) });", smp.name);
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
		builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.2.4.0\")]");
		builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
		builder.tabs(tabLevel).appendLine("public class {0}Header : ICoalescenceParameters", m.name);
		builder.tabs(tabLevel++).appendLine("{");
		foreach(smp; m.header) {
			builder.tabs(tabLevel).appendLine("public {1} {0} { get; }", smp.name, generateType(smp, false, true));
		}
		builder.appendLine();
		builder.tabs(tabLevel++).append("public {0}Header(", m.name);
		foreach(smp; m.header) {
			builder.append("{1} {0}, ", smp.name, generateType(smp, false, true));
		}
		builder.removeRight(2);
		builder.appendLine(") {");
		foreach(smp; m.header) {
			builder.tabs(tabLevel).appendLine("this.{0} = {0};", smp.name);
		}
		builder.tabs(--tabLevel).appendLine("}");
		builder.appendLine();
		builder.tabs(tabLevel++).appendLine("IDictionary<string, IEnumerable<string>> ICoalescenceParameters.GetParameters() {");
		builder.tabs(tabLevel).appendLine("var rl = new Dictionary<string, IEnumerable<string>>();");
		foreach(smp; m.header) {
			if (smp.type.mode == TypeMode.Collection) {
				builder.tabs(tabLevel).appendLine("rl.Add(\"{0}\", {0}.Select(a => Convert.ToString(a)));", smp.name);
			} else if (smp.type.mode == TypeMode.Primitive) {
				builder.tabs(tabLevel).appendLine("rl.Add(\"{0}\", new[] { Convert.ToString({0}) });", smp.name);
			}
		}
		builder.tabs(tabLevel).appendLine("return rl;");
		builder.tabs(--tabLevel).appendLine("}");
		builder.tabs(--tabLevel).appendLine("}");
	}

	builder.appendLine();
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.2.4.0\")]");
	builder.tabs(tabLevel).appendLine("{1} interface I{0}", s.name, s.isPublic ? "public" : "internal");
	builder.tabs(tabLevel++).appendLine("{");
	foreach(m; s.methods) {
		generateClientInterfaceMethod(builder, m, cast(ushort)(tabLevel));
	}
	builder.tabs(--tabLevel).appendLine("}");
	builder.appendLine();
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.2.4.0\")]");
	builder.tabs(tabLevel).appendLine("{1} sealed partial class {0} : I{0}", s.name, s.isPublic ? "public" : "internal");
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel).appendLine("private readonly ICoalescenceRequestFactory requests;");
	if (s.scheme != string.init) builder.tabs(tabLevel).appendLine("private readonly string defaultAuthenticationScheme = \"{0}\";", s.scheme);
	builder.appendLine();
	builder.tabs(tabLevel).appendLine("public {0}(ICoalescenceRequestFactory requests)", s.name);
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
			builder.append("<{0}>", generateType(sm.returns[0]));
		} else if (sm.returns.length > 1) {
			builder.append("<(");
			foreach (rp; sm.returns) {
				builder.append("{0} {1}, ", generateType(rp), cleanName(rp.name));
			}
			builder.removeRight(2);
			builder.append(")>");
		}
	}
	else {
		if (sm.returns.length == 1) {
			builder.tabs(tabLevel).append(generateType(sm.returns[0], false));
		} else if (sm.returns.length > 1) {
			builder.tabs(tabLevel).append("(");
			foreach (rp; sm.returns) {
				builder.append("{0} {1}, ", generateType(rp), cleanName(rp.name));
			}
			builder.removeRight(2);
			builder.append(")");
		}
	}
	builder.append(" {0}(", cleanName(sm.name));
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
			builder.append("<{0}>", generateType(sm.returns[0]));
		} else if (sm.returns.length > 1) {
			builder.append("<(");
			foreach (rp; sm.returns) {
				builder.append("{0} {1}, ", generateType(rp), cleanName(rp.name));
			}
			builder.removeRight(2);
			builder.append(")>");
		}
	}
	else {
		builder.tabs(tabLevel).append("public");
		if (sm.returns.length == 1) {
			builder.append(" {0}", generateType(sm.returns[0], false));
		} else if (sm.returns.length > 1) {
			builder.append(" (");
			foreach (rp; sm.returns) {
				builder.append("{0} {1}, ", generateType(rp), cleanName(rp.name));
			}
			builder.removeRight(2);
			builder.append(")");
		}
	}
	builder.append(" {0}(", cleanName(sm.name));
	generateClientMethodParams(builder, sm);
	builder.appendLine(")");
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel++).appendLine("await using var response = await requests.CreateRequest({0}).{1}()", s.getRequest(), to!string(sm.verb).capitalize());

	if (s.route.length > 0) {
		builder.tabs(tabLevel).appendLine(".Path(\"{0}\")", s.route.join("\", \""));
	}

	if (sm.routeParts.length > 0) {
		if (sm.route.length > 0) {
			foreach(pp; sm.routeParts) {
				auto ptc = sm.getRouteType(pp);
				if (ptc is null) {
					builder.tabs(tabLevel).appendLine(".Path(\"{0}\")", pp);
				} else {
					builder.tabs(tabLevel).appendLine(".Path({0})", pp);
				}
			}
		} else {
			builder.tabs(tabLevel).appendLine(".Path(\"{0}\")", sm.routeParts.join("\", \""));
		}
	}

	if (sm.query.length > 0) {
		if (!sm.queryAsParams) {
			builder.tabs(tabLevel).appendLine(".Query(query)");
		} else {
			foreach (smp; sm.query) {
				builder.tabs(tabLevel).appendLine(".Query(\"{0}\", {0})", smp.name);
			}
		}
	}

	if (sm.header.length > 0) {
		builder.tabs(tabLevel).appendLine(".Header(headers)");
	}

	if (sm.authenticate && sm.scheme != string.init) {
		builder.tabs(tabLevel).appendLine(".Authentication(\"{0}\")", sm.scheme);
	} else if (sm.authenticate || s.authenticate) {
		builder.tabs(tabLevel).appendLine(".Authentication()");
	}

	if (sm.timeout > 0) builder.tabs(tabLevel).append(".Timeout(TimeSpan.FromSeconds({0}))", to!string(sm.timeout));

	if (!sm.retry) builder.tabs(tabLevel).append(".NoRetry()");

	if (sm.content.length == 1) {
		TypeComplex tc = sm.content[0];
		if (typeid(tc.type) == typeid(TypeByteArray)) {
			builder.tabs(tabLevel).appendLine(".ByteArray({0})", tc.name);
		}
		else if (typeid(tc.type) == typeid(TypeStream)) {
			builder.tabs(tabLevel).appendLine(".Stream({0})", tc.name);
		}
		else if (typeid(tc.type) == typeid(TypeContent)) {
			builder.tabs(tabLevel).appendLine(".Content({0})", tc.name);
		}
		else if (typeid(tc.type) == typeid(TypePrimitive) && (cast(TypePrimitive)tc.type).primitive == TypePrimitives.String) {
			builder.tabs(tabLevel).appendLine(".Text({0})", tc.name);
		}
		else if (typeid(tc.type) == typeid(TypeFormUrlEncoded)) {
			builder.tabs(tabLevel).appendLine(".FormUrlEncoded({0})", tc.name);
		}
		else {
			builder.tabs(tabLevel).appendLine(".Serialized({0})", tc.name);
		}
	} else if (sm.content.length > 1) {
		builder.tabs(tabLevel++).appendLine(".Multipart{0}()", sm.bodyForm ? "Form" : string.init);
		if (sm.bodySubtype != string.init) builder.tabs(tabLevel).appendLine(".Subtype(\"{0}\")", sm.bodySubtype);
		if (sm.bodySubtype != string.init) builder.tabs(tabLevel).appendLine(".Boundary(\"{0}\")", sm.bodyBoundary);
		foreach (tc; sm.content) {
			if (typeid(tc.type) == typeid(TypeByteArray) || typeid(tc.type) == typeid(TypeStream)) {
				builder.tabs(tabLevel).appendLine(".File({0})", tc.name);
			}
			else if (typeid(tc.type) == typeid(TypeContent)) {
				builder.tabs(tabLevel).appendLine(".Content({0})", tc.name);
			}
			else if (typeid(tc.type) == typeid(TypePrimitive) && (cast(TypePrimitive)tc.type).primitive == TypePrimitives.String) {
				builder.tabs(tabLevel).appendLine(".Text({0})", tc.name);
			}
			else if (typeid(tc.type) == typeid(TypeFormUrlEncoded)) {
				builder.tabs(tabLevel).appendLine(".FormUrlEncoded({0})", tc.name);
			}
			else {
				builder.tabs(tabLevel).appendLine(".Serialized({0})", tc.name);
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
				builder.tabs(tabLevel--).appendLine(".AsDeserialized<{0}>();", generateType(tc));
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
		builder.append("{0} {1}, ", generateType(smp, false, false), cleanName(smp.name));
	}

	foreach (smp; sm.content) {
		if (smp.hasDefault()) continue;
		builder.append("{0} {1}, ", generateType(smp, false, false), cleanName(smp.name));
	}

	if (sm.query.length != 0) {
		if (!sm.queryAsParams) {
			foreach (smp; sm.query) {
				if (smp.hasDefault()) continue;
				builder.append("{0} {1}, ", generateType(smp, false, false), cleanName(smp.name));
			}
		}
	}

	// Generate optional parameters
	foreach (smp; sm.route) {
		if (!smp.hasDefault()) continue;
		builder.append("{0} {1} = {2}, ", generateType(smp, false, false), cleanName(smp.name), getDefaultValue(smp));
	}

	if (sm.query.length != 0) {
		if (!sm.queryAsParams) {
			builder.append("{0}Query query = null, ", sm.name);
		} else {
			foreach (smp; sm.query) {
				if (!smp.hasDefault()) continue;
				builder.append("{0} {1} = {2}, ", generateType(smp, false, false)), cleanName(smp.name), getDefaultValue(smp);
			}
		}
	}

	if (sm.header.length != 0) {
		builder.append("{0}Header headers = null, ", sm.name);
	}

	foreach (smp; sm.content) {
		if (!smp.hasDefault()) continue;
		builder.append("{0} {1} = {2}, ", generateType(smp, false, false), cleanName(smp.name), getDefaultValue(smp));
	}

	if ((sm.route.length + sm.query.length + sm.header.length + sm.content.length) > 0) builder.removeRight(2);
}
