module coalescence.languages.csharp.efcore.dbcontext;

import std.array;
import std.algorithm.searching;
import std.algorithm.iteration;
import std.conv;
import std.path;
import std.stdio;
import std.string;

import coalescence.stringbuilder;
import coalescence.schema;
import coalescence.utility;
import coalescence.database.mssql.types;
import coalescence.languages.csharp.extensions;
import coalescence.languages.csharp.language;

public void generateEFContext(CSharpProjectOptions opts, Schema[] schemata) {
	auto sb = new StringBuilder(8_388_608);
	int tabLevel = 1;

	sb.appendLine("namespace {0}", opts.namespace);
	sb.appendLine("{");
	sb.tabs(tabLevel).appendLine("using System;");
	sb.tabs(tabLevel).appendLine("using System.Collections.Generic;");
	sb.tabs(tabLevel).appendLine("using System.Data;");
	sb.tabs(tabLevel).appendLine("using System.Threading.Tasks;");
	sb.tabs(tabLevel).appendLine("using Microsoft.Data.SqlClient;");
	sb.tabs(tabLevel).appendLine("using Microsoft.EntityFrameworkCore;");
	sb.tabs(tabLevel).appendLine("using Microsoft.EntityFrameworkCore.Metadata;");
	sb.tabs(tabLevel).appendLine("using EllipticBit.Services.Database;");
	sb.appendLine();
	sb.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.3.3.0\")]");
	if (opts.enableEFExtensions) {
		sb.tabs(tabLevel).appendLine("public class {0} : EfCoreDatabaseService<{0}>, IDatabaseService<{0}>", opts.contextName.cleanName());
	}
	else {
		sb.tabs(tabLevel).appendLine("public class {0} : DbContext", opts.contextName.cleanName());
	}
	sb.tabs(tabLevel++).appendLine("{");
	sb.tabs(tabLevel).appendLine("private readonly string _connectionString;");
	foreach (s; schemata.filter!(a => a.hasDatabaseItems)) {
		foreach (t; s.getTables())
			sb.tabs(tabLevel).appendLine("internal virtual DbSet<{1}.{0}> {1}_{0} { get; set; }", t.name, s.name.uppercaseFirst());
		foreach (t; s.getViews())
			sb.tabs(tabLevel).appendLine("internal virtual DbSet<{1}.{0}> {1}_{0} { get; set; }", t.name, s.name.uppercaseFirst());
	}
	sb.appendLine();
	foreach (s; schemata.filter!(a => a.hasDatabaseItems))
		sb.tabs(tabLevel).appendLine("public {0}Schema {0} { get; }", s.name.uppercaseFirst());
	foreach (s; schemata.filter!(a => a.hasDatabaseItems))
		generateSchemaModel(opts, sb, s, tabLevel);
	sb.appendLine();
	if (opts.enableEFExtensions) {
		sb.tabs(tabLevel).appendLine("public {0}() : base() { }", opts.contextName.cleanName());
		sb.appendLine();
		sb.tabs(tabLevel).appendLine("{0} IDatabaseService<{0}>.GetDatabase(IDatabaseServiceOptions options, IDatabaseConflictDetection detector, IDatabaseConflictResolver resolver) => new {0}(options, detector, resolver);", opts.contextName.cleanName());
		sb.appendLine();
		sb.tabs(tabLevel).appendLine("private {0}(IDatabaseServiceOptions options, IDatabaseConflictDetection detector, IDatabaseConflictResolver resolver) : base(options, detector, resolver)", opts.contextName.cleanName());
	}
	else {
		sb.tabs(tabLevel).appendLine("public {0}(DbContextOptions<{0}> options) : base(options)", opts.contextName.cleanName());
	}
	sb.tabs(tabLevel++).appendLine("{");
	foreach (s; schemata.filter!(a => a.hasDatabaseItems))
		sb.tabs(tabLevel).appendLine("this.{0} = new {0}Schema(this);", s.name.uppercaseFirst());
	sb.tabs(tabLevel).appendLine("this._connectionString = this.Database.GetDbConnection().ConnectionString;");
	sb.tabs(--tabLevel).appendLine("}");
	sb.appendLine();
	sb.tabs(tabLevel).appendLine("protected override void OnModelCreating(ModelBuilder modelBuilder)");
	sb.tabs(tabLevel++).appendLine("{");
	foreach (s; schemata.filter!(a => a.hasDatabaseItems)) {
		foreach (t; s.getTables()) {
			sb.tabs(tabLevel).appendLine("modelBuilder.Entity<{1}.{0}>(entity =>", t.name, s.name.uppercaseFirst());
			sb.tabs(tabLevel++).appendLine("{");
			sb.tabs(tabLevel).appendLine("entity.ToTable(\"{0}\", \"{1}\");", t.name, s.name);
			generateIndexModel(opts, sb, t, tabLevel + 1);
			foreach (c; t.members)
				generatePropertyModel(opts, sb, c, tabLevel + 1);
			generateForeignKeyModel(sb, t, tabLevel + 1);
			sb.tabs(--tabLevel).appendLine("});");
		}
		foreach (t; s.getViews()) {
			sb.tabs(tabLevel).appendLine("modelBuilder.Entity<{1}.{0}>(entity =>", t.name, s.name.uppercaseFirst());
			sb.tabs(tabLevel++).appendLine("{");
			sb.tabs(tabLevel).appendLine("entity.HasNoKey().ToView(\"{0}\", \"{1}\");", t.name, s.name);
			foreach (c; t.members)
				generatePropertyModel(opts, sb, c, tabLevel + 1);
			sb.tabs(--tabLevel).appendLine("});");
		}
	}

	sb.tabs(--tabLevel).appendLine("}");
	sb.tabs(--tabLevel).appendLine("}");
	sb.appendLine("}");

	opts.writeFile(sb, opts.contextName.cleanName());
}

