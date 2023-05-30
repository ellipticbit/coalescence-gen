module hwgen.database.mssql.types;

import std.conv;
import std.string;

import hwgen.schema;

public string getMssqlTypeFromColumn(DataMember col)
{
	if (col.sqlType == SqlDbType.Bit) return "bit";
	if (col.sqlType == SqlDbType.TinyInt) return "tinyint";
	if (col.sqlType == SqlDbType.SmallInt) return "smallint";
	if (col.sqlType == SqlDbType.Int) return "int";
	if (col.sqlType == SqlDbType.BigInt) return "bigint";
	if (col.sqlType == SqlDbType.Binary) return "binary(" ~ to!string(col.maxLength) ~ ")";
	if (col.sqlType == SqlDbType.VarBinary) return "varbinary(" ~ (col.maxLength == -1 ? "max" : to!string(col.maxLength)) ~ ")";
	if (col.sqlType == SqlDbType.Image) return "image";
	if (col.sqlType == SqlDbType.Char) return "char(" ~ to!string(col.maxLength) ~ ")";
	if (col.sqlType == SqlDbType.VarChar) return "varchar(" ~ (col.maxLength == -1 ? "max" : to!string(col.maxLength)) ~ ")";
	if (col.sqlType == SqlDbType.NChar) return "nchar(" ~ to!string(col.maxLength) ~ ")";
	if (col.sqlType == SqlDbType.NVarChar) return "nvarchar(" ~ (col.maxLength == -1 ? "max" : to!string(col.maxLength)) ~ ")";
	if (col.sqlType == SqlDbType.Text) return "text";
	if (col.sqlType == SqlDbType.NText) return "ntext";
	if (col.sqlType == SqlDbType.Time) return "time(" ~ to!string(col.precision) ~ ")";
	if (col.sqlType == SqlDbType.Date) return "date";
	if (col.sqlType == SqlDbType.SmallDateTime) return "smalldatetime";
	if (col.sqlType == SqlDbType.DateTime) return "datetime";
	if (col.sqlType == SqlDbType.DateTime2) return "datetime2(" ~ to!string(col.precision) ~ ")";
	if (col.sqlType == SqlDbType.DateTimeOffset) return "datetimeoffset(" ~ to!string(col.precision) ~ ")";
	if (col.sqlType == SqlDbType.Money) return "money";
	if (col.sqlType == SqlDbType.SmallMoney) return "smallmoney";
	if (col.sqlType == SqlDbType.Decimal) return "decimal(" ~ to!string(col.precision) ~ ", " ~ to!string(col.scale) ~ ")";
	if (col.sqlType == SqlDbType.Float) return "float(" ~ to!string(col.precision) ~ ")";
	if (col.sqlType == SqlDbType.Real) return "real";
	if (col.sqlType == SqlDbType.UniqueIdentifier) return "uniqueidentifier";
	if (col.sqlType == SqlDbType.Timestamp) return "rowversion";
	if (col.sqlType == SqlDbType.Variant) return "sql_variant";
	if (col.sqlType == SqlDbType.Xml) return "xml";
	return string.init;
}

public SqlDbType parseMssqlDbType(string type)
{
	if (toUpper(type) == toUpper("bit")) return SqlDbType.Bit;
	if (toUpper(type) == toUpper("tinyint")) return SqlDbType.TinyInt;
	if (toUpper(type) == toUpper("smallint")) return SqlDbType.SmallInt;
	if (toUpper(type) == toUpper("int")) return SqlDbType.Int;
	if (toUpper(type) == toUpper("bigint")) return SqlDbType.BigInt;
	if (toUpper(type) == toUpper("binary")) return SqlDbType.Binary;
	if (toUpper(type) == toUpper("varbinary")) return SqlDbType.VarBinary;
	if (toUpper(type) == toUpper("image")) return SqlDbType.Image;
	if (toUpper(type) == toUpper("char")) return SqlDbType.Char;
	if (toUpper(type) == toUpper("varchar")) return SqlDbType.VarChar;
	if (toUpper(type) == toUpper("nchar")) return SqlDbType.NChar;
	if (toUpper(type) == toUpper("nvarchar")) return SqlDbType.NVarChar;
	if (toUpper(type) == toUpper("text")) return SqlDbType.Text;
	if (toUpper(type) == toUpper("ntext")) return SqlDbType.NText;
	if (toUpper(type) == toUpper("time")) return SqlDbType.Time;
	if (toUpper(type) == toUpper("date")) return SqlDbType.Date;
	if (toUpper(type) == toUpper("smalldatetime")) return SqlDbType.SmallDateTime;
	if (toUpper(type) == toUpper("datetime")) return SqlDbType.DateTime;
	if (toUpper(type) == toUpper("datetime2")) return SqlDbType.DateTime2;
	if (toUpper(type) == toUpper("datetimeoffset")) return SqlDbType.DateTimeOffset;
	if (toUpper(type) == toUpper("money")) return SqlDbType.Money;
	if (toUpper(type) == toUpper("smallmoney")) return SqlDbType.SmallMoney;
	if (toUpper(type) == toUpper("decimal")) return SqlDbType.Decimal;
	if (toUpper(type) == toUpper("float")) return SqlDbType.Float;
	if (toUpper(type) == toUpper("real")) return SqlDbType.Real;
	if (toUpper(type) == toUpper("uniqueidentifier")) return SqlDbType.UniqueIdentifier;
	if (toUpper(type) == toUpper("rowversion")) return SqlDbType.Timestamp;
	if (toUpper(type) == toUpper("timestamp")) return SqlDbType.Timestamp;
	if (toUpper(type) == toUpper("sql_variant")) return SqlDbType.Variant;
	if (toUpper(type) == toUpper("xml")) return SqlDbType.Xml;
	if (toUpper(type) == toUpper("TABLE TYPE")) return SqlDbType.Udt;
	if (toUpper(type) == toUpper("NUMERIC")) return SqlDbType.Decimal;
	return to!SqlDbType(type);
}
