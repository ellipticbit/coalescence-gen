module coalescence.database.mssql.schemareader;

import std.array;
import std.algorithm.searching;
import std.algorithm.iteration;
import std.algorithm.sorting;
import std.algorithm.mutation;
import std.conv;
import std.stdio;
import std.string;
import std.uni;

import phobos.database.sql;

import coalescence.globals;
import coalescence.schema;
import coalescence.utility;
import coalescence.database.mssql.types;

public Schema[] readMssqlSchemata(SqlConnection conn)
{
	static import std.algorithm.mutation;

	Schema[] sl;

	//Read schemas
	{
		auto cmd = new SqlCommand(conn, i"SELECT [Name] = CONVERT(VARCHAR(256), ss.[name]), [ID] = ss.[schema_id] FROM [sys].[schemas] AS ss WHERE ss.[name] <> 'sys' AND ss.[name] <> 'guest' AND ss.[name] <> 'INFORMATION_SCHEMA' AND ss.[name] NOT LIKE 'db[_]%' ORDER BY ss.[name]");
		scope(exit) cmd.dispose();
		auto schemardr = cmd.executeDataReader();
		scope(exit) schemardr.close();
		while (schemardr.read())
		{
			sl ~= new Schema(schemardr.getInt(1), schemardr.getString(0));
		}
	}

	//Read tables and indexes
	foreach (s; sl)
	{
		//Read tables
		{
			auto cmd = new SqlCommand(conn, i"SELECT CONVERT(VARCHAR(256), syt.[name]), syt.[object_id], MAX(trg.[object_id]) FROM [sys].[tables] AS syt LEFT JOIN [sys].[triggers] AS trg ON trg.[parent_id] = syt.[object_id] WHERE syt.[schema_id] = $(s.sqlId) AND syt.[type] = 'U' GROUP BY CONVERT(VARCHAR(256), syt.[name]), syt.[object_id] ORDER BY CONVERT(VARCHAR(256), syt.[name])");
			scope(exit) cmd.dispose();
			auto tablerdr = cmd.executeDataReader();
			scope(exit) tablerdr.close();
			while (tablerdr.read())
			{
				auto nt = new Table(s, tablerdr.getInt(1), tablerdr.getString(0));
				if ((nt.name in s.udts) is null) {
					s.tables[nt.name] = nt;
				} else {
					writeError("Table '" ~ nt.name ~ "' already exists in schema '" ~ s.name ~ "'");
				}

				nt.hasTrigger = !tablerdr.isNull(2);
			}
		}

		foreach (t; s.tables.values)
		{
			//Read columns
			t.members ~= readColumns(t, conn);
		}

		foreach (t; s.tables.values)
		{
			//Read indexes
			t.indexes ~= readIndexes(t.sqlId, t.members, conn);
		}

		//Remove any tables that do not have a Primary Key
		auto nopk = s.tables.values.filter!(t => !t.indexes.any!(a => a.isPrimaryKey)).array;
		foreach (t; nopk)
		{
			writeln("WARN: Table [" ~ s.name ~ "].[" ~ t.name ~ "] does not have a primary key defined. Skipping.");
			s.tables.remove(t.name);
		}
	}

	//Read views
	foreach (s; sl)
	{
		//Read views
		{
			auto cmd = new SqlCommand(conn, i"SELECT CONVERT(VARCHAR(256), syt.[name]), syt.[object_id] FROM [sys].[views] AS syt WHERE syt.[schema_id] = $(s.sqlId) AND syt.[type] = 'V' ORDER BY syt.[name]");
			scope(exit) cmd.dispose();
			auto viewrdr = cmd.executeDataReader();
			scope(exit) viewrdr.close();
			while (viewrdr.read())
			{
				auto nv = new View(s, viewrdr.getInt(1), viewrdr.getString(0));
				if ((nv.name in s.udts) is null) {
					s.views[nv.name] = nv;
				} else {
					writeError("View '" ~ nv.name ~ "' already exists in schema '" ~ s.name ~ "'");
				}
			}
		}

		//Read columns
		foreach (t; s.views.values) {
			t.members ~= readColumns(t, conn);
		}
	}

	//Read UDTs
	foreach (s; sl)
	{
		//Read tables
		{
			auto cmd = new SqlCommand(conn, i"SELECT CONVERT(VARCHAR(256), syt.[name]), syt.[type_table_object_id] FROM [sys].[table_types] AS syt WHERE syt.[schema_id] = $(s.sqlId) ORDER BY syt.[name]");
			scope(exit) cmd.dispose();
			auto udtrdr = cmd.executeDataReader();
			scope(exit) udtrdr.close();
			while (udtrdr.read())
			{
				auto nu = new Udt(s, udtrdr.getInt(1), udtrdr.getString(0));
				if ((nu.name in s.udts) is null) {
					s.udts[nu.name] = nu;
				} else {
					writeError("UDT '" ~ nu.name ~ "' already exists in schema '" ~ s.name ~ "'");
				}
			}
		}

		//Read columns
		foreach (t; s.udts.values) {
			t.members ~= readColumns(t, conn);
		}
	}

	//Read foreign keys
	foreach (s; sl)
	{
		foreach (t; s.tables.values) {
			ForeignKey[] fkl = readForeignKeys(t, sl, conn);
			t.foreignKeys ~= fkl.sort!((a, b) => a.name.toUpper() < b.name.toUpper()).array;
		}
	}

	//Read stored procedures
	foreach (s; sl)
	{
		{
			auto cmd = new SqlCommand(conn, i"SELECT CONVERT(VARCHAR(256), syp.[name]), syp.[object_id] FROM sys.[procedures] AS syp WHERE syp.[schema_id] = $(s.sqlId) ORDER BY syp.[name]");
			scope(exit) cmd.dispose();
			auto procrdr = cmd.executeDataReader();
			scope(exit) procrdr.close();
			while (procrdr.read()) {
				auto np = new Procedure(s, procrdr.getInt(1), procrdr.getString(0));
				if ((np.name in s.procedures) is null) {
					s.procedures[np.name] = np;
				} else {
					writeError("Stored Procedure '" ~ np.name ~ "' already exists in schema '" ~ s.name ~ "'");
				}
			}
		}

		foreach (t; s.procedures.values)
		{
			int procId = t.sqlId;
			auto cmd = new SqlCommand(conn, i"SELECT [typeName] = CONVERT(VARCHAR(256), CASE syp.[system_type_id] WHEN 243 THEN 'TABLE TYPE' ELSE syt.[name] END), CONVERT(VARCHAR(256), syp.[name]), syp.[parameter_id], CONVERT(SMALLINT, syp.[system_type_id]), syp.[max_length], syp.[precision], syp.[scale], CONVERT(TINYINT, syp.[is_output]), CONVERT(TINYINT, syp.[is_readonly]), [udtOid] = CONVERT(INT, CASE syp.[system_type_id] WHEN 243 THEN sytt.[type_table_object_id] ELSE -1 END)FROM [sys].[parameters] AS syp INNER JOIN sys.[types] AS syt ON syt.[user_type_id] = syp.[user_type_id] AND syt.[user_type_id] <> 240 LEFT JOIN sys.[table_types] AS sytt ON sytt.[user_type_id] = syp.[user_type_id]WHERE syp.[object_id] = $(procId) ORDER BY syp.[parameter_id]");
			scope(exit) cmd.dispose();
			auto paramrdr = cmd.executeDataReader();
			scope(exit) paramrdr.close();
			while (paramrdr.read())
			{
				auto udt = paramrdr.isNull(9) ? null : getUdt(paramrdr.getInt(9), sl);
				t.parameters ~= new Parameter(
					paramrdr.getString(1).replace("@", ""),
					parseParameterDirection(paramrdr.getInt(2), to!bool(paramrdr.getByte(7))),
					paramrdr.getInt(8),
					parseMssqlDbType(paramrdr.getString(0)),
					udt,
					paramrdr.getShort(4),
					paramrdr.getByte(5),
					paramrdr.getByte(6),
					to!bool(paramrdr.getByte(8))
				);
			}
		}
	}

	return sl.sort!((a, b) => a.name.toUpper() < b.name.toUpper()).array;
}

