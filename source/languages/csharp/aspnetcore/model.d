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
        builder.appendLine("{0}[DataContract]", generateTabs(tabLevel));
    }
    builder.appendLine("{0}public sealed partial class {1}{2}", generateTabs(tabLevel), m.name, (hasOption("xaml") && clientGen) ? " : INotifyPropertyChanged" : string.init);
    builder.appendLine("{0}{", generateTabs(tabLevel));

    foreach(v; m.members)
        generateMemberModel(builder, m, v, cast(ushort)(tabLevel+1));

	if (hasOption("xaml") && clientGen)
	{
		builder.appendLine("{0}public event PropertyChangedEventHandler PropertyChanged;", generateTabs(tabLevel+1));
		builder.appendLine("{0}protected void BindablePropertyChanged(string propertyName) {", generateTabs(tabLevel+1));
		builder.appendLine("{0}if (PropertyChanged != null)", generateTabs(tabLevel+2));
		builder.appendLine("{0}PropertyChanged(this, new PropertyChangedEventArgs(propertyName));", generateTabs(tabLevel+3));
		builder.appendLine("{0}}", generateTabs(tabLevel+1));
	}

    builder.appendLine("{0}public {1}() { }", generateTabs(tabLevel+1), m.name);
    builder.appendLine();

    if (serverGen)
    {
        builder.append("{0}public static {1} Create{1}(", generateTabs(tabLevel+1), m.name);

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
        builder.appendLine("{0}{", generateTabs(tabLevel+1));
        builder.appendLine("{0}return new {1}()", generateTabs(tabLevel+2), m.name);
        builder.appendLine("{0}{", generateTabs(tabLevel+2));
        foreach(mm; m.members.filter!(a => a.readonly && (a.type.type.mode == TypeMode.Primitive || a.type.type.mode == TypeMode.ByteArray))())
            builder.appendLine("{0}{1} = {1},", generateTabs(tabLevel+3), mm.name);
        builder.appendLine("{0}};", generateTabs(tabLevel+2));
        builder.appendLine("{0}}", generateTabs(tabLevel+1));
        builder.appendLine();
    }

    if (m.hasDatabase && serverGen)
    {
        builder.appendLine("{0}public {2}({1} dbObj)", generateTabs(tabLevel+1), m.database, m.name);
        builder.appendLine("{0}{", generateTabs(tabLevel+1));

        foreach(mm; m.members.filter!(a => a.hasDatabase && (a.type.type.mode == TypeMode.Primitive || a.type.type.mode == TypeMode.ByteArray))())
            builder.appendLine("{0}{1} = dbObj.{2};", generateTabs(tabLevel+2), mm.name, mm.database);
        foreach(mm; m.members.filter!(a => a.hasDatabase && (a.type.type.mode == TypeMode.Enum))())
            builder.appendLine("{0}{1} = ({3})dbObj.{2};", generateTabs(tabLevel+2), mm.name, mm.database, generateType(mm.type, false));
        foreach(mm; m.members.filter!(a => a.modelbind && a.hasDatabase && (a.type.type.mode == TypeMode.Model))())
            builder.appendLine("{0}{1} = new {3}(dbObj.{2});", generateTabs(tabLevel+2), mm.name, mm.database, generateType(mm.type, false));
        foreach(mm; m.members.filter!(a => !a.readonly && a.modelbind && a.hasDatabase && (a.type.type.mode == TypeMode.Collection))()) {
            builder.appendLine("{0}{1} = new {3}(dbObj.{2}.Count);", generateTabs(tabLevel+2), mm.name, mm.database, generateType(mm.type, false));
            builder.appendLine("{0}foreach(var t in dbObj.{1}) {", generateTabs(tabLevel+2), mm.database);
            auto tc = cast(TypeCollection)mm.type;
            if (tc.collectionType.mode == TypeMode.Model) {
                builder.appendLine("{0}{1}.Add(new {2}(t));", generateTabs(tabLevel+3), mm.name, generateType(tc.collectionType, false));
            } else if (tc.collectionType.mode == TypeMode.Primitive) {
                builder.appendLine("{0}{1}.Add(t);", generateTabs(tabLevel+3), mm.name);
            }
            builder.appendLine("{0}}", generateTabs(tabLevel+2));
        }
        builder.appendLine("{0}PostCreate(dbObj);", generateTabs(tabLevel+2));
        builder.appendLine("{0}}", generateTabs(tabLevel+1));
        builder.appendLine("{0}partial void PostCreate({1} entity);", generateTabs(tabLevel+1), m.database);
        builder.appendLine();
        builder.appendLine("{0}public void Update(Microsoft.EntityFrameworkCore.DbContext context, {1} dbObj, bool cascade = false)", generateTabs(tabLevel+1), m.database);
        builder.appendLine("{0}{", generateTabs(tabLevel+1));
        foreach(mm; m.members.filter!(a => !a.readonly && a.hasDatabase && (a.type.type.mode == TypeMode.Primitive || a.type.type.mode == TypeMode.ByteArray))())
            builder.appendLine("{0}dbObj.{1} = this.{2};", generateTabs(tabLevel+2), mm.database,  mm.name);
        //Cannot generate updates for Enums.
        foreach(mm; m.members.filter!(a => !a.readonly && a.modelbind && a.update && a.hasDatabase && (a.type.type.mode == TypeMode.Model))()) {
            builder.appendLine("{0}if (dbObj.{1} == null) dbObj.{1} = context.Add(new {2}()).Entity;", generateTabs(tabLevel+2), mm.database, m.database);
            builder.appendLine("{0}this.{1}.UpdateEntity(context, dbObj.{2});", generateTabs(tabLevel+2), mm.name, mm.database);
        }
        builder.appendLine("{0}PostUpdate(context, dbObj);", generateTabs(tabLevel+2));
        builder.appendLine("{0}if (!cascade) return;", generateTabs(tabLevel+2));
        foreach(mm; m.members.filter!(a => !a.readonly && a.modelbind && a.update && a.hasDatabase && (a.type.type.mode == TypeMode.Collection))()) {
            auto tc = cast(TypeCollection)mm.type;
            builder.appendLine("{0}foreach(var t in dbObj.{1}.ToArray()) {", generateTabs(tabLevel+2), mm.database);
            if (tc.collectionType.mode == TypeMode.Model) {
                auto otc = cast(TypeModel)tc.collectionType;
                if (otc.definition.hasPrimaryKey) {
                    string[] terms;
                    foreach (pkm; otc.definition.members.filter!(a => a.primaryKey)()) {
                        terms ~= "a." ~ pkm.name ~ " == " ~ "t." ~ pkm.database;
                    }
                    builder.appendLine("{0}var f = this.{1}.FirstOrDefault(a => {2});", generateTabs(tabLevel+3), mm.name, terms.join(" && "));
                    builder.appendLine("{0}if (f != null) continue;", generateTabs(tabLevel+3), otc.definition.database);
                    builder.appendLine("{0}context.Remove(t);", generateTabs(tabLevel+3));
                    builder.appendLine("{0}dbObj.{1}.Remove(t);", generateTabs(tabLevel+3), mm.database);
                }
            }
            builder.appendLine("{0}}", generateTabs(tabLevel+2));
        }
        foreach(mm; m.members.filter!(a => !a.readonly && a.modelbind && a.update && a.hasDatabase && (a.type.type.mode == TypeMode.Collection))()) {
            auto tc = cast(TypeCollection)mm.type;
            if (tc.collectionType.mode == TypeMode.Primitive) builder.appendLine("{0}dbObj.{1}.Clear();", generateTabs(tabLevel+2), mm.database);
            builder.appendLine("{0}if (this.{1} != null) {", generateTabs(tabLevel+2), mm.name);
            builder.appendLine("{0}var _tdbl = dbObj.{1}.ToList();", generateTabs(tabLevel+3), mm.database);
            builder.appendLine("{0}foreach(var t in this.{1}) {", generateTabs(tabLevel+3), mm.name);
            if (tc.collectionType.mode == TypeMode.Model) {
                auto otc = cast(TypeModel)tc.collectionType;
                if (otc.definition.hasPrimaryKey) {
                    string[] terms;
                    foreach (pkm; otc.definition.members.filter!(a => a.primaryKey)()) {
                        terms ~= "a." ~ pkm.database ~ " == " ~ "t." ~ pkm.name;
                    }
                    builder.appendLine("{0}var f = _tdbl.FirstOrDefault(a => {1});", generateTabs(tabLevel+4), terms.join(" && "));
                    builder.appendLine("{0}var n = f ?? context.Add(new {1}()).Entity;", generateTabs(tabLevel+4), otc.definition.database);
                    builder.appendLine("{0}t.Update(context, n, cascade);", generateTabs(tabLevel+4));
                    builder.appendLine("{0}if (f == null) dbObj.{1}.Add(n);", generateTabs(tabLevel+4), mm.database);
                }
            } else if (tc.collectionType.mode == TypeMode.Primitive) {
                builder.appendLine("{0}dbObj.{1}.Add(t);", generateTabs(tabLevel+4), mm.database);
            }
            builder.appendLine("{0}}", generateTabs(tabLevel+3));
            builder.appendLine("{0}}", generateTabs(tabLevel+2));
        }
        builder.appendLine("{0}}", generateTabs(tabLevel+1));
        builder.appendLine("{0}partial void PostUpdate(Microsoft.EntityFrameworkCore.DbContext context, {1} entity);", generateTabs(tabLevel+1), m.database);
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
        builder.appendLine("{0}public {1}(System.Data.DataTableReader reader)", generateTabs(tabLevel+1), m.name);
        builder.appendLine("{0}{", generateTabs(tabLevel+1));
        foreach(mm; m.members.filter!(a => a.hasDatabase && (a.type.type.mode == TypeMode.Primitive))()) {
            builder.appendLine("{0}if (!reader.IsDBNull(reader.GetOrdinal(\"{1}\"))) {1} = reader.Get{2}(reader.GetOrdinal(\"{1}\"));", generateTabs(tabLevel+2), mm.name, GetDataReaderTypeName(cast(TypePrimitive)mm.type.type));
        }
        foreach(mm; m.members.filter!(a => a.hasDatabase && (a.type.type.mode == TypeMode.ByteArray))()) {
            builder.appendLine("{0}if (!reader.IsDBNull(reader.GetOrdinal(\"{1}\"))) {{", generateTabs(tabLevel+2), mm.name);
            builder.appendLine("{0}var len = reader.GetBytes(reader.GetOrdinal(\"{1}\"), 0, null, 0, Int32.MaxValue);", generateTabs(tabLevel+3), mm.name);
            builder.appendLine("{0}{1} = new byte[len];", generateTabs(tabLevel+3), mm.name);
            builder.appendLine("{0}{1} = reader.GetBytes(reader.GetOrdinal(\"{1}\"), 0, {1}, 0, len);", generateTabs(tabLevel+3), mm.name);
            builder.appendLine("{0}}}", generateTabs(tabLevel+2), mm.name);
        }
        builder.appendLine("{0}}", generateTabs(tabLevel+1));
        builder.appendLine();
    }

    builder.appendLine("{0}}", generateTabs(tabLevel));
}