private void generateSchemaModel(CSharpProjectOptions opts, StringBuilder sb, Schema s, int tabLevel) {
	sb.appendLine();
	sb.tabs(tabLevel).appendLine("public class {0}Schema", s.name.uppercaseFirst());
	sb.tabs(tabLevel++).appendLine("{");
	sb.tabs(tabLevel).appendLine("private readonly {0} _parent;", opts.contextName.cleanName());
	sb.appendLine();
	foreach (t; s.tables)
		sb.tabs(tabLevel).appendLine("public DbSet<{0}.{1}> {1} => _parent.{0}_{1};", s.name.uppercaseFirst(), t.name);
	foreach (t; s.views) {
		sb.tabs(tabLevel).appendLine("public DbSet<{0}.{1}> {1} => _parent.{0}_{1};", s.name.uppercaseFirst(), t.name);
	}
	sb.appendLine();
	sb.tabs(tabLevel).appendLine("internal {0}Schema({1} parent)", s.name.uppercaseFirst(), opts.contextName.cleanName());
	sb.tabs(tabLevel++).appendLine("{");
	sb.tabs(tabLevel).appendLine("this._parent = parent;");
	sb.tabs(--tabLevel).appendLine("}");
	foreach (p; s.getProcedures()) {
		if (toUpper(s.name) == toUpper("dbo") && !toUpper(p.name).startsWith(toUpper("dt_"))) {
			generateStoredProcedure(sb, p, tabLevel);
		} else if (toUpper(s.name) != toUpper("dbo")) {
			generateStoredProcedure(sb, p, tabLevel);
		}
	}
	sb.tabs(--tabLevel).appendLine("}");
}

