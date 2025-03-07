module coalescence.languages.csharp.generator;

import coalescence.globals;
import coalescence.types;
import coalescence.schema;
import coalescence.stringbuilder;
import coalescence.utility;

import coalescence.languages.csharp.enums;
import coalescence.languages.csharp.data;
import coalescence.languages.csharp.extensions;
import coalescence.languages.csharp.aspnetcore.client;
import coalescence.languages.csharp.aspnetcore.server;
import coalescence.languages.csharp.signalr.server;
import coalescence.languages.csharp.signalr.client;
import coalescence.languages.csharp.efcore.dbcontext;

import std.algorithm.searching;
import std.path;
import std.stdio;
import std.uni;
import std.string;

public void generateCSharp(Project prj, CSharpProjectOptions opts)
{
	opts.cleanFiles();

	if (prj.hasDatabaseItems && opts.mode != CSharpGeneratorMode.Client) {
		generateEFContext(opts, prj.serverSchema);
	}

	if (opts.outputMode == CSharpOutputMode.SingleFile) {
		if (opts.mode != CSharpGeneratorMode.Client) {
			auto serverBuilder = new StringBuilder(8_388_608);
			serverBuilder.generateUsingsServerComplete(prj, opts);
			foreach(ns; prj.serverSchema) {
				ns.generateSchemaServer(serverBuilder, prj, opts);
			}
			opts.writeFile(serverBuilder, opts.contextName);
		}

		if (opts.mode == CSharpGeneratorMode.Client) {
			auto clientBuilder = new StringBuilder(8_388_608);
			clientBuilder.generateUsingsClientComplete(prj, opts);
			foreach(ns; prj.clientSchema) {
				ns.generateSchemaClient(clientBuilder, prj, opts);
			}
			opts.writeFile(clientBuilder, opts.contextName);
		}
	} else if (opts.outputMode == CSharpOutputMode.FilePerSchema) {
		if (opts.mode != CSharpGeneratorMode.Client) {
			foreach(ns; prj.serverSchema) {
				auto serverBuilder = new StringBuilder(1_048_576);
				serverBuilder.generateUsingsServerComplete(prj, opts);
				ns.generateSchemaServer(serverBuilder, prj, opts);
				opts.writeFile(serverBuilder, ns.name);
			}
		}

		if (opts.mode == CSharpGeneratorMode.Client) {
			foreach(ns; prj.clientSchema) {
				auto clientBuilder = new StringBuilder(1_048_576);
				clientBuilder.generateUsingsClientComplete(prj, opts);
				ns.generateSchemaClient(clientBuilder, prj, opts);
				opts.writeFile(clientBuilder, ns.name);
			}
		}
	} else if (opts.outputMode == CSharpOutputMode.FilePerObject) {
		if (opts.mode != CSharpGeneratorMode.Client) {
			foreach(ns; prj.serverSchema) {
				ns.generateSchemaServer(null, prj, opts);
			}
		}

		if (opts.mode == CSharpGeneratorMode.Client) {
			foreach(ns; prj.clientSchema) {
				ns.generateSchemaClient(null, prj, opts);
			}
		}
	}
}

