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

import std.ascii;
import std.array;
import std.algorithm.comparison;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.stdio;
import std.string;
import std.conv;

public void generateDataNetwork(Network m, StringBuilder builder, CSharpProjectOptions opts, bool isClient, ushort tabLevel)
{
	// Create short transport names
	if (opts.shortTransports) {
		string[] pmtl;
		pmtl.length = m.members.length;
		foreach(pm; m.members) {
			if (pm.transport.isNullOrWhitespace()) {
				pm.transport = getShortTransport(pmtl, pm.name);
				pmtl ~= pm.transport;
			}
		}
	}

    builder.appendLine();
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.4.0.0\")]");
    if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
        builder.tabs(tabLevel).appendLine("[DataContract]");
    }
	if (opts.changeTracking) {
		builder.tabs(tabLevel).appendLine("public partial class {0} : TrackingObject{1}", m.name, m.hasKey ? "<" ~ m.name ~ ">" : string.init);
	} else if (opts.uiBindings) {
		builder.tabs(tabLevel).appendLine("public partial class {0} : BindingObject", m.name);
	} else {
		builder.tabs(tabLevel).appendLine("public partial class {0}", m.name);
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
	if (opts.changeTracking) {
		foreach (mm; m.members) {
			if (mm.type.isCollection) {
				TypeCollection t = cast(TypeCollection)(mm.type.type);
				builder.tabs(tabLevel).appendLine("{0} = RegisterCollectionProperty<{1}>(nameof({2}));", getFieldName(mm.name), generateType(t.collectionType), mm.name);
			} else {
				builder.tabs(tabLevel).appendLine("{0} = RegisterProperty<{1}>(nameof({2}){3});", getFieldName(mm.name), generateType(mm.type), mm.name, mm.isKey ? ", true" : string.init);
			}
		}
	}
	if (opts.changeTracking) builder.tabs(tabLevel).appendLine("RegistrationCompleted();");
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
	builder.generateBindingMetadata(mm, opts, tabLevel, false);
	if (opts.changeTracking) {
		builder.tabs(tabLevel).appendLine("private readonly {0}<{1}> {2};", mm.type.isCollection ? "TrackingCollection" : "TrackingValue", generateType(mm.type), getFieldName(mm.name));
	} else {
		builder.tabs(tabLevel).appendLine("private {0} {1};", generateType(mm.type), getFieldName(mm.name));
	}
	builder.generateBindingMetadata(mm, opts, tabLevel, true);
	builder.tabs(tabLevel).appendLine("public {0} {1} { get => {2}{3}; {4}set => {5}; }", generateType(mm.type, false, false, opts.changeTracking), mm.name, getFieldName(mm.name), opts.changeTracking ? ".Value" : string.init, mm.isReadOnly ? "private " : string.init, generateSetter(getFieldName(mm.name), opts, mm.type.isCollection));
}

