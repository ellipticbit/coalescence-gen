module restforge.languages.csharp.aspnetcore.http.client;

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

public void generateHttpClient(StringBuilder builder, HttpService s, ushort tabLevel)
{
	auto ext = s.getAspNetCoreHttpExtension();

	// Generate Query classes
	builder.appendLine();
	foreach(m; s.methods) {
		if (m.query.length == 0) continue;
		builder.appendLine("{0}public class {1}Query : IHotwireParameters", generateTabs(tabLevel), m.name);
		builder.appendLine("{0}{", generateTabs(tabLevel));
		foreach(smp; m.query) {
			builder.appendLine("{0}public {2} {1} { get; }", generateTabs(tabLevel+1), smp.name, generateType(smp, false, true));
		}
		builder.appendLine();
		builder.appendLine("{0}public {1}Query() {", generateTabs(tabLevel+1), s.name);
		foreach (smp; m.query) {
			if (smp.type.mode != TypeMode.Collection) continue;
			builder.appendLine("{0}{1} = new {2}();", generateTabs(tabLevel+2), smp.name, generateType(smp, false, true));
		}
		builder.appendLine("{0}}", generateTabs(tabLevel+1));
		builder.appendLine();
		builder.appendLine("{0}IDictionary<string, IEnumerable<string>> IHotwireParameters.GetParameters() {", generateTabs(tabLevel+1));
		builder.appendLine("{0}var rl = new Dictionary<string, IEnumerable<string>>();", generateTabs(tabLevel+2));
		foreach(smp; m.query) {
			if (smp.type.mode == TypeMode.Collection) {
				builder.appendLine("{0}rl.Add(\"{1}\", {1}.Select(a => Convert.ToString(a)));", generateTabs(tabLevel+2), smp.name);
			} else if (smp.type.mode == TypeMode.Primitive) {
				builder.appendLine("{0}rl.Add(\"{1}\", new[] { Convert.ToString({1}) });", generateTabs(tabLevel+2), smp.name);
			}
		}
		builder.appendLine("{0}return rl;", generateTabs(tabLevel+2));
		builder.appendLine("{0}}", generateTabs(tabLevel+1));
		builder.appendLine("{0}}", generateTabs(tabLevel));
	}

	// Generate Header classes
	builder.appendLine();
	foreach(m; s.methods) {
		if (m.header.length == 0) continue;
		builder.appendLine("{0}public class {1}Header : IHotwireParameters", generateTabs(tabLevel), m.name);
		builder.appendLine("{0}{", generateTabs(tabLevel));
		foreach(smp; m.header) {
			builder.appendLine("{0}public {2} {1} { get; }", generateTabs(tabLevel+1), smp.name, generateType(smp, false, true));
		}
		builder.appendLine();
		builder.appendLine("{0}public {1}Header() {", generateTabs(tabLevel+1), s.name);
		foreach (smp; m.header) {
			if (smp.type.mode != TypeMode.Collection) continue;
			builder.appendLine("{0}{1} = new {2}();", generateTabs(tabLevel+2), smp.name, generateType(smp, false, true));
		}
		builder.appendLine("{0}}", generateTabs(tabLevel+1));
		builder.appendLine();
		builder.appendLine("{0}IDictionary<string, IEnumerable<string>> IHotwireParameters.GetParameters() {", generateTabs(tabLevel+1));
		builder.appendLine("{0}var rl = new Dictionary<string, IEnumerable<string>>();", generateTabs(tabLevel+2));
		foreach(smp; m.header) {
			if (smp.type.mode == TypeMode.Collection) {
				builder.appendLine("{0}rl.Add(\"{1}\", {1}.Select(a => Convert.ToString(a)));", generateTabs(tabLevel+2), smp.name);
			} else if (smp.type.mode == TypeMode.Primitive) {
				builder.appendLine("{0}rl.Add(\"{1}\", new[] { Convert.ToString({1}) });", generateTabs(tabLevel+2), smp.name);
			}
		}
		builder.appendLine("{0}return rl;", generateTabs(tabLevel+2));
		builder.appendLine("{0}}", generateTabs(tabLevel+1));
		builder.appendLine("{0}}", generateTabs(tabLevel));
	}

	builder.appendLine();
	builder.appendLine("{0}{2} interface I{1}", generateTabs(tabLevel), s.name, s.isPublic ? "public" : "internal");
	builder.appendLine("{0}{", generateTabs(tabLevel));
	foreach(m; s.methods) {
		generateClientInterfaceMethod(builder, m, cast(ushort)(tabLevel+1));
	}
	builder.appendLine("{0}}", generateTabs(tabLevel));
	builder.appendLine();
	builder.appendLine("{0}{2} sealed partial class {1} : I{1}", generateTabs(tabLevel), s.name, s.isPublic ? "public" : "internal");
	builder.appendLine("{0}{", generateTabs(tabLevel));
	builder.appendLine("{0}private readonly IHotwireRequestFactory requests;", generateTabs(tabLevel+1));
	builder.appendLine();
	builder.appendLine("{0}public {1}(IHotwireRequestFactory requests)", generateTabs(tabLevel+1), s.name);
	builder.appendLine("{0}{", generateTabs(tabLevel+1));
	builder.appendLine("{0}this.requests = requests;", generateTabs(tabLevel+2));
	builder.appendLine("{0}}", generateTabs(tabLevel+1));
	builder.appendLine();

	foreach(m; s.methods) {
		generateClientMethod(builder, s, m, cast(ushort)(tabLevel+1));
	}
	builder.appendLine("{0}}", generateTabs(tabLevel));
}

