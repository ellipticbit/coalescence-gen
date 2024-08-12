module coalescence.languages.csharp.enums;

import coalescence.schema;
import coalescence.globals;
import coalescence.stringbuilder;
import coalescence.utility;

import coalescence.languages.csharp.extensions;
import coalescence.languages.csharp.generator;

import std.conv;
import std.stdio;

public void generateEnum(Enumeration en, StringBuilder builder, CSharpProjectOptions opts, ushort tabLevel)
{
    builder.appendLine();
	builder.tabs(tabLevel).appendLine("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", \"1.3.3.0\")]");
    if (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) {
        builder.tabs(tabLevel).appendLine("[DataContract]");
    }
    if(en.packed)
    {
        builder.tabs(tabLevel).appendLine("[Flags]");
        builder.tabs(tabLevel).appendLine("public enum {0} : ulong", en.name);
    }
    else
        builder.tabs(tabLevel).appendLine("public enum {0}", en.name);
    builder.tabs(tabLevel++).appendLine("{");
    if (en.packed)
        builder.tabs(tabLevel).appendLine("{0}} None = 0,", (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) ? "[EnumMember()] " : string.init);
    ushort bsc = 0;
    foreach(env; en.values)
    {
        if(en.packed) {
            builder.tabs(tabLevel).appendLine("{2}{0} = 1 << {1},", env.name, to!string(bsc++), (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) ? "[EnumMember()] " : string.init);
        }
        else if(!env.value.isNull) {
            builder.tabs(tabLevel).appendLine("{2} {0} = {1},", env.name, to!string(env.value.get()), (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) ? "[EnumMember()] " : string.init);
        }
        else if(env.aggregate.length != 0) {
            builder.tabs(tabLevel).append("{1} {0} = ", env.name, (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) ? "[EnumMember()] " : string.init);
            for(int i = 0; i < env.aggregate.length; i++)
            {
                //writeln(env.name);
                builder.append(env.aggregate[i].parent.parent.name ~ "." ~ env.aggregate[i].value.name);
                if(i < env.aggregate.length - 1)
                    builder.append(" | ");
            }
            builder.appendLine(",");
        }
        else {
            builder.tabs(tabLevel).appendLine("{1} {0},", env.name, (opts.hasSerializer(CSharpSerializers.NewtonsoftJson) || opts.hasSerializer(CSharpSerializers.DataContract)) ? "[EnumMember()] " : string.init);
        }
    }
    builder.tabs(--tabLevel).appendLine("}");
}
