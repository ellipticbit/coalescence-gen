module restforge.languages.csharp.aspnetcore.enums;

import restforge.model;
import restforge.globals;
import restforge.stringbuilder;

import restforge.languages.csharp.aspnetcore.generator;

import std.conv;
import std.stdio;

public void generateEnum(StringBuilder builder, Enumeration en, ushort tabLevel)
{
    builder.appendLine();
    builder.appendLine("{0}[DataContract]", generateTabs(tabLevel));
    if(en.packed)
    {
        builder.appendLine("{0}[Flags]", generateTabs(tabLevel));
        builder.appendLine("{0}public enum {1} : ulong", generateTabs(tabLevel), en.name);
    }
    else
        builder.appendLine("{0}public enum {1}", generateTabs(tabLevel), en.name);
    builder.appendLine("{0}{", generateTabs(tabLevel));
    if (en.packed)
        builder.appendLine("{0}[EnumMember()] None = 0,", generateTabs(tabLevel + 1));
    ushort bsc = 0;
    foreach(env; en.values)
    {
        if(en.packed) {
            builder.appendLine("{0}[EnumMember()] {1} = 1 << {2},", generateTabs(tabLevel + 1), env.name, to!string(bsc++));
        }
        else if(!env.value.isNull) {
            builder.appendLine("{0}[EnumMember()] {1} = {2},", generateTabs(tabLevel + 1), env.name, to!string(env.value.get()));
        }
        else if(env.aggregate.length != 0) {
            builder.append("{0}[EnumMember()] {1} = ", generateTabs(tabLevel + 1), env.name);
            for(int i = 0; i < env.aggregate.length; i++)
            {
                //writeln(env.name);
                builder.append(env.aggregate[i].type.getFqn() ~ "." ~ env.aggregate[i].value.name);
                if(i < env.aggregate.length - 1)
                    builder.append(" | ");
            }
            builder.appendLine(",");
        }
        else {
            builder.appendLine("{0}[EnumMember()] {1},", generateTabs(tabLevel + 1), env.name);
        }
    }
    builder.appendLine("{0}}", generateTabs(tabLevel));
}