private void generateMemberModel(StringBuilder builder, Model m, ModelMember mm, ushort tabLevel)
{
	if (mm.hidden) return;

	if (hasOption("useNewtonsoft")) builder.appendLine("{0}[DataMember(Name = \"{1}\", IsRequired = {2})]", generateTabs(tabLevel), mm.hasTransport ? mm.transport : mm.name, mm.type.nullable ? "false" : "true");
	builder.appendLine("{0}private {1} _{2};", generateTabs(tabLevel), generateType(mm.type, false), mm.name);
	if (!hasOption("useNewtonsoft")) {
		builder.appendLine("{0}[JsonPropertyName(\"{1}\")]", generateTabs(tabLevel), mm.hasTransport ? mm.transport : mm.name);
		builder.appendLine("{0}[JsonInclude]", generateTabs(tabLevel));
	}
	if (hasOption("xaml") && clientGen) {
		builder.appendLine("{0}public {1} {2} { get { return _{2}; } {3}set { _{2} = value; BindablePropertyChanged(\"{2}\"); } }", generateTabs(tabLevel), generateType(mm.type, false), mm.name, mm.readonly ? "private ": string.init);
	} else {
		builder.appendLine("{0}public {1} {2} { get { return _{2}; } {3}set { _{2} = value; } }", generateTabs(tabLevel), generateType(mm.type, false), mm.name, mm.readonly ? "private ": string.init);
	}

	builder.appendLine();
}
