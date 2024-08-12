module coalescence.schema;

import coalescence.globals;
import coalescence.types;
import coalescence.stringbuilder;
import coalescence.utility;
import coalescence.database.utility;

// Extensions
import coalescence.languages.csharp.extensions;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.algorithm.sorting;
import std.array;
import std.conv;
import std.typecons;
import std.stdio;
import std.string;

import sdlang;

public enum SqlDbType {
	None = 0,
	BigInt,
	Binary,
	Bit,
	Char,
	Date,
	DateTime,
	DateTime2,
	DateTimeOffset,
	Decimal,
	Float,
	Image,
	Int,
	Money,
	NChar,
	NText,
	NVarChar,
	Real,
	SmallDateTime,
	SmallInt,
	SmallMoney,
	Structured,
	Text,
	Time,
	Timestamp,
	TinyInt,
	Udt,
	UniqueIdentifier,
	VarBinary,
	VarChar,
	Variant,
	Xml,
}

public bool isVariableLengthType(SqlDbType type)
{
	return type == SqlDbType.Binary || type == SqlDbType.VarBinary || type == SqlDbType.Char || type == SqlDbType.VarChar || type == SqlDbType.NChar || type == SqlDbType.NVarChar;
}

public bool isScalarType(SqlDbType type)
{
	return !(type == SqlDbType.Binary || type == SqlDbType.VarBinary || type == SqlDbType.Char || type == SqlDbType.VarChar || type == SqlDbType.NChar || type == SqlDbType.NVarChar || type == SqlDbType.Image || type == SqlDbType.Text || type == SqlDbType.NText || type == SqlDbType.Timestamp || type == SqlDbType.Variant);
}

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

public final class Project {
	public CSharpProjectOptions[] csharpOptions;

	public Schema[] serverSchema;
	public Schema[] clientSchema;

	public this(Tag root, Schema[] schemata, string databaseName, string projectRoot)
	{
		auto nn = root.maybe.namespaces["generators"];
		foreach(gt; nn.tags){
			if (gt.name.toUpper() == "csharp".toUpper()) {
				foreach (pt; gt.tags) {
					csharpOptions ~= new CSharpProjectOptions(pt, databaseName, projectRoot);
				}
			}
		}

		string[] del;
		auto ed = root.getTagValues("exclude:database");
		foreach(e; ed) {
			del ~= e.get!string();
		}

		string[] cel;
		auto ec = root.getTagValues("exclude:client");
		foreach(e; ec) {
			cel ~= e.get!string();
		}

		foreach(s; schemata) {
			if (del.length == 0) {
				serverSchema ~= s;
				if (cel.length == 0) {
					clientSchema ~= s;
				}
			}
			else if (!del.any!(a => a.toUpper() == s.name.toUpper())()) {
				serverSchema ~= s;
				if (cel.length == 0) {
					clientSchema ~= s;
				}
				else if (!cel.any!(b => b.toUpper() == s.name.toUpper())()) {
					clientSchema ~= s;
				}
			}
		}
	}

	public @property bool hasHttpServices() {
		return serverSchema.any!(a => a.services.length > 0)();
	}

	public @property bool hasSocketServices() {
		return serverSchema.any!(a => a.sockets.length > 0)();
	}

	public @property bool hasDatabaseItems() {
		return serverSchema.any!(a => a.hasDatabaseItems)();
	}
}

public final class Schema
{
	public int sqlId;
	public string name;
	public string sqlName;

	public Table[] getTables() {
		return tables.values.sort!((a, b) => a.name.toUpper() < b.name.toUpper()).array;
	}

	public View[] getViews() {
		return views.values.sort!((a, b) => a.name.toUpper() < b.name.toUpper()).array;
	}

	public Udt[] getUdts() {
		return udts.values.sort!((a, b) => a.name.toUpper() < b.name.toUpper()).array;
	}