public void generateDataTable(Table table, StringBuilder builder, CSharpProjectOptions opts, Project prj, bool isClient, ushort tabLevel) {
	auto fkTarget = getForeignKeysTargetTable(table.sqlId, isClient ? prj.clientSchema : prj.serverSchema);
	auto fkSource = getForeignKeysSourceTable(table.sqlId, isClient ? prj.clientSchema : prj.serverSchema);

	// Create short transport names
	if (opts.shortTransports) {
		string[] pmtl;
		pmtl.length = table.members.length + fkTarget.length + fkSource.length;
		foreach(pm; table.members) {
			if (pm.transport.isNullOrWhitespace()) {
				pm.transport = getShortTransport(pmtl, pm.name);
				pmtl ~= pm.transport;
			}
		}
		foreach(fk; fkTarget) {
			if (fk.transport.isNullOrWhitespace()) {
				fk.transport = getShortTransport(pmtl, fk.targetId());
				pmtl ~= fk.transport;
			}
		}
		foreach(fk; fkSource) {
			if (fk.transport.isNullOrWhitespace()) {
				fk.transport = getShortTransport(pmtl, fk.sourceId());
				pmtl ~= fk.transport;
			}
		}
	}

	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.4.0.0\")]");
    if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
        builder.tabs(tabLevel).appendLine("[DataContract]");
    }
	if (!isClient && opts.enableEFExtensions) {
		builder.tabs(tabLevel).appendLine("public partial class {0} : {1}IDatabaseMergeable<{0}>", table.name, opts.changeTracking ? "TrackingObject, " : (opts.uiBindings ? "BindingObject, " : string.init));
	} else if (opts.changeTracking) {
		builder.tabs(tabLevel).appendLine("public partial class {0} : TrackingObject{1}", table.name, table.hasPrimaryKey ? "<" ~ table.name ~ ">" : string.init);
	} else if (opts.uiBindings) {
		builder.tabs(tabLevel).appendLine("public partial class {0} : BindingObject", table.name);
	} else {
		builder.tabs(tabLevel).appendLine("public partial class {0}", table.name);
	}

	builder.tabs(tabLevel++).appendLine("{");

	if (opts.hasSerializer(CSharpSerializers.SystemTextJson)) {
		builder.tabs(tabLevel).appendLine("[JsonConstructor]");
	}
	builder.tabs(tabLevel++).appendLine("public {0}() {", table.name);
	if (opts.changeTracking) {
		foreach (mm; table.members) {
			builder.tabs(tabLevel).appendLine("{0} = RegisterProperty<{1}>(nameof({2}){3});", getFieldName(mm.name), generateType(mm.type), mm.name, mm.isKey ? ", true" : string.init);
		}

		if (table.modifications !is null) {
			foreach (mm; table.modifications.additions) {
				if (mm.type.isCollection) {
					TypeCollection t = cast(TypeCollection)(mm.type.type);
					builder.tabs(tabLevel).appendLine("{0} = RegisterCollectionProperty<{1}>(nameof({2}));", getFieldName(mm.name), generateType(t.collectionType), mm.name);
				} else {
					builder.tabs(tabLevel).appendLine("{0} = RegisterProperty<{1}>(nameof({2}){3});", getFieldName(mm.name), generateType(mm.type), mm.name, mm.isKey ? ", true" : string.init);
				}
			}
		}

		foreach (fk; fkTarget) {
			if (fk.direction != ForeignKeyDirection.OneToOne) {
				builder.tabs(tabLevel).appendLine("{0} = RegisterCollectionProperty<{1}>(nameof({2}));", getFieldName(fk.targetId()), fk.sourceTable.getCSharpFullName(), fk.targetId());
			} else {
				builder.tabs(tabLevel).appendLine("{0} = RegisterProperty<{1}>(nameof({2}), false);", getFieldName(fk.targetId()), fk.sourceTable.getCSharpFullName(), fk.targetId());
			}
		}

		foreach (fk; fkSource) {
			if (fk.direction != ForeignKeyDirection.ManyToMany) {
				builder.tabs(tabLevel).appendLine("{0} = RegisterProperty<{1}>(nameof({2}), false);", getFieldName(fk.sourceId()), fk.targetTable.getCSharpFullName(), fk.sourceId());
			} else {
				builder.tabs(tabLevel).appendLine("{0} = RegisterCollectionProperty<{1}>(nameof({2}));", getFieldName(fk.sourceId()), fk.targetTable.getCSharpFullName(), fk.sourceId());
			}
		}
		
	} else {
		foreach (fk; fkTarget.filter!(a => a.targetTable.sqlId == table.sqlId && a.direction != ForeignKeyDirection.OneToOne)) {
			builder.tabs(tabLevel).appendLine("this.{0} = new HashSet<{1}>();", fk.targetId(), fk.sourceTable.getCSharpFullName());
		}
	}
	if (opts.changeTracking) builder.tabs(tabLevel).appendLine("RegistrationCompleted();");
	builder.tabs(tabLevel).appendLine("PostInitializer();");
	builder.tabs(--tabLevel).appendLine("}");
	builder.tabs(tabLevel).appendLine("partial void PostInitializer();");

	foreach (c; table.members) {
		builder.appendLine();
		builder.generateBindingMetadata(c, opts, tabLevel, false);
		if (opts.changeTracking) {
			builder.tabs(tabLevel).appendLine("private readonly TrackingValue<{0}> {1};", getTypeFromSqlType(c.sqlType, c.isNullable), getFieldName(c.name));
		} else {
			builder.tabs(tabLevel).appendLine("private {0} {1};", getTypeFromSqlType(c.sqlType, c.isNullable), getFieldName(c.name));
		}
		builder.generateBindingMetadata(c, opts, tabLevel, true);
		builder.tabs(tabLevel).appendLine("public {0} {1} { get => {2}{3}; set => {4}; }", getTypeFromSqlType(c.sqlType, c.isNullable), c.name, getFieldName(c.name), opts.changeTracking ? ".Value" : string.init, generateSetter(getFieldName(c.name), opts, c.type.isCollection));
	}
	if (table.modifications !is null) {
		foreach (c; table.modifications.additions) {
			c.generateDataNetworkMember(builder, opts, tabLevel);
		}
	}

	foreach (fk; fkTarget) {
		builder.appendLine();
		if (fk.direction != ForeignKeyDirection.OneToOne) {
			builder.generateBindingMetadata(fk, opts, tabLevel, false, false);
			if (opts.changeTracking) {
				builder.tabs(tabLevel).appendLine("private readonly TrackingCollection<{0}> {1};", fk.sourceTable.getCSharpFullName(), getFieldName(fk.targetId()));
			} else {
				builder.tabs(tabLevel).appendLine("private ICollection<{0}> {1};", fk.sourceTable.getCSharpFullName(), getFieldName(fk.targetId()));
			}
			builder.generateBindingMetadata(fk, opts, tabLevel, false, true);
			builder.tabs(tabLevel).appendLine("public virtual {0}<{1}> {2} { get => {3}{4}; set => {5}; }", opts.changeTracking ? "ObservableCollection" : "ICollection", fk.sourceTable.getCSharpFullName(), fk.targetId(), getFieldName(fk.targetId()), opts.changeTracking ? ".Value" : string.init, generateSetter(getFieldName(fk.targetId()), opts, true));
		}
		else {
			builder.generateBindingMetadata(fk, opts, tabLevel, false, false);
			if (opts.changeTracking) {
				builder.tabs(tabLevel).appendLine("private readonly TrackingValue<{0}> {1};", fk.sourceTable.getCSharpFullName(), getFieldName(fk.targetId()));
			} else {
				builder.tabs(tabLevel).appendLine("private {0} {1};", fk.sourceTable.getCSharpFullName(), getFieldName(fk.targetId()));
			}
			builder.generateBindingMetadata(fk, opts, tabLevel, false, true);
			builder.tabs(tabLevel).appendLine("public virtual {0} {1} { get => {2}{3}; set => {4}; }", fk.sourceTable.getCSharpFullName(), fk.targetId(), getFieldName(fk.targetId()), opts.changeTracking ? ".Value" : string.init, generateSetter(getFieldName(fk.targetId()), opts, false));
		}
	}

	foreach (fk; fkSource) {
		builder.appendLine();
		if (fk.direction != ForeignKeyDirection.ManyToMany) {
			builder.generateBindingMetadata(fk, opts, tabLevel, true, false);
			if (opts.changeTracking) {
				builder.tabs(tabLevel).appendLine("private readonly TrackingValue<{0}> {1};", fk.targetTable.getCSharpFullName(), getFieldName(fk.sourceId()));
			} else {
				builder.tabs(tabLevel).appendLine("private {0} {1};", fk.targetTable.getCSharpFullName(), getFieldName(fk.sourceId()));
			}
			builder.generateBindingMetadata(fk, opts, tabLevel, true, true);
			builder.tabs(tabLevel).appendLine("public virtual {0} {1} { get => {2}{3}; set => {4}; }", fk.targetTable.getCSharpFullName(), fk.sourceId(), getFieldName(fk.sourceId()), opts.changeTracking ? ".Value" : string.init, generateSetter(getFieldName(fk.sourceId()), opts, false));
		}
		else {
			builder.generateBindingMetadata(fk, opts, tabLevel, true, false);
			if (opts.changeTracking) {
				builder.tabs(tabLevel).appendLine("private readonly TrackingCollection<{0}> {1};", fk.targetTable.getCSharpFullName(), getFieldName(fk.sourceId()));
			} else {
				builder.tabs(tabLevel).appendLine("private ICollection<{0}> {1};", fk.targetTable.getCSharpFullName(), getFieldName(fk.sourceId()));
			}
			builder.generateBindingMetadata(fk, opts, tabLevel, true, true);
			builder.tabs(tabLevel).appendLine("public virtual {0}<{1}> {2} { get => {3}{4}; set => {5}; }", opts.changeTracking ? "ObservableCollection" : "ICollection", fk.targetTable.getCSharpFullName(), fk.sourceId(), getFieldName(fk.sourceId()), opts.changeTracking ? ".Value" : string.init, generateSetter(getFieldName(fk.sourceId()), opts, true));
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
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.4.0.0\")]");
	builder.tabs(tabLevel).appendLine("public sealed partial class {0}{1}", table.name, opts.changeTracking ? " : TrackingObject<" ~ table.name ~ ">" : (opts.uiBindings ? " : BindingObject" : string.init));
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel++).appendLine("public {0}() {", table.name);
	if (opts.changeTracking) {
		foreach (mm; table.members) {
			builder.tabs(tabLevel).appendLine("{0} = RegisterProperty<{1}>(nameof({2}));", getFieldName(mm.name), generateType(mm.type), mm.name);
		}
	}
	if (opts.changeTracking) builder.tabs(tabLevel).appendLine("RegistrationCompleted();");
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
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.4.0.0\")]");
	builder.tabs(tabLevel).appendLine("public sealed partial class {0}Udt{1}", udt.name, opts.changeTracking ? " : TrackingObject<" ~ udt.name ~ ">" : (opts.uiBindings ? " : BindingObject" : string.init));
	builder.tabs(tabLevel++).appendLine("{");
	builder.tabs(tabLevel++).appendLine("public {0}() {", udt.name);
	if (opts.changeTracking) {
		foreach (mm; udt.members) {
			builder.tabs(tabLevel).appendLine("{0} = RegisterProperty<{1}>(nameof({2}));", getFieldName(mm.name), generateType(mm.type), mm.name);
		}
	}
	if (opts.changeTracking) builder.tabs(tabLevel).appendLine("RegistrationCompleted();");
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
	builder.generateBindingMetadata(mm, opts, tabLevel, false);
	if (opts.changeTracking) {
		builder.tabs(tabLevel).appendLine("private readonly TrackingValue<{0}> {1};", getTypeFromSqlType(mm.sqlType, mm.isNullable), getFieldName(mm.name));
	} else {
		builder.tabs(tabLevel).appendLine("private {0} {1};", getTypeFromSqlType(mm.sqlType, mm.isNullable), getFieldName(mm.name));
	}
	builder.generateBindingMetadata(mm, opts, tabLevel, true);
	builder.tabs(tabLevel).appendLine("public {0} {1} { get => {2}{3}; {4}set => {5}; }", getTypeFromSqlType(mm.sqlType, mm.isNullable), mm.name, getFieldName(mm.name), opts.changeTracking ? ".Value" : string.init, mm.isReadOnly ? "private " : string.init, generateSetter(getFieldName(mm.name), opts, false));
}

