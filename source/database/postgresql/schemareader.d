module coalescence.database.postgresql.schemareader;

import std.array;
import std.algorithm.searching;
import std.algorithm.sorting;
import std.algorithm.iteration;
import std.conv;
import std.stdio;
import std.string;

import phobos.database.sql;

import coalescence.globals;
import coalescence.schema;
import coalescence.utility;
import coalescence.database.postgresql.types;

// Reads every user schema (pg_namespace) within the connected database. The
// connection is already scoped to the database named by --db-name, so all
// non-system namespaces in it are read as Coalescence schemas using real
// PostgreSQL object identifiers (OIDs / attnums).
public Schema[] readPostgresSchemata(SqlConnection conn)
{
	Schema[] sl;

	//Read schemas
	{
		auto cmd = new SqlCommand(conn, i"SELECT n.nspname, n.oid FROM pg_catalog.pg_namespace n WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema' ORDER BY n.nspname");
		scope(exit) cmd.dispose();
		auto rdr = cmd.executeDataReader();
		scope(exit) rdr.close();
		while (rdr.read())
			sl ~= new Schema(cast(int)rdr.getLong(1), rdr.getString(0));
	}

	//Collect the set of relations that have at least one user trigger.
	bool[int] triggerRels;
	{
		auto cmd = new SqlCommand(conn, i"SELECT DISTINCT t.tgrelid FROM pg_catalog.pg_trigger t WHERE NOT t.tgisinternal");
		scope(exit) cmd.dispose();
		auto rdr = cmd.executeDataReader();
		scope(exit) rdr.close();
		while (rdr.read())
			triggerRels[cast(int)rdr.getLong(0)] = true;
	}

	//Build an OID -> type name map used to resolve routine argument types.
	string[int] oidTypeName;
	{
		auto cmd = new SqlCommand(conn, i"SELECT t.oid, t.typname FROM pg_catalog.pg_type t");
		scope(exit) cmd.dispose();
		auto rdr = cmd.executeDataReader();
		scope(exit) rdr.close();
		while (rdr.read())
			oidTypeName[cast(int)rdr.getLong(0)] = rdr.getString(1);
	}

	//Read tables, views and composite types per schema.
	foreach (s; sl)
	{
		//Read tables
		{
			auto cmd = new SqlCommand(conn, i"SELECT c.relname, c.oid FROM pg_catalog.pg_class c WHERE c.relnamespace = $(s.sqlId) AND c.relkind IN ('r', 'p') ORDER BY c.relname");
			scope(exit) cmd.dispose();
			auto rdr = cmd.executeDataReader();
			scope(exit) rdr.close();
			while (rdr.read())
			{
				auto nt = new Table(s, cast(int)rdr.getLong(1), rdr.getString(0));
				nt.hasTrigger = (nt.sqlId in triggerRels) !is null;
				if ((nt.name in s.udts) is null) {
					s.tables[nt.name] = nt;
				} else {
					writeError("Table '" ~ nt.name ~ "' already exists in schema '" ~ s.name ~ "'");
				}
			}
		}

		foreach (t; s.tables.values)
			t.members ~= readColumns(t, conn);
		foreach (t; s.tables.values)
			t.indexes ~= readIndexes(t, conn);

		//Remove any tables that do not have a Primary Key
		auto nopk = s.tables.values.filter!(t => !t.indexes.any!(a => a.isPrimaryKey)).array;
		foreach (t; nopk)
		{
			writeln("WARN: Table [" ~ s.name ~ "].[" ~ t.name ~ "] does not have a primary key defined. Skipping.");
			s.tables.remove(t.name);
		}

		//Read views (regular and materialized)
		{
			auto cmd = new SqlCommand(conn, i"SELECT c.relname, c.oid FROM pg_catalog.pg_class c WHERE c.relnamespace = $(s.sqlId) AND c.relkind IN ('v', 'm') ORDER BY c.relname");
			scope(exit) cmd.dispose();
			auto rdr = cmd.executeDataReader();
			scope(exit) rdr.close();
			while (rdr.read())
			{
				auto nv = new View(s, cast(int)rdr.getLong(1), rdr.getString(0));
				if ((nv.name in s.udts) is null) {
					s.views[nv.name] = nv;
				} else {
					writeError("View '" ~ nv.name ~ "' already exists in schema '" ~ s.name ~ "'");
				}
			}
		}

		foreach (t; s.views.values)
			t.members ~= readColumns(t, conn);

		//Read composite types (standalone CREATE TYPE ... AS) as UDTs.
		{
			auto cmd = new SqlCommand(conn, i"SELECT t.typname, c.oid FROM pg_catalog.pg_type t INNER JOIN pg_catalog.pg_class c ON c.oid = t.typrelid AND c.relkind = 'c' WHERE t.typnamespace = $(s.sqlId) ORDER BY t.typname");
			scope(exit) cmd.dispose();
			auto rdr = cmd.executeDataReader();
			scope(exit) rdr.close();
			while (rdr.read())
			{
				auto nu = new Udt(s, cast(int)rdr.getLong(1), rdr.getString(0));
				if ((nu.name in s.udts) is null) {
					s.udts[nu.name] = nu;
				} else {
					writeError("UDT '" ~ nu.name ~ "' already exists in schema '" ~ s.name ~ "'");
				}
			}
		}

		foreach (t; s.udts.values)
			t.members ~= readColumns(t, conn);
	}

	//Read foreign keys (may reference tables in other schemas).
	foreach (s; sl)
	{
		foreach (t; s.tables.values)
		{
			ForeignKey[] fkl = readForeignKeys(t, sl, conn);
			t.foreignKeys ~= fkl.sort!((a, b) => a.name.toUpper() < b.name.toUpper()).array;
		}
	}

	//Read stored procedures and functions.
	foreach (s; sl)
		readRoutines(s, oidTypeName, conn);

	return sl.sort!((a, b) => a.name.toUpper() < b.name.toUpper()).array;
}