private void generateSchemaServer(Schema ns, StringBuilder schemaBuilder, Project prj, CSharpProjectOptions opts)
{
	if (opts.outputMode != CSharpOutputMode.FilePerObject) {
		schemaBuilder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
		schemaBuilder.appendLine("{");
		foreach(e; ns.enums.values) {
			generateEnum(e, schemaBuilder, opts, 1);
		}
		foreach(d; ns.tables.values) {
			generateDataTable(d, schemaBuilder, opts, prj, false, 1);
		}
		foreach(d; ns.views.values) {
			generateDataView(d, schemaBuilder, opts, false, 1);
		}
		foreach(d; ns.udts.values) {
			generateDataUdt(d, schemaBuilder, opts, false, 1);
		}
		if (opts.mode != CSharpGeneratorMode.Database) {
			foreach(d; ns.network.values) {
				generateDataNetwork(d, schemaBuilder, opts, false, 1);
			}
			foreach(s; ns.services.values) {
				generateHttpServer(schemaBuilder, s, 1);
			}
			foreach(s; ns.sockets.values) {
				generateWebsocketServer(schemaBuilder, s, 1);
			}
		}
		schemaBuilder.appendLine("}");
	} else {
		foreach(e; ns.enums.values) {
			auto builder = new StringBuilder(4_096);
			builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
			builder.appendLine("{");
			generateEnum(e, builder, opts, 1);
			builder.appendLine("}");
			builder.appendLine();
			opts.writeFile(builder, ns.name, e.name);
		}
		foreach(d; ns.tables.values) {
			auto builder = new StringBuilder(16_384);
			builder.generateUsingsServerData(opts);
			builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
			builder.appendLine("{");
			generateDataTable(d, builder, opts, prj, false, 1);
			builder.appendLine("}");
			builder.appendLine();
			opts.writeFile(builder, ns.name, d.name);
		}
		foreach(d; ns.views.values) {
			auto builder = new StringBuilder(16_384);
			builder.generateUsingsServerData(opts);
			builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
			builder.appendLine("{");
			generateDataView(d, builder, opts, false, 1);
			builder.appendLine("}");
			builder.appendLine();
			opts.writeFile(builder, ns.name, d.name);
		}
		foreach(d; ns.udts.values) {
			auto builder = new StringBuilder(16_384);
			builder.generateUsingsServerData(opts);
			builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
			builder.appendLine("{");
			generateDataUdt(d, builder, opts, false, 1);
			builder.appendLine("}");
			builder.appendLine();
			opts.writeFile(builder, ns.name, d.name);
		}
		if (opts.mode != CSharpGeneratorMode.Database) {
			foreach(d; ns.network.values) {
				auto builder = new StringBuilder(16_384);
				builder.generateUsingsServerData(opts);
				builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
				builder.appendLine("{");
				generateDataNetwork(d, builder, opts, false, 1);
				builder.appendLine("}");
				builder.appendLine();
				opts.writeFile(builder, ns.name, d.name);
			}
			foreach(s; ns.services.values) {
				auto builder = new StringBuilder(32_768);
				builder.generateUsingsServerHttp();
				builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
				builder.appendLine("{");
				generateHttpServer(builder, s, 1);
				builder.appendLine("}");
				builder.appendLine();
				opts.writeFile(builder, ns.name, s.name);
			}
			foreach(s; ns.sockets.values) {
				auto builder = new StringBuilder(32_768);
				builder.generateUsingsServerSocket();
				builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
				builder.appendLine("{");
				generateWebsocketServer(builder, s, 1);
				builder.appendLine("}");
				builder.appendLine();
				opts.writeFile(builder, ns.name, s.name);
			}
		}
	}
}

