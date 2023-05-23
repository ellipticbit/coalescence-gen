module hwgen.languages.csharp.enums;

import hwgen.schema;
import hwgen.globals;
import hwgen.stringbuilder;
import hwgen.utility;

import hwgen.languages.csharp.generator;

import std.conv;
import std.stdio;

public void generateEnum(StringBuilder builder, Enumeration en, ushort tabLevel)
{
    builder.appendLine();
    builder.tabs(tabLevel).appendLine("[DataContract]");
    if(en.packed)
    {
        builder.tabs(tabLevel).appendLine("[Flags]");
        builder.tabs(tabLevel).appendLine("public enum {0} : ulong", en.name);
    }
    else
        builder.tabs(tabLevel).appendLine("public enum {0}", en.name);
    builder.tabs(tabLevel++).appendLine("{");
    if (en.packed)
        builder.tabs(tabLevel).appendLine("[EnumMember()] None = 0,");
    ushort bsc = 0;
    foreach(env; en.values)
    {
        if(en.packed) {
            builder.tabs(tabLevel).appendLine("[EnumMember()] {0} = 1 << {1},", env.name, to!string(bsc++));
        }
        else if(!env.value.isNull) {
            builder.tabs(tabLevel).appendLine("[EnumMember()] {0} = {1},", env.name, to!string(env.value.get()));
        }
        else if(env.aggregate.length != 0) {
            builder.tabs(tabLevel).append("[EnumMember()] {0} = ", env.name);
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
            builder.tabs(tabLevel).appendLine("[EnumMember()] {0},", env.name);
        }
    }
    builder.tabs(--tabLevel).appendLine("}");
}
