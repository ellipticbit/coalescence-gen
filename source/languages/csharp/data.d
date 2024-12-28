module coalescence.languages.csharp.data;

import coalescence.languages.csharp.language;
import coalescence.database.utility;
import coalescence.types;
import coalescence.schema;
import coalescence.globals;
import coalescence.stringbuilder;
import coalescence.utility;

import coalescence.languages.csharp.extensions;
import coalescence.languages.csharp.generator;

import std.array;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.stdio;
import std.string;
import std.conv;

public void generateDataNetwork(Network m, StringBuilder builder, CSharpProjectOptions opts, bool isClient, ushort tabLevel)
{
    builder.appendLine();
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.3.3.0\")]");
    if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
        builder.tabs(tabLevel).appendLine("[DataContract]");
    }
	if (opts.uiBindings) {
		builder.tabs(tabLevel).appendLine("public sealed partial class {0} : BindingObject", m.name);
	}
	else {
		builder.tabs(tabLevel).appendLine("public sealed partial class {0}", m.name);
	}
    builder.tabs(tabLevel++).appendLine("{");

    foreach(v; m.members) {
        v.generateDataNetworkMember(builder, opts, tabLevel);
	}

    builder.appendLine();
	if (opts.hasSerializer(CSharpSerializers.SystemTextJson)) {
		builder.tabs(tabLevel).appendLine("[JsonConstructor]");
	}
	builder.tabs(tabLevel++).appendLine("public {0}() {", m.name);
	builder.tabs(tabLevel).appendLine("PostInitializer();");
	builder.tabs(--tabLevel).appendLine("}");
	builder.tabs(tabLevel).appendLine("partial void PostInitializer();");
    builder.appendLine();

    if (!isClient)
    {
        builder.tabs(tabLevel).append("public static {0} Create{0}(", m.name);

        if(m.members.any!(a => a.isReadOnly))
        {
            auto mml = m.members.filter!(a => a.isReadOnly).array;
            builder.append("{0} {1}", generateType(mml[0].type, false), mml[0].name);
            for (int i = 1; i < mml.length; i++)
            {
                builder.append(", {0} {1}", generateType(mml[i].type, false), mml[i].name);
            }
        }

        builder.appendLine(")");
        builder.tabs(tabLevel++).appendLine("{");
        builder.tabs(tabLevel).appendLine("return new {0}()", m.name);
        builder.tabs(tabLevel++).appendLine("{");
        foreach(mm; m.members.filter!(a => a.isReadOnly && (a.type.type.mode == TypeMode.Primitive || a.type.type.mode == TypeMode.ByteArray))())
            builder.tabs(tabLevel).appendLine("{0} = {0},", mm.name);
        builder.tabs(--tabLevel).appendLine("};");
        builder.tabs(--tabLevel).appendLine("}");
        builder.appendLine();
    }
    builder.tabs(--tabLevel).appendLine("}");
}

private void generateDataNetworkMember(DataMember mm, StringBuilder builder, CSharpProjectOptions opts, ushort tabLevel)
{
	if (mm.hidden) return;

	builder.appendLine();
	if (opts.serializerFieldAttributes) builder.generateBindingMetadata(mm.transport, !mm.isNullable, mm.isTypeEnum(), opts, tabLevel);
	builder.tabs(tabLevel).appendLine("private {0} _{1};", generateType(mm.type, false), mm.name);
	builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
	if (!opts.serializerFieldAttributes) builder.generateBindingMetadata(mm.transport, !mm.isNullable, mm.isTypeEnum(), opts, tabLevel);
	builder.tabs(tabLevel).appendLine("public {0} {1} { get { return _{1}; } {2}set { {3} } }", generateType(mm.type, false), mm.name, mm.isReadOnly ? "private " : string.init, generateSetter(mm.name, opts.uiBindings));
}

