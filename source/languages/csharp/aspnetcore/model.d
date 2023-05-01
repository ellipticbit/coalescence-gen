module restforge.languages.csharp.aspnetcore.model;

import restforge.types;
import restforge.model;
import restforge.globals;
import restforge.stringbuilder;

import restforge.languages.csharp.aspnetcore.generator;

import std.array;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.stdio;
import std.conv;

public void generateModel(StringBuilder builder, Model m, ushort tabLevel)
{
    builder.appendLine();
    if (hasOption("useNewtonsoft")) {
        builder.tabs(tabLevel).appendLine("[DataContract]");
    }
    builder.tabs(tabLevel).appendLine("public sealed partial class {0}{1}", m.name, (hasOption("xaml") && clientGen) ? " : INotifyPropertyChanged" : string.init);
    builder.tabs(tabLevel++).appendLine("{");

    foreach(v; m.members)
        generateMemberModel(builder, m, v, cast(ushort)(tabLevel));

	if (hasOption("xaml") && clientGen)
	{
		builder.tabs(tabLevel).appendLine("public event PropertyChangedEventHandler PropertyChanged;");
		builder.tabs(tabLevel++).appendLine("private void BindablePropertyChanged(string propertyName) {");
		builder.tabs(tabLevel).appendLine("if (PropertyChanged != null) PropertyChanged(this, new PropertyChangedEventArgs(propertyName));");
		builder.tabs(--tabLevel).appendLine("}");
	}

    builder.tabs(tabLevel).appendLine("public {0}() { }", m.name);
    builder.appendLine();

    if (serverGen)
    {
        builder.tabs(tabLevel).append("public static {0} Create{0}(", m.name);

        if(m.members.any!(a => a.readonly))
        {
            auto mml = m.members.filter!(a => a.readonly).array;
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
        foreach(mm; m.members.filter!(a => a.readonly && (a.type.type.mode == TypeMode.Primitive || a.type.type.mode == TypeMode.ByteArray))())
            builder.tabs(tabLevel).appendLine("{0} = {0},", mm.name);
        builder.tabs(--tabLevel).appendLine("};");
        builder.tabs(--tabLevel).appendLine("}");
        builder.appendLine();
    }

    if (m.hasDatabase && serverGen)
    {
        builder.tabs(tabLevel).appendLine("public {1}({0} dbObj)", m.database, m.name);
        builder.tabs(tabLevel++).appendLine("{");

        foreach(mm; m.members.filter!(a => a.hasDatabase && (a.type.type.mode == TypeMode.Primitive || a.type.type.mode == TypeMode.ByteArray))())
            builder.tabs(tabLevel).appendLine("{0} = dbObj.{1};", mm.name, mm.database);
        foreach(mm; m.members.filter!(a => a.hasDatabase && (a.type.type.mode == TypeMode.Enum))())
            builder.tabs(tabLevel).appendLine("{0} = ({2})dbObj.{1};", mm.name, mm.database, generateType(mm.type, false));
        foreach(mm; m.members.filter!(a => a.modelbind && a.hasDatabase && (a.type.type.mode == TypeMode.Model))())
            builder.tabs(tabLevel).appendLine("{0} = new {2}(dbObj.{1});", mm.name, mm.database, generateType(mm.type, false));
        foreach(mm; m.members.filter!(a => !a.readonly && a.modelbind && a.hasDatabase && (a.type.type.mode == TypeMode.Collection))()) {
            builder.tabs(tabLevel).appendLine("{0} = new {2}(dbObj.{1}.Count);", mm.name, mm.database, generateType(mm.type, false));
            builder.tabs(tabLevel).appendLine("foreach(var t in dbObj.{0}) {", mm.database);
            auto tc = cast(TypeCollection)mm.type.type;
            if (tc.collectionType.mode == TypeMode.Model) {
                builder.tabs(tabLevel).appendLine("{0}.Add(new {1}(t));", mm.name, generateType(tc.collectionType, false));
            } else if (tc.collectionType.mode == TypeMode.Primitive) {
                builder.tabs(tabLevel).appendLine("{0}.Add(t);", mm.name);
            }
            builder.tabs(tabLevel).appendLine("}");
        }
        builder.tabs(tabLevel).appendLine("PostCreate(dbObj);");
        builder.tabs(--tabLevel).appendLine("}");
        builder.tabs(tabLevel).appendLine("partial void PostCreate({0} entity);", m.database);
        builder.appendLine();
        builder.tabs(tabLevel).appendLine("public void Update(Microsoft.EntityFrameworkCore.DbContext context, {0} dbObj, bool cascade = false)", m.database);
        builder.tabs(tabLevel++).appendLine("{");
        foreach(mm; m.members.filter!(a => !a.readonly && a.hasDatabase && (a.type.type.mode == TypeMode.Primitive || a.type.type.mode == TypeMode.ByteArray))())
            builder.tabs(tabLevel).appendLine("dbObj.{0} = this.{1};", mm.database,  mm.name);
        //Cannot generate updates for Enums.
        foreach(mm; m.members.filter!(a => !a.readonly && a.modelbind && a.update && a.hasDatabase && (a.type.type.mode == TypeMode.Model))()) {
            builder.tabs(tabLevel).appendLine("if (dbObj.{0} == null) dbObj.{0} = context.Add(new {1}()).Entity;", mm.database, generateType(mm.type, false));
            builder.tabs(tabLevel).appendLine("this.{0}.Update(context, dbObj.{1});", mm.name, mm.database);
        }
        builder.tabs(tabLevel).appendLine("PostUpdate(context, dbObj);");
        builder.tabs(tabLevel).appendLine("if (!cascade) return;");
        foreach(mm; m.members.filter!(a => !a.readonly && a.modelbind && a.update && a.hasDatabase && (a.type.type.mode == TypeMode.Collection))()) {
            auto tc = cast(TypeCollection)mm.type.type;
            builder.tabs(tabLevel++).appendLine("foreach(var t in dbObj.{0}.ToArray()) {", mm.database);
            if (tc.collectionType.mode == TypeMode.Model) {
                auto otc = cast(TypeModel)tc.collectionType;
                if (otc.definition.hasPrimaryKey) {
                    string[] terms;
                    foreach (pkm; otc.definition.members.filter!(a => a.primaryKey)()) {
                        terms ~= "a." ~ pkm.name ~ " == " ~ "t." ~ pkm.database;
                    }
                    builder.tabs(tabLevel).appendLine("var f = this.{0}.FirstOrDefault(a => {1});", mm.name, terms.join(" && "));
                    builder.tabs(tabLevel).appendLine("if (f != null) continue;", otc.definition.database);
                    builder.tabs(tabLevel).appendLine("context.Remove(t);");
                    builder.tabs(tabLevel).appendLine("dbObj.{0}.Remove(t);", mm.database);
                }
            }
            builder.tabs(--tabLevel).appendLine("}");
        }
        foreach(mm; m.members.filter!(a => !a.readonly && a.modelbind && a.update && a.hasDatabase && (a.type.type.mode == TypeMode.Collection))()) {
            auto tc = cast(TypeCollection)mm.type.type;
            if (tc.collectionType.mode == TypeMode.Primitive) builder.appendLine("dbObj.{0}.Clear();", mm.database);
            builder.tabs(tabLevel++).appendLine("if (this.{0} != null) {", mm.name);
            builder.tabs(tabLevel).appendLine("var _tdbl = dbObj.{0}.ToList();", mm.database);
            builder.tabs(tabLevel++).appendLine("foreach(var t in this.{0}) {", mm.name);
            if (tc.collectionType.mode == TypeMode.Model) {
                auto otc = cast(TypeModel)tc.collectionType;
                if (otc.definition.hasPrimaryKey) {
                    string[] terms;
                    foreach (pkm; otc.definition.members.filter!(a => a.primaryKey)()) {
                        terms ~= "a." ~ pkm.database ~ " == " ~ "t." ~ pkm.name;
                    }
                    builder.tabs(tabLevel).appendLine("var f = _tdbl.FirstOrDefault(a => {0});", terms.join(" && "));
                    builder.tabs(tabLevel).appendLine("var n = f ?? context.Add(new {0}()).Entity;", otc.definition.database);
                    builder.tabs(tabLevel).appendLine("t.Update(context, n, cascade);");
                    builder.tabs(tabLevel).appendLine("if (f == null) dbObj.{0}.Add(n);", mm.database);
                }
            } else if (tc.collectionType.mode == TypeMode.Primitive) {
                builder.tabs(tabLevel).appendLine("dbObj.{0}.Add(t);", mm.database);
            }
            builder.tabs(--tabLevel).appendLine("}");
            builder.tabs(--tabLevel).appendLine("}");
        }
        builder.tabs(--tabLevel).appendLine("}");
        builder.tabs(tabLevel).appendLine("partial void PostUpdate(Microsoft.EntityFrameworkCore.DbContext context, {0} entity);", m.database);
        builder.appendLine();
    }

    string GetDataReaderTypeName(TypePrimitive type) {
        if (type.primitive == TypePrimitives.Boolean) return "Boolean";
        if (type.primitive == TypePrimitives.Int8) return "Char";
        if (type.primitive == TypePrimitives.UInt8) return "Byte";
        if (type.primitive == TypePrimitives.Int16) return "Int16";
        if (type.primitive == TypePrimitives.UInt16) return "Int16";
        if (type.primitive == TypePrimitives.Int32) return "Int32";
        if (type.primitive == TypePrimitives.UInt32) return "Int32";
        if (type.primitive == TypePrimitives.Int64) return "Int64";
        if (type.primitive == TypePrimitives.UInt64) return "Int64";
        if (type.primitive == TypePrimitives.Float) return "Float";
        if (type.primitive == TypePrimitives.Double) return "Double";
        if (type.primitive == TypePrimitives.Fixed) return "Decimal";
        if (type.primitive == TypePrimitives.String || type.primitive == TypePrimitives.Base64String || type.primitive == TypePrimitives.Guid) return "String";
        if (type.primitive == TypePrimitives.DateTime) return "DateTime";
        if (type.primitive == TypePrimitives.DateTimeTz) return "DateTimeOffset";
        if (type.primitive == TypePrimitives.TimeSpan) return "TimeSpan";
        return string.init;
    }

    if (serverGen && !m.hasDatabase && m.members.any!(a => a.hasDatabase)) {
        builder.tabs(tabLevel).appendLine("public {0}(System.Data.DataTableReader reader)", m.name);
        builder.tabs(tabLevel++).appendLine("{");
        foreach(mm; m.members.filter!(a => a.hasDatabase && (a.type.type.mode == TypeMode.Primitive))()) {
            builder.tabs(tabLevel).appendLine("if (!reader.IsDBNull(reader.GetOrdinal(\"{0}\"))) {0} = reader.Get{1}(reader.GetOrdinal(\"{0}\"));", mm.name, GetDataReaderTypeName(cast(TypePrimitive)mm.type.type));
        }
        foreach(mm; m.members.filter!(a => a.hasDatabase && (a.type.type.mode == TypeMode.ByteArray))()) {
            builder.tabs(tabLevel++).appendLine("if (!reader.IsDBNull(reader.GetOrdinal(\"{0}\"))) {{", mm.name);
            builder.tabs(tabLevel).appendLine("var len = reader.GetBytes(reader.GetOrdinal(\"{0}\"), 0, null, 0, Int32.MaxValue);", mm.name);
            builder.tabs(tabLevel).appendLine("{0} = new byte[len];", mm.name);
            builder.tabs(tabLevel).appendLine("{0} = reader.GetBytes(reader.GetOrdinal(\"{0}\"), 0, {0}, 0, len);", mm.name);
            builder.tabs(--tabLevel).appendLine("}}", mm.name);
        }
        builder.tabs(--tabLevel).appendLine("}");
        builder.appendLine();
    }

    builder.tabs(--tabLevel).appendLine("}");
}

private void generateMemberModel(StringBuilder builder, Model m, ModelMember mm, ushort tabLevel)
{
	if (mm.hidden) return;

	if (hasOption("useNewtonsoft")) builder.tabs(tabLevel).appendLine("[DataMember(Name = \"{0}\", IsRequired = {1})]", mm.hasTransport ? mm.transport : mm.name, mm.type.nullable ? "false" : "true");
	builder.tabs(tabLevel).appendLine("private {0} _{1};", generateType(mm.type, false), mm.name);
	if (!hasOption("useNewtonsoft")) {
		builder.tabs(tabLevel).appendLine("[JsonPropertyName(\"{0}\")]", mm.hasTransport ? mm.transport : mm.name);
		builder.tabs(tabLevel).appendLine("[JsonInclude]");
	}
	if (hasOption("xaml") && clientGen) {
		builder.tabs(tabLevel).appendLine("public {0} {1} { get { return _{1}; } {2}set { _{1} = value; BindablePropertyChanged(nameof({1})); } }", generateType(mm.type, false), mm.name, mm.readonly ? "private ": string.init);
	} else {
		builder.tabs(tabLevel).appendLine("public {0} {1} { get { return _{1}; } {2}set { _{1} = value; } }", generateType(mm.type, false), mm.name, mm.readonly ? "private ": string.init);
	}

	builder.appendLine();
}