	public Procedure[] getProcedures() {
		return procedures.values.sort!((a, b) => a.name.toUpper() < b.name.toUpper()).array;
	}

	public @property bool hasDatabaseItems() {
		return tables.length > 0 || views.length > 0 || udts.length > 0 || procedures.length > 0;
	}

	public Enumeration[string] enums;
	public Network[string] network;
	public Table[string] tables;
	public View[string] views;
	public Udt[string] udts;
	public Procedure[string] procedures;
	public HttpService[string] services;
	public WebsocketService[string] sockets;

	public this(int objectId, string name) {
		this.sqlId = objectId;
		this.name = this.sqlName = name;
	}

	public this(Tag root) {
		this.sqlId = -1;
		this.name = this.sqlName = root.expectValue!string();
		merge(root);
	}

	public void merge(Tag root) {
		foreach (t; root.maybe.tags) {
			if (t.name.toUpper() == "enum".toUpper()) {
				auto en = t.expectValue!string();
				if ((en in enums) != null) {
					writeParseError("Enumeration '" ~ en ~ "' alreadys exists in schema '" ~ name ~ "'", t.location);
				} else {
					enums[en] = new Enumeration(this, t);
				}
			}
			else if (t.name.toUpper() == "model".toUpper()) {
				auto mn = t.expectValue!string();
				if ((mn in network) != null) {
					writeParseError("Data Model '" ~ mn ~ "' alreadys exists in schema '" ~ name ~ "'", t.location);
				} else {
					network[mn] = new Network(this, t);
				}
			}
			else if (t.name.toUpper() == "database".toUpper()) {
				auto dn = t.expectValue!string();
				if ((dn in tables) is null && (dn in views) is null && (dn in udts) is null) {
					writeParseError("Unable to locate Database Model '" ~ dn ~ "' in schema '" ~ name ~ "'", t.location);
				} else {
					if ((dn in tables) !is null) {
						tables[dn].modifications = new Database(tables[dn], t);
					} else if ((dn in views) !is null) {
						views[dn].modifications = new Database(views[dn], t);
					} else if ((dn in udts) !is null) {
						udts[dn].modifications = new Database(udts[dn], t);
					}
				}
			}
			else if (t.name.toUpper() == "http".toUpper()) {
				auto sn = t.expectValue!string();
				if ((sn in services) != null) {
					writeParseError("HTTP Service '" ~ sn ~ "' alreadys exists in schema '" ~ name ~ "'", t.location);
				} else {
					services[sn] = new HttpService(this, t);
				}
			}
			else if (t.name.toUpper() == "websocket".toUpper()) {
				auto sn = t.expectValue!string();
				if ((sn in enums) != null) {
					writeParseError("WebSocket Service '" ~ sn ~ "' alreadys exists in schema '" ~ name ~ "'", t.location);
				} else {
					sockets[sn] = new WebsocketService(this, t);
				}
			}
			else {
				writeParseWarning("Found unrecognized tag '" ~ t.name ~ "'. Skipping.", t.location);
			}
		}

		enums.rehash();
		network.rehash();
		tables.rehash();
		views.rehash();
		udts.rehash();
		procedures.rehash();
		services.rehash();
		sockets.rehash();
	}
}

