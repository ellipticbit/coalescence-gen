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

public string getMssqlDefaultValue(DataMember mm) {
	if (mm.defaultValue is null || mm.defaultValue.length < 5 || mm.defaultValue == "(N'')") return string.init;
	string modified = mm.defaultValue[2..$-2];
	if (modified[0] == '\'') modified = modified[1..$];

	if (mm.sqlType == SqlDbType.Bit) return modified == "0" ? "false" : "true";
	if (mm.sqlType == SqlDbType.VarChar || mm.sqlType == SqlDbType.NVarChar || mm.sqlType == SqlDbType.Char || mm.sqlType == SqlDbType.NChar || mm.sqlType == SqlDbType.Text || mm.sqlType == SqlDbType.NText) return "\"" ~ modified ~ "\"";
	if (mm.sqlType == SqlDbType.Decimal) return modified ~ "M";

	return modified;
}
