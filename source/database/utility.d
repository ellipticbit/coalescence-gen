module coalescence.database.utility;

import coalescence.schema;

import std.algorithm;
import std.array;
import std.string;

public string cleanForeignKeyName(string name) {
	name = name.strip();
	if (name.toUpper().endsWith("_ID".toUpper())) return name[0..$-3];
	if (name.toUpper().endsWith("Id".toUpper())) return name[0..$-2];
	return name;
}

public ForeignKey[] getForeignKeysTargetTable(int oid, Schema[] schemata) {
	ForeignKey[] fkl;
	foreach (s; schemata) {
		foreach (t; s.tables) {
			fkl ~= (cast(Table)t).foreignKeys.filter!(a => a.targetTable.sqlId == oid)().array;
		}
	}
	return fkl;
}

public ForeignKey[] getForeignKeysSourceTable(int oid, Schema[] schemata) {
	ForeignKey[] fkl;
	foreach (s; schemata) {
		foreach (t; s.tables) {
			fkl ~= (cast(Table)t).foreignKeys.filter!(a => a.sourceTable.sqlId == oid)().array;
		}
	}
	return fkl;
}