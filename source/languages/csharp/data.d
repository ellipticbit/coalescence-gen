module hwgen.languages.csharp.data;

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
import std.conv;

public void generateDataNetwork(Network m, StringBuilder builder, CSharpProjectOptions opts, bool isClient, ushort tabLevel)
{
    builder.appendLine();
    if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
        builder.tabs(tabLevel).appendLine("[DataContract]");
    }
    builder.tabs(tabLevel).appendLine("public sealed partial class {0}{1}", m.name, (opts.serverUIBindings || opts.clientUIBindings) ? " : INotifyPropertyChanged" : string.init);
    builder.tabs(tabLevel++).appendLine("{");

    foreach(v; m.members) {
        v.generateMember(builder, opts, tabLevel);
	}

	if (opts.serverUIBindings || opts.clientUIBindings)
	{
		builder.tabs(tabLevel).appendLine("public event PropertyChangedEventHandler PropertyChanged;");
		builder.tabs(tabLevel++).appendLine("private void BindablePropertyChanged(string propertyName) {");
		builder.tabs(tabLevel).appendLine("if (PropertyChanged != null) PropertyChanged(this, new PropertyChangedEventArgs(propertyName));");
		builder.tabs(--tabLevel).appendLine("}");
	}

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

private void generateMember(DataMember mm, StringBuilder builder, CSharpProjectOptions opts, ushort tabLevel)
{
	if (mm.hidden) return;

	builder.tabs(tabLevel).appendLine("private {0} _{1};", generateType(mm.type, false), mm.name);
	if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
		builder.tabs(tabLevel).appendLine("[DataMember(Name = \"{0}\", IsRequired = {1})]", mm.transport.isNullOrWhitespace() ? mm.transport : mm.name, mm.type.nullable ? "false" : "true");
	}
	else if (opts.hasSerializer(CSharpSerializers.SystemTextJson)) {
		builder.tabs(tabLevel).appendLine("[JsonPropertyName(\"{0}\")]", mm.transport.isNullOrWhitespace() ? mm.transport : mm.name);
		builder.tabs(tabLevel).appendLine("[JsonInclude]");
	}

	if (opts.serverUIBindings || opts.clientUIBindings) {
		builder.tabs(tabLevel).appendLine("public {0} {1} { get { return _{1}; } {2}set { _{1} = value; BindablePropertyChanged(nameof({1})); } }", generateType(mm.type, false), mm.name, mm.isReadOnly ? "private ": string.init);
	} else {
		builder.tabs(tabLevel).appendLine("public {0} {1} { get { return _{1}; } {2}set { _{1} = value; } }", generateType(mm.type, false), mm.name, mm.isReadOnly ? "private ": string.init);
	}

	builder.appendLine();
}
