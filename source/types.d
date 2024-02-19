module coalescence.types;
import coalescence.schema;
import coalescence.globals;
import coalescence.generator;

import sdlang;

import std.algorithm.searching;
import std.string;
import std.stdio;

public TypePrimitives getTypePrimitive(TypeBase type) {
	if (typeid(type) == typeid(TypePrimitive)) {
		return (cast(TypePrimitive)type).primitive;
	}

	return TypePrimitives.None;
}

public enum TypeMode
{
	Unknown,
	Complex,
	Enum,
	Model,
	Service,
	Void,
	Primitive,
	ByteArray,
	Collection,
	Dictionary,
	Content,
	Stream,
	FormUrlEncoded,
}

public enum TypePrimitives
{
	None,
	Boolean,
	Int8,
	UInt8,
	Int16,
	UInt16,
	Int32,
	UInt32,
	Int64,
	UInt64,
	Float,
	Double,
	Fixed,
	String,
	Base64ByteArray,
	Base64String,
	DateTime,
	DateTimeTz,
	TimeSpan,
	Guid,
}

public abstract class TypeBase
{
	public abstract @property TypeMode mode();
}

public abstract class TypeUser : TypeBase
{
	private string _name;
	public final @property string name() { return _name; }
	protected final @property string name(string value) { return _name = value; }

	private Location _sourceLocation;
	public final @property Location sourceLocation() { return _sourceLocation; }

	public this() { }

	public this(string name, Location loc) {
		this._name = name;
		this._sourceLocation = loc;
	}
}

public final class TypeUnknown : TypeBase {
	public override @property TypeMode mode() { return TypeMode.Unknown; }

	private string _typeName;
	public @property string typeName() { return _typeName; }

	private Location _sourceLocation;
	public final @property Location sourceLocation() { return _sourceLocation; }

	public this(string typeName, Location sourceLocation) {
		this._typeName = typeName;
		this._sourceLocation = sourceLocation;
	}
}

public final class TypeEnum : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Enum; }
	public @property TypePrimitives primitive() { return TypePrimitives.Int64; }

	private Enumeration _definition;
	public @property Enumeration definition() { return _definition; }
	public @property Enumeration definition(Enumeration value) { return _definition = value; }

	public this(Location loc) {
		super(string.init, loc);
		this._definition = null;
	}

	public this(Enumeration refType, Location loc)
	{
		super(refType.name, loc);
		_definition = refType;
		this.name = refType.fullName;
	}
}

public final class TypeModel : TypeUser
{
	public override @property TypeMode mode() { return TypeMode.Model; }

	private DataObject _definition;
	public @property DataObject definition() { return _definition; }
	public @property DataObject definition(DataObject value) { return _definition = value; }

	public this(Location loc) {
		super(string.init, loc);
		this._definition = null;
	}

	public this(DataObject refType, Location loc)
	{
		super(refType.name, loc);
		_definition = refType;
		super.name = refType.fullName;
	}
}

public final class TypePrimitive : TypeBase {
	public override @property TypeMode mode() { return TypeMode.Primitive; }
	private TypePrimitives _primitive;
	public @property TypePrimitives primitive() { return _primitive; }

	public this(TypePrimitives primitive) {
		_primitive = primitive;
	}
}

public final class TypeVoid : TypeBase
{
	public override @property TypeMode mode() { return TypeMode.Void; }
}

public final class TypeByteArray : TypeBase
{
	public override @property TypeMode mode() { return TypeMode.ByteArray; }
}

public final class TypeStream : TypeBase
{
	public override @property TypeMode mode() { return TypeMode.Stream; }
}

public final class TypeContent : TypeBase
{
	public override @property TypeMode mode() { return TypeMode.Content; }
}

public final class TypeFormUrlEncoded : TypeBase
{
	public override @property TypeMode mode() { return TypeMode.FormUrlEncoded; }
}

public final class TypeCollection : TypeBase
{
	public override @property TypeMode mode() { return TypeMode.Collection; }

	private TypeComplex _collectionType;
	public @property TypeComplex collectionType() { return _collectionType; }
	public @property TypeComplex collectionType(TypeComplex value) { return _collectionType = value;}

	public this(TypeComplex collectionType) {
		this._collectionType = collectionType;
	}
}

public final class TypeDictionary : TypeBase
{
	public override @property TypeMode mode() { return TypeMode.Dictionary; }

	private TypeComplex _keyType;
	public @property TypeComplex keyType() { return _keyType; }
	public @property TypeComplex keyType(TypeComplex value) { return _keyType = value;}

	private TypeComplex _valueType;
	public @property TypeComplex valueType() { return _valueType; }
	public @property TypeComplex valueType(TypeComplex value) { return _valueType = value;}