private DataMember[] readColumns(DataObject t, SqlConnection conn)
{
	int oid = t.sqlId;
	auto cmd = new SqlCommand(conn, i"SELECT CONVERT(VARCHAR(256), syt.[name]), CONVERT(VARCHAR(256), syc.[name]), syc.[column_id], syc.[max_length], syc.[precision], syc.[scale], CONVERT(TINYINT, CASE syc.[default_object_id] WHEN 0 THEN 0 ELSE 1 END), COALESCE(CONVERT(VARCHAR(512), sdc.[definition]), ''), CONVERT(TINYINT, syc.[is_nullable]), CONVERT(TINYINT, syc.[is_identity]), CONVERT(TINYINT, syc.[is_computed]) FROM sys.[columns] AS syc INNER JOIN [sys].[types] AS syt ON syt.[user_type_id] = syc.[user_type_id] AND syt.[user_type_id] <> 240 LEFT JOIN [sys].[default_constraints] AS sdc ON sdc.[object_id] = syc.[default_object_id]WHERE syc.[object_id] = $(oid) ORDER BY syc.[name]");
	scope(exit) cmd.dispose();
	auto crdr = cmd.executeDataReader();
	scope(exit) crdr.close();

	DataMember[] cl;
	while (crdr.read())
	{
		cl ~= new DataMember(t,
			crdr.getInt(2),
			crdr.getString(1),
			parseMssqlDbType(crdr.getString(0)),
			crdr.getShort(3),
			crdr.getByte(4),
			crdr.getByte(5),
			to!bool(crdr.getByte(6)),
			crdr.getString(7),
			to!bool(crdr.getByte(8)),
			to!bool(crdr.getByte(9)),
			to!bool(crdr.getByte(10))
		);
	}
	return cl;
}