private void generateIndexModel(CSharpProjectOptions opts, StringBuilder sb, Table t, int tabLevel) {
	if (t.indexes.any!(a => a.isPrimaryKey)) {
		auto pk = t.indexes.find!(a => a.isPrimaryKey)[0];
		sb.appendLine();
		sb.tabs(tabLevel - 1).append("entity.HasKey(e => new { ");
		for (int i = 0; i < pk.columns.length; i++) {
			sb.append("e.{0}", pk.columns[i].name);
			if (i < pk.columns.length - 1)
				sb.append(", ");
		}
		sb.appendLine(" })");
		sb.tabs(tabLevel).appendLine(".HasName(\"{0}\");", pk.name);
	}

	foreach (ix; t.indexes.filter!(a => !a.isPrimaryKey)) {
		sb.appendLine();
		sb.tabs(tabLevel - 1).append("entity.HasIndex(e => new { ");
		for (int i = 0; i < ix.columns.length; i++) {
			sb.append("e.{0}", ix.columns[i].name);
			if (i < ix.columns.length - 1)
				sb.append(", ");
		}
		sb.appendLine(" })");
		sb.tabs(tabLevel).append(".HasDatabaseName(\"{0}\")", ix.name);
		if (ix.isUnique) {
			sb.appendLine();
			sb.tabs(tabLevel).append(".IsUnique()");
		}
		sb.appendLine(";");
	}
}

private void generateForeignKeyModel(StringBuilder sb, Table t, int tabLevel) {
	foreach (fk; t.foreignKeys) {
		string fkSrcId = fk.sourceId();
		string fkTgtId = fk.targetId();
		sb.appendLine();
		if (fk.direction == ForeignKeyDirection.OneToOne) {
			sb.tabs(tabLevel - 1).appendLine("entity.HasOne(d => d.{0})", fkSrcId);
			sb.tabs(tabLevel).appendLine(".WithOne(p => p.{0})", fkTgtId);
			sb.tabs(tabLevel).append(".HasForeignKey<{0}.{1}>(d => new { ", t.parent.name.uppercaseFirst(), t.name);
		}
		if (fk.direction == ForeignKeyDirection.OneToMany) {
			sb.tabs(tabLevel - 1).appendLine("entity.HasOne(d => d.{0})", fkSrcId);
			sb.tabs(tabLevel).appendLine(".WithMany(p => p.{0})", fkTgtId);
			sb.tabs(tabLevel).append(".HasForeignKey(d => new { ");
		}
		if (fk.direction == ForeignKeyDirection.ManyToMany) {
			sb.tabs(tabLevel - 1).appendLine("entity.HasMany(d => d.{0})", fkSrcId);
			sb.tabs(tabLevel).appendLine(".WithMany(p => p.{0})", fkTgtId);
			sb.tabs(tabLevel).append(".HasForeignKey(d => new { ");
		}

		for (int i = 0; i < fk.source.length; i++) {
			sb.append("d.{0}", fk.source[i].name);
			if (i < fk.source.length - 1)
				sb.append(", ");
		}
		sb.appendLine(" })");
		sb.tabs(tabLevel).appendLine(".OnDelete(DeleteBehavior.{0})", (fk.onDelete == ForeignKeyAction.Cascade ? "Cascade" : fk.onDelete == ForeignKeyAction.NoAction ? "Restrict" : "SetNull"));
		sb.tabs(tabLevel).appendLine(".HasConstraintName(\"{0}\");", fk.name);
	}
}

