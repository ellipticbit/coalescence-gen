module restforge.globals;

import restforge.model;
import restforge.types;

import std.conv;
import std.file;
import std.format;
import std.path;
import std.stdio;
import std.string;

import sdlang;

public const string appver = "2.0.0";

public __gshared ProjectFile[] projectFiles;

public __gshared bool serverGen = false;
public __gshared bool clientGen = false;
public __gshared string inputPath = null;
public __gshared bool pathIsDir = false;
public __gshared string outputPath = null;
public __gshared string language = null;

public __gshared bool useSpaces = true;
public __gshared ushort tabSpaces = 4;

public __gshared string[string] options;

public __gshared int errorCount = 0;
public __gshared int warnCount = 0;

public string cleanName(string name) {
    return name.replace("[", string.init)
            .replace("]", string.init)
            .replace("{", string.init)
            .replace("}", string.init)
            .replace("(", string.init)
            .replace(")", string.init);
}

public void writeFile(ProjectFile file, string ext)
{
    //Write generated code to disk
    writeln("Output File: " ~ setExtension(file.outputPath, ext));
    if(!exists(dirName(file.outputPath)))
        mkdirRecurse(dirName(file.outputPath));
    auto fsfile = File(setExtension(file.outputPath, ext), "w");
    fsfile.write(file.builder);
    fsfile.close();
}

public string getFullPath(string partialPath)
{
    try {
        if(pathIsDir)
            return buildNormalizedPath(inputPath, partialPath);
        else
            return buildNormalizedPath(dirName(inputPath), partialPath);
    }
    catch (Throwable) { }
    return "";
}

public bool hasProjectFile(string inputPath)
{
    foreach(pf; projectFiles)
        if(pf.inputPath == inputPath)
            return true;
    return false;
}

public bool isStringDictionary(TypeBase type)
{
    if(typeid(type) == typeid(TypeDictionary))
    {
        TypeDictionary td = cast(TypeDictionary)(type);
        if(getTypePrimitive(td.keyType) == TypePrimitives.String && getTypePrimitive(td.valueType) == TypePrimitives.String)
            return true;
    }
    return false;
}

public bool hasOption(string name)
{
    return (name in options) !is null;
}

public void writeParseError(string message, Location location)
{
	errorCount++;
    writef("%s(%d,%d) ERROR: ", location.file, location.line, location.col);
    writeln(message);
}

public void writeParseWarning(string message, Location location)
{
	warnCount++;
    writef("%s(%d,%d) WARN: ", location.file, location.line, location.col);
    writeln(message);
}

public void writeTypeError(TypeUser type)
{
	errorCount++;
    writefln("%s(%d,%d) ERROR: Unable to locate type '%s'", type.sourceLocation.file, type.sourceLocation.line, type.sourceLocation.col, type.name);
}

public void writeTypeErrorSuggest(TypeUser type, string suggest)
{
    writefln("%s(%d,%d) INFO: Did you mean '%s'", type.sourceLocation.file, type.sourceLocation.line, type.sourceLocation.col, suggest);
}

public void writeAnalyserError(string message, Location loc)
{
	errorCount++;
    writefln("%s(%d,%d) ERROR: %s", loc.file, loc.line, loc.col, message);
}
