module coalescence.languages.csharp.efcore.dbcontext;

import std.array;
import std.algorithm.searching;
import std.algorithm.iteration;
import std.conv;
import std.path;
import std.stdio;
import std.string;

import phobos.text.stringbuilder;
import coalescence.globals;
import coalescence.schema;
import coalescence.utility;
import coalescence.database.mssql.types;
import coalescence.database.mysql.types;
import coalescence.database.postgresql.types;
import coalescence.database.utility;
import coalescence.languages.csharp.extensions;
import coalescence.languages.csharp.language;
import coalescence.languages.csharp.data;

public void generateEFContext(CSharpProjectOptions opts, Schema[] schemata) {
	auto sb = new StringBuilder(8_388_608);
	int tabLevel = 1;

	sb.appendLine(i"namespace $(opts.namespace)");
	sb.appendLine("{");
	sb.tabs(tabLevel).appendLine("using System;");
	sb.tabs(tabLevel).appendLine("using System.Collections.Generic;");
	sb.tabs(tabLevel).appendLine("using System.Data;");
	sb.tabs(tabLevel).appendLine("using System.Threading.Tasks;");
	if (databaseProvider == DatabaseProvider.SqlServer)
		sb.tabs(tabLevel).appendLine("using Microsoft.Data.SqlClient;");
	else if (databaseProvider == DatabaseProvider.MySql)
		sb.tabs(tabLevel).appendLine("using MySqlConnector;");
	else if (databaseProvider == DatabaseProvider.PostgreSql) {
		sb.tabs(tabLevel).appendLine("using Npgsql;");
		sb.tabs(tabLevel).appendLine("using NpgsqlTypes;");
	}
	sb.tabs(tabLevel).appendLine("using Microsoft.EntityFrameworkCore;");
	sb.tabs(tabLevel).appendLine("using Microsoft.EntityFrameworkCore.Metadata;");
	sb.tabs(tabLevel).appendLine("using EllipticBit.Services.Database;");
	sb.appendLine();
	sb.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"2.0.0.0\")]");
	if (opts.enableEFExtensions) {
		sb.tabs(tabLevel).appendLine(i"public $(opts.enableEFContextMocking ? string.init : "sealed ")partial class $(opts.contextName.cleanName()) : EfCoreDatabaseService<$(opts.contextName.cleanName())>");
	}
	else {
		sb.tabs(tabLevel).appendLine(i"public $(opts.enableEFContextMocking ? string.init : "sealed ")partial class $(opts.contextName.cleanName()) : DbContext");
	}
	sb.tabs(tabLevel++).appendLine("{");
	foreach (s; schemata.filter!(a => a.hasDatabaseItems)) {
		foreach (t; s.getTables())
			sb.tabs(tabLevel).appendLine(i"$(opts.enableEFContextMocking ? "public virtual" : "internal") DbSet<$(s.name.uppercaseFirst()).$(t.name)> $(s.name.uppercaseFirst())_$(t.name) { get; set; }");
		foreach (t; s.getViews())
			sb.tabs(tabLevel).appendLine(i"$(opts.enableEFContextMocking ? "public virtual" : "internal") DbSet<$(s.name.uppercaseFirst()).$(t.name)> $(s.name.uppercaseFirst())_$(t.name) { get; set; }");
	}
	sb.appendLine();
	foreach (s; schemata.filter!(a => a.hasDatabaseItems))
		sb.tabs(tabLevel).appendLine(i"public $(s.name.uppercaseFirst())Schema $(s.name.uppercaseFirst()) { get; }");
	foreach (s; schemata.filter!(a => a.hasDatabaseItems))
		generateSchemaModel(opts, sb, s, tabLevel);
	sb.appendLine();
	sb.tabs(tabLevel).appendLine(i"public $(opts.contextName.cleanName())(DbContextOptions<$(opts.contextName.cleanName())> options) : base(options)");
	sb.tabs(tabLevel++).appendLine("{");
	foreach (s; schemata.filter!(a => a.hasDatabaseItems))
		sb.tabs(tabLevel).appendLine(i"this.$(s.name.uppercaseFirst()) = new $(s.name.uppercaseFirst())Schema(this);");
	sb.tabs(--tabLevel).appendLine("}");
	sb.appendLine();
	sb.tabs(tabLevel).appendLine("protected override void OnModelCreating(ModelBuilder modelBuilder)");
	sb.tabs(tabLevel++).appendLine("{");
	foreach (s; schemata.filter!(a => a.hasDatabaseItems)) {
		foreach (t; s.getTables()) {
			sb.tabs(tabLevel).appendLine(i"modelBuilder.Entity<$(s.name.uppercaseFirst()).$(t.name)>(entity =>");
			sb.tabs(tabLevel++).appendLine("{");
			sb.tabs(tabLevel).appendLine(i"entity.ToTable(\"$(t.name)\", \"$(s.name)\"$((t.hasTrigger ? ", tb => tb.HasTrigger(\"" ~ t.name ~ "_Trigger\")" : string.init)));");
			generateIndexModel(opts, sb, t, tabLevel + 1);
			foreach (c; t.members)
				generatePropertyModel(opts, sb, c, tabLevel + 1);
			generateForeignKeyModel(sb, t, tabLevel + 1);
			sb.tabs(--tabLevel).appendLine("});");
		}
		foreach (t; s.getViews()) {
			sb.tabs(tabLevel).appendLine(i"modelBuilder.Entity<$(s.name.uppercaseFirst()).$(t.name)>(entity =>");
			sb.tabs(tabLevel++).appendLine("{");
			sb.tabs(tabLevel).appendLine(i"entity.HasNoKey().ToView(\"$(t.name)\", \"$(s.name)\");");
			foreach (c; t.members)
				generatePropertyModel(opts, sb, c, tabLevel + 1);
			sb.tabs(--tabLevel).appendLine("});");
		}
	}

	sb.tabs(--tabLevel).appendLine("}");
	sb.tabs(--tabLevel).appendLine("}");
	sb.appendLine("}");

	opts.writeFile(sb.toString(), opts.contextName.cleanName());
}

