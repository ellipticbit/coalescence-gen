module coalescence.database.mysql.schemareader;

import std.array;
import std.algorithm.searching;
import std.algorithm.sorting;
import std.algorithm.iteration;
import std.stdio;
import std.string;

import phobos.database.sql;

import coalescence.globals;
import coalescence.schema;
import coalescence.utility;
import coalescence.database.mysql.types;

// Reads the single database named by `dbname` as one Coalescence schema. MySQL
// (and MariaDB) databases are themselves schemas, so every information_schema
// query is scoped by TABLE_SCHEMA/ROUTINE_SCHEMA/CONSTRAINT_SCHEMA = dbname.
public Schema[] readMysqlSchemata(SqlConnection conn, string dbname)
{
	Schema[] sl;
	auto s = new Schema(1, dbname);
	sl ~= s;

	// Synthesized object identifiers. information_schema exposes no stable
	// numeric object IDs, so we assign sequential IDs (schema uses 1).
	int nextId = 2;

	// Collect the set of tables that have at least one trigger.
	bool[string] triggerTables;
	{
		auto cmd = new SqlCommand(conn, i"SELECT DISTINCT EVENT_OBJECT_TABLE FROM INFORMATION_SCHEMA.TRIGGERS WHERE TRIGGER_SCHEMA = $(dbname)");
		scope(exit) cmd.dispose();
		auto rdr = cmd.executeDataReader();
		scope(exit) rdr.close();
		while (rdr.read())
			triggerTables[rdr.getString(0)] = true;
	}

	//Read tables
	{
		auto cmd = new SqlCommand(conn, i"SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = $(dbname) AND TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME");
		scope(exit) cmd.dispose();
		auto rdr = cmd.executeDataReader();
		scope(exit) rdr.close();
		while (rdr.read())
		{
			auto name = rdr.getString(0);
			auto nt = new Table(s, nextId++, name);
			nt.hasTrigger = (name in triggerTables) !is null;
			if ((nt.name in s.udts) is null) {
				s.tables[nt.name] = nt;
			} else {
				writeError("Table '" ~ nt.name ~ "' already exists in schema '" ~ s.name ~ "'");
			}
		}
	}

	//Read columns and indexes
	foreach (t; s.tables.values)
		t.members ~= readColumns(t, dbname, conn);
	foreach (t; s.tables.values)
		t.indexes ~= readIndexes(t, dbname, conn);

	//Remove any tables that do not have a Primary Key
	auto nopk = s.tables.values.filter!(t => !t.indexes.any!(a => a.isPrimaryKey)).array;
	foreach (t; nopk)
	{
		writeln("WARN: Table [" ~ s.name ~ "].[" ~ t.name ~ "] does not have a primary key defined. Skipping.");
		s.tables.remove(t.name);
	}

	//Read views
	{
		auto cmd = new SqlCommand(conn, i"SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = $(dbname) AND TABLE_TYPE = 'VIEW' ORDER BY TABLE_NAME");
		scope(exit) cmd.dispose();
		auto rdr = cmd.executeDataReader();
		scope(exit) rdr.close();
		while (rdr.read())
		{
			auto nv = new View(s, nextId++, rdr.getString(0));
			if ((nv.name in s.udts) is null) {
				s.views[nv.name] = nv;
			} else {
				writeError("View '" ~ nv.name ~ "' already exists in schema '" ~ s.name ~ "'");
			}
		}
	}

	foreach (t; s.views.values)
		t.members ~= readColumns(t, dbname, conn);

	//Read foreign keys
	foreach (t; s.tables.values)
	{
		ForeignKey[] fkl = readForeignKeys(t, s, dbname, conn);
		t.foreignKeys ~= fkl.sort!((a, b) => a.name.toUpper() < b.name.toUpper()).array;
	}

	//Read stored procedures and functions
	{
		auto cmd = new SqlCommand(conn, i"SELECT ROUTINE_NAME FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = $(dbname) ORDER BY ROUTINE_NAME");
		scope(exit) cmd.dispose();
		auto rdr = cmd.executeDataReader();
		scope(exit) rdr.close();
		while (rdr.read())
		{
			auto np = new Procedure(s, nextId++, rdr.getString(0));
			if ((np.name in s.procedures) is null) {
				s.procedures[np.name] = np;
			} else {
				writeError("Routine '" ~ np.name ~ "' already exists in schema '" ~ s.name ~ "'");
			}
		}
	}

	foreach (p; s.procedures.values)
		readParameters(p, dbname, conn);

	return sl;
}

private DataMember[] readColumns(DataObject t, string dbname, SqlConnection conn)
{
	auto tableName = t.name;
	auto cmd = new SqlCommand(conn, i"SELECT COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = $(dbname) AND TABLE_NAME = $(tableName) ORDER BY ORDINAL_POSITION");
	scope(exit) cmd.dispose();
	auto crdr = cmd.executeDataReader();
	scope(exit) crdr.close();

	DataMember[] cl;
	while (crdr.read())
	{
		long ml = crdr.isNull(7) ? -1 : crdr.getLong(7);
		int maxLength = (ml < 0 || ml > int.max) ? -1 : cast(int)ml;
		byte precision = crdr.isNull(8) ? cast(byte)0 : cast(byte)crdr.getLong(8);
		byte scale = crdr.isNull(9) ? cast(byte)0 : cast(byte)crdr.getLong(9);
		string extra = crdr.isNull(6) ? string.init : crdr.getString(6);

		cl ~= new DataMember(t,
			cast(int)crdr.getLong(1),
			crdr.getString(0),
			parseMysqlDbType(crdr.getString(2), crdr.getString(3)),
			maxLength,
			precision,
			scale,
			!crdr.isNull(5),
			crdr.isNull(5) ? null : crdr.getString(5),
			crdr.getString(4).toUpper() == "YES",
			extra.toLower().canFind("auto_increment"),
			extra.toUpper().canFind("GENERATED")
		);
	}
	return cl;
}