private void generateSchemaClient(Schema ns, StringBuilder schemaBuilder, Project prj, CSharpProjectOptions opts)
{
	if (opts.outputMode != CSharpOutputMode.FilePerObject) {
		schemaBuilder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
		schemaBuilder.appendLine("{");
		foreach(e; ns.enums.values) {
			generateEnum(e, schemaBuilder, opts, 1);
		}
		foreach(d; ns.tables.values) {
			generateDataTable(d, schemaBuilder, opts, prj, true, 1);
		}
		foreach(d; ns.views.values) {
			generateDataView(d, schemaBuilder, opts, true, 1);
		}
		foreach(d; ns.udts.values) {
			generateDataUdt(d, schemaBuilder, opts, true, 1);
		}
		if (opts.mode != CSharpGeneratorMode.Database) {
			foreach(d; ns.network.values) {
				generateDataNetwork(d, schemaBuilder, opts, true, 1);
			}
			foreach(s; ns.services.values) {
				generateHttpClient(schemaBuilder, s, 1);
			}
			foreach(s; ns.sockets.values) {
				generateWebsocketClient(schemaBuilder, s, 1);
			}
		}
		schemaBuilder.appendLine("}");
	} else {
		foreach(e; ns.enums.values) {
			auto builder = new StringBuilder(4_096);
			builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
			builder.appendLine("{");
			generateEnum(e, builder, opts, 1);
			builder.appendLine("}");
			builder.appendLine();
			opts.writeFile(builder, ns.name, e.name);
		}
		foreach(d; ns.tables.values) {
			auto builder = new StringBuilder(16_384);
			builder.generateUsingsClientData(opts);
			builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
			builder.appendLine("{");
			generateDataTable(d, builder, opts, prj, true, 1);
			builder.appendLine("}");
			builder.appendLine();
			opts.writeFile(builder, ns.name, d.name);
		}
		foreach(d; ns.views.values) {
			auto builder = new StringBuilder(16_384);
			builder.generateUsingsClientData(opts);
			builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
			builder.appendLine("{");
			generateDataView(d, builder, opts, true, 1);
			builder.appendLine("}");
			builder.appendLine();
			opts.writeFile(builder, ns.name, d.name);
		}
		foreach(d; ns.udts.values) {
			auto builder = new StringBuilder(16_384);
			builder.generateUsingsClientData(opts);
			builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
			builder.appendLine("{");
			generateDataUdt(d, builder, opts, true, 1);
			builder.appendLine("}");
			builder.appendLine();
			opts.writeFile(builder, ns.name, d.name);
		}
		if (opts.mode != CSharpGeneratorMode.Database) {
			foreach(d; ns.network.values) {
				auto builder = new StringBuilder(16_384);
				builder.generateUsingsClientData(opts);
				builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
				builder.appendLine("{");
				generateDataNetwork(d, builder, opts, true, 1);
				builder.appendLine("}");
				builder.appendLine();
				opts.writeFile(builder, ns.name, d.name);
			}
			foreach(s; ns.services.values) {
				auto builder = new StringBuilder(32_768);
				builder.generateUsingsClientHttp();
				builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
				builder.appendLine("{");
				generateHttpClient(builder, s, 1);
				builder.appendLine("}");
				builder.appendLine();
				opts.writeFile(builder, ns.name, s.name);
			}
			foreach(s; ns.sockets.values) {
				auto builder = new StringBuilder(32_768);
				builder.generateUsingsClientSocket();
				builder.appendLine("namespace {0}", ns.getCSharpFqn(opts));
				builder.appendLine("{");
				generateWebsocketClient(builder, s, 1);
				builder.appendLine("}");
				builder.appendLine();
				opts.writeFile(builder, ns.name, s.name);
			}
		}
	}
}

private void generateUsingsServerComplete(StringBuilder builder, Project prj, CSharpProjectOptions opts) {
	builder.appendLine("using System;");
	builder.appendLine("using System.Collections.Generic;");
	if (opts.changeTracking) builder.appendLine("using System.Collections.ObjectModel;");
	builder.appendLine("using System.Linq;");
	builder.appendLine("using System.IO;");
	if (opts.serializers.any!(a => a == CSharpSerializers.DataContract)) {
		builder.appendLine("using System.Runtime.Serialization;");
	}
	if (opts.serializers.any!(a => a == CSharpSerializers.SystemTextJson)) {
		builder.appendLine("using System.Text.Json.Serialization;");
	}
	if (opts.serializers.any!(a => a == CSharpSerializers.NewtonsoftJson)) {
		builder.appendLine("using Newtonsoft.Json;");
	}
	builder.appendLine("using System.Threading.Tasks;");
	builder.appendLine("using Microsoft.Extensions.Primitives;");
	if (opts.mode != CSharpGeneratorMode.Database) {
		builder.appendLine("using Microsoft.AspNetCore.Mvc;");
		builder.appendLine("using Microsoft.AspNetCore.Authorization;");
		if (prj.hasSocketServices) {
			builder.appendLine("using Microsoft.AspNetCore.SignalR;");
			builder.appendLine("using EllipticBit.Coalescence.SignalR;");
		}
		if (prj.hasHttpServices) {
			builder.appendLine("using EllipticBit.Coalescence.AspNetCore;");
		}
	}
	builder.appendLine("using EllipticBit.Coalescence.Shared;");
	if (opts.changeTracking) {
		builder.appendLine("using EllipticBit.Coalescence.Windows;");
	}
	if (opts.enableEFExtensions) builder.appendLine("using EllipticBit.Services.Database;");
	builder.appendLine();
}