private void generateSchemaModel(CSharpProjectOptions opts, StringBuilder sb, Schema s, int tabLevel) {
	sb.appendLine();
	sb.tabs(tabLevel).appendLine(i"public class $(s.name.uppercaseFirst())Schema");
	sb.tabs(tabLevel++).appendLine("{");
	sb.tabs(tabLevel).appendLine(i"private readonly $(opts.contextName.cleanName()) _parent;");
	sb.appendLine();
	foreach (t; s.tables)
		sb.tabs(tabLevel).appendLine(i"public DbSet<$(s.name.uppercaseFirst()).$(t.name)> $(t.name) => _parent.$(s.name.uppercaseFirst())_$(t.name);");
	foreach (t; s.views) {
		sb.tabs(tabLevel).appendLine(i"public DbSet<$(s.name.uppercaseFirst()).$(t.name)> $(t.name) => _parent.$(s.name.uppercaseFirst())_$(t.name);");
	}
	sb.appendLine();
	sb.tabs(tabLevel).appendLine(i"internal $(s.name.uppercaseFirst())Schema($(opts.contextName.cleanName()) parent)");
	sb.tabs(tabLevel++).appendLine("{");
	sb.tabs(tabLevel).appendLine("this._parent = parent;");
	sb.tabs(--tabLevel).appendLine("}");
	foreach (p; s.getProcedures()) {
		// Stored-routine wrappers use the raw ADO.NET provider client
		// (SqlClient/MySqlConnector/Npgsql), so dispatch to the generator that
		// matches the database the schema was read from.
		if (databaseProvider == DatabaseProvider.SqlServer) {
			// SQL Server: skip the `dt_` system procedures in the dbo schema.
			if (toUpper(s.name) == toUpper("dbo") && !toUpper(p.name).startsWith(toUpper("dt_"))) {
				generateStoredProcedure(sb, p, tabLevel);
			} else if (toUpper(s.name) != toUpper("dbo")) {
				generateStoredProcedure(sb, p, tabLevel);
			}
		} else if (databaseProvider == DatabaseProvider.MySql) {
			generateMySqlStoredProcedure(sb, p, tabLevel);
		} else if (databaseProvider == DatabaseProvider.PostgreSql) {
			generatePostgresStoredProcedure(sb, p, tabLevel);
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
			sb.append(i"e.$(pk.columns[i].name)");
			if (i < pk.columns.length - 1)
				sb.append(", ");
		}
		sb.appendLine(" })");
		sb.tabs(tabLevel).appendLine(i".HasName(\"$(pk.name)\");");
	}

	foreach (ix; t.indexes.filter!(a => !a.isPrimaryKey)) {
		sb.appendLine();
		sb.tabs(tabLevel - 1).append("entity.HasIndex(e => new { ");
		for (int i = 0; i < ix.columns.length; i++) {
			sb.append(i"e.$(ix.columns[i].name)");
			if (i < ix.columns.length - 1)
				sb.append(", ");
		}
		sb.appendLine(" })");
		sb.tabs(tabLevel).append(i".HasDatabaseName(\"$(ix.name)\")");
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
			sb.tabs(tabLevel - 1).appendLine(i"entity.HasOne(d => d.$(fkSrcId))");
			sb.tabs(tabLevel).appendLine(i".WithOne(p => p.$(fkTgtId))");
			sb.tabs(tabLevel).append(i".HasForeignKey<$(t.parent.name.uppercaseFirst()).$(t.name)>(d => new { ");
		}
		if (fk.direction == ForeignKeyDirection.OneToMany) {
			sb.tabs(tabLevel - 1).appendLine(i"entity.HasOne(d => d.$(fkSrcId))");
			sb.tabs(tabLevel).appendLine(i".WithMany(p => p.$(fkTgtId))");
			sb.tabs(tabLevel).append(".HasForeignKey(d => new { ");
		}
		if (fk.direction == ForeignKeyDirection.ManyToMany) {
			sb.tabs(tabLevel - 1).appendLine(i"entity.HasMany(d => d.$(fkSrcId))");
			sb.tabs(tabLevel).appendLine(i".WithMany(p => p.$(fkTgtId))");
			sb.tabs(tabLevel).append(".HasForeignKey(d => new { ");
		}

		for (int i = 0; i < fk.source.length; i++) {
			sb.append(i"d.$(fk.source[i].name)");
			if (i < fk.source.length - 1)
				sb.append(", ");
		}
		sb.appendLine(" })");
		sb.tabs(tabLevel).appendLine(i".OnDelete(DeleteBehavior.$((fk.onDelete == ForeignKeyAction.Cascade ? "Cascade" : fk.onDelete == ForeignKeyAction.NoAction ? "Restrict" : "SetNull")))");
		sb.tabs(tabLevel).appendLine(i".HasConstraintName(\"$(fk.name)\");");
	}
}