private void generateClientInterfaceMethod(StringBuilder builder, HttpServiceMethod sm, ushort tabLevel)
{
	auto ext = sm.getAspNetCoreHttpExtension();
	bool isSync = (ext !is null && ext.sync);

	if(!isSync) {
		builder.append("{0}Task", generateTabs(tabLevel));
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
			builder.append("{0}{1}", generateTabs(tabLevel), generateType(sm.returns[0], false));
		} else if (sm.returns.length > 1) {
			builder.append("{0}(", generateTabs(tabLevel));
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
		builder.append("{0}public async Task", generateTabs(tabLevel));
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
		builder.append("{0}public", generateTabs(tabLevel));
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
	builder.appendLine("{0}{", generateTabs(tabLevel++));
	builder.appendLine("{0}var response = await requests.CreateRequest({1}).{2}()", generateTabs(tabLevel), s.getRequest(), to!string(sm.verb).capitalize());

	if (sm.routeParts.length > 0) {
		if (sm.route.length > 0) {
			foreach(pp; sm.routeParts) {
				auto ptc = sm.getRouteType(pp);
				if (ptc is null) {
					builder.appendLine("{0}.Path(\"{1}\")", generateTabs(tabLevel+1), pp);
				} else {
					builder.appendLine("{0}.Path({1})", generateTabs(tabLevel+1), pp);
				}
			}
		} else {
			builder.appendLine("{0}.Path(\"{1}\")", generateTabs(tabLevel+1), sm.routeParts.join("\", \""));
		}
	}

	if (sm.query.length > 0) {
		builder.appendLine("{0}.Query(query)", generateTabs(tabLevel+1));
	}

	if (sm.header.length > 0) {
		builder.appendLine("{0}.Header(headers)", generateTabs(tabLevel+1));
	}

	if (sm.authentication != string.init) {
		builder.appendLine("{0}.Authentication(\"{1}\")", generateTabs(tabLevel+1), sm.authentication);
	}

	if (sm.timeout > 0) builder.append("{0}.Timeout(TimeSpan.FromSeconds({1}))", generateTabs(tabLevel+1), to!string(sm.timeout));

	if (!sm.retry) builder.append("{0}.NoRetry()", generateTabs(tabLevel+1));

	if (sm.content.length == 1) {
		TypeComplex tc = sm.content[0];
		if (typeid(tc.type) == typeid(TypeByteArray)) {
			builder.appendLine("{0}.ByteArray({1})", generateTabs(tabLevel+1), tc.name);
		}
		else if (typeid(tc.type) == typeid(TypeStream)) {
			builder.appendLine("{0}.Stream({1})", generateTabs(tabLevel+1), tc.name);
		}
		else if (typeid(tc.type) == typeid(TypeContent)) {
			builder.appendLine("{0}.Content({1})", generateTabs(tabLevel+1), tc.name);
		}
		else if (typeid(tc.type) == typeid(TypePrimitive) && (cast(TypePrimitive)tc.type).primitive == TypePrimitives.String) {
			builder.appendLine("{0}.Text({1})", generateTabs(tabLevel+1), tc.name);
		}
		else if (typeid(tc.type) == typeid(TypeFormUrlEncoded)) {
			builder.appendLine("{0}.FormUrlEncoded({1})", generateTabs(tabLevel+1), tc.name);
		}
		else {
			builder.appendLine("{0}.Serialized({1})", generateTabs(tabLevel+1), tc.name);
		}
	} else if (sm.content.length > 1) {
		builder.appendLine("{0}.Multipart{1}()", generateTabs(tabLevel+1), sm.bodyForm ? "Form" : string.init);
		if (sm.bodySubtype != string.init) builder.appendLine("{0}.Subtype(\"{1}\")", generateTabs(tabLevel+2), sm.bodySubtype);
		if (sm.bodySubtype != string.init) builder.appendLine("{0}.Boundary(\"{1}\")", generateTabs(tabLevel+2), sm.bodyBoundary);
		foreach (tc; sm.content) {
			if (typeid(tc.type) == typeid(TypeByteArray) || typeid(tc.type) == typeid(TypeStream)) {
				builder.appendLine("{0}.File({1})", generateTabs(tabLevel+2), tc.name);
			}
			else if (typeid(tc.type) == typeid(TypeContent)) {
				builder.appendLine("{0}.Content({1})", generateTabs(tabLevel+2), tc.name);
			}
			else if (typeid(tc.type) == typeid(TypePrimitive) && (cast(TypePrimitive)tc.type).primitive == TypePrimitives.String) {
				builder.appendLine("{0}.Text({1})", generateTabs(tabLevel+2), tc.name);
			}
			else if (typeid(tc.type) == typeid(TypeFormUrlEncoded)) {
				builder.appendLine("{0}.FormUrlEncoded({1})", generateTabs(tabLevel+2), tc.name);
			}
			else {
				builder.appendLine("{0}.Serialized({1})", generateTabs(tabLevel+2), tc.name);
			}
		}
		builder.appendLine("{0}.Compile()", generateTabs(tabLevel+2));
	}

	builder.appendLine("{0}.Send();", generateTabs(tabLevel+1));

	if (sm.returns.length > 0) {
		builder.appendLine();
		if (sm.returns.length == 1) {
			TypeComplex tc = sm.returns[0];
			builder.append("{0}return await response", generateTabs(tabLevel));
			if (!sm.retry) builder.appendLine(".ThrowOnFailureResponse()", generateTabs(tabLevel));
			if (typeid(tc.type) == typeid(TypeByteArray)) {
				builder.appendLine(".AsByteArray();");
			}
			else if (typeid(tc.type) == typeid(TypeStream)) {
				builder.appendLine(".AsStream();");
			}
			else if (typeid(tc.type) == typeid(TypeContent)) {
				builder.appendLine(".AsContent();");
			}
			else if (typeid(tc.type) == typeid(TypePrimitive) && (cast(TypePrimitive)tc.type).primitive == TypePrimitives.String) {
				builder.appendLine(".AsText();");
			}
			else if (typeid(tc.type) == typeid(TypeFormUrlEncoded)) {
				builder.appendLine(".AsFormUrlEncoded();");
			}
			else {
				builder.appendLine(".AsObject<{0}>();", generateType(tc));
			}
		} else {
			//TODO: Multipart returns not implemented in client library.
		}
	}

	builder.appendLine("{0}}", generateTabs(--tabLevel));
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

	// Generate optional parameters
	foreach (smp; sm.route) {
		if (!smp.hasDefault()) continue;
		builder.append("{0} {1} = {2}, ", generateType(smp, false, false), cleanName(smp.name), getDefaultValue(smp));
	}

	// These parameters are only required in the abstract signature
	if (sm.query.length != 0) {
		builder.append("{0}Query query = null, ", sm.name);
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