private void generateUsingsClientComplete(StringBuilder builder, Project prj, CSharpProjectOptions opts) {
	builder.appendLine("using System;");
	builder.appendLine("using System.Collections.Generic;");
	if (opts.changeTracking) builder.appendLine("using System.Collections.ObjectModel;");
	builder.appendLine("using System.Linq;");
	builder.appendLine("using System.IO;");
	if (opts.serializers.any!(a => a == CSharpSerializers.DataContract)) {
		builder.appendLine("using System.Runtime.Serialization;");
	}
	if (opts.serializers.any!(a => a == CSharpSerializers.SystemTextJson)) {
		builder.appendLine("using System.Text.Json.Serialization;");
	}
	if (opts.serializers.any!(a => a == CSharpSerializers.NewtonsoftJson)) {
		builder.appendLine("using Newtonsoft.Json;");
	}
	builder.appendLine("using System.Threading.Tasks;");
	builder.appendLine("using System.Net;");
	builder.appendLine("using System.Net.Http;");
	builder.appendLine("using System.Net.Http.Headers;");
	builder.appendLine("using System.Text;");
	builder.appendLine("using Microsoft.Extensions.DependencyInjection;");
	builder.appendLine("using Microsoft.Extensions.DependencyInjection.Extensions;");
	if (opts.mode != CSharpGeneratorMode.Database) {
		if (prj.hasSocketServices) {
			builder.appendLine("using Microsoft.AspNetCore.SignalR.Client;");
			builder.appendLine("using EllipticBit.Coalescence.SignalR;");
		}
		if (prj.hasHttpServices) {
			builder.appendLine("using EllipticBit.Coalescence.Shared.Request;");
		}
	}
	if (opts.uiBindings) {
		builder.appendLine("using EllipticBit.Coalescence.Shared;");
	}
	if (opts.changeTracking) {
		builder.appendLine("using EllipticBit.Coalescence.Windows;");
	}
	builder.appendLine();
}

private void generateUsingsServerData(StringBuilder builder, CSharpProjectOptions opts) {
	builder.appendLine("using System;");
	builder.appendLine("using System.Collections.Generic;");
	if (opts.changeTracking) builder.appendLine("using System.Collections.ObjectModel;");
	builder.appendLine("using System.Linq;");
	builder.appendLine("using System.IO;");
	if (opts.serializers.any!(a => a == CSharpSerializers.DataContract)) {
		builder.appendLine("using System.Runtime.Serialization;");
	}
	if (opts.serializers.any!(a => a == CSharpSerializers.SystemTextJson)) {
		builder.appendLine("using System.Text.Json.Serialization;");
	}
	if (opts.serializers.any!(a => a == CSharpSerializers.NewtonsoftJson)) {
		builder.appendLine("using Newtonsoft.Json;");
	}
	if (opts.enableEFExtensions) builder.appendLine("using EllipticBit.Services.Database;");
	if (opts.uiBindings) {
		builder.appendLine("using EllipticBit.Coalescence.Shared;");
	}
	if (opts.changeTracking) {
		builder.appendLine("using EllipticBit.Coalescence.Windows;");
	}
	builder.appendLine();
}

private void generateUsingsClientData(StringBuilder builder, CSharpProjectOptions opts) {
	builder.appendLine("using System;");
	builder.appendLine("using System.Collections.Generic;");
	if (opts.changeTracking) builder.appendLine("using System.Collections.ObjectModel;");
	builder.appendLine("using System.Linq;");
	builder.appendLine("using System.IO;");
	if (opts.serializers.any!(a => a == CSharpSerializers.DataContract)) {
		builder.appendLine("using System.Runtime.Serialization;");
	}
	if (opts.serializers.any!(a => a == CSharpSerializers.SystemTextJson)) {
		builder.appendLine("using System.Text.Json.Serialization;");
	}
	if (opts.serializers.any!(a => a == CSharpSerializers.NewtonsoftJson)) {
		builder.appendLine("using Newtonsoft.Json;");
	}
	if (opts.uiBindings) {
		builder.appendLine("using EllipticBit.Coalescence.Shared;");
	}
	if (opts.changeTracking) {
		builder.appendLine("using EllipticBit.Coalescence.Windows;");
	}
	builder.appendLine();
}

