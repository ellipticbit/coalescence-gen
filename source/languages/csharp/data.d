module hwgen.languages.csharp.data;

import hwgen.languages.csharp.language;
import hwgen.database.utility;
import hwgen.types;
import hwgen.schema;
import hwgen.globals;
import hwgen.stringbuilder;
import hwgen.utility;

import hwgen.languages.csharp.extensions;
import hwgen.languages.csharp.generator;

import std.array;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.stdio;
import std.string;
import std.conv;

public void generateDataNetwork(Network m, StringBuilder builder, CSharpProjectOptions opts, bool isClient, ushort tabLevel)
{
    builder.appendLine();
    if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
        builder.tabs(tabLevel).appendLine("[DataContract]");
    }
    builder.tabs(tabLevel).appendLine("public sealed partial class {0}{1}", m.name, (opts.serverUIBindings || opts.clientUIBindings) ? " : INotifyPropertyChanged" : string.init);
    builder.tabs(tabLevel++).appendLine("{");

	if (opts.serverUIBindings || opts.clientUIBindings)
	{
		builder.tabs(tabLevel).appendLine("public event PropertyChangedEventHandler PropertyChanged;");
		builder.tabs(tabLevel++).appendLine("private void BindablePropertyChanged(string propertyName) {");
		builder.tabs(tabLevel).appendLine("if (PropertyChanged != null) PropertyChanged(this, new PropertyChangedEventArgs(propertyName));");
		builder.tabs(--tabLevel).appendLine("}");
	}

    foreach(v; m.members) {
        v.generateDataNetworkMember(builder, opts, tabLevel);
	}

    builder.appendLine();
    builder.tabs(tabLevel).appendLine("public {0}() { }", m.name);
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
	builder.tabs(tabLevel).appendLine("private {0} _{1};", generateType(mm.type, false), mm.name);
	builder.generateBindingMetadata(mm.transport.isNullOrWhitespace() ? mm.name : mm.transport, mm.isNullable, opts, tabLevel);
	if (opts.serverUIBindings || opts.clientUIBindings) {
		builder.tabs(tabLevel).appendLine("public {0} {1} { get { return _{1}; } {2}set { _{1} = value; BindablePropertyChanged(nameof({1})); } }", generateType(mm.type, false), mm.name, mm.isReadOnly ? "private " : string.init);
	} else {
		builder.tabs(tabLevel).appendLine("public {0} {1} { get { return _{1}; } {2}set { _{1} = value; } }", generateType(mm.type, false), mm.name, mm.isReadOnly ? "private " : string.init);
	}
}

