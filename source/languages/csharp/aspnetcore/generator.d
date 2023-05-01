module restforge.languages.csharp.aspnetcore.generator;

import restforge.globals;
import restforge.types;
import restforge.model;
import restforge.stringbuilder;

import restforge.languages.csharp.aspnetcore.enums;
import restforge.languages.csharp.aspnetcore.model;
import restforge.languages.csharp.aspnetcore.http.client;
import restforge.languages.csharp.aspnetcore.http.server;
import restforge.languages.csharp.aspnetcore.signalr.server;
import restforge.languages.csharp.aspnetcore.signalr.client;
import restforge.languages.csharp.aspnetcore.extensions;

import std.stdio;
import std.uni;
import std.string;

public void generateCSharp(ProjectFile file)
{
	foreach(ns; file.namespaces)
		generateNamespace(file.builder, ns);

	writeFile(file, "cs");
}

private void generateNamespace(StringBuilder builder, Namespace ns)
{
	uint c = 0;
	builder.appendLine("using System;");
	builder.appendLine("using System.Collections.Generic;");
	if(hasOption("xaml") && clientGen) {
		builder.appendLine("using System.ComponentModel;");
	}
	builder.appendLine("using System.Linq;");
	builder.appendLine("using System.IO;");
	builder.appendLine("using System.Runtime.Serialization;");
	if(!hasOption("useNewtonsoft")) {
		builder.appendLine("using System.Text.Json.Serialization;");
	}
	builder.appendLine("using System.Threading.Tasks;");
	if(clientGen)
	{
		builder.appendLine("using System.Net;");
		builder.appendLine("using System.Net.Http;");
		builder.appendLine("using System.Net.Http.Headers;");
		builder.appendLine("using System.Text;");
		builder.appendLine("using System.Windows;");
		if (ns.sockets.length>0) {
			builder.appendLine("using Microsoft.AspNetCore.SignalR.Client;");
			builder.appendLine("using Microsoft.Extensions.DependencyInjection;");
			builder.appendLine("using Microsoft.Extensions.DependencyInjection.Extensions;");
			builder.appendLine("using EllipticBit.Hotwire.SignalR;");
		}
		builder.appendLine("using EllipticBit.Hotwire.Request;");
	}
	if (serverGen)
	{
		builder.appendLine("using Microsoft.Extensions.Primitives;");
		builder.appendLine("using Microsoft.AspNetCore.Mvc;");
		builder.appendLine("using Microsoft.AspNetCore.Authorization;");
		if (ns.sockets.length>0) {
			builder.appendLine("using Microsoft.AspNetCore.SignalR;");
			builder.appendLine("using EllipticBit.Hotwire.SignalR;");
		}
		builder.appendLine("using EllipticBit.Hotwire.Shared;");
		builder.appendLine("using EllipticBit.Hotwire.AspNetCore;");
	}
	builder.appendLine();
	builder.append("namespace ");
	builder.append(ns.getFqn());
	builder.appendLine();
	builder.appendLine("{");
	foreach(e; ns.enums)
		generateEnum(builder, e, 1);
	foreach(m; ns.models)
		generateModel(builder, m, 1);

	if(serverGen) {
		foreach(s; ns.services)
			generateHttpServer(builder, s, 1);
	} else {
		foreach(s; ns.services)
			generateHttpClient(builder, s, 1);
	}

	if(serverGen) {
		foreach(s; ns.sockets)
			generateWebsocketServer(builder, s, 1);
	} else {
		foreach(s; ns.sockets)
			generateWebsocketClient(builder, s, 1);
	}

	builder.appendLine("}");
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

public string generateType(TypeComplex type, bool base64external = false, bool forceOptional = false)
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
		return "List<" ~ generateType(t.collectionType) ~ ">";
	}

	else if(typeid(type.type) == typeid(TypeDictionary)) {
		TypeDictionary t = cast(TypeDictionary)(type.type);
		return "Dictionary<" ~ generateType(t.keyType) ~ ", " ~ generateType(t.valueType) ~ ">";
	}

	else if(typeid(type.type) == typeid(TypeEnum)) {
		TypeEnum t = cast(TypeEnum)(type.type);
		return t.definition.getFqn() ~ (type.nullable ? "?" : "");
	}

	else if(typeid(type.type) == typeid(TypeModel)) {
		TypeModel t = cast(TypeModel)(type.type);
		return t.definition.getFqn();
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
	} else if (typeid(type.type) == typeid(TypeVoid)) {
		return string.init;
	} else if (typeid(type.type) == typeid(TypeByteArray)) {
		if (type.defaultInit || type.defaultNull) {
			return "null";
		} else {
			writeParseError("Invalid default values for Byte Array types.", type.sourceLocation);
			return string.init;
		}
	} else if (typeid(type.type) == typeid(TypeModel) || typeid(type.type) == typeid(TypeStream) || typeid(type.type) == typeid(TypeContent)) {
		if (type.defaultNull) {
			return "null";
		} else {
			writeParseError("Invalid default values for Model/Stream/Content types.", type.sourceLocation);
			return string.init;
		}
	} else if (typeid(type.type) == typeid(TypeCollection) || typeid(type.type) == typeid(TypeDictionary)) {
		if (type.defaultInit || type.defaultNull) {
			return "new()";
		} else {
			writeParseError("Invalid default values for Collection and Dictionary types.", type.sourceLocation);
			return string.init;
		}
	}

	return string.init;
}

public string getFqn(Namespace n) {
	string fqn = string.init;
	foreach (s; n.segments) {
		fqn ~= s ~ ".";
	}
	return fqn[0..$-1];
}

public string getFqn(Enumeration e) {
	return e.parent.getFqn() ~ "." ~ e.name;
}

public string getFqn(Model m) {
	return m.parent.getFqn() ~ "." ~ m.name;
}

public bool isCSharpLang(string language)
{
	return language.toLower() == "CS".toLower() || language.toLower() == "CSharp".toLower();
}

public void displayCSharpOptions()
{
	writeln("C# Code Generation Options:");
	writeln("    -xaml                       Generate XAML/WinForms compatible bindings for the generated models.");
	writeln("    -useTabs                    Use tabs instead of spaces in the generated code.");
}

public string[string] parseCSharpOptions(string[] args)
{
	string[string] opts;
	opts = opts.init;

	for(int i = 0; i < args.length; i++)
	{
		if(args[i] == "-xaml")
			opts["xaml"] = "true";
		if(args[i] == "-useTabs") {
			opts["useSpaces"] = "false";
			useSpaces = false;
		}
	}

	return opts.rehash;
}