private void generateUsingsServerHttp(StringBuilder builder) {
	builder.appendLine("using System;");
	builder.appendLine("using System.Collections.Generic;");
	builder.appendLine("using System.Linq;");
	builder.appendLine("using System.IO;");
	builder.appendLine("using System.Threading.Tasks;");
	builder.appendLine("using Microsoft.Extensions.Primitives;");
	builder.appendLine("using Microsoft.AspNetCore.Mvc;");
	builder.appendLine("using Microsoft.AspNetCore.Authorization;");
	builder.appendLine("using EllipticBit.Coalescence.Shared;");
	builder.appendLine("using EllipticBit.Coalescence.AspNetCore;");
	builder.appendLine();
}

private void generateUsingsClientHttp(StringBuilder builder) {
	builder.appendLine("using System;");
	builder.appendLine("using System.Collections.Generic;");
	builder.appendLine("using System.Linq;");
	builder.appendLine("using System.IO;");
	builder.appendLine("using System.Threading.Tasks;");
	builder.appendLine("using System.Net;");
	builder.appendLine("using System.Net.Http;");
	builder.appendLine("using System.Net.Http.Headers;");
	builder.appendLine("using System.Text;");
	builder.appendLine("using EllipticBit.Coalescence.Shared.Request;");
	builder.appendLine();
}

private void generateUsingsServerSocket(StringBuilder builder) {
	builder.appendLine("using System;");
	builder.appendLine("using System.Collections.Generic;");
	builder.appendLine("using System.Linq;");
	builder.appendLine("using System.IO;");
	builder.appendLine("using System.Threading.Tasks;");
	builder.appendLine("using Microsoft.Extensions.Primitives;");
	builder.appendLine("using Microsoft.AspNetCore.Mvc;");
	builder.appendLine("using Microsoft.AspNetCore.Authorization;");
	builder.appendLine("using Microsoft.AspNetCore.SignalR;");
	builder.appendLine("using EllipticBit.Coalescence.SignalR;");
	builder.appendLine("using EllipticBit.Coalescence.Shared;");
	builder.appendLine();
}

private void generateUsingsClientSocket(StringBuilder builder) {
	builder.appendLine("using System;");
	builder.appendLine("using System.Collections.Generic;");
	builder.appendLine("using System.Linq;");
	builder.appendLine("using System.IO;");
	builder.appendLine("using System.Threading.Tasks;");
	builder.appendLine("using System.Net;");
	builder.appendLine("using System.Net.Http;");
	builder.appendLine("using System.Net.Http.Headers;");
	builder.appendLine("using System.Text;");
	builder.appendLine("using Microsoft.AspNetCore.SignalR.Client;");
	builder.appendLine("using Microsoft.Extensions.DependencyInjection;");
	builder.appendLine("using Microsoft.Extensions.DependencyInjection.Extensions;");
	builder.appendLine("using EllipticBit.Coalescence.SignalR;");
	builder.appendLine();
}

public void generateAuthorization(StringBuilder builder, immutable(AspNetCoreAuthorizationExtension) auth, bool authenticate, bool hasControllerAuth, int tabLevel) {
	if (!authenticate) {
		builder.tabs(tabLevel).appendLine("[AllowAnonymous]");
	} else if (authenticate && !hasControllerAuth && auth is null) {
		builder.tabs(tabLevel).appendLine("[Authorize]");
	} else if (authenticate && auth !is null) {
		if (auth.requireAllRoles) {
			foreach(r; auth.roles) {
				builder.tabs(tabLevel).appendLine("[Authorize(Roles = \"{0}\")]", r);
			}
		} else if (auth.roles.length > 0) {
			builder.tabs(tabLevel).appendLine("[Authorize(Roles = \"{0}\")]", auth.roles.join(","));
		}
		if (auth.schemes.length > 0) {
			builder.tabs(tabLevel).appendLine("[Authorize(AuthenticationSchemes = \"{0}\")]", auth.schemes.join(","));
		}
		if (auth.policy != string.init) {
			builder.tabs(tabLevel).appendLine("[Authorize(Policy = \"{0}\")]", auth.policy);
		}
	}
}