public void generateDataTable(Table table, StringBuilder builder, CSharpProjectOptions opts, Project prj, bool isClient, ushort tabLevel) {
	auto fkTarget = getForeignKeysTargetTable(table.sqlId, isClient ? prj.clientSchema : prj.serverSchema);
	auto fkSource = getForeignKeysSourceTable(table.sqlId, isClient ? prj.clientSchema : prj.serverSchema);

	if (opts.enableEFExtensions && !(opts.serverUIBindings || opts.clientUIBindings)) {
		builder.tabs(tabLevel).appendLine("public partial class {0} : IDatabaseMergeable<{0}>", table.name);
	}
	else if (!opts.enableEFExtensions && (opts.serverUIBindings || opts.clientUIBindings)) {
		builder.tabs(tabLevel).appendLine("public partial class {0} : BindingObject", table.name);
	}
	else if (opts.enableEFExtensions && (opts.serverUIBindings || opts.clientUIBindings)) {
		builder.tabs(tabLevel).appendLine("public partial class {0} : BindingObject, IDatabaseMergeable<{0}>", table.name);
	}
	else {
		builder.tabs(tabLevel).appendLine("public partial class {0}", table.name);
	}

	builder.tabs(tabLevel++).appendLine("{");

	builder.tabs(tabLevel++).appendLine("public {0}() {", table.name);
	foreach (fk; fkTarget.filter!(a => a.targetTable.sqlId == table.sqlId && a.direction != ForeignKeyDirection.OneToOne)) {
		builder.tabs(tabLevel).appendLine("this.{0} = new {1}<{2}>();", fk.targetId(), ((opts.serverUIBindings || opts.clientUIBindings) ? "ThreadObservableCollection" : "HashSet"), fk.sourceTable.getCSharpFullName());
	}
	builder.tabs(tabLevel).appendLine("PostInitializer();");
	builder.tabs(--tabLevel).appendLine("}");
	builder.tabs(tabLevel).appendLine("partial void PostInitializer();");

	foreach (c; table.members) {
		builder.appendLine();
		builder.tabs(2).appendLine("private {0} _{1};", getTypeFromSqlType(c.sqlType, c.isNullable), c.name);
		builder.generateBindingMetadata(c.transport.isNullOrWhitespace() ? c.name : c.transport, c.isNullable, opts, tabLevel);
		builder.tabs(2).appendLine("public {0} {1} { get { return _{1}; } set { {2} } }", getTypeFromSqlType(c.sqlType, c.isNullable), c.name, generateSetter(c.name, (opts.serverUIBindings || opts.clientUIBindings)));
	}

	foreach (fk; fkTarget) {
		builder.appendLine();
		if (fk.direction != ForeignKeyDirection.OneToOne) {
			builder.tabs(2).appendLine("private {0}<{1}> _{2};", ((opts.serverUIBindings || opts.clientUIBindings) ? "ThreadObservableCollection" : "ICollection"), fk.sourceTable.getCSharpFullName(), fk.targetId());
			builder.generateBindingMetadata(fk.targetId(), false, opts, tabLevel);
			builder.tabs(2).appendLine("public virtual {0}<{1}> {2} { get { return _{2}; } set { {3} } }", ((opts.serverUIBindings || opts.clientUIBindings) ? "ThreadObservableCollection" : "ICollection"), fk.sourceTable.getCSharpFullName(), fk.targetId(), generateSetter(fk.targetId(), (opts.serverUIBindings || opts.clientUIBindings)));
		}
		else {
			builder.tabs(2).appendLine("private {0} _{1};", fk.sourceTable.getCSharpFullName(), fk.targetId());
			builder.generateBindingMetadata(fk.targetId(), false, opts, tabLevel);
			builder.tabs(2).appendLine("public virtual {0} {1} { get { return _{1}; } set { {2} } }", fk.sourceTable.getCSharpFullName(), fk.targetId(), generateSetter(fk.targetId(), (opts.serverUIBindings || opts.clientUIBindings)));
		}
	}

	foreach (fk; fkSource) {
		builder.appendLine();
		if (fk.direction != ForeignKeyDirection.ManyToMany) {
			builder.tabs(tabLevel).appendLine("private {0} _{1};", fk.targetTable.getCSharpFullName(), fk.sourceId());
			builder.generateBindingMetadata(fk.sourceId(), false, opts, tabLevel);
			builder.tabs(tabLevel).appendLine("public virtual {0} {1} { get { return _{1}; } set { {2} } }", fk.targetTable.getCSharpFullName(), fk.sourceId(), generateSetter(fk.sourceId(), (opts.serverUIBindings || opts.clientUIBindings)));
		}
		else {
			builder.tabs(tabLevel).appendLine("private {0}<{1}> _{2};", ((opts.serverUIBindings || opts.clientUIBindings) ? "ThreadObservableCollection" : "ICollection"), fk.targetTable.getCSharpFullName(), fk.sourceId());
			builder.generateBindingMetadata(fk.sourceId(), false, opts, tabLevel);
			builder.tabs(tabLevel).appendLine("public virtual {0}<{1}> {2} { get { return _{2}; } set { {3} } }", ((opts.serverUIBindings || opts.clientUIBindings) ? "ThreadObservableCollection" : "ICollection"), fk.targetTable.getCSharpFullName(), fk.sourceId(), generateSetter(fk.sourceId(), (opts.serverUIBindings || opts.clientUIBindings)));
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

public void generateDataView(View table, StringBuilder builder, CSharpProjectOptions opts, ushort tabLevel)
{
	builder.tabs(tabLevel).appendLine("[GeneratedCodeAttribute()]");
	builder.tabs(tabLevel).appendLine("[DebuggerNonUserCodeAttribute()]");
	builder.tabs(tabLevel).appendLine("public class {0}{1}", table.name, (opts.serverUIBindings || opts.clientUIBindings) ? " : BindingObject" : string.init);
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel).appendLine("public {0}() { }", table.name);
	foreach (c; table.members) {
		c.generateDataSqlMember(builder, opts, tabLevel);
	}
	builder.tabs(--tabLevel).appendLine("}");
}

public void generateDataUdt(Udt udt, StringBuilder builder, CSharpProjectOptions opts, ushort tabLevel)
{
	builder.tabs(tabLevel).appendLine("public partial class {0}Udt{1}", udt.name, (opts.serverUIBindings || opts.clientUIBindings) ? " : BindingObject" : string.init);
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel++).appendLine("public {0}() {", udt.name);
	builder.tabs(tabLevel).appendLine("PostInitializer();");
	builder.tabs(--tabLevel).appendLine("}");
	builder.tabs(tabLevel).appendLine("partial void PostInitializer();");
	foreach (c; udt.members) {
		c.generateDataSqlMember(builder, opts, tabLevel);
	}
	builder.tabs(--tabLevel).appendLine("}");
	builder.appendLine();
}

private void generateDataSqlMember(DataMember mm, StringBuilder builder, CSharpProjectOptions opts, ushort tabLevel)
{
	if (mm.hidden) return;

	builder.appendLine();
	builder.tabs(tabLevel).appendLine("private {0} _{1};", getTypeFromSqlType(mm.sqlType, mm.isNullable), mm.name);
	builder.generateBindingMetadata(mm.transport.isNullOrWhitespace() ? mm.name : mm.transport, mm.isNullable, opts, tabLevel);
	if (opts.serverUIBindings || opts.clientUIBindings) {
		builder.tabs(tabLevel).appendLine("public {0} {1} { get { return _{1}; } {2}set { _{1} = value; BindablePropertyChanged(nameof({1})); } }", getTypeFromSqlType(mm.sqlType, mm.isNullable), mm.name, mm.isReadOnly ? "private " : string.init);
	} else {
		builder.tabs(tabLevel).appendLine("public {0} {1} { get { return _{1}; } {2}set { _{1} = value; } }", getTypeFromSqlType(mm.sqlType, mm.isNullable), mm.name, mm.isReadOnly ? "private " : string.init);
	}
}

private void generateBindingMetadata(StringBuilder builder, string transport, bool isRequired, CSharpProjectOptions opts, ushort tabLevel) {
	builder.tabs(tabLevel).appendLine("[GeneratedCodeAttribute(\"EllipticBit.Hotwire.Generator\", \"2.0.0.0\")]");
	builder.tabs(tabLevel).appendLine("[DebuggerNonUserCodeAttribute()]");
	if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
		builder.tabs(tabLevel).appendLine("[DataMember(Name = \"{0}\", IsRequired = {1})]", transport, isRequired ? "false" : "true");
	}
	else if (opts.hasSerializer(CSharpSerializers.SystemTextJson)) {
		builder.tabs(tabLevel).appendLine("[JsonPropertyName(\"{0}\")]", transport);
		builder.tabs(tabLevel).appendLine("[JsonInclude]");
		if (isRequired) builder.tabs(tabLevel).appendLine("[JsonRequired]");
	}
}

private string generateSetter(string name, bool binding) {
	return binding ? "SetField(ref _" ~ name ~ ", value, \"" ~ name ~"\");" : "_" ~ name ~ " = value;";
}
