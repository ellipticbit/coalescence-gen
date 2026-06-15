module coalescence.database.postgresql.types;

import std.string;

import coalescence.schema;

// Maps a PostgreSQL pg_type.typname onto the cross-dialect SqlDbType enum.
// Domains are expected to be resolved to their base type before calling this.
public SqlDbType parsePostgresDbType(string typname)
{
	string t = typname.toLower().strip();

	// Array types are named with a leading underscore (e.g. _int4).
	if (t.startsWith("_")) return SqlDbType.Array;

	if (t == "bool" || t == "boolean") return SqlDbType.Bit;
	if (t == "int2" || t == "smallint" || t == "smallserial") return SqlDbType.SmallInt;
	if (t == "int4" || t == "integer" || t == "serial") return SqlDbType.Int;
	if (t == "int8" || t == "bigint" || t == "bigserial" || t == "oid") return SqlDbType.BigInt;
	if (t == "float4" || t == "real") return SqlDbType.Real;
	if (t == "float8" || t == "double precision") return SqlDbType.Float;
	if (t == "numeric" || t == "decimal") return SqlDbType.Decimal;
	if (t == "money") return SqlDbType.Money;
	if (t == "bpchar" || t == "char" || t == "character") return SqlDbType.Char;
	if (t == "varchar" || t == "character varying") return SqlDbType.VarChar;
	if (t == "text" || t == "name" || t == "citext") return SqlDbType.Text;
	if (t == "bytea") return SqlDbType.VarBinary;
	if (t == "date") return SqlDbType.Date;
	if (t == "time" || t == "timetz") return SqlDbType.Time;
	if (t == "timestamp") return SqlDbType.DateTime2;
	if (t == "timestamptz") return SqlDbType.DateTimeOffset;
	if (t == "uuid") return SqlDbType.UniqueIdentifier;
	if (t == "json") return SqlDbType.Json;
	if (t == "jsonb") return SqlDbType.Jsonb;
	if (t == "xml") return SqlDbType.Xml;
	if (t == "interval") return SqlDbType.Interval;
	if (t == "inet") return SqlDbType.Inet;
	if (t == "cidr") return SqlDbType.Cidr;
	if (t == "macaddr" || t == "macaddr8") return SqlDbType.MacAddr;

	// Enums, geometric, range and any other unsupported types fall back to text.
	return SqlDbType.VarChar;
}

// Maps a PostgreSQL pg_constraint confupdtype/confdeltype char onto the byte
// code used by the ForeignKeyAction enum.
public byte parsePostgresForeignKeyAction(string action)
{
	switch (action.toLower().strip())
	{
		case "c": return cast(byte)ForeignKeyAction.Cascade;
		case "n": return cast(byte)ForeignKeyAction.SetNull;
		case "d": return cast(byte)ForeignKeyAction.SetDefault;
		default: return cast(byte)ForeignKeyAction.NoAction; // 'a' (no action) / 'r' (restrict)
	}
}

// Maps a PostgreSQL pg_proc.proargmodes char onto the ParameterDirection enum.
public ParameterDirection parsePostgresParameterDirection(string mode)
{
	switch (mode.toLower().strip())
	{
		case "o": return ParameterDirection.Output;
		case "b": return ParameterDirection.InputOutput;
		case "t": return ParameterDirection.Output; // TABLE column
		default: return ParameterDirection.Input;    // 'i' IN / 'v' VARIADIC
	}
}
