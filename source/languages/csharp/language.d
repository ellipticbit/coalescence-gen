module coalescence.languages.csharp.language;

import coalescence.schema;
import coalescence.types;

import std.conv : text;

public string getTypeFromSqlType(SqlDbType type, bool isNullable)
{
	if (type == SqlDbType.Bit) return text(i"bool$(isNullable ? "?" : "")");
	if (type == SqlDbType.TinyInt) return text(i"byte$(isNullable ? "?" : "")");
	if (type == SqlDbType.SmallInt) return text(i"short$(isNullable ? "?" : "")");
	if (type == SqlDbType.Int) return text(i"int$(isNullable ? "?" : "")");
	if (type == SqlDbType.BigInt) return text(i"long$(isNullable ? "?" : "")");
	if (type == SqlDbType.Binary || type == SqlDbType.VarBinary || type == SqlDbType.Image) return "byte[]";
	if (type == SqlDbType.Char || type == SqlDbType.VarChar || type == SqlDbType.NChar || type == SqlDbType.NVarChar || type == SqlDbType.Text || type == SqlDbType.NText) return "string";
	if (type == SqlDbType.Time) return text(i"TimeSpan$(isNullable ? "?" : "")");
	if (type == SqlDbType.Date || type == SqlDbType.SmallDateTime || type == SqlDbType.DateTime || type == SqlDbType.DateTime2) return text(i"DateTime$(isNullable ? "?" : "")");
	if (type == SqlDbType.DateTimeOffset) return text(i"DateTimeOffset$(isNullable ? "?" : "")");
	if (type == SqlDbType.Money || type == SqlDbType.SmallMoney || type == SqlDbType.Decimal) return text(i"decimal$(isNullable ? "?" : "")");
	if (type == SqlDbType.Float) return text(i"double$(isNullable ? "?" : "")");
	if (type == SqlDbType.Real) return text(i"float$(isNullable ? "?" : "")");
	if (type == SqlDbType.UniqueIdentifier) return text(i"Guid$(isNullable ? "?" : "")");
	if (type == SqlDbType.Timestamp) return "byte[]";
	if (type == SqlDbType.Variant) return "object";
	if (type == SqlDbType.Json || type == SqlDbType.Jsonb) return "System.Text.Json.JsonDocument";
	if (type == SqlDbType.Interval) return text(i"TimeSpan$(isNullable ? "?" : "")");
	if (type == SqlDbType.Inet || type == SqlDbType.Cidr || type == SqlDbType.MacAddr) return "string";
	if (type == SqlDbType.Year) return text(i"short$(isNullable ? "?" : "")");
	if (type == SqlDbType.Enum || type == SqlDbType.Set) return "string";
	if (type == SqlDbType.Array) return "string";
	return string.init;
}

// Resolves the C# type for a database column, accounting for array columns
// (e.g. PostgreSQL/Npgsql native arrays) which map to a CLR array of the
// element type rather than a scalar.
public string getTypeFromSqlMember(DataMember mm)
{
	if (mm.sqlType == SqlDbType.Array) {
		string elem = getTypeFromSqlType(mm.arrayElementType, false);
		if (elem.length == 0) elem = "string";
		return text(i"$(elem)[]");
	}
	return getTypeFromSqlType(mm.sqlType, mm.isNullable);
}

public string getValueTypeFromSqlType(SqlDbType type)
{
	if (type == SqlDbType.Bit) return "DatabaseValueType.Bool";
	if (type == SqlDbType.TinyInt) return "DatabaseValueType.Byte";
	if (type == SqlDbType.SmallInt) return "DatabaseValueType.Short";
	if (type == SqlDbType.Int) return "DatabaseValueType.Int";
	if (type == SqlDbType.BigInt) return "DatabaseValueType.Long";
	if (type == SqlDbType.Binary || type == SqlDbType.VarBinary || type == SqlDbType.Image) return "DatabaseValueType.ByteArray";
	if (type == SqlDbType.Char || type == SqlDbType.VarChar || type == SqlDbType.NChar || type == SqlDbType.NVarChar || type == SqlDbType.Text || type == SqlDbType.NText) return "DatabaseValueType.String";
	if (type == SqlDbType.Time) return "DatabaseValueType.TimeSpan";
	if (type == SqlDbType.Date || type == SqlDbType.SmallDateTime || type == SqlDbType.DateTime || type == SqlDbType.DateTime2) return "DatabaseValueType.DateTime";
	if (type == SqlDbType.DateTimeOffset) return "DatabaseValueType.DateTimeOffset";
	if (type == SqlDbType.Money || type == SqlDbType.SmallMoney || type == SqlDbType.Decimal) return "DatabaseValueType.Decimal";
	if (type == SqlDbType.Float) return "DatabaseValueType.Double";
	if (type == SqlDbType.Real) return "DatabaseValueType.Float";
	if (type == SqlDbType.UniqueIdentifier) return "DatabaseValueType.Guid";
	if (type == SqlDbType.Timestamp) return "DatabaseValueType.ByteArray";
	if (type == SqlDbType.Variant) return "DatabaseValueType.Object";
	if (type == SqlDbType.Json || type == SqlDbType.Jsonb || type == SqlDbType.Inet || type == SqlDbType.Cidr || type == SqlDbType.MacAddr || type == SqlDbType.Enum || type == SqlDbType.Set || type == SqlDbType.Array) return "DatabaseValueType.String";
	if (type == SqlDbType.Interval) return "DatabaseValueType.TimeSpan";
	if (type == SqlDbType.Year) return "DatabaseValueType.Short";
	return string.init;
}

public bool isPrimitiveType(TypeComplex type, TypePrimitives primitive) {
	if (typeid(type.type) == typeid(TypePrimitive)) {
		TypePrimitive p = cast(TypePrimitive)type.type;
		return p.primitive == primitive;
	}

	return false;
}