private Index[] readIndexes(Table t, string dbname, SqlConnection conn)
{
	auto tableName = t.name;
	auto cmd = new SqlCommand(conn, i"SELECT INDEX_NAME, NON_UNIQUE, COLUMN_NAME, SEQ_IN_INDEX FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = $(dbname) AND TABLE_NAME = $(tableName) ORDER BY INDEX_NAME, SEQ_IN_INDEX");
	scope(exit) cmd.dispose();
	auto irdr = cmd.executeDataReader();
	scope(exit) irdr.close();

	Index[] il;
	while (irdr.read())
	{
		string iname = irdr.getString(0);
		bool isUnique = irdr.getLong(1) == 0;
		string colName = irdr.getString(2);

		auto col = t.members.find!(a => a.name == colName);
		if (col.length == 0) continue;

		auto index = il.find!(a => toUpper(a.name) == toUpper(iname));
		if (index.length == 0)
		{
			Index ni = new Index(iname, isUnique, toUpper(iname) == "PRIMARY");
			ni.columns ~= col[0];
			il ~= ni;
		}
		else
		{
			index[0].columns ~= col[0];
		}
	}

	return il;
}

private ForeignKey[] readForeignKeys(Table t, Schema s, string dbname, SqlConnection conn)
{
	auto tableName = t.name;
	auto cmd = new SqlCommand(conn, i"SELECT k.CONSTRAINT_NAME, k.COLUMN_NAME, k.REFERENCED_TABLE_NAME, k.REFERENCED_COLUMN_NAME, r.UPDATE_RULE, r.DELETE_RULE FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE k INNER JOIN INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS r ON r.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA AND r.CONSTRAINT_NAME = k.CONSTRAINT_NAME AND r.TABLE_NAME = k.TABLE_NAME WHERE k.CONSTRAINT_SCHEMA = $(dbname) AND k.TABLE_NAME = $(tableName) AND k.REFERENCED_TABLE_NAME IS NOT NULL ORDER BY k.CONSTRAINT_NAME, k.ORDINAL_POSITION");
	scope(exit) cmd.dispose();
	auto fkrdr = cmd.executeDataReader();
	scope(exit) fkrdr.close();

	ForeignKey[] fkl;
	while (fkrdr.read())
	{
		string name = fkrdr.getString(0);
		string colName = fkrdr.getString(1);
		string refTableName = fkrdr.getString(2);
		string refColName = fkrdr.getString(3);
		byte onUpdate = parseMysqlForeignKeyAction(fkrdr.getString(4));
		byte onDelete = parseMysqlForeignKeyAction(fkrdr.getString(5));

		auto srcCol = t.members.find!(a => a.name == colName);
		if (srcCol.length == 0) continue;
		if ((refTableName in s.tables) is null) continue;
		Table refTable = s.tables[refTableName];
		auto refCol = refTable.members.find!(a => a.name == refColName);
		if (refCol.length == 0) continue;

		if (!fkl.any!(a => toUpper(a.name) == toUpper(name)))
		{
			bool pu = isColumnUnique(t, colName);
			bool ru = isColumnUnique(refTable, refColName);
			ForeignKeyDirection fkd = (pu && ru) ? ForeignKeyDirection.OneToOne : (!pu && ru) ? ForeignKeyDirection.OneToMany : ForeignKeyDirection.ManyToMany;

			ForeignKey nfk = new ForeignKey(name, t, refTable, srcCol[0].sqlId, fkd, onUpdate, onDelete);
			nfk.source ~= srcCol[0];
			fkl ~= nfk;
		}
		else
		{
			auto nfk = fkl.find!(a => toUpper(a.name) == toUpper(name));
			nfk[0].source ~= srcCol[0];
		}
	}

	return fkl;
}

private bool isColumnUnique(Table t, string colName)
{
	return t.indexes.any!(a => a.columns.any!(b => b.name == colName) && ((a.isUnique && a.columns.length == 1) || a.isPrimaryKey));
}

private void readParameters(Procedure p, string dbname, SqlConnection conn)
{
	auto routineName = p.name;
	auto cmd = new SqlCommand(conn, i"SELECT PARAMETER_NAME, ORDINAL_POSITION, PARAMETER_MODE, DATA_TYPE, DTD_IDENTIFIER, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE FROM INFORMATION_SCHEMA.PARAMETERS WHERE SPECIFIC_SCHEMA = $(dbname) AND SPECIFIC_NAME = $(routineName) ORDER BY ORDINAL_POSITION");
	scope(exit) cmd.dispose();
	auto prdr = cmd.executeDataReader();
	scope(exit) prdr.close();

	while (prdr.read())
	{
		long ml = prdr.isNull(5) ? 0 : prdr.getLong(5);
		short maxLen = (ml < 0 || ml > short.max) ? cast(short)0 : cast(short)ml;
		byte precision = prdr.isNull(6) ? cast(byte)0 : cast(byte)prdr.getLong(6);
		byte scale = prdr.isNull(7) ? cast(byte)0 : cast(byte)prdr.getLong(7);

		p.parameters ~= new Parameter(
			prdr.isNull(0) ? string.init : prdr.getString(0),
			parseMysqlParameterDirection(prdr.isNull(2) ? null : prdr.getString(2)),
			0,
			parseMysqlDbType(prdr.getString(3), prdr.isNull(4) ? string.init : prdr.getString(4)),
			null,
			maxLen,
			precision,
			scale,
			false
		);
	}
}