private Index[] readIndexes(int oid, DataMember[] cols, SqlConnection conn)
{
	auto cmd = new SqlCommand(conn, i"SELECT [Name] = CONVERT(VARCHAR(256), syi.[name]), [IsUnique] = CONVERT(TINYINT, syi.[is_unique]), [IsPrimary] = CONVERT(TINYINT, syi.[is_primary_key]), [CID] = sic.[column_id] FROM [sys].[index_columns] AS sic INNER JOIN [sys].[indexes] AS syi ON syi.[object_id] = sic.[object_id] AND syi.[index_id] = sic.[index_id] WHERE sic.[object_id] = $(oid) ORDER BY syi.[name]");
	scope(exit) cmd.dispose();
	auto irdr = cmd.executeDataReader();
	scope(exit) irdr.close();

	Index[] il;
	while (irdr.read())
	{
		int cid = irdr.getInt(3);
		auto index = il.find!(a => toUpper(a.name) == toUpper(irdr.getString(0))).array;
		if (index.length == 0)
		{
			Index ni = new Index(
				irdr.getString(0),
				to!bool(irdr.getByte(1)),
				to!bool(irdr.getByte(2))
			);
			ni.columns ~= cols.find!(a => a.sqlId == cid)[0];
			il ~= ni;
		}
		else
		{
			index[0].columns ~= cols.find!(a => a.sqlId == cid)[0];
		}
	}

	return il;
}

private ForeignKey[] readForeignKeys(Table t, Schema[] schemata, SqlConnection conn)
{
	int oid = t.sqlId;
	auto cmd = new SqlCommand(conn, i"SELECT CONVERT(VARCHAR(256), sfk.[name]), sfc.[parent_object_id], sfc.[parent_column_id], sfc.[referenced_object_id], sfc.[referenced_column_id], sfk.[update_referential_action], sfk.[delete_referential_action] FROM [sys].[foreign_key_columns] AS sfc INNER JOIN [sys].[foreign_keys] AS sfk ON sfk.[object_id] = sfc.[constraint_object_id] WHERE sfc.[parent_object_id] = $(oid) ORDER BY sfk.[name]");
	scope(exit) cmd.dispose();
	auto fkrdr = cmd.executeDataReader();
	scope(exit) fkrdr.close();

	ForeignKey[] fkl;
	while (fkrdr.read())
	{
		string name = fkrdr.getString(0);
		int poid = fkrdr.getInt(1);
		int pcid = fkrdr.getInt(2);
		int roid = fkrdr.getInt(3);
		int rcid = fkrdr.getInt(4);
		auto pc = getTableColumn(poid, pcid, schemata);
		auto rc = getTableColumn(roid, rcid, schemata);

		//Verify that we have tables for this Foreign Key
		if (pc is null || rc is null) continue;

		if (!fkl.any!(a => toUpper(a.name) == toUpper(name)))
		{
			bool pu = isColumnIndexUnique(poid, pcid, schemata);
			bool ru = isColumnIndexUnique(roid, rcid, schemata);
			ForeignKeyDirection fkd = (pu && ru) ? ForeignKeyDirection.OneToOne : (!pu && ru) ? ForeignKeyDirection.OneToMany : ForeignKeyDirection.ManyToMany;

			ForeignKey nfk = new ForeignKey(
				name,
				cast(Table)pc.parent,
				cast(Table)rc.parent,
				pcid,
				fkd,
				fkrdr.getByte(5),
				fkrdr.getByte(6)
			);
			nfk.source ~= pc;
			fkl ~= nfk;
		}
		else
		{
			auto nfk = fkl.find!(a => toUpper(a.name) == toUpper(name))[0];
			nfk.source ~= pc;
		}
	}

	return fkl;
}

private bool isColumnIndexUnique(int oid, int cid, Schema[] schemata)
{
	foreach (s; schemata) {
		if (s.tables.values.any!(a => a.sqlId == oid))
		{
			auto tbl = s.tables.values.find!(a => a.sqlId == oid)[0];
			if (tbl.indexes.any!(a => a.columns.any!(b => b.sqlId == cid) && ((a.isUnique && a.columns.length == 1 /*TODO: This is a HACK it is possible that this will generate false negatives.*/) || a.isPrimaryKey)))
				return true;
		}
	}
	return false;
}

private DataMember getTableColumn(int oid, int cid, Schema[] schemata)
{
	foreach (s; schemata)
		if (s.tables.values.any!(a => a.sqlId == oid)) {
			auto t = s.tables.values.filter!(a => a.sqlId == oid).array[0];
			return t.members.filter!(b => b.sqlId == cid).array[0];
		}
	return null;
}

private Udt getUdt(int oid, Schema[] schemata)
{
	foreach (s; schemata)
		if (s.udts.values.any!(a => a.sqlId == oid))
			return s.udts.values.filter!(a => a.sqlId == oid).array[0];
	return null;
}

private ParameterDirection parseParameterDirection(int paramId, bool isOutput)
{
	if (isOutput && paramId == 0) return ParameterDirection.ReturnValue;
	else if (!isOutput) return ParameterDirection.Input;
	else return ParameterDirection.InputOutput;
}
