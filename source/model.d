module restforge.model;

import restforge.globals;
import restforge.types;
import restforge.stringbuilder;

// Extensions
import restforge.languages.csharp.aspnetcore.extensions;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.typecons;
import std.stdio;
import std.string;

import sdlang;

public abstract class LanguageExtensionBase
{
	public immutable string language;
	public immutable string framework;
	public immutable AuthorizationExtensionBase authorization;

	protected this(string language, string framework, AuthorizationExtensionBase authorization) {
		this.language = language;
		this.framework = framework;
		this.authorization = cast(immutable(AuthorizationExtensionBase)) authorization;
	}
}

public abstract class AuthorizationExtensionBase { }

public final class ProjectFile
{
	public string inputPath;
	public string outputPath;

	public Namespace[] namespaces;
	public StringBuilder builder;

	public this(string filePath, string outputPath)
	{
		builder = new StringBuilder(32_768);
		this.inputPath = filePath;
		this.outputPath = outputPath;
		auto root = parseFile(filePath);
		foreach(t; root.tags) {
			if (t.name.toLower() != "namespace") writeParseError("Unexpected declaration: " ~ t.name, root.location);
			namespaces ~= new Namespace(t);
		}
	}
}

public final class Namespace
{
	public string name;
	public string[] segments;
	public string[] imports;

	public Enumeration[] enums;
	public Model[] models;
	public HttpService[] services;
	public WebsocketService[] sockets;

	public this() { }

	public this (Tag root) {
		this.name = root.expectValue!string();
		this.segments = this.name.split(".");

		foreach(t; root.tags) {
			if(t.name.toLower() == "enum".toLower()) enums ~= new Enumeration(this, t);
			else if(t.name.toLower() == "model".toLower()) models ~= new Model(this, t);
			else if(t.name.toLower() == "http".toLower()) services ~= new HttpService(this, t);
			else if(t.name.toLower() == "websocket".toLower()) sockets ~= new WebsocketService(this, t);
			else if(t.name.toLower() == "import".toLower()) imports ~= t.expectValue!string();
			else writeParseError("Unexpected declaration: " ~ t.name, root.location);
		}
	}
}

public final class Enumeration : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Enum; }

	public Namespace parent;
	public bool packed = false;
	public EnumerationValue[] values;

	public this(Namespace parent, Tag root) {
		this.parent = parent;
		this.name = root.expectValue!string();
		this.packed = root.getAttribute!bool("packed", false);

		foreach (Tag t; root.tags) {
			values ~= new EnumerationValue(this, t);
		}

		super(name, root.location);
	}
}

public final class EnumerationValue : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Enum; }

	public Enumeration parent;
	public Nullable!long value;
	public EnumerationValueAggregate[] aggregate;

	public this(Enumeration parent, Tag root) {
		this.parent = parent;
		this.name = root.name;
		if (root.values.length == 1 && root.values[0].convertsTo!long()) {
			value = root.values[0].get!long();
		} else if (root.values.length >= 1 && root.values[0].convertsTo!string()) {
			foreach (v; root.values) {
				auto eva = new EnumerationValueAggregate();
				eva.parent = this;
				eva.type = parent;
				eva.aggregateLabel = v.get!string();
				this.aggregate ~= eva;
			}
		}

		super(name, root.location);
	}
}

public final class EnumerationValueAggregate
{
	public EnumerationValue parent;
	public string aggregateLabel;
	public Enumeration type;
	public EnumerationValue value;
}

public final class Model : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Model; }

	public Namespace parent;
	public ModelMember[] members;

	public string database;
	public bool hasDatabase() { return database != null && database != string.init; }
	public bool hasPrimaryKey() { return members.any!(a => a.primaryKey)(); }

	public this(Namespace parent, Tag root) {
		this.parent = parent;
		this.name = root.expectValue!string();
		this.database = root.getAttribute!string("database", string.init);

		foreach (Tag t; root.tags) {
			members ~= new ModelMember(this, t);
		}

		super(name, root.location);
	}
}

public final class ModelMember : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Model; }

	public Model parent;

	public TypeComplex type = null;
	public bool hidden;
	public bool readonly;
	public bool sync;
	public bool primaryKey;

	public string transport;
	public bool hasTransport() { return transport != null && transport != string.init; }
	public string database;
	public bool hasDatabase() { return database != null && database != string.init; }
	public bool isIdentity;
	public bool modelbind;
	public bool update;

	public this(Model parent, Tag root) {
		this.parent = parent;
		this.name = root.name;
		this.hidden = root.getAttribute!bool("hidden", false);
		this.readonly = root.getAttribute!bool("readonly", false);
		this.sync = root.getAttribute!bool("sync", false);
		this.primaryKey = root.getAttribute!bool("primaryKey", false);
		this.update = root.getAttribute!bool("update", true);
		this.transport = root.getAttribute!string("transport", string.init);
		this.database = root.getAttribute!string("database", string.init);
		this.isIdentity = root.getAttribute!bool("identity", false);
		this.modelbind = root.getAttribute!bool("modelbind", false);

		this.type = new TypeComplex(this.name, root.expectAttribute!string("type"), root.location);

		super(name, root.location);
	}
}