	public this(TypeComplex keyType, TypeComplex valueType) {
		this._keyType = keyType;
		this._valueType = valueType;
	}
}

public final class TypeComplex : TypeBase {
	public override @property TypeMode mode() { return TypeMode.Complex; }

	private Location _sourceLocation;
	public final @property Location sourceLocation() { return _sourceLocation; }

	private TypeBase _type;
	public @property TypeBase type() { return _type; }
	public @property TypeBase type(TypeBase value) { return _type = value;}

	private string _name = string.init;
	public @property string name() { return _name; }

	private bool _nullable = false;
	public @property bool nullable() { return _nullable; }

	private bool _defaultInit = false;
	public @property bool defaultInit() { return _defaultInit; }

	private bool _defaultNull = false;
	public @property bool defaultNull() { return _defaultNull; }

	private string _defaultValue = null;
	public @property string defaultValue() { return _defaultValue; }

	public @property bool hasDefault() { return _defaultInit || _defaultNull || _defaultValue !is null; }

	// Test Cases
	// [[(datetimetz, (int, TestModel))]]=init
	// test [TestModel]=init
	// test datetimetz?=null
	// bytearray [unit8]=null
	public this (string name, string typeStr, Location location) {
		_name = name;
		_sourceLocation = location;

		void ProcessOptions(string typeDef, bool isNullable, bool allowValues) {
			if (typeDef == string.init) return;

			_nullable = isNullable || typeDef.canFind('?');
			if (!(isNullable || _nullable) && typeDef.canFind("=null") && typeid(_type) != typeid(TypeUnknown)) {
				writeParseError("Null default value specified on non-nullable type. The null default value specifier will be ignored", location);
			} else {
				_defaultNull = typeDef.canFind("=null");
			}
			_defaultInit = typeDef.canFind("=init");

			if (allowValues) {
				if (typeDef.canFind("='")) {
					string split = findSplitAfter(typeDef, "='")[1];
					_defaultValue = split[0..lastIndexOf(split, '\'')];
				} else if (typeDef.canFind("=")) {
					_defaultValue = findSplitAfter(typeDef, "=")[1];
				} else {
					if (typeDef.canFind("=")) writeParseWarning("Invalid default value specified. No default value will be set.", location);
				}
			}
		}

		if (typeStr.toLower().startsWith("void".toLower())) {
			_type = new TypeVoid();
			_nullable = false;
		}
		else if (typeStr[0] == '[') {
			_nullable = true;

			long closeIdx = lastIndexOf(typeStr, ']');
			TypeComplex collectionType = new TypeComplex(name, typeStr[1..closeIdx], location);
			if (collectionType.type.mode == TypeMode.Primitive && (cast(TypePrimitive)collectionType.type).primitive == TypePrimitives.UInt8) {
				_type = new TypeByteArray();
			} else {
				_type = new TypeCollection(collectionType);
			}

			ProcessOptions(typeStr[closeIdx+1..$], true, false);
			return;
		}
		else if (typeStr[0] == '(') {
			_nullable = true;

			long closeIdx = lastIndexOf(typeStr, ')');
			string ktStr = typeStr[1..closeIdx];

			if (ktStr[0] == '<' || ktStr[0] == '(') {
				writeParseError("Invalid Dictionary key type '" ~ ktStr[0..indexOf(ktStr, ',')] ~ "' specified. Dictionary key must be a Primitive type.", location);
				return;
			}

			TypeComplex keyType = new TypeComplex(name, ktStr[0..indexOf(ktStr, ',')], location);
			if (keyType.type.mode != TypeMode.Primitive) {
				writeParseError("Invalid Dictionary key type '" ~ ktStr[0..indexOf(ktStr, ',')] ~ "' specified. Dictionary key must be a Primitive type.", location);
				return;
			}

			TypeComplex valueType = new TypeComplex(name, ktStr[indexOf(ktStr, ',')+1..$], location);

			if ((cast(TypePrimitive)keyType.type).primitive == TypePrimitives.String &&
				typeid(valueType.type) == typeid(TypePrimitive) &&
				(cast(TypePrimitive)valueType.type).primitive == TypePrimitives.String) {
				type = new TypeFormUrlEncoded();
			} else {
				_type = new TypeDictionary(keyType, valueType);
			}

			ProcessOptions(typeStr[closeIdx..$], true, false);
			return;
		}
		else if (typeStr.toLower().startsWith("stream".toLower())) {
			_type = new TypeStream();
			_nullable = true;
		}
		else if (typeStr.toLower().startsWith("content".toLower())) {
			_type = new TypeContent();
			_nullable = true;
		}
		else if (typeStr.toLower().startsWith("bool".toLower())) _type = new TypePrimitive(TypePrimitives.Boolean);
		else if (typeStr.toLower().startsWith("uint8".toLower())) _type = new TypePrimitive(TypePrimitives.UInt8);
		else if (typeStr.toLower().startsWith("int8".toLower())) _type = new TypePrimitive(TypePrimitives.Int8);
		else if (typeStr.toLower().startsWith("uint16".toLower())) _type = new TypePrimitive(TypePrimitives.UInt16);
		else if (typeStr.toLower().startsWith("int16".toLower())) _type = new TypePrimitive(TypePrimitives.Int16);
		else if (typeStr.toLower().startsWith("uint32".toLower())) _type = new TypePrimitive(TypePrimitives.UInt32);
		else if (typeStr.toLower().startsWith("int32".toLower())) _type = new TypePrimitive(TypePrimitives.Int32);
		else if (typeStr.toLower().startsWith("uint64".toLower())) _type = new TypePrimitive(TypePrimitives.UInt64);
		else if (typeStr.toLower().startsWith("int64".toLower())) _type = new TypePrimitive(TypePrimitives.Int64);
		else if (typeStr.toLower().startsWith("float".toLower())) _type = new TypePrimitive(TypePrimitives.Float);
		else if (typeStr.toLower().startsWith("double".toLower())) _type = new TypePrimitive(TypePrimitives.Double);
		else if (typeStr.toLower().startsWith("fixed".toLower())) _type = new TypePrimitive(TypePrimitives.Fixed);
		else if (typeStr.toLower().startsWith("string".toLower())) {
			_type = new TypePrimitive(TypePrimitives.String);
			_nullable = true;
		}
		else if (typeStr.toLower().startsWith("array64".toLower())) {
			_type = new TypePrimitive(TypePrimitives.Base64ByteArray);
			_nullable = true;
		}
		else if (typeStr.toLower().startsWith("string64".toLower())) {
			_type = new TypePrimitive(TypePrimitives.Base64String);
			_nullable = true;
		}
		else if (typeStr.toLower().startsWith("datetime".toLower())) _type = new TypePrimitive(TypePrimitives.DateTime);
		else if (typeStr.toLower().startsWith("datetimetz".toLower())) _type = new TypePrimitive(TypePrimitives.DateTimeTz);
		else if (typeStr.toLower().startsWith("timespan".toLower())) _type = new TypePrimitive(TypePrimitives.TimeSpan);
		else if (typeStr.toLower().startsWith("guid".toLower())) _type = new TypePrimitive(TypePrimitives.Guid);
		else {
			string tstr = typeStr;
			if (tstr.canFind('?')) tstr = tstr.findSplitBefore("?")[0];
			if (tstr.canFind('=')) tstr = tstr.findSplitBefore("=")[0];
			_type = new TypeUnknown(tstr, location);
		}

		ProcessOptions(typeStr, _nullable, true);
	}
}

