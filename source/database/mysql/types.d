module coalescence.database.mysql.types;

import std.string;

import coalescence.schema;

// Maps a MySQL/MariaDB information_schema DATA_TYPE (with the full COLUMN_TYPE
// available for disambiguation) onto the cross-dialect SqlDbType enum.
public SqlDbType parseMysqlDbType(string dataType, string columnType)
{
	string dt = dataType.toLower().strip();
	string ct = columnType.toLower().strip();

	if (dt == "bit") return SqlDbType.Bit;
	if (dt == "bool" || dt == "boolean") return SqlDbType.Bit;
	if (dt == "tinyint") return ct == "tinyint(1)" ? SqlDbType.Bit : SqlDbType.TinyInt;
	if (dt == "smallint") return SqlDbType.SmallInt;
	if (dt == "mediumint" || dt == "int" || dt == "integer") return SqlDbType.Int;
	if (dt == "bigint") return SqlDbType.BigInt;
	if (dt == "decimal" || dt == "numeric" || dt == "dec" || dt == "fixed") return SqlDbType.Decimal;
	if (dt == "float") return SqlDbType.Real;
	if (dt == "double" || dt == "double precision" || dt == "real") return SqlDbType.Float;
	if (dt == "char") return SqlDbType.Char;
	if (dt == "varchar") return SqlDbType.VarChar;
	if (dt == "tinytext" || dt == "text" || dt == "mediumtext" || dt == "longtext") return SqlDbType.Text;
	if (dt == "binary") return SqlDbType.Binary;
	if (dt == "varbinary") return SqlDbType.VarBinary;
	if (dt == "tinyblob" || dt == "blob" || dt == "mediumblob" || dt == "longblob") return SqlDbType.VarBinary;
	if (dt == "date") return SqlDbType.Date;
	if (dt == "datetime") return SqlDbType.DateTime2;
	if (dt == "timestamp") return SqlDbType.DateTime2;
	if (dt == "time") return SqlDbType.Time;
	if (dt == "year") return SqlDbType.Year;
	if (dt == "json") return SqlDbType.Json;
	if (dt == "enum") return SqlDbType.Enum;
	if (dt == "set") return SqlDbType.Set;

	// Spatial and any other unsupported types fall back to a string representation.
	return SqlDbType.VarChar;
}

// Maps a MySQL referential action string onto the byte code used by the
// ForeignKeyAction enum (NoAction=0, Cascade=1, SetNull=2, SetDefault=3).
public byte parseMysqlForeignKeyAction(string rule)
{
	switch (rule.toUpper().strip())
	{
		case "CASCADE": return cast(byte)ForeignKeyAction.Cascade;
		case "SET NULL": return cast(byte)ForeignKeyAction.SetNull;
		case "SET DEFAULT": return cast(byte)ForeignKeyAction.SetDefault;
		default: return cast(byte)ForeignKeyAction.NoAction; // NO ACTION / RESTRICT
	}
}

// Maps a MySQL routine PARAMETER_MODE onto the ParameterDirection enum. A null
// mode denotes a function's return value (ORDINAL_POSITION = 0).
public ParameterDirection parseMysqlParameterDirection(string mode)
{
	if (mode is null || mode.strip().length == 0) return ParameterDirection.ReturnValue;

	switch (mode.toUpper().strip())
	{
		case "IN": return ParameterDirection.Input;
		case "OUT": return ParameterDirection.Output;
		case "INOUT": return ParameterDirection.InputOutput;
		default: return ParameterDirection.Input;
	}
}