private void generatePropertyModel(CSharpProjectOptions opts, StringBuilder sb, DataMember c, int tabLevel) {
	sb.appendLine();
	sb.tabs(tabLevel - 1).append("entity.Property(e => e.{0})", c.name);
	sb.appendLine();
	sb.tabs(tabLevel).append(".HasColumnName(\"{0}\")", c.name);
	sb.appendLine();
	sb.tabs(tabLevel).append(".HasColumnType(\"{0}\")", getMssqlTypeFromColumn(c));
	sb.appendLine();
	if (c.precision != 0) {
		if (c.scale != 0) {
			sb.tabs(tabLevel).append(".HasPrecision({0}, {1})", to!string(c.precision), to!string(c.scale));
		}
		else {
			sb.tabs(tabLevel).append(".HasPrecision({0})", to!string(c.precision));
		}
	}

	if (isVariableLengthType(c.sqlType) && c.maxLength > 0) {
		sb.appendLine();
		sb.tabs(tabLevel).append(".HasMaxLength({0})", to!string(c.maxLength));
	}

	if (c.sqlType == SqlDbType.Timestamp) {
		sb.appendLine();
		sb.tabs(tabLevel).append(".IsConcurrencyToken()");
		sb.appendLine();
		sb.tabs(tabLevel).append(".ValueGeneratedOnAddOrUpdate()");
	}
	else if (c.isComputed) {
		sb.appendLine();
		sb.tabs(tabLevel).append(".ValueGeneratedOnAddOrUpdate()");
	}
	else if (c.isIdentity) {
		sb.appendLine();
		sb.tabs(tabLevel).append(".ValueGeneratedOnAdd()");
	}

	if (c.hasDefault) {
		sb.appendLine();
		sb.tabs(tabLevel).append(".HasDefaultValue()");
	}

	if (!c.isNullable) {
		sb.appendLine();
		sb.tabs(tabLevel).append(".IsRequired()");
	}

	sb.appendLine(";");
}

