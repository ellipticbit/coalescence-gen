module coalescence.languages.csharp.enums;

import coalescence.schema;
import coalescence.globals;
import phobos.text.stringbuilder;
import coalescence.utility;

import coalescence.languages.csharp.extensions;
import coalescence.languages.csharp.generator;

import std.conv;
import std.stdio;

public void generateEnum(Enumeration en, StringBuilder builder, CSharpProjectOptions opts, ushort tabLevel)
{
    builder.appendLine();
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"2.0.0.0\")]");
    if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
        builder.tabs(tabLevel).appendLine("[DataContract]");
    }
    if(en.packed)
    {
        builder.tabs(tabLevel).appendLine("[Flags]");
        builder.tabs(tabLevel).appendLine(i"public enum $(en.name) : ulong");
    }
    else
        builder.tabs(tabLevel).appendLine(i"public enum $(en.name)");
    builder.tabs(tabLevel++).appendLine("{");
    if (en.packed)
        builder.tabs(tabLevel).appendLine(i"$((opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) ? "[EnumMember()] " : string.init)} None = 0,");
    ushort bsc = 0;
    foreach(env; en.values)
    {
        if(en.packed) {
            builder.tabs(tabLevel).appendLine(i"$((opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) ? "[EnumMember()] " : string.init)$(env.name) = 1 << $(to!string(bsc++)),");
        }
        else if(!env.value.isNull) {
            builder.tabs(tabLevel).appendLine(i"$((opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) ? "[EnumMember()] " : string.init) $(env.name) = $(to!string(env.value.get())),");
        }
        else if(env.aggregate.length != 0) {
            builder.tabs(tabLevel).append(i"$((opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) ? "[EnumMember()] " : string.init) $(env.name) = ");
            for(int i = 0; i < env.aggregate.length; i++)
            {
                //writeln(env.name);
                builder.append(i"$(env.aggregate[i].parent.parent.name).$(env.aggregate[i].value.name)");
                if(i < env.aggregate.length - 1)
                    builder.append(" | ");
            }
            builder.appendLine(",");
        }
        else {
            builder.tabs(tabLevel).appendLine(i"$((opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) ? "[EnumMember()] " : string.init) $(env.name),");
        }
    }
    builder.tabs(--tabLevel).appendLine("}");
}