public string generateType(TypeComplex type, bool base64external = false, bool forceOptional = false, bool isTracking = false)
{
	if (typeid(type.type) == typeid(TypePrimitive)) {
		TypePrimitive p = cast(TypePrimitive)type.type;
		if(p.primitive == TypePrimitives.Boolean) return "bool" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.UInt8) return "byte" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.Int8) return "sbyte" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.UInt16) return "ushort" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.Int16) return "short" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.UInt32) return "uint" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.Int32) return "int" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.UInt64) return "ulong" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.Int64) return "long" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.Float) return "float" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.Double) return "double" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.Fixed) return "decimal" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.String || p.primitive == TypePrimitives.Base64String) return "string";
		else if(p.primitive == TypePrimitives.Base64ByteArray) return base64external ? "byte[]" : "string";
		else if(p.primitive == TypePrimitives.DateTime) return "DateTime" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.DateTimeTz) return "DateTimeOffset" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.TimeSpan) return "TimeSpan" ~ (type.nullable || forceOptional ? "?" : string.init);
		else if(p.primitive == TypePrimitives.Guid) return "Guid" ~ (type.nullable || forceOptional ? "?" : string.init);
	}

	else if(typeid(type.type) == typeid(TypeVoid)) {
		return "void";
	}

	else if(typeid(type.type) == typeid(TypeStream)) {
		return "Stream";
	}

	else if(typeid(type.type) == typeid(TypeContent)) {
		return "HttpContent";
	}

	else if(typeid(type.type) == typeid(TypeByteArray)) {
		return "byte[]";
	}

	else if(typeid(type.type) == typeid(TypeCollection)) {
		TypeCollection t = cast(TypeCollection)(type.type);
		if (isTracking) return "ObservableCollection<" ~ generateType(t.collectionType, base64external, forceOptional) ~ ">";
		return "List<" ~ generateType(t.collectionType, base64external, forceOptional) ~ ">";
	}

	else if(typeid(type.type) == typeid(TypeDictionary)) {
		TypeDictionary t = cast(TypeDictionary)(type.type);
		return "Dictionary<" ~ generateType(t.keyType, base64external, forceOptional) ~ ", " ~ generateType(t.valueType, base64external, forceOptional) ~ ">";
	}

	else if(typeid(type.type) == typeid(TypeEnum)) {
		TypeEnum t = cast(TypeEnum)(type.type);
		return t.definition.parent.name.uppercaseFirst() ~ "." ~ t.definition.name ~ (type.nullable ? "?" : "");
		//return t.definition.getCSharpFqn() ~ (type.nullable ? "?" : "");
	}

	else if(typeid(type.type) == typeid(TypeModel)) {
		TypeModel t = cast(TypeModel)(type.type);
		return t.definition.parent.name.uppercaseFirst() ~ "." ~ t.definition.name;
		//return t.definition.getCSharpFqn();
	}

	return string.init;
}