private void generateStoredProcedure(StringBuilder sb, Procedure p, int tabLevel) {
	sb.appendLine();
	if (p.parameters.any!(a => (a.direction == ParameterDirection.ReturnValue ||
								a.direction == ParameterDirection.InputOutput ||
								a.direction == ParameterDirection.Output) &&
								a.type != SqlDbType.Udt)) {
		sb.tabs(tabLevel).appendLine("public class {0}Result", p.name);
		sb.tabs(tabLevel++).appendLine("{");
		foreach (pp; p.parameters.filter!(a => (a.direction == ParameterDirection.ReturnValue ||
													a.direction == ParameterDirection.InputOutput ||
													a.direction == ParameterDirection.Output) &&
													a.type != SqlDbType.Udt)) {
			sb.tabs(tabLevel).appendLine("public {0} {1} { get; internal set; }", getTypeFromSqlType(pp.type, pp.isNullable), pp.name);
		}
		sb.tabs(--tabLevel).appendLine("}");
		sb.appendLine();
		sb.tabs(tabLevel).append("public async Task<{0}Result> {0}(", p.name);
	} else {
		sb.tabs(tabLevel).append("public async Task<SqlDataReader> {0}(", p.name);
	}
	bool hasParam = false;
	foreach (pp; p.parameters.filter!(a => a.direction == ParameterDirection.Input)) {
		hasParam = true;
		if (pp.type != SqlDbType.Udt) {
			sb.append("{0} {1}, ", getTypeFromSqlType(pp.type, false), pp.name);
		} else {
			sb.append("IEnumerable<{0}.{1}Udt> {2}, ", pp.udtType.parent.name, pp.udtType.name, pp.name);
		}
	}
	foreach (pp; p.parameters.filter!(a => a.direction == ParameterDirection.InputOutput && a.type != SqlDbType.Udt)) {
		hasParam = true;
		sb.append("{0} {1} = null, ", getTypeFromSqlType(pp.type, true), pp.name);
	}
	if (hasParam) {
		sb.removeRight(2);
	}
	if (p.parameters.any!(a => (a.direction == ParameterDirection.ReturnValue ||
								a.direction == ParameterDirection.InputOutput ||
								a.direction == ParameterDirection.Output) &&
								a.type != SqlDbType.Udt)) {
		sb.appendLine(")");
	} else {
		if (p.parameters.length == 0) {
			sb.appendLine("bool noResult = true)");
		} else {
			sb.appendLine(", bool noResult = true)");
		}
	}
	sb.tabs(tabLevel++).appendLine("{");
	sb.tabs(tabLevel).appendLine("var dbc = new SqlConnection(_parent._connectionString);");
	sb.tabs(tabLevel).appendLine("var cmd = dbc.CreateCommand();");
	sb.tabs(tabLevel).appendLine("await dbc.OpenAsync();");
	sb.tabs(tabLevel).appendLine("cmd.CommandText = \"[{0}].[{1}]\";", p.parent.sqlName, p.sqlName);
	sb.tabs(tabLevel).appendLine("cmd.CommandType = CommandType.StoredProcedure;");
	foreach (pp; p.parameters) {
		if (pp.type != SqlDbType.Udt) {
			auto direction = pp.direction == ParameterDirection.Input ? "Input" :
				pp.direction == ParameterDirection.InputOutput ? "InputOutput" :
				"ReturnValue";
			sb.tabs(tabLevel).appendLine("var p{0} = new SqlParameter(\"@{0}\", SqlDbType.{1}) { Value = (object){0} ?? DBNull.Value, Direction = ParameterDirection.{2} };", pp.name, to!string(pp.type), direction);
			sb.tabs(tabLevel).appendLine("cmd.Parameters.Add(p{0});", pp.name);
		} else if (pp.type == SqlDbType.Udt) {
			sb.tabs(tabLevel).appendLine("var dt{0} = new DataTable();", pp.name);
			foreach (c; pp.udtType.members)
				sb.appendLine("dt{0}.Columns.Add(\"{1}\", typeof({2}));", pp.name, c.name, getTypeFromSqlType(c.sqlType, c.isNullable));
			sb.tabs(tabLevel).appendLine("foreach(var t in {0})", pp.name);
			sb.tabs(tabLevel++).appendLine("{");
			sb.tabs(tabLevel).append("dt{0}.Columns.Add(", pp.name);
			for (int i = 0; i < pp.udtType.members.length; i++) {
				auto c = pp.udtType.members[i];
				sb.append("t.{0}", c.name);
				if (i < pp.udtType.members.length - 1)
					sb.append(", ");
			}
			sb.appendLine(");");
			sb.tabs(--tabLevel).appendLine("}");
			sb.tabs(tabLevel).appendLine("var p{0} = cmd.Parameters.AddWithValue(\"@{0}\", dt{0});", pp.name);
			sb.tabs(tabLevel).appendLine("p{0}.SqlDbType = SqlDbType.Structured;", pp.name);
			sb.tabs(tabLevel).appendLine("p{0}.TypeName = \"[{1}].[{2}]\";", pp.name, pp.udtType.parent.name, pp.udtType.name);
		}
	}
	if (p.parameters.any!(a => (a.direction == ParameterDirection.ReturnValue ||
								a.direction == ParameterDirection.InputOutput ||
								a.direction == ParameterDirection.Output) &&
								a.type != SqlDbType.Udt)) {
		sb.tabs(tabLevel).appendLine("await cmd.ExecuteNonQueryAsync();");
		sb.tabs(tabLevel).appendLine("var rv = new {0}Result();", p.name);
		foreach (pp; p.parameters.filter!(a => (a.direction == ParameterDirection.ReturnValue ||
													a.direction == ParameterDirection.InputOutput ||
													a.direction == ParameterDirection.Output) &&
													a.type != SqlDbType.Udt)) {
			sb.tabs(tabLevel).appendLine("rv.{0} = p{0}.Value != DBNull.Value ? ({1})p{0}.Value : null;", pp.name, getTypeFromSqlType(pp.type, pp.isNullable));
		}
		sb.tabs(tabLevel).appendLine("return rv;");
	} else {
		sb.tabs(tabLevel++).appendLine("if (noResult) {");
		sb.tabs(tabLevel).appendLine("await cmd.ExecuteNonQueryAsync();");
		sb.tabs(tabLevel).appendLine("dbc.Close();");
		sb.tabs(tabLevel).appendLine("cmd.Dispose();");
		sb.tabs(tabLevel).appendLine("dbc.Dispose();");
		sb.tabs(tabLevel).appendLine("return null;");
		sb.tabs(--tabLevel).appendLine("}");
		sb.tabs(tabLevel).appendLine("return await cmd.ExecuteReaderAsync(CommandBehavior.CloseConnection);");
	}
	sb.tabs(--tabLevel).appendLine("}");
}