private void generatePropertyModel(CSharpProjectOptions opts, StringBuilder sb, DataMember c, int tabLevel) {
	sb.appendLine();
	sb.tabs(tabLevel - 1).append(i"entity.Property(e => e.$(c.name))");
	sb.appendLine();
	sb.tabs(tabLevel).append(i".HasField(\"$(getFieldName(c.name))\")");
	sb.appendLine();
	sb.tabs(tabLevel).append(i".HasColumnName(\"$(c.name)\")");
	// .HasColumnType emits the native T-SQL type name, so only set it for SQL
	// Server. Other providers (Npgsql, Pomelo) infer the store type from the
	// CLR property type, which correctly handles e.g. PostgreSQL arrays.
	if (databaseProvider == DatabaseProvider.SqlServer) {
		sb.appendLine();
		sb.tabs(tabLevel).append(i".HasColumnType(\"$(getMssqlTypeFromColumn(c))\")");
	}
	if (c.precision != 0) {
		sb.appendLine();
		if (c.scale != 0) {
			sb.tabs(tabLevel).append(i".HasPrecision($(c.precision), $(c.scale))");
		}
		else {
			sb.tabs(tabLevel).append(i".HasPrecision($(c.precision))");
		}
	}

	if (isVariableLengthType(c.sqlType) && c.maxLength > 0) {
		sb.appendLine();
		sb.tabs(tabLevel).append(i".HasMaxLength($(c.maxLength))");
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
		if (!c.isKey) {
			sb.appendLine();
			if (c.sqlType == SqlDbType.Bit && databaseProvider == DatabaseProvider.SqlServer) {
				sb.tabs(tabLevel).append(i".HasDefaultValue($(getMssqlDefaultValue(c)))");
			} else {
				sb.tabs(tabLevel).append(".HasDefaultValue()");
			}
		}
		sb.appendLine();
		sb.tabs(tabLevel).append(".ValueGeneratedOnAdd()");
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
		sb.tabs(tabLevel).appendLine(i"public class $(p.name)Result");
		sb.tabs(tabLevel++).appendLine("{");
		foreach (pp; p.parameters.filter!(a => (a.direction == ParameterDirection.ReturnValue ||
													a.direction == ParameterDirection.InputOutput ||
													a.direction == ParameterDirection.Output) &&
													a.type != SqlDbType.Udt)) {
			sb.tabs(tabLevel).appendLine(i"public $(getTypeFromSqlType(pp.type, pp.isNullable)) $(pp.name) { get; internal set; }");
		}
		sb.tabs(--tabLevel).appendLine("}");
		sb.appendLine();
		sb.tabs(tabLevel).append(i"public async Task<$(p.name)Result> $(p.name)(");
	} else {
		sb.tabs(tabLevel).append(i"public async Task<SqlDataReader> $(p.name)(");
	}
	bool hasParam = false;
	foreach (pp; p.parameters.filter!(a => a.direction == ParameterDirection.Input)) {
		hasParam = true;
		if (pp.type != SqlDbType.Udt) {
			sb.append(i"$(getTypeFromSqlType(pp.type, false)) $(pp.name), ");
		} else {
			sb.append(i"IEnumerable<$(pp.udtType.parent.name).($(pp.udtType.name))Udt> $(pp.name), ");
		}
	}
	foreach (pp; p.parameters.filter!(a => a.direction == ParameterDirection.InputOutput && a.type != SqlDbType.Udt)) {
		hasParam = true;
		sb.append(i"$(getTypeFromSqlType(pp.type, true)) $(pp.name) = null, ");
	}
	if (hasParam) {
		sb.remove(sb.length-2, 2);
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
	sb.tabs(tabLevel).appendLine("var dbc = new SqlConnection(_parent.Database.GetConnectionString());");
	sb.tabs(tabLevel).appendLine("var cmd = dbc.CreateCommand();");
	sb.tabs(tabLevel).appendLine("await dbc.OpenAsync();");
	sb.tabs(tabLevel).appendLine(i"cmd.CommandText = \"[$(p.parent.sqlName)].[$(p.sqlName)]\";");
	sb.tabs(tabLevel).appendLine("cmd.CommandType = CommandType.StoredProcedure;");
	foreach (pp; p.parameters) {
		if (pp.type != SqlDbType.Udt) {
			auto direction = pp.direction == ParameterDirection.Input ? "Input" :
				pp.direction == ParameterDirection.InputOutput ? "InputOutput" :
				"ReturnValue";
			sb.tabs(tabLevel).appendLine(i"var p$(pp.name) = new SqlParameter(\"@$(pp.name)\", SqlDbType.$(to!string(pp.type))) { Value = (object)$(pp.name) ?? DBNull.Value, Direction = ParameterDirection.$(direction) };");
			sb.tabs(tabLevel).appendLine(i"cmd.Parameters.Add(p$(pp.name));");
		} else if (pp.type == SqlDbType.Udt) {
			sb.tabs(tabLevel).appendLine(i"var dt$(pp.name) = new DataTable();");
			foreach (c; pp.udtType.members)
				sb.appendLine(i"dt$(pp.name).Columns.Add(\"$(c.name)\", typeof($(getTypeFromSqlType(c.sqlType, c.isNullable))));");
			sb.tabs(tabLevel).appendLine(i"foreach(var t in $(pp.name))");
			sb.tabs(tabLevel++).appendLine("{");
			sb.tabs(tabLevel).append(i"dt$(pp.name).Columns.Add(");
			for (int i = 0; i < pp.udtType.members.length; i++) {
				auto c = pp.udtType.members[i];
				sb.append(i"t.$(c.name)");
				if (i < pp.udtType.members.length - 1)
					sb.append(", ");
			}
			sb.appendLine(");");
			sb.tabs(--tabLevel).appendLine("}");
			sb.tabs(tabLevel).appendLine(i"var p$(pp.name) = cmd.Parameters.AddWithValue(\"@$(pp.name)\", dt$(pp.name));");
			sb.tabs(tabLevel).appendLine(i"p$(pp.name).SqlDbType = SqlDbType.Structured;");
			sb.tabs(tabLevel).appendLine(i"p$(pp.name).TypeName = \"[$(pp.udtType.parent.name)].[$(pp.udtType.name)]\";");
		}
	}
	if (p.parameters.any!(a => (a.direction == ParameterDirection.ReturnValue ||
								a.direction == ParameterDirection.InputOutput ||
								a.direction == ParameterDirection.Output) &&
								a.type != SqlDbType.Udt)) {
		sb.tabs(tabLevel).appendLine("await cmd.ExecuteNonQueryAsync();");
		sb.tabs(tabLevel).appendLine(i"var rv = new $(p.name)Result();");
		foreach (pp; p.parameters.filter!(a => (a.direction == ParameterDirection.ReturnValue ||
													a.direction == ParameterDirection.InputOutput ||
													a.direction == ParameterDirection.Output) &&
													a.type != SqlDbType.Udt)) {
			sb.tabs(tabLevel).appendLine(i"rv.$(pp.name) = p$(pp.name).Value != DBNull.Value ? ($(getTypeFromSqlType(pp.type, pp.isNullable)))p$(pp.name).Value : null;");
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

// True when the routine surfaces any value back to the caller (a function
// return value, an INOUT parameter, or an OUT parameter), which determines
// whether a strongly-typed <Name>Result class is generated.
private bool procHasOutputs(Procedure p) {
	return p.parameters.any!(a => (a.direction == ParameterDirection.ReturnValue ||
								   a.direction == ParameterDirection.InputOutput ||
								   a.direction == ParameterDirection.Output) &&
								   a.type != SqlDbType.Udt);
}

// Emits the strongly-typed result class that carries a routine's output values.
private void generateProcResultClass(StringBuilder sb, Procedure p, int tabLevel) {
	sb.tabs(tabLevel).appendLine(i"public class $(p.name)Result");
	sb.tabs(tabLevel++).appendLine("{");
	foreach (pp; p.parameters.filter!(a => (a.direction == ParameterDirection.ReturnValue ||
												a.direction == ParameterDirection.InputOutput ||
												a.direction == ParameterDirection.Output) &&
												a.type != SqlDbType.Udt)) {
		sb.tabs(tabLevel).appendLine(i"public $(getTypeFromSqlType(pp.type, pp.isNullable)) $(pp.name) { get; internal set; }");
	}
	sb.tabs(--tabLevel).appendLine("}");
}

// Emits the method signature (input + inout parameters) up to and including the
// closing parenthesis, shared by the MySQL and PostgreSQL routine generators.
private void generateProcSignature(StringBuilder sb, Procedure p, string returnType, int tabLevel) {
	sb.tabs(tabLevel).append(i"public async Task<$(returnType)> $(p.name)(");
	bool hasParam = false;
	foreach (pp; p.parameters.filter!(a => a.direction == ParameterDirection.Input)) {
		hasParam = true;
		sb.append(i"$(getTypeFromSqlType(pp.type, false)) $(pp.name), ");
	}
	foreach (pp; p.parameters.filter!(a => a.direction == ParameterDirection.InputOutput)) {
		hasParam = true;
		sb.append(i"$(getTypeFromSqlType(pp.type, true)) $(pp.name) = null, ");
	}
	if (hasParam) {
		sb.remove(sb.length-2, 2);
	}
	if (procHasOutputs(p)) {
		sb.appendLine(")");
	} else {
		if (p.parameters.length == 0) {
			sb.appendLine("bool noResult = true)");
		} else {
			sb.appendLine(", bool noResult = true)");
		}
	}
}

private void generateMySqlStoredProcedure(StringBuilder sb, Procedure p, int tabLevel) {
	sb.appendLine();
	bool outputs = procHasOutputs(p);
	if (outputs) {
		generateProcResultClass(sb, p, tabLevel);
		sb.appendLine();
		generateProcSignature(sb, p, p.name ~ "Result", tabLevel);
	} else {
		generateProcSignature(sb, p, "MySqlDataReader", tabLevel);
	}
	sb.tabs(tabLevel++).appendLine("{");
	sb.tabs(tabLevel).appendLine("var dbc = new MySqlConnection(_parent.Database.GetConnectionString());");
	sb.tabs(tabLevel).appendLine("var cmd = dbc.CreateCommand();");
	sb.tabs(tabLevel).appendLine("await dbc.OpenAsync();");
	// MySqlConnector resolves the routine within the connection's default
	// schema. Both stored procedures and functions are invoked through
	// CommandType.StoredProcedure (functions expose a ReturnValue parameter).
	sb.tabs(tabLevel).appendLine(i"cmd.CommandText = \"$(p.sqlName)\";");
	sb.tabs(tabLevel).appendLine("cmd.CommandType = CommandType.StoredProcedure;");
	foreach (pp; p.parameters) {
		auto direction = pp.direction == ParameterDirection.Input ? "Input" :
			pp.direction == ParameterDirection.InputOutput ? "InputOutput" :
			pp.direction == ParameterDirection.Output ? "Output" : "ReturnValue";
		bool hasInputValue = pp.direction == ParameterDirection.Input || pp.direction == ParameterDirection.InputOutput;
		auto valueExpr = hasInputValue ? text(i"(object)$(pp.name) ?? DBNull.Value") : "DBNull.Value";
		sb.tabs(tabLevel).appendLine(i"var p$(pp.name) = new MySqlParameter(\"@$(pp.name)\", MySqlDbType.$(getMySqlDbType(pp.type))) { Value = $(valueExpr), Direction = ParameterDirection.$(direction) };");
		sb.tabs(tabLevel).appendLine(i"cmd.Parameters.Add(p$(pp.name));");
	}
	if (outputs) {
		sb.tabs(tabLevel).appendLine("await cmd.ExecuteNonQueryAsync();");
		sb.tabs(tabLevel).appendLine(i"var rv = new $(p.name)Result();");
		foreach (pp; p.parameters.filter!(a => a.direction == ParameterDirection.ReturnValue ||
												a.direction == ParameterDirection.InputOutput ||
												a.direction == ParameterDirection.Output)) {
			sb.tabs(tabLevel).appendLine(i"rv.$(pp.name) = p$(pp.name).Value != DBNull.Value ? ($(getTypeFromSqlType(pp.type, pp.isNullable)))p$(pp.name).Value : null;");
		}
		sb.tabs(tabLevel).appendLine("await dbc.CloseAsync();");
		sb.tabs(tabLevel).appendLine("return rv;");
	} else {
		sb.tabs(tabLevel++).appendLine("if (noResult) {");
		sb.tabs(tabLevel).appendLine("await cmd.ExecuteNonQueryAsync();");
		sb.tabs(tabLevel).appendLine("await dbc.CloseAsync();");
		sb.tabs(tabLevel).appendLine("return null;");
		sb.tabs(--tabLevel).appendLine("}");
		sb.tabs(tabLevel).appendLine("return (MySqlDataReader)await cmd.ExecuteReaderAsync(CommandBehavior.CloseConnection);");
	}
	sb.tabs(--tabLevel).appendLine("}");
}

private void generatePostgresStoredProcedure(StringBuilder sb, Procedure p, int tabLevel) {
	sb.appendLine();
	bool outputs = procHasOutputs(p);
	if (outputs) {
		generateProcResultClass(sb, p, tabLevel);
		sb.appendLine();
		generateProcSignature(sb, p, p.name ~ "Result", tabLevel);
	} else {
		generateProcSignature(sb, p, "NpgsqlDataReader", tabLevel);
	}
	sb.tabs(tabLevel++).appendLine("{");
	sb.tabs(tabLevel).appendLine("var dbc = new NpgsqlConnection(_parent.Database.GetConnectionString());");
	sb.tabs(tabLevel).appendLine("var cmd = dbc.CreateCommand();");
	sb.tabs(tabLevel).appendLine("await dbc.OpenAsync();");

	// Build the positional argument list. Functions are invoked with
	// `SELECT * FROM` and receive only IN/INOUT arguments; procedures are
	// invoked with `CALL` and require a placeholder for every parameter,
	// passing NULL for OUT parameters.
	string[] callArgs;
	foreach (pp; p.parameters) {
		if (pp.direction == ParameterDirection.Input || pp.direction == ParameterDirection.InputOutput)
			callArgs ~= "@" ~ pp.name;
		else if (pp.direction == ParameterDirection.Output && !p.isFunction)
			callArgs ~= "NULL";
	}
	string argList = callArgs.join(", ");
	if (p.isFunction) {
		sb.tabs(tabLevel).appendLine(i"cmd.CommandText = \"SELECT * FROM \\\"$(p.parent.sqlName)\\\".\\\"$(p.sqlName)\\\"($(argList))\";");
	} else {
		sb.tabs(tabLevel).appendLine(i"cmd.CommandText = \"CALL \\\"$(p.parent.sqlName)\\\".\\\"$(p.sqlName)\\\"($(argList))\";");
	}
	sb.tabs(tabLevel).appendLine("cmd.CommandType = CommandType.Text;");
	foreach (pp; p.parameters.filter!(a => a.direction == ParameterDirection.Input || a.direction == ParameterDirection.InputOutput)) {
		sb.tabs(tabLevel).appendLine(i"cmd.Parameters.Add(new NpgsqlParameter(\"@$(pp.name)\", NpgsqlDbType.$(getNpgsqlDbType(pp.type))) { Value = (object)$(pp.name) ?? DBNull.Value });");
	}
	if (outputs) {
		// Npgsql surfaces a function's OUT/return values (and a procedure's
		// INOUT values) as the columns of the returned row, in declaration
		// order.
		sb.tabs(tabLevel).appendLine(i"var rv = new $(p.name)Result();");
		sb.tabs(tabLevel).appendLine("await using var rdr = await cmd.ExecuteReaderAsync(CommandBehavior.CloseConnection);");
		sb.tabs(tabLevel++).appendLine("if (await rdr.ReadAsync()) {");
		int ord = 0;
		foreach (pp; p.parameters.filter!(a => a.direction == ParameterDirection.ReturnValue ||
												a.direction == ParameterDirection.InputOutput ||
												a.direction == ParameterDirection.Output)) {
			sb.tabs(tabLevel).appendLine(i"rv.$(pp.name) = await rdr.IsDBNullAsync($(ord)) ? ($(getTypeFromSqlType(pp.type, true)))null : rdr.GetFieldValue<$(getTypeFromSqlType(pp.type, false))>($(ord));");
			ord++;
		}
		sb.tabs(--tabLevel).appendLine("}");
		sb.tabs(tabLevel).appendLine("return rv;");
	} else {
		sb.tabs(tabLevel++).appendLine("if (noResult) {");
		sb.tabs(tabLevel).appendLine("await cmd.ExecuteNonQueryAsync();");
		sb.tabs(tabLevel).appendLine("await dbc.CloseAsync();");
		sb.tabs(tabLevel).appendLine("return null;");
		sb.tabs(--tabLevel).appendLine("}");
		sb.tabs(tabLevel).appendLine("return (NpgsqlDataReader)await cmd.ExecuteReaderAsync(CommandBehavior.CloseConnection);");
	}
	sb.tabs(--tabLevel).appendLine("}");
}
