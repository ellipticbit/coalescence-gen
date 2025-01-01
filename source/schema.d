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

import sdlite;

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

	public this(SDLNode root, Schema[] schemata, string databaseName, string projectRoot)
	{
		auto nn = root.getNodes("generators");
		foreach(gt; nn){
			if (gt.name.toUpper() == "csharp".toUpper()) {
				foreach (pt; gt.children) {
					csharpOptions ~= new CSharpProjectOptions(pt, databaseName, projectRoot);
				}
			}
		}

		string[] del;
		auto ed = root.getNodeValues("exclude:database");
		foreach(e; ed) {
			del ~= e.value!string();
		}

		string[] cel;
		auto ec = root.getNodeValues("exclude:client");
		foreach(e; ec) {
			cel ~= e.value!string();
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

	public this(SDLNode root) {
		this.sqlId = -1;
		this.name = this.sqlName = root.expectValue!string(0);
		merge(root);
	}

	public void merge(SDLNode root) {
		foreach (t; root.children) {
			if (t.name.toUpper() == "enum".toUpper()) {
				auto en = t.expectValue!string(0);
				if ((en in enums) != null) {
					writeParseError("Enumeration '" ~ en ~ "' alreadys exists in schema '" ~ name ~ "'", t.location);
				} else {
					enums[en] = new Enumeration(this, t);
				}
			}
			else if (t.name.toUpper() == "model".toUpper()) {
				auto mn = t.expectValue!string(0);
				if ((mn in network) != null) {
					writeParseError("Data Model '" ~ mn ~ "' alreadys exists in schema '" ~ name ~ "'", t.location);
				} else {
					network[mn] = new Network(this, t);
				}
			}
			else if (t.name.toUpper() == "database".toUpper()) {
				auto dn = t.expectValue!string(0);
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
				auto sn = t.expectValue!string(0);
				if ((sn in services) != null) {
					writeParseError("HTTP Service '" ~ sn ~ "' alreadys exists in schema '" ~ name ~ "'", t.location);
				} else {
					services[sn] = new HttpService(this, t);
				}
			}
			else if (t.name.toUpper() == "websocket".toUpper()) {
				auto sn = t.expectValue!string(0);
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

	public this(Schema parent, SDLNode root) {
		this.parent = parent;
		this.name = root.expectValue!string(0);
		this.packed = root.getAttributeValue!bool("packed", false);

		foreach (t; root.children) {
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

	public this(Enumeration parent, SDLNode root) {
		this.parent = parent;
		this.name = root.name;
		this.isDefault = root.getAttributeValue!bool("isDefaultValue", false);
		if (root.values.length == 1 && root.values[0].kind == SDLValue.Kind.long_) {
			value = root.values[0].value!long();
		} else if (root.values.length == 1 && root.values[0].kind == SDLValue.Kind.int_) {
			value = root.values[0].value!int();
		} else if (root.values.length >= 1 && root.values[0].kind == SDLValue.Kind.text) {
			foreach (v; root.values) {
				auto eva = new EnumerationValueAggregate();
				eva.parent = this;
				eva.aggregateLabel = v.value!string();
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
		super(name, Location(string.init, -1, -1, -1));
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
	public this(Schema parent, SDLNode root) {
		foreach (t; root.children) {
			members ~= new DataMember(this, t);
		}

		super(parent, root.expectValue!string(0), root.location);
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

	public this(DataObject parent, SDLNode root) {
		this.parent = parent;
		this.name = root.expectValue!string(0);
		this.sourceName = root.getAttributeValue!string("source", this.name);

		auto rl = root.getNode("rename");
		if (!rl.isNull) {
			foreach(r; rl.get().children) {
				renames[r.name] = r.expectValue!string(0);
			}
		}

		auto tl = root.getNode("types");
		if (!tl.isNull) {
			foreach (t; tl.get().children) {
				retypes[t.name] = new TypeComplex(t.name, t.expectValue!string(0), t.location);
			}
		}

		string[] del;
		auto ed = root.getNode("exclude:database");
		if (!ed.isNull) {
			foreach(e; ed.get().values) {
				del ~= e.value!string();
			}
		}

		string[] cel;
		auto ec = root.getNode("exclude:client");
		if (!ec.isNull) {
			foreach(e; ec.get().values) {
				cel ~= e.value!string();
			}
		}

		databaseExclude = del;
		clientExclude = cel;

		auto al = root.getNode("additions");
		if (!al.isNull) {
			foreach (member; al.get().children) {
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
	public string transportshort;
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
		this.name = this.sqlName = name;
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

	public this (DataObject parent, SDLNode root) {
		this.parent = parent;
		this.sqlId = -1;
		this.name = this.sqlName = root.name();
		this.transport = root.getAttributeValue!string("transport", string.init);
		this.type = new TypeComplex(this.name, root.expectAttributeValue!string("type"), root.location);
		this.enumAsString = root.getAttributeValue!bool("enumString", false);
		this.sqlType = SqlDbType.None;
		this.maxLength = root.getAttributeValue!int("maxLength", -1);
		this.precision = -1;
		this.scale = -1;
		this.isComputed = false;
		this.isIdentity = false;
		this.isReadOnly = root.getAttributeValue!bool("readonly", false);
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

	public this(Schema parent, SDLNode root) {
		this.parent = parent;
		this.name = root.expectValue!string(0);
		this.isPublic = root.getAttributeValue!bool("public", true);
		this.route = root.getAttributeValue!string("route", string.init).strip().strip("/").split("/").array;
		this.authenticate = root.getAttributeValue!bool("authenticate", true);
		this.scheme = root.getAttributeValue!string("scheme", string.init);
		this.requestName = root.getAttributeValue!string("requestName", null);
		this.requestParameterId = root.getAttributeValue!string("requestParameterId", null);

		auto ancext = root.getNode("extensions:aspnetcore");
		if (!ancext.isNull) extensions ~= new AspNetCoreHttpExtension(this, ancext.get());

		foreach(sm; root.children) {
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

	public this(HttpService parent, SDLNode root) {
		this.parent = parent;
		this.name = root.expectValue!string(0);
		this.hidden = root.getAttributeValue!bool("hidden", false);
		this.authenticate = root.getAttributeValue!bool("authenticate", true);
		this.scheme = root.getAttributeValue!string("scheme", string.init);
		this.timeout = root.getAttributeValue!int("timeout", 0);
		this.noThrow = root.getAttributeValue!bool("noThrow", true);
		this.retry = root.getAttributeValue!bool("retry", true);
		this.requestEncoding = root.getAttributeValue!string("requestEncoding", string.init);
		this.responseEncoding = root.getAttributeValue!string("responseEncoding", string.init);

		auto ancext = root.getNode("extensions:aspnetcore");
		if (!ancext.isNull) extensions ~= new AspNetCoreHttpMethodExtension(this, ancext.get());

		string verb = root.name;
		if (verb.toUpper() == "get".toUpper()) this.verb = HttpServiceMethodVerb.Get;
		else if (verb.toUpper() == "head".toUpper()) this.verb = HttpServiceMethodVerb.Head;
		else if (verb.toUpper() == "put".toUpper()) this.verb = HttpServiceMethodVerb.Put;
		else if (verb.toUpper() == "post".toUpper()) this.verb = HttpServiceMethodVerb.Post;
		else if (verb.toUpper() == "delete".toUpper()) this.verb = HttpServiceMethodVerb.Delete;
		else if (verb.toUpper() == "patch".toUpper()) this.verb = HttpServiceMethodVerb.Patch;
		else writeParseError("Unexpected method verb: " ~ verb, root.location);

		auto ptn = root.getNode("route");
		if (!ptn.isNull) {
			auto pt = ptn.get();
			foreach(smp; pt.attributes) {
				route ~= new TypeComplex(smp.name, smp.value.value!string(), root.location);
			}
			if (pt.values.length == 1) {
				routeParts ~= pt.values[0].value!string().strip().strip("/").split("/");
			} else if (pt.values.length > 1) {
				foreach(rv; pt.values) {
					routeParts ~= rv.value!string().strip().strip("/").split("/");
				}
			}
		}

		auto qtn = root.getNode("query");
		if (!qtn.isNull) {
			auto qt = qtn.get();
			this.queryAsParams = qt.getAttributeValue!bool("asParams", true);
			foreach(smp; qt.attributes) {
				if (smp.name == "asParams") continue;
				query ~= new TypeComplex(smp.name, smp.value.value!string(), root.location);
			}
		}

		auto htn = root.getNode("header");
		if (!htn.isNull) {
			foreach(smp; htn.get().attributes) {
				header ~= new TypeComplex(smp.name, smp.value.value!string(), root.location);
			}
		}

		string rtid = !ptn.isNull ? ptn.get().getNodeAttributeValue!string("route", "tenantId", null) : null;
		string qtid = !qtn.isNull ? qtn.get().getNodeAttributeValue!string("query", "tenantId", null) : null;
		string htid = !htn.isNull ? htn.get().getNodeAttributeValue!string("header", "tenantId", null) : null;
		this.tenantIdParameter = qtid !is null ? qtid : htid !is null ? htid : rtid;

		auto btn = root.getNode("body");
		if (!btn.isNull) {
			auto bt = btn.get();
			foreach(smp; bt.attributes) {
				content ~= new TypeComplex(smp.name, smp.value.value!string(), root.location);
			}
			bodyForm = bt.getAttributeValue!bool("multipart:form", false);
			bodySubtype = bt.getAttributeValue!string("multipart:subtype", string.init);
			bodyBoundary = bt.getAttributeValue!string("multipart:boundary", string.init);
		}

		auto rtn = root.getNode("return");
		if (!rtn.isNull) {
			auto rt = rtn.get();
			foreach(smp; rt.attributes) {
				returns ~= new TypeComplex(smp.name, smp.value.value!string(), root.location);
			}
			returnForm = rt.getAttributeValue!bool("multipart:form", false);
			returnSubtype = rt.getAttributeValue!string("multipart:subtype", string.init);
			returnBoundary = rt.getAttributeValue!string("multipart:boundary", string.init);
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

	public this(Schema parent, SDLNode root) {
		this.parent = parent;
		this.name = root.expectValue!string(0);
		string mstr = root.getAttributeValue!string("system", "SignalR").toUpper();
		this.systemMode = (mstr == "Raw".toUpper() ? WebsocketServiceSystem.Raw : WebsocketServiceSystem.SignalR);
		this.isPublic = root.getAttributeValue!bool("public", true);
		this.authenticate = root.getAttributeValue!bool("authenticate", true);

		auto ancext = root.getNode("extensions:aspnetcore");
		if (!ancext.isNull) extensions ~= new AspNetCoreWebsocketExtension(this, ancext.get());

		foreach(ns; root.children) {
			if (ns.name == "namespace") {
				string namespace = ns.expectValue!string(0);
				WebsocketServiceMethod[] nssml;
				auto nst = ns.getNode("server");
				if (!nst.isNull) {
					foreach(sm; nst.get().children) {
						nssml ~= new WebsocketServiceMethod(this, sm);
					}
				}

				WebsocketServiceMethod[] ncsml;
				auto nct = ns.getNode("client");
				if (!nct.isNull) {
					foreach(sm; nct.get().children) {
						ncsml ~= new WebsocketServiceMethod(this, sm);
					}
				}

				namespaces ~= new WebsocketServiceNamespace(namespace, nssml, ncsml);
			}
		}

		WebsocketServiceMethod[] ssml;
		auto st = root.getNode("server");
		if (!st.isNull) {
			foreach(sm; st.get().children) {
				ssml ~= new WebsocketServiceMethod(this, sm);
			}
		}

		WebsocketServiceMethod[] csml;
		auto ct = root.getNode("client");
		if (!ct.isNull) {
			foreach(sm; ct.get().children) {
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

	public this(WebsocketService parent, SDLNode root) {
		this.parent = parent;
		this.name = root.name;
		this.socketName = root.name;
		this.hidden = root.getAttributeValue!bool("hidden", false);
		this.sync = root.getAttributeValue!bool("sync", false);
		this.authenticate = root.getAttributeValue!bool("authenticate", true);

		auto ancext = root.getNode("extensions:aspnetcore");
		if (!ancext.isNull) extensions ~= new AspNetCoreWebsocketMethodExtension(this, ancext.get());

		auto pt = root.getNode("parameters");
		if (!pt.isNull) {
			foreach(smp; pt.get().attributes) {
				parameters ~= new TypeComplex(smp.name, smp.value.value!string(), root.location);
			}
		}

		auto rt = root.getNode("return");
		if (!rt.isNull) {
			foreach(smp; rt.get().attributes) {
				returns ~= new TypeComplex(smp.name, smp.value.value!string(), root.location);
			}
		}

		super(name, root.location);
	}
}