public TypeComplex getTypeComplexFromSqlDbType(SqlDbType dbType, bool isNullable, string name) {
	if (dbType == SqlDbType.Bit) return new TypeComplex(name, "bool" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.TinyInt) return new TypeComplex(name, "uint8" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.SmallInt) return new TypeComplex(name, "int16" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.Int) return new TypeComplex(name, "int32" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.BigInt) return new TypeComplex(name, "int64" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.Binary || dbType == SqlDbType.VarBinary || dbType == SqlDbType.Image) return new TypeComplex(name, "[uint8]" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.Char || dbType == SqlDbType.VarChar || dbType == SqlDbType.NChar || dbType == SqlDbType.NVarChar || dbType == SqlDbType.Text || dbType == SqlDbType.NText) return new TypeComplex(name, "string" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.Time) return new TypeComplex(name, "timespan" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.Date || dbType == SqlDbType.SmallDateTime || dbType == SqlDbType.DateTime || dbType == SqlDbType.DateTime2) return new TypeComplex(name, "datetime" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.DateTimeOffset) return new TypeComplex(name, "datetimetz" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.Money || dbType == SqlDbType.SmallMoney || dbType == SqlDbType.Decimal) return new TypeComplex(name, "fixed" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.Float) return new TypeComplex(name, "double" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.Real) return new TypeComplex(name, "float" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.UniqueIdentifier) return new TypeComplex(name, "guid" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.Timestamp) return new TypeComplex(name, "[uint8]" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	if (dbType == SqlDbType.Variant) return new TypeComplex(name, "stream" ~ (isNullable ? "?" : string.init), Location(-1,-1,-1));
	return null;
}