public void generateDataTable(Table table, StringBuilder builder, CSharpProjectOptions opts, Project prj, bool isClient, ushort tabLevel) {
	auto fkTarget = getForeignKeysTargetTable(table.sqlId, isClient ? prj.clientSchema : prj.serverSchema);
	auto fkSource = getForeignKeysSourceTable(table.sqlId, isClient ? prj.clientSchema : prj.serverSchema);

	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.3.3.0\")]");
    if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
        builder.tabs(tabLevel).appendLine("[DataContract]");
    }
	if (!isClient && opts.enableEFExtensions) {
		builder.tabs(tabLevel).appendLine("public partial class {0} : {1}IDatabaseMergeable<{0}>", table.name, opts.uiBindings ? "BindingObject, " : string.init);
	}
	else if (opts.uiBindings) {
		builder.tabs(tabLevel).appendLine("public partial class {0} : BindingObject", table.name);
	}
	else {
		builder.tabs(tabLevel).appendLine("public partial class {0}", table.name);
	}

	builder.tabs(tabLevel++).appendLine("{");

	if (opts.hasSerializer(CSharpSerializers.SystemTextJson)) {
		builder.tabs(tabLevel).appendLine("[JsonConstructor]");
	}
	builder.tabs(tabLevel++).appendLine("public {0}() {", table.name);
	foreach (fk; fkTarget.filter!(a => a.targetTable.sqlId == table.sqlId && a.direction != ForeignKeyDirection.OneToOne)) {
		builder.tabs(tabLevel).appendLine("this.{0} = new HashSet<{1}>();", fk.targetId(), fk.sourceTable.getCSharpFullName());
	}
	builder.tabs(tabLevel).appendLine("PostInitializer();");
	builder.tabs(--tabLevel).appendLine("}");
	builder.tabs(tabLevel).appendLine("partial void PostInitializer();");

	foreach (c; table.members) {
		builder.appendLine();
		if (opts.serializerFieldAttributes) builder.generateBindingMetadata(c.transport, !c.isNullable, c.isTypeEnum(), opts, tabLevel);
		builder.tabs(tabLevel).appendLine("private {0} {1};", getTypeFromSqlType(c.sqlType, c.isNullable), c.name.toLower());
		builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
		if (!opts.serializerFieldAttributes) builder.generateBindingMetadata(c.transport, !c.isNullable, c.isTypeEnum(), opts, tabLevel);
		builder.tabs(tabLevel).appendLine("public {0} {1} { get { return {2}; } set { {3} } }", getTypeFromSqlType(c.sqlType, c.isNullable), c.name, c.name.toLower(), generateSetter(c.name.toLower(), opts.uiBindings));
	}
	if (table.modifications !is null) {
		foreach (c; table.modifications.additions) {
			c.generateDataNetworkMember(builder, opts, tabLevel);
		}
	}

	foreach (fk; fkTarget) {
		builder.appendLine();
		if (fk.direction != ForeignKeyDirection.OneToOne) {
			if (opts.serializerFieldAttributes) builder.generateBindingMetadata(fk.targetId(), false, false, opts, tabLevel);
			builder.tabs(tabLevel).appendLine("private ICollection<{0}> {1};", fk.sourceTable.getCSharpFullName(), fk.targetId().toLower());
			builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
			if (!opts.serializerFieldAttributes) builder.generateBindingMetadata(fk.targetId(), false, false, opts, tabLevel);
			builder.tabs(tabLevel).appendLine("public virtual ICollection<{0}> {1} { get { return {2}; } set { {3} } }", fk.sourceTable.getCSharpFullName(), fk.targetId(), fk.targetId().toLower(), generateSetter(fk.targetId().toLower(), opts.uiBindings));
		}
		else {
			if (opts.serializerFieldAttributes) builder.generateBindingMetadata(fk.targetId(), false, false, opts, tabLevel);
			builder.tabs(tabLevel).appendLine("private {0} {1};", fk.sourceTable.getCSharpFullName(), fk.targetId().toLower());
			builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
			if (!opts.serializerFieldAttributes) builder.generateBindingMetadata(fk.targetId(), false, false, opts, tabLevel);
			builder.tabs(tabLevel).appendLine("public virtual {0} {1} { get { return {2}; } set { {3} } }", fk.sourceTable.getCSharpFullName(), fk.targetId(), fk.targetId().toLower(), generateSetter(fk.targetId().toLower(), opts.uiBindings));
		}
	}

	foreach (fk; fkSource) {
		builder.appendLine();
		if (fk.direction != ForeignKeyDirection.ManyToMany) {
			if (opts.serializerFieldAttributes) builder.generateBindingMetadata(fk.sourceId(), false, false, opts, tabLevel);
			builder.tabs(tabLevel).appendLine("private {0} {1};", fk.targetTable.getCSharpFullName(), fk.sourceId().toLower());
			builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
			if (!opts.serializerFieldAttributes) builder.generateBindingMetadata(fk.sourceId(), false, false, opts, tabLevel);
			builder.tabs(tabLevel).appendLine("public virtual {0} {1} { get { return {2}; } set { {3} } }", fk.targetTable.getCSharpFullName(), fk.sourceId(), fk.sourceId().toLower(), generateSetter(fk.sourceId().toLower(), opts.uiBindings));
		}
		else {
			if (opts.serializerFieldAttributes) builder.generateBindingMetadata(fk.sourceId(), false, false, opts, tabLevel);
			builder.tabs(tabLevel).appendLine("private ICollection<{0}> {1};", fk.targetTable.getCSharpFullName(), fk.sourceId().toLower());
			builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
			if (!opts.serializerFieldAttributes) builder.generateBindingMetadata(fk.sourceId(), false, false, opts, tabLevel);
			builder.tabs(tabLevel).appendLine("public virtual ICollection<{0}> {1} { get { return {2}; } set { {3} } }", fk.targetTable.getCSharpFullName(), fk.sourceId(), fk.sourceId().toLower(), generateSetter(fk.sourceId().toLower(), opts.uiBindings));
		}
	}

	if (!isClient && opts.enableEFExtensions) {
		builder.appendLine();
		builder.tabs(tabLevel++).appendLine("DataValue[] IDatabaseMergeable<{0}>.GetMergeableValues() {", table.name);
		builder.tabs(tabLevel).appendLine("var values = new List<DataValue>({0});", to!string(table.members.length));
		foreach (c; table.members.filter!(a => a.sqlType != SqlDbType.Timestamp && !a.isIdentity && !a.isComputed)) {
			builder.tabs(tabLevel).appendLine("values.Add(new DataValue({0}, {1}, this.{2}, \"{2}\"));", getValueTypeFromSqlType(c.sqlType), toLower(to!string(c.isNullable)), c.name);
		}
		builder.tabs(tabLevel).appendLine("return values.ToArray();");
		builder.tabs(--tabLevel).appendLine("}");

		builder.appendLine();
		builder.tabs(tabLevel++).appendLine("void IDatabaseMergeable<{0}>.ApplyConflictResolutions(DataConflictResolution[] resolutions) {", table.name);
		builder.tabs(tabLevel++).appendLine("foreach(var r in resolutions) {");
		foreach (c; table.members.filter!(a => a.sqlType != SqlDbType.Timestamp && !a.isIdentity && !a.isComputed)) {
			builder.tabs(tabLevel).appendLine("if (r.Name.Equals(\"{0}\", StringComparison.OrdinalIgnoreCase)) this.{0} = ({1})r.Resolved;", c.name, getTypeFromSqlType(c.sqlType, c.isNullable));
		}
		builder.tabs(--tabLevel).appendLine("}");
		builder.tabs(--tabLevel).appendLine("}");
	}

	builder.tabs(--tabLevel).appendLine("}");
}