public final class HttpService : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Service; }

	public Namespace parent;
	public HttpServiceMethod[] methods;
	public LanguageExtensionBase[] extensions;

	public bool isPublic;
	public string route;
	public bool hasRoute() { return route != null && route != string.init; }
	public bool authenticate;
	public string scheme;
	public string requestName;
	public string requestParameterId;

	public this(Namespace parent, Tag root) {
		this.parent = parent;
		this.name = root.expectValue!string();
		this.isPublic = root.getAttribute!bool("public", true);
		this.route = root.getAttribute!string("route", string.init).strip().strip("/");
		this.authenticate = root.getAttribute!bool("authenticate", true);
		this.scheme = root.getAttribute!string("scheme", string.init);
		this.requestName = root.getAttribute!string("requestName", null);
		this.requestParameterId = root.getAttribute!string("requestParameterId", null);

		auto ancext = root.getTag("extensions:aspnetcore", null);
		if(ancext !is null) extensions ~= new AspNetCoreHttpExtension(this, ancext);

		foreach(sm; root.tags) {
			if (sm.namespace == "extensions") continue;
			methods ~= new HttpServiceMethod(this, sm);
		}

		super(name, root.location);
	}

	public string getRequest() {
		if (requestName !is null && requestName != string.init) {
			return "\"" ~ requestName ~ "\"";
		} else if (requestParameterId !is null && requestParameterId != string.init) {
			return requestParameterId ~ ".ToString()";
		}

		return string.init;
	}
}

public enum HttpServiceMethodVerb
{
	Get,
	Head,
	Put,
	Post,
	Delete,
	Patch
}

public final class HttpServiceMethod : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Service; }

	public HttpService parent;
	public bool hidden;

	public bool hasRoute() { return route != null && route.length > 0; }
	public bool authenticate;
	public string scheme;
	public uint timeout;
	public bool retry;

	public HttpServiceMethodVerb verb;
	public string[] routeParts;
	public TypeComplex[] route;
	public TypeComplex[] query;
	public TypeComplex[] header;
	public TypeComplex[] content;
	public TypeComplex[] returns;

	public string tenantIdParameter;

	public bool bodyForm;
	public string bodyBoundary;
	public string bodySubtype;

	public bool returnForm;
	public string returnBoundary;
	public string returnSubtype;

	public LanguageExtensionBase[] extensions;

	public this(HttpService parent, Tag root) {
		this.parent = parent;
		this.name = root.values[0].get!string();
		this.hidden = root.getAttribute!bool("hidden", false);
		this.authenticate = root.getAttribute!bool("authenticate", true);
		this.scheme = root.getAttribute!string("scheme", string.init);
		this.timeout = root.getAttribute!int("timeout", 0);
		this.retry = root.getAttribute!bool("retry", true);

		auto ancext = root.getTag("extensions:aspnetcore", null);
		if(ancext !is null) extensions ~= new AspNetCoreHttpMethodExtension(this, ancext);

		string verb = root.name;
		if (verb.toLower() == "get") this.verb = HttpServiceMethodVerb.Get;
		else if (verb.toLower() == "head") this.verb = HttpServiceMethodVerb.Head;
		else if (verb.toLower() == "put") this.verb = HttpServiceMethodVerb.Put;
		else if (verb.toLower() == "post") this.verb = HttpServiceMethodVerb.Post;
		else if (verb.toLower() == "delete") this.verb = HttpServiceMethodVerb.Delete;
		else if (verb.toLower() == "patch") this.verb = HttpServiceMethodVerb.Patch;
		else writeParseError("Unexpected method verb: " ~ verb, root.location);

		auto pt = root.getTag("route", null);
		if (pt !is null) {
			foreach(smp; pt.maybe.attributes) {
				route ~= new TypeComplex(smp.name, smp.value.get!string(), root.location);
			}
			if (pt.values.length == 1) {
				routeParts ~= pt.values[0].get!string().strip().strip("/").split("/");
			} else if (pt.values.length > 1) {
				foreach(rv; pt.values) {
					routeParts ~= rv.get!string().strip().strip("/").split("/");
				}
			}
		}

		auto qt = root.getTag("query", null);
		if (qt !is null) {
			foreach(smp; qt.maybe.attributes) {
				query ~= new TypeComplex(smp.name, smp.value.get!string(), root.location);
			}
		}

		auto ht = root.getTag("header", null);
		if (ht !is null) {
			foreach(smp; ht.maybe.attributes) {
				header ~= new TypeComplex(smp.name, smp.value.get!string(), root.location);
			}
		}

		string rtid = pt !is null ? pt.getTagAttribute!string("route", "tenantId", null) : null;
		string qtid = qt !is null ? qt.getTagAttribute!string("query", "tenantId", null) : null;
		string htid = ht !is null ? ht.getTagAttribute!string("header", "tenantId", null) : null;
		this.tenantIdParameter = qtid !is null ? qtid : htid !is null ? htid : rtid;

		auto bt = root.getTag("body", null);
		if (bt !is null) {
			foreach(smp; bt.maybe.attributes) {
				content ~= new TypeComplex(smp.name, smp.value.get!string(), root.location);
			}
			bodyForm = bt.getAttribute!bool("multipart:form", false);
			bodySubtype = bt.getAttribute!string("multipart:subtype", string.init);
			bodyBoundary = bt.getAttribute!string("multipart:boundary", string.init);
		}

		auto rt = root.getTag("return", null);
		if (rt !is null) {
			foreach(smp; rt.maybe.attributes) {
				returns ~= new TypeComplex(smp.name, smp.value.get!string(), root.location);
			}
			returnForm = rt.getAttribute!bool("multipart:form", false);
			returnSubtype = rt.getAttribute!string("multipart:subtype", string.init);
			returnBoundary = rt.getAttribute!string("multipart:boundary", string.init);
		}
		super(name, root.location);
	}

	public TypeComplex getRouteType(string name) {
		foreach(tc; route) {
			if (tc.name.toLower() == name.toLower()) return tc;
		}

		return null;
	}
}