public final class Enumeration : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Enum; }
	public @property string fullName() { return parent.name ~ "." ~ name; }

	public Schema parent;
	public bool packed = false;
	public EnumerationValue[] values;

	public this(Schema parent, Tag root) {
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
	public bool isDefault;

	public this(Enumeration parent, Tag root) {
		this.parent = parent;
		this.name = root.name;
		this.isDefault = root.getAttribute("isDefaultValue", false);
		if (root.values.length == 1 && root.values[0].convertsTo!long()) {
			value = root.values[0].get!long();
		} else if (root.values.length >= 1 && root.values[0].convertsTo!string()) {
			foreach (v; root.values) {
				auto eva = new EnumerationValueAggregate();
				eva.parent = this;
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
	public EnumerationValue value;
}

public enum DataObjectType {
	Table,
	View,
	Udt,
	Network
}

public abstract class DataObject : TypeUser {
	public override @property TypeMode mode() { return TypeMode.Model; }

	public immutable DataObjectType objectType;
	public immutable int sqlId;
	public string sqlName;
	public Schema parent;
	public @property string fullName() { return join([parent.name, name], "."); }

	public DataMember[] members;

	public this(Schema parent, string name, Location loc) {
		this.objectType = DataObjectType.Network;
		this.parent = parent;
		this.sqlId = -1;
		super(name, loc);
	}

	public this(DataObjectType type, Schema parent, int objectId, string name) {
		this.objectType = type;
		this.parent = parent;
		this.sqlId = objectId;
		super(name, Location(-1, -1, -1));
	}
}

public abstract class DatabaseObject : DataObject
{
	public Database modifications;

	public this(DataObjectType type, Schema parent, int oid, string name)
	{
		super(type, parent, oid, name);
	}
}

public final class Table : DatabaseObject
{
	public Index[] indexes;
	public ForeignKey[] foreignKeys;

	public bool hasPrimaryKey() {
		foreach (t; indexes){
			if (t.isPrimaryKey) return true;
		}

		return false;
	}

	public this(Schema parent, int oid, string name)
	{
		super(DataObjectType.Table, parent, oid, name);
	}
}

public final class View : DatabaseObject
{
	public this(Schema parent, int oid, string name)
	{
		super(DataObjectType.View, parent, oid, name);
	}
}

public final class Udt : DatabaseObject
{
	public this(Schema parent, int oid, string name)
	{
		super(DataObjectType.Udt, parent, oid, name);
	}
}

public final class Network : DataObject
{
	public this(Schema parent, Tag root) {
		foreach (Tag t; root.tags) {
			members ~= new DataMember(this, t);
		}

		super(parent, root.expectValue!string(), root.location);
	}
}

public final class Database
{
	public DataObject parent;

	public string name;
	public string sourceName;

	public string[] databaseExclude;
	public string[] clientExclude;
	public string[string] renames;
	public TypeComplex[string] retypes;
	public DataMember[] additions;

	public this(DataObject parent, Tag root) {
		this.parent = parent;
		this.name = root.expectValue!string();
		this.sourceName = root.getAttribute!string("source", this.name);

		auto rl = root.getTag("rename");
		if (rl !is null) {
			foreach(r; rl.attributes) {
				renames[r.name] = r.value.get!string();
			}
		}

		auto tl = root.getTag("types");
		if (tl !is null) {
			foreach (t; tl.attributes) {
				retypes[t.name] = new TypeComplex(t.name, t.value.get!string(), t.location);
			}
		}

		string[] del;
		auto ed = root.getTag("exclude:database");
		if (ed !is null) {
			foreach(e; ed.values) {
				del ~= e.get!string();
			}
		}

		string[] cel;
		auto ec = root.getTag("exclude:client");
		if (ec !is null) {
			foreach(e; ec.values) {
				cel ~= e.get!string();
			}
		}

		databaseExclude = del;
		clientExclude = cel;

		auto al = root.getTag("additions");
		if (al !is null) {
			foreach (member; al.tags) {
				additions ~= new DataMember(parent, member);
			}
		}
	}
}

public final class DataMember
{
	public DataObject parent;
	public bool hidden;

	public string name;
	public TypeComplex type = null;
	public string transport;
	public bool enumAsString = false;

	public int sqlId;
	public string sqlName;
	public SqlDbType sqlType;

	public bool isNullable;
	public bool hasDefault;
	public int maxLength;
	public byte precision;
	public byte scale;
	public bool isIdentity;
	public bool isComputed;
	public bool isReadOnly;

	public bool isTypeEnum() { return typeid(type.type) == typeid(TypeEnum); }

	public this(DataObject parent, int id, string name, SqlDbType type, int maxLength, byte precision, byte scale, bool hasDefault, bool isNullable, bool isIdentity, bool isComputed)
	{
		this.parent = parent;
		this.sqlId = id;
		this.transport = this.name = this.sqlName = name;
		this.sqlType = type;
		this.maxLength = maxLength;
		if (type == SqlDbType.Decimal || type == SqlDbType.Float)
		{
			this.precision = precision;
			this.scale = scale;
		}
		if (type == SqlDbType.DateTime2 || type == SqlDbType.DateTimeOffset || type == SqlDbType.Time)
		{
			this.precision = scale;
		}
		this.hasDefault = hasDefault;
		this.isNullable = isNullable;
		this.isIdentity = isIdentity;
		this.isComputed = isComputed;
		this.isReadOnly = isComputed || isIdentity;
		this.type = getTypeComplexFromSqlDbType(this.sqlType, this.isNullable, this.name);
	}

	public this (DataObject parent, Tag root) {
		this.parent = parent;
		this.sqlId = -1;
		this.name = this.sqlName = root.name();
		this.transport = root.getAttribute!string("transport", this.name);
		this.type = new TypeComplex(this.name, root.expectAttribute!string("type"), root.location);
		this.enumAsString = root.getAttribute!bool("enumString", false);
		this.sqlType = SqlDbType.None;
		this.maxLength = root.getAttribute!int("maxLength", -1);
		this.precision = -1;
		this.scale = -1;
		this.isComputed = false;
		this.isIdentity = false;
		this.isReadOnly = root.getAttribute!bool("readonly", false);
		this.isNullable = this.type.nullable;
	}

	public this(DataMember copy) {
		this.parent = copy.parent;
		this.hidden = copy.hidden;

		this.name = copy.name;
		this.type = copy.type;
		this.transport = copy.transport;
		this.enumAsString = copy.enumAsString;

		this.sqlId = copy.sqlId;
		this.sqlName = copy.sqlName;
		this.sqlType = copy.sqlType;

		this.isNullable = copy.isNullable;
		this.hasDefault = copy.hasDefault;
		this.maxLength = copy.maxLength;
		this.precision = copy.precision;
		this.scale = copy.scale;
		this.isIdentity = copy.isIdentity;
		this.isComputed = copy.isComputed;
		this.isReadOnly = copy.isReadOnly;
	}
}

public class Index
{
	public string name;
	public bool isUnique;
	public bool isPrimaryKey;

	public DataMember[] columns;

	public this(string name, bool isUnique, bool isPrimaryKey)
	{
		this.name = name;
		this.isUnique = isUnique;
		this.isPrimaryKey = isPrimaryKey;
	}
}

public enum ForeignKeyAction
{
	NoAction,
	Cascade,
	SetNull,
	SetDefault
}

public enum ForeignKeyDirection
{
	OneToOne,
	OneToMany,
	ManyToMany
}

public class ForeignKey
{
	private int sourceColumnId;

	public string name;
	public string sqlName;
	public Table sourceTable;
	public Table targetTable;
	private DataMember sourceColumn() {
		return sourceTable.members.filter!(a => a.sqlId == sourceColumnId).array[0];
	}
	public ForeignKeyDirection direction;
	public ForeignKeyAction onUpdate;
	public ForeignKeyAction onDelete;
	public DataMember[] source;

	public this(string name, Table source, Table target, int sourceColumnId, ForeignKeyDirection direction, byte onUpdate, byte onDelete)
	{
		this.sourceColumnId = sourceColumnId;

		this.name = this.sqlName = name;
		this.sourceTable = source;
		this.targetTable = target;
		this.direction = direction;
		this.onUpdate = cast(ForeignKeyAction)onUpdate;
		this.onDelete = cast(ForeignKeyAction)onDelete;
	}

	public string targetId() {
		if (sourceTable.sqlId != targetTable.sqlId) {
			return cleanForeignKeyName(sourceColumn().name) ~ "_" ~ sourceTable.parent.name.uppercaseFirst() ~ sourceTable.name;
		} else {
			return cleanForeignKeyName(sourceColumn().name) ~ "_" ~ sourceTable.parent.name.uppercaseFirst() ~ sourceTable.name ~ "_Self";
		}
	}

	public string sourceId() {
		if (sourceTable.sqlId != targetTable.sqlId) {
			return cleanForeignKeyName(sourceColumn().name) ~ "_" ~ targetTable.parent.name.uppercaseFirst() ~ targetTable.name;
		} else {
			return cleanForeignKeyName(sourceColumn().name) ~ "_" ~ targetTable.parent.name.uppercaseFirst() ~ targetTable.name ~ "_Navigation";
		}
	}
}

public class Procedure
{
	public Schema parent;
	public int sqlId;
	public string name;
	public string sqlName;

	public Parameter[] parameters;

	public this(Schema parent, int sqlId, string name)
	{
		this.parent = parent;
		this.sqlId = sqlId;
		this.name = name;
		this.sqlName = name;
	}
}

public enum ParameterDirection {
	Input,
	InputOutput,
	Output,
	ReturnValue,
}

public class Parameter
{
	public string name;
	public ParameterDirection direction;
	public SqlDbType type;
	public int typeId;
	public Udt udtType;
	public bool isNullable;
	public short maxLength;
	public byte precision;
	public byte scale;
	public bool isReadOnly;

	public this(string name, ParameterDirection direction, int typeId, SqlDbType dataType, Udt udt, short maxLen, byte precision, byte scale, bool isReadOnly)
	{
		this.name = name.isNullOrEmpty() ? "ReturnValue" : name;
		this.direction = direction;
		this.type = dataType;
		this.udtType = udt;
		this.typeId = typeId;
		this.isNullable = true;
		this.maxLength = maxLen;
		this.precision = precision;
		this.scale = scale;
		this.isReadOnly = isReadOnly;
	}
}

public final class HttpService : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Service; }

	public Schema parent;
	public HttpServiceMethod[] methods;
	public LanguageExtensionBase[] extensions;

	public bool isPublic;
	public string[] route;
	public bool hasRoute() { return route.length > 0; }
	public bool authenticate;
	public string scheme;
	public string requestName;
	public string requestParameterId;

	public this(Schema parent, Tag root) {
		this.parent = parent;
		this.name = root.expectValue!string();
		this.isPublic = root.getAttribute!bool("public", true);
		this.route = root.getAttribute!string("route", string.init).strip().strip("/").split("/").array;
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

	public bool hasRoute() { return routeParts.length > 0; }
	public bool authenticate;
	public string scheme;
	public uint timeout;
	public bool noThrow;
	public bool retry;

	public HttpServiceMethodVerb verb;
	public string[] routeParts;
	public TypeComplex[] route;
	public TypeComplex[] query;
	public bool queryAsParams;
	public TypeComplex[] header;
	public TypeComplex[] content;
	public TypeComplex[] returns;

	public string requestEncoding;
	public string responseEncoding;

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
		this.noThrow = root.getAttribute!bool("noThrow", true);
		this.retry = root.getAttribute!bool("retry", true);
		this.requestEncoding = root.getAttribute!string("requestEncoding", string.init);
		this.responseEncoding = root.getAttribute!string("responseEncoding", string.init);

		auto ancext = root.getTag("extensions:aspnetcore", null);
		if(ancext !is null) extensions ~= new AspNetCoreHttpMethodExtension(this, ancext);

		string verb = root.name;
		if (verb.toUpper() == "get".toUpper()) this.verb = HttpServiceMethodVerb.Get;
		else if (verb.toUpper() == "head".toUpper()) this.verb = HttpServiceMethodVerb.Head;
		else if (verb.toUpper() == "put".toUpper()) this.verb = HttpServiceMethodVerb.Put;
		else if (verb.toUpper() == "post".toUpper()) this.verb = HttpServiceMethodVerb.Post;
		else if (verb.toUpper() == "delete".toUpper()) this.verb = HttpServiceMethodVerb.Delete;
		else if (verb.toUpper() == "patch".toUpper()) this.verb = HttpServiceMethodVerb.Patch;
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
			this.queryAsParams = qt.getAttribute!bool("asParams", true);
			foreach(smp; qt.maybe.attributes) {
				if (smp.name == "asParams") continue;
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
			if (tc.name.toUpper() == name.toUpper()) return tc;
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

	public Schema parent;
	public WebsocketServiceNamespace[] namespaces;
	public LanguageExtensionBase[] extensions;

	public WebsocketServiceSystem systemMode;
	public bool isPublic;
	public bool authenticate;

	public this(Schema parent, Tag root) {
		this.parent = parent;
		this.name = root.expectValue!string();
		string mstr = root.getAttribute!string("system", "SignalR").toUpper();
		this.systemMode = (mstr == "Raw".toUpper() ? WebsocketServiceSystem.Raw : WebsocketServiceSystem.SignalR);
		this.isPublic = root.getAttribute!bool("public", true);
		this.authenticate = root.getAttribute!bool("authenticate", true);

		auto ancext = root.getTag("extensions:aspnetcore", null);
		if(ancext !is null) extensions ~= new AspNetCoreWebsocketExtension(this, ancext);

		foreach(ns; root.tags) {
			if (ns.name == "namespace") {
				string namespace = ns.expectValue!string();
				WebsocketServiceMethod[] nssml;
				auto nst = ns.getTag("server", null);
				if (nst !is null) {
					foreach(sm; nst.maybe.tags) {
						nssml ~= new WebsocketServiceMethod(this, sm);
					}
				}

				WebsocketServiceMethod[] ncsml;
				auto nct = ns.getTag("client", null);
				if (nct !is null) {
					foreach(sm; nct.maybe.tags) {
						ncsml ~= new WebsocketServiceMethod(this, sm);
					}
				}

				namespaces ~= new WebsocketServiceNamespace(namespace, nssml, ncsml);
			}
		}

		WebsocketServiceMethod[] ssml;
		auto st = root.getTag("server", null);
		if (st !is null) {
			foreach(sm; st.maybe.tags) {
				ssml ~= new WebsocketServiceMethod(this, sm);
			}
		}

		WebsocketServiceMethod[] csml;
		auto ct = root.getTag("client", null);
		if (ct !is null) {
			foreach(sm; ct.maybe.tags) {
				csml ~= new WebsocketServiceMethod(this, sm);
			}
		}

		namespaces ~= new WebsocketServiceNamespace(string.init, ssml, csml);

		super(name, root.location);
	}

	public bool hasClient() {
		ulong count = 0;
		foreach(ns; namespaces) {
			count += ns.client.length;
		}
		return count != 0;
	}
}

public final class WebsocketServiceNamespace {
	public string name;
	public WebsocketServiceMethod[] server;
	public WebsocketServiceMethod[] client;

	public this(string namespace, WebsocketServiceMethod[] server, WebsocketServiceMethod[] client) {
		this.name = namespace;
		this.server = server;
		this.client = client;
	}
}

public final class WebsocketServiceMethod : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Service; }

	public WebsocketService parent;
	public string socketName;
	public bool hidden;

	public bool sync;
	public bool authenticate;

	public TypeComplex[] parameters;
	public TypeComplex[] returns;

	public LanguageExtensionBase[] extensions;

	public this(WebsocketService parent, Tag root) {
		this.parent = parent;
		this.name = root.name;
		this.socketName = root.name;
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