private DataMember[] readColumns(DataObject t, SqlConnection conn)
{
	int oid = t.sqlId;
	auto cmd = new SqlCommand(conn, i"SELECT a.attname, a.attnum, CASE WHEN ty.typtype = 'd' THEN bt.typname ELSE ty.typname END AS typname, a.attnotnull, a.atttypmod, COALESCE(pg_catalog.pg_get_expr(ad.adbin, ad.adrelid), '') AS adsrc, (ad.adbin IS NOT NULL) AS hasdefault, a.attidentity, a.attgenerated, CASE WHEN ty.typtype = 'd' THEN bt.typcategory ELSE ty.typcategory END AS typcat FROM pg_catalog.pg_attribute a INNER JOIN pg_catalog.pg_type ty ON ty.oid = a.atttypid LEFT JOIN pg_catalog.pg_type bt ON bt.oid = ty.typbasetype LEFT JOIN pg_catalog.pg_attrdef ad ON ad.adrelid = a.attrelid AND ad.adnum = a.attnum WHERE a.attrelid = $(oid) AND a.attnum > 0 AND NOT a.attisdropped ORDER BY a.attnum");
	scope(exit) cmd.dispose();
	auto crdr = cmd.executeDataReader();
	scope(exit) crdr.close();

	DataMember[] cl;
	while (crdr.read())
	{
		int attnum = cast(int)crdr.getLong(1);
		string typname = crdr.getString(2);
		bool notNull = crdr.getBool(3);
		int typmod = cast(int)crdr.getLong(4);
		string adsrc = crdr.isNull(5) ? string.init : crdr.getString(5);
		bool hasDefault = crdr.getBool(6);
		string identity = crdr.isNull(7) ? string.init : crdr.getString(7);
		string generated = crdr.isNull(8) ? string.init : crdr.getString(8);
		string typcat = crdr.isNull(9) ? string.init : crdr.getString(9);

		SqlDbType sqlType = (typcat == "A") ? SqlDbType.Array : parsePostgresDbType(typname);

		int maxLength = -1;
		byte precision = 0;
		byte scale = 0;
		computeTypmod(sqlType, typmod, maxLength, precision, scale);

		bool isIdentity = identity == "a" || identity == "d" || adsrc.canFind("nextval(");
		bool isComputed = generated == "s";

		cl ~= new DataMember(t,
			attnum,
			crdr.getString(0),
			sqlType,
			maxLength,
			precision,
			scale,
			hasDefault,
			hasDefault ? adsrc : null,
			!notNull,
			isIdentity,
			isComputed
		);
	}
	return cl;
}