private void generateBindingMetadata(StringBuilder builder, DataMember mm, CSharpProjectOptions opts, ushort tabLevel, bool isProperty) {
	string transport = getTransportName(mm.name, mm.transport);
	if (!isProperty && transport.isNullOrWhitespace()) transport = mm.name;

	if ((opts.serializeFields && !isProperty) || (!opts.serializeFields && isProperty)) {
		if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
			if (!transport.isNullOrWhitespace()) {
				builder.tabs(tabLevel).appendLine("[DataMember(Name = \"{0}\", IsRequired = {1})]", transport, mm.isNullable ? "false" : "true");
			} else {
				builder.tabs(tabLevel).appendLine("[DataMember(IsRequired = {0})]", mm.isNullable ? "false" : "true");
			}
		}
		if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) ) {
			if (mm.isTypeEnum()) builder.tabs(tabLevel).appendLine("[JsonConverter(typeof(JsonStringEnumConverter))]");
		}
		if (opts.hasSerializer(CSharpSerializers.SystemTextJson)) {
			if (!transport.isNullOrWhitespace()) builder.tabs(tabLevel).appendLine("[JsonPropertyName(\"{0}\")]", transport);
			if (!mm.isNullable) builder.tabs(tabLevel).appendLine("[JsonRequired]");
			if (mm.isTypeEnum()) builder.tabs(tabLevel).appendLine("[JsonConverter(typeof(JsonStringEnumConverter))]");
			builder.tabs(tabLevel).appendLine("[JsonInclude]");
		}
	}

	if (isProperty) {
		builder.generatePropertyMetadata(opts, tabLevel);
	} else {
		builder.generateFieldMetadata(opts, tabLevel);
	}
}

