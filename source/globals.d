module coalescence.globals;

import coalescence.stringbuilder;
import coalescence.types;

import std.conv;
import std.file;
import std.format;
import std.path;
import std.stdio;
import std.string;

import sdlang;

public const string appver = "1.2.0";

public __gshared int errorCount = 0;
public __gshared int warnCount = 0;

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

public void writeError(string message)
{
	errorCount++;
    writefln("ERROR: %s", message);
}