public void generateDataView(View table, StringBuilder builder, CSharpProjectOptions opts, bool isClient, ushort tabLevel)
{
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.3.3.0\")]");
	builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
	builder.tabs(tabLevel).appendLine("public partial class {0}{1}", table.name, opts.uiBindings ? " : BindingObject" : string.init);
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel++).appendLine("public {0}() {", table.name);
	builder.tabs(tabLevel).appendLine("PostInitializer();");
	builder.tabs(--tabLevel).appendLine("}");
	builder.tabs(tabLevel).appendLine("partial void PostInitializer();");
	foreach (c; table.members) {
		c.generateDataSqlMember(builder, opts, isClient, tabLevel);
	}
	if (table.modifications !is null) {
		foreach (c; table.modifications.additions) {
			c.generateDataNetworkMember(builder, opts, tabLevel);
		}
	}
	builder.tabs(--tabLevel).appendLine("}");
}

public void generateDataUdt(Udt udt, StringBuilder builder, CSharpProjectOptions opts, bool isClient, ushort tabLevel)
{
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.3.3.0\")]");
	builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
	builder.tabs(tabLevel).appendLine("public partial class {0}Udt{1}", udt.name, opts.uiBindings ? " : BindingObject" : string.init);
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel++).appendLine("public {0}() {", udt.name);
	builder.tabs(tabLevel).appendLine("PostInitializer();");
	builder.tabs(--tabLevel).appendLine("}");
	builder.tabs(tabLevel).appendLine("partial void PostInitializer();");
	foreach (c; udt.members) {
		c.generateDataSqlMember(builder, opts, isClient, tabLevel);
	}
	if (udt.modifications !is null) {
		foreach (c; udt.modifications.additions) {
			c.generateDataNetworkMember(builder, opts, tabLevel);
		}
	}
	builder.tabs(--tabLevel).appendLine("}");
	builder.appendLine();
}