private void generateBindingMetadata(StringBuilder builder, ForeignKey fk, CSharpProjectOptions opts, ushort tabLevel, bool isSource, bool isProperty) {
	string transport = getTransportName(isSource ? fk.sourceId() : fk.targetId(), fk.transport);
	if (!isProperty && transport.isNullOrWhitespace()) transport = isSource ? fk.sourceId() : fk.targetId();

	if ((opts.serializeFields && !isProperty) || (!opts.serializeFields && isProperty)) {
		if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
			if (!transport.isNullOrWhitespace()) {
				builder.tabs(tabLevel).appendLine("[DataMember(Name = \"{0}\", IsRequired = false)]", transport);
			} else {
				builder.tabs(tabLevel).appendLine("[DataMember(IsRequired = false)]");
			}
		}
		if (opts.hasSerializer(CSharpSerializers.SystemTextJson)) {
			if (!transport.isNullOrWhitespace()) builder.tabs(tabLevel).appendLine("[JsonPropertyName(\"{0}\")]", transport);
			builder.tabs(tabLevel).appendLine("[JsonInclude]");
		}
	}

	if (isProperty) {
		builder.generatePropertyMetadata(opts, tabLevel);
	} else {
		builder.generateFieldMetadata(opts, tabLevel);
	}
}