private void computeTypmod(SqlDbType type, int typmod, ref int maxLength, ref byte precision, ref byte scale)
{
	maxLength = -1;
	precision = 0;
	scale = 0;

	if (type == SqlDbType.VarChar || type == SqlDbType.Char || type == SqlDbType.NVarChar || type == SqlDbType.NChar)
	{
		if (typmod > 4) maxLength = typmod - 4;
	}
	else if (type == SqlDbType.Decimal)
	{
		if (typmod >= 4)
		{
			int m = typmod - 4;
			precision = cast(byte)((m >> 16) & 0xFFFF);
			scale = cast(byte)(m & 0xFFFF);
		}
	}
	else if (type == SqlDbType.Time || type == SqlDbType.DateTime2 || type == SqlDbType.DateTimeOffset)
	{
		if (typmod >= 0) scale = cast(byte)(typmod & 0xFFFF);
	}
}

private Index[] readIndexes(Table t, SqlConnection conn)
{
	int oid = t.sqlId;
	auto cmd = new SqlCommand(conn, i"SELECT ic.relname, i.indisunique, i.indisprimary, i.indkey FROM pg_catalog.pg_index i INNER JOIN pg_catalog.pg_class ic ON ic.oid = i.indexrelid WHERE i.indrelid = $(oid) ORDER BY ic.relname");
	scope(exit) cmd.dispose();
	auto irdr = cmd.executeDataReader();
	scope(exit) irdr.close();

	Index[] il;
	while (irdr.read())
	{
		Index ni = new Index(irdr.getString(0), irdr.getBool(1), irdr.getBool(2));
		foreach (k; parseIntVector(irdr.getString(3)))
		{
			if (k == 0) continue; // expression column
			auto col = t.members.find!(a => a.sqlId == k);
			if (col.length != 0) ni.columns ~= col[0];
		}
		if (ni.columns.length != 0) il ~= ni;
	}

	return il;
}

private ForeignKey[] readForeignKeys(Table t, Schema[] schemata, SqlConnection conn)
{
	int oid = t.sqlId;
	auto cmd = new SqlCommand(conn, i"SELECT con.conname, con.confrelid, con.conkey, con.confkey, con.confupdtype, con.confdeltype FROM pg_catalog.pg_constraint con WHERE con.conrelid = $(oid) AND con.contype = 'f' ORDER BY con.conname");
	scope(exit) cmd.dispose();
	auto fkrdr = cmd.executeDataReader();
	scope(exit) fkrdr.close();

	ForeignKey[] fkl;
	while (fkrdr.read())
	{
		string name = fkrdr.getString(0);
		int confrelid = cast(int)fkrdr.getLong(1);
		int[] conkey = parseIntArray(fkrdr.getString(2));
		int[] confkey = parseIntArray(fkrdr.getString(3));
		byte onUpdate = parsePostgresForeignKeyAction(fkrdr.getString(4));
		byte onDelete = parsePostgresForeignKeyAction(fkrdr.getString(5));

		if (conkey.length == 0) continue;
		Table refTable = findTableByOid(schemata, confrelid);
		if (refTable is null) continue;

		bool pu = isColumnUnique(t, conkey[0]);
		bool ru = confkey.length != 0 ? isColumnUnique(refTable, confkey[0]) : false;
		ForeignKeyDirection fkd = (pu && ru) ? ForeignKeyDirection.OneToOne : (!pu && ru) ? ForeignKeyDirection.OneToMany : ForeignKeyDirection.ManyToMany;

		ForeignKey nfk = new ForeignKey(name, t, refTable, conkey[0], fkd, onUpdate, onDelete);
		foreach (k; conkey)
		{
			auto col = t.members.find!(a => a.sqlId == k);
			if (col.length != 0) nfk.source ~= col[0];
		}
		fkl ~= nfk;
	}

	return fkl;
}