public string getStringConversion(TypeComplex type, string name) {
	if (typeid(type.type) == typeid(TypePrimitive)) {
		TypePrimitive p = cast(TypePrimitive)type.type;
		if(p.primitive == TypePrimitives.Boolean) return StringBuilder.format("Convert.ToBoolean({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.UInt8) return StringBuilder.format("Convert.ToByte({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.Int8) return StringBuilder.format("Convert.ToSByte({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.UInt16) return StringBuilder.format("Convert.ToUInt16({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.Int16) return StringBuilder.format("Convert.ToInt16({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.UInt32) return StringBuilder.format("Convert.ToUInt32({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.Int32) return StringBuilder.format("Convert.ToInt32({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.UInt64) return StringBuilder.format("Convert.ToUInt64({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.Int64) return StringBuilder.format("Convert.ToInt64({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.Float) return StringBuilder.format("Convert.ToFloat({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.Double) return StringBuilder.format("Convert.ToDouble({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.Fixed) return StringBuilder.format("Convert.ToDecimal({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.DateTime) return StringBuilder.format("DateTime.Parse({0}{1}, DateTimeFormatInfo.InvariantInfo)", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.DateTimeTz) return StringBuilder.format("DateTimeOffset.Parse({0}{1}, DateTimeFormatInfo.InvariantInfo)", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.TimeSpan) return StringBuilder.format("TimeSpan.Parse({0}{1}, DateTimeFormatInfo.InvariantInfo)", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
		if(p.primitive == TypePrimitives.Guid) return StringBuilder.format("Guid.Parse({0}{1})", name, type.nullable ? "?? " ~ getDefaultValue(type) : string.init);
	}

	return name;
}

public string getDefaultValue(TypeComplex type) {
	if (typeid(type.type) == typeid(TypePrimitive)) {
		TypePrimitive p = cast(TypePrimitive)type.type;
		if (type.defaultInit) {
			if(p.primitive == TypePrimitives.Boolean) return "default(bool)";
			if(p.primitive == TypePrimitives.UInt8) return "default(byte)";
			if(p.primitive == TypePrimitives.Int8) return "default(sbyte)";
			if(p.primitive == TypePrimitives.UInt16) return "default(ushort)";
			if(p.primitive == TypePrimitives.Int16) return "default(short)";
			if(p.primitive == TypePrimitives.UInt32) return "default(uint)";
			if(p.primitive == TypePrimitives.Int32) return "default(int)";
			if(p.primitive == TypePrimitives.UInt64) return "default(uint64)";
			if(p.primitive == TypePrimitives.Int64) return "default(int64)";
			if(p.primitive == TypePrimitives.Float) return "default(float)";
			if(p.primitive == TypePrimitives.Double) return "default(double)";
			if(p.primitive == TypePrimitives.Fixed) return "default(decimal)";
			if(p.primitive == TypePrimitives.DateTime) return "default(DateTime)";
			if(p.primitive == TypePrimitives.DateTimeTz) return "default(DateTimeOffset)";
			if(p.primitive == TypePrimitives.TimeSpan) return "default(TimeSpan)";
			if(p.primitive == TypePrimitives.Guid) return "default(Guid)";
		}
		if (type.defaultNull) {
			return type.nullable ? "null" : string.init;
		}
		if (type.defaultValue != string.init) {
			if (p.primitive == TypePrimitives.String || p.primitive == TypePrimitives.Base64String) {
				return "\"" ~ type.defaultValue ~ "\"";
			} else {
				return type.defaultValue;
			}
		}
	} else if (typeid(type.type) == typeid(TypeEnum)) {
		TypeEnum te = cast(TypeEnum)type.type;
		auto idx = te.definition.values.countUntil!(a => a.isDefault)();
		if (idx == -1) {
			writeParseError("Unable able to locate the default value for enumeration: " ~ te.definition.name, type.sourceLocation);
			return string.init;
		}
		return getCSharpFullName(te.definition) ~ "." ~ te.definition.values[idx].name;
	} else if (typeid(type.type) == typeid(TypeVoid)) {
		return string.init;
	} else if (typeid(type.type) == typeid(TypeByteArray) || typeid(type.type) == typeid(TypeModel) || typeid(type.type) == typeid(TypeStream) || typeid(type.type) == typeid(TypeContent)) {
		if (type.defaultInit || type.defaultNull) {
			return "null";
		} else {
			return string.init;
		}
	} else if (typeid(type.type) == typeid(TypeCollection) || typeid(type.type) == typeid(TypeDictionary)) {
		if (type.defaultInit || type.defaultNull) {
			return "default(" ~ generateType(type) ~ ")";
		} else {
			return string.init;
		}
	}

	return string.init;
}

public string getCSharpFqn(Schema n, CSharpProjectOptions opts) {
	return opts.namespace ~ "." ~ n.name.uppercaseFirst();
}

public string getCSharpFqn(Enumeration e, CSharpProjectOptions opts) {
	return e.parent.getCSharpFqn(opts) ~ "." ~ e.name.uppercaseFirst();
}

public string getCSharpFqn(DataObject m, CSharpProjectOptions opts) {
	return m.parent.getCSharpFqn(opts) ~ "." ~ m.name.uppercaseFirst();
}

public string getCSharpFullName(Enumeration e) {
	return e.parent.name.uppercaseFirst() ~ "." ~ e.name.uppercaseFirst();
}

public string getCSharpFullName(DataObject m) {
	return m.parent.name.uppercaseFirst() ~ "." ~ m.name.uppercaseFirst();
}