public enum WebsocketServiceSystem {
	Raw,
	SignalR,
}

public final class WebsocketService : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Service; }

	public Namespace parent;
	public WebsocketServiceMethod[] server;
	public WebsocketServiceMethod[] client;
	public LanguageExtensionBase[] extensions;

	public WebsocketServiceSystem systemMode;
	public bool isPublic;
	public string route;
	public bool hasRoute() { return route != null && route != string.init; }
	public bool authenticate;

	public this(Namespace parent, Tag root) {
		this.parent = parent;
		this.name = root.expectValue!string();
		string mstr = root.getAttribute!string("system", "SignalR").toLower();
		this.systemMode = (mstr == "Raw".toLower() ? WebsocketServiceSystem.Raw : WebsocketServiceSystem.SignalR);
		this.isPublic = root.getAttribute!bool("public", true);
		this.route = root.getAttribute!string("route", string.init).strip().strip("/");
		this.authenticate = root.getAttribute!bool("authenticate", true);

		auto ancext = root.getTag("extensions:aspnetcore", null);
		if(ancext !is null) extensions ~= new AspNetCoreWebsocketExtension(this, ancext);

		foreach(sm; root.expectTag("server").tags) {
			server ~= new WebsocketServiceMethod(this, sm);
		}

		auto ct = root.getTag("client", null);
		if (ct !is null) {
			foreach(sm; ct.maybe.tags) {
				client ~= new WebsocketServiceMethod(this, sm);
			}
		}

		super(name, root.location);
	}
}

public final class WebsocketServiceMethod : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Service; }

	public WebsocketService parent;
	public bool hidden;

	public bool sync;
	public bool authenticate;

	public TypeComplex[] parameters;
	public TypeComplex[] returns;

	public LanguageExtensionBase[] extensions;

	public this(WebsocketService parent, Tag root) {
		this.parent = parent;
		this.name = root.name;
		this.hidden = root.getAttribute!bool("hidden", false);
		this.sync = root.getAttribute!bool("sync", false);
		this.authenticate = root.getAttribute!bool("authenticate", true);

		auto ancext = root.getTag("extensions:aspnetcore", null);
		if(ancext !is null) extensions ~= new AspNetCoreWebsocketMethodExtension(this, ancext);

		auto pt = root.getTag("parameters", null);
		if (pt !is null) {
			foreach(smp; pt.maybe.attributes) {
				parameters ~= new TypeComplex(smp.name, smp.value.get!string(), root.location);
			}
		}

		auto rt = root.getTag("return", null);
		if (rt !is null) {
			foreach(smp; rt.maybe.attributes) {
				returns ~= new TypeComplex(smp.name, smp.value.get!string(), root.location);
			}
		}

		super(name, root.location);
	}
}