private void readRoutines(Schema s, string[int] oidTypeName, SqlConnection conn)
{
	auto cmd = new SqlCommand(conn, i"SELECT p.proname, p.oid, p.prokind, p.prorettype, p.proargtypes, p.proallargtypes, p.proargmodes, p.proargnames FROM pg_catalog.pg_proc p WHERE p.pronamespace = $(s.sqlId) ORDER BY p.proname, p.oid");
	scope(exit) cmd.dispose();
	auto rdr = cmd.executeDataReader();
	scope(exit) rdr.close();

	while (rdr.read())
	{
		string pname = rdr.getString(0);
		int poid = cast(int)rdr.getLong(1);
		string prokind = rdr.isNull(2) ? "f" : rdr.getString(2);
		int prorettype = cast(int)rdr.getLong(3);
		string argtypes = rdr.isNull(4) ? string.init : rdr.getString(4);
		string allargtypes = rdr.isNull(5) ? string.init : rdr.getString(5);
		string argmodes = rdr.isNull(6) ? string.init : rdr.getString(6);
		string argnames = rdr.isNull(7) ? string.init : rdr.getString(7);

		// Skip aggregate and window functions.
		if (prokind == "a" || prokind == "w") continue;

		if ((pname in s.procedures) !is null) continue; // overloaded; keep first
		auto np = new Procedure(s, poid, pname);
		s.procedures[np.name] = np;

		int[] typeOids = allargtypes.length != 0 ? parseIntArray(allargtypes) : parseIntVector(argtypes);
		string[] modes = argmodes.length != 0 ? parseTextArray(argmodes) : null;
		string[] names = argnames.length != 0 ? parseTextArray(argnames) : null;

		foreach (i, toid; typeOids)
		{
			string mode = (modes !is null && i < modes.length) ? modes[i] : "i";
			string aname = (names !is null && i < names.length) ? names[i] : string.init;
			string tn = (toid in oidTypeName) ? oidTypeName[toid] : string.init;
			np.parameters ~= new Parameter(aname, parsePostgresParameterDirection(mode), 0, parsePostgresDbType(tn), null, cast(short)0, cast(byte)0, cast(byte)0, false);
		}

		// Scalar function return value (skip void/trigger and OUT-style functions).
		if (prokind == "f" && allargtypes.length == 0 && prorettype != 2278 && prorettype != 2279)
		{
			string tn = (prorettype in oidTypeName) ? oidTypeName[prorettype] : string.init;
			np.parameters ~= new Parameter(string.init, ParameterDirection.ReturnValue, 0, parsePostgresDbType(tn), null, cast(short)0, cast(byte)0, cast(byte)0, false);
		}
	}
}

private bool isColumnUnique(Table t, int attnum)
{
	return t.indexes.any!(a => a.columns.any!(b => b.sqlId == attnum) && ((a.isUnique && a.columns.length == 1) || a.isPrimaryKey));
}

private Table findTableByOid(Schema[] schemata, int oid)
{
	foreach (s; schemata)
		foreach (t; s.tables.values)
			if (t.sqlId == oid) return t;
	return null;
}

private int[] parseIntVector(string s)
{
	int[] r;
	foreach (p; s.strip().split())
		if (p.length != 0) r ~= to!int(p);
	return r;
}

private int[] parseIntArray(string s)
{
	s = s.strip();
	if (s.length >= 2 && s[0] == '{' && s[$ - 1] == '}') s = s[1 .. $ - 1];
	int[] r;
	foreach (p; s.split(","))
	{
		auto v = p.strip();
		if (v.length != 0) r ~= to!int(v);
	}
	return r;
}

private string[] parseTextArray(string s)
{
	s = s.strip();
	if (s.length >= 2 && s[0] == '{' && s[$ - 1] == '}') s = s[1 .. $ - 1];
	string[] r;
	foreach (p; s.split(","))
	{
		auto v = p.strip();
		if (v.length >= 2 && v[0] == '"' && v[$ - 1] == '"') v = v[1 .. $ - 1];
		r ~= v;
	}
	return r;
}
