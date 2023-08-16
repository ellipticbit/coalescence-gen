module hwgen.languages.csharp.language;

import hwgen.schema;
import hwgen.types;

public string getTypeFromSqlType(SqlDbType type, bool isNullable)
{
	if (type == SqlDbType.Bit) return "bool" ~ (isNullable ? "?" : "");
	if (type == SqlDbType.TinyInt) return "byte" ~ (isNullable ? "?" : "");
	if (type == SqlDbType.SmallInt) return "short" ~ (isNullable ? "?" : "");
	if (type == SqlDbType.Int) return "int" ~ (isNullable ? "?" : "");
	if (type == SqlDbType.BigInt) return "long" ~ (isNullable ? "?" : "");
	if (type == SqlDbType.Binary || type == SqlDbType.VarBinary || type == SqlDbType.Image) return "byte[]";
	if (type == SqlDbType.Char || type == SqlDbType.VarChar || type == SqlDbType.NChar || type == SqlDbType.NVarChar || type == SqlDbType.Text || type == SqlDbType.NText) return "string";
	if (type == SqlDbType.Time) return "TimeSpan" ~ (isNullable ? "?" : "");
	if (type == SqlDbType.Date || type == SqlDbType.SmallDateTime || type == SqlDbType.DateTime || type == SqlDbType.DateTime2) return "DateTime" ~ (isNullable ? "?" : "");
	if (type == SqlDbType.DateTimeOffset) return "DateTimeOffset" ~ (isNullable ? "?" : "");
	if (type == SqlDbType.Money || type == SqlDbType.SmallMoney || type == SqlDbType.Decimal) return "decimal" ~ (isNullable ? "?" : "");
	if (type == SqlDbType.Float) return "double" ~ (isNullable ? "?" : "");
	if (type == SqlDbType.Real) return "float" ~ (isNullable ? "?" : "");
	if (type == SqlDbType.UniqueIdentifier) return "Guid" ~ (isNullable ? "?" : "");
	if (type == SqlDbType.Timestamp) return "byte[]";
	if (type == SqlDbType.Variant) return "object";
	return string.init;
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
	return string.init;
}

public bool isPrimitiveType(TypeComplex type, TypePrimitives primitive) {
	if (typeid(type.type) == typeid(TypePrimitive)) {
		TypePrimitive p = cast(TypePrimitive)type.type;
		return p.primitive == primitive;
	}

	return false;
}