private void generatePropertyMetadata(StringBuilder builder, CSharpProjectOptions opts, ushort tabLevel) {
	if (opts.serializeFields && (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract))) {
		builder.tabs(tabLevel).appendLine("[IgnoreDataMember]");
	}
	if (opts.serializeFields && opts.hasSerializer(CSharpSerializers.SystemTextJson)) {
		builder.tabs(tabLevel).appendLine("[JsonIgnore]");
	}
	builder.tabs(tabLevel).appendLine("[System.Diagnostics.DebuggerNonUserCode()]");
}

private void generateFieldMetadata(StringBuilder builder, CSharpProjectOptions opts, ushort tabLevel) {
	if (!opts.serializeFields && (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract))) {
		builder.tabs(tabLevel).appendLine("[IgnoreDataMember]");
	}
	if (!opts.serializeFields && opts.hasSerializer(CSharpSerializers.SystemTextJson)) {
		builder.tabs(tabLevel).appendLine("[JsonIgnore]");
	}
}

private string generateSetter(string name, CSharpProjectOptions opts, bool isCollection = false) {
	if (opts.changeTracking) {
		return isCollection ? "SetCollection(" ~ name ~ ", value)" : "SetValue(" ~ name ~ ", value)";
	}
	return opts.uiBindings ? "SetField(ref " ~ name ~ ", value)" : name ~ " = value";
}

private string getFieldName(string name) {
	return "_" ~ name.toLower();
}

private bool isCSharpKeyword(string name) {
	return name.toLower().among("abstract", "as", "base", "bool", "break", "byte", "case", "catch", "char", "checked", "class", "const", "continue", "decimal", "default", "delegate", "do", "double", "else", "enum", "event", "explicit", "extern", "false", "finally", "fixed", "float", "for", "foreach", "goto", "if", "implicit", "in", "int", "interface", "internal", "is", "lock", "long", "namespace", "new", "null", "object", "operator", "out", "override", "params", "private", "protected", "public", "readonly", "ref", "return", "sbyte", "sealed", "short", "sizeof", "stackalloc", "static", "string", "struct", "switch", "this", "throw", "true", "try", "typeof", "uint", "ulong", "unchecked", "unsafe", "ushort", "using", "virtual", "while") != 0;
}

private string getTransportName(string name, string transport) {
	if (transport.isNullOrWhitespace && isCSharpKeyword(name)) return name.toLower();
	return transport;
}

private string getShortTransport(string[] pmtl, string name) {
	string sn = string.init;
	foreach(c; name) {
		if (c.isUpper()) {
			sn ~= c;
		}
	}
	string tsn = sn = sn.toLower();
	int c = 1;
	while (pmtl.count(tsn) > 0) {
		tsn = sn ~ to!string(c++);
	}

	return tsn;
}