private void generateDataSqlMember(DataMember mm, StringBuilder builder, CSharpProjectOptions opts, bool isClient, ushort tabLevel)
{
	if (mm.hidden) return;

	builder.appendLine();
	if (opts.serializerFieldAttributes) builder.generateBindingMetadata(mm.transport, !mm.isNullable, mm.isTypeEnum(), opts, tabLevel);
	builder.tabs(tabLevel).appendLine("private {0} {1};", getTypeFromSqlType(mm.sqlType, mm.isNullable), mm.name.toLower());
	builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
	if (!opts.serializerFieldAttributes) builder.generateBindingMetadata(mm.transport, !mm.isNullable, mm.isTypeEnum(), opts, tabLevel);
	builder.tabs(tabLevel).appendLine("public {0} {1} { get { return {2}; } {3}set { {4} } }", getTypeFromSqlType(mm.sqlType, mm.isNullable), mm.name, mm.name.toLower(), mm.isReadOnly ? "private " : string.init, generateSetter(mm.name.toLower(), opts.uiBindings));
}

private void generateBindingMetadata(StringBuilder builder, string transport, bool isRequired, bool stringEnum, CSharpProjectOptions opts, ushort tabLevel) {
	if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
		if (!transport.isNullOrWhitespace()) builder.tabs(tabLevel).appendLine("[DataMember(Name = \"{0}\", IsRequired = {1})]", transport, isRequired ? "false" : "true");
	}
	if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) ) {
		if (stringEnum) builder.tabs(tabLevel).appendLine("[JsonConverter(typeof(JsonStringEnumConverter))]");
	}
	if (opts.hasSerializer(CSharpSerializers.SystemTextJson)) {
		if (!transport.isNullOrWhitespace()) builder.tabs(tabLevel).appendLine("[JsonPropertyName(\"{0}\")]", transport);
		builder.tabs(tabLevel).appendLine("[JsonInclude]");
		if (isRequired) builder.tabs(tabLevel).appendLine("[JsonRequired]");
		if (stringEnum) builder.tabs(tabLevel).appendLine("[JsonConverter(typeof(JsonStringEnumConverter))]");
	}
}

private string generateSetter(string name, bool binding) {
	return binding ? "SetField(ref " ~ name ~ ", value);" : name ~ " = value;";
}
