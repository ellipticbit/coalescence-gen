module coalescence.globals;

import coalescence.stringbuilder;
import coalescence.types;

import std.conv;
import std.file;
import std.format;
import std.path;
import std.stdio;
import std.string;

import sdlite;

public const string appver = "1.5.1";

public __gshared int errorCount = 0;
public __gshared int warnCount = 0;

public void writeParseError(string message, Location location)
{
	errorCount++;
	writef("%s(%d,%d) ERROR: ", location.file, location.line, location.column);
	writeln(message);
}

public void writeParseWarning(string message, Location location)
{
	warnCount++;
	writef("%s(%d,%d) WARN: ", location.file, location.line, location.column);
	writeln(message);
}

public void writeTypeError(TypeUser type)
{
	errorCount++;
	writefln("%s(%d,%d) ERROR: Unable to locate type '%s'", type.sourceLocation.file, type.sourceLocation.line, type.sourceLocation.column, type.name);
}

public void writeTypeErrorSuggest(string suggest, Location loc)
{
	writefln("%s(%d,%d)        Did you mean: %s", loc.file, loc.line, loc.column, suggest);
}

public void writeAnalyserError(string message, Location loc)
{
	errorCount++;
	writefln("%s(%d,%d) ERROR: %s", loc.file, loc.line, loc.column, message);
}

public void writeAnalyserWarning(string message, Location loc)
{
	writefln("%s(%d,%d) WARN: %s", loc.file, loc.line, loc.column, message);
}

public void writeError(string message)
{
	errorCount++;
	writefln("ERROR: %s", message);
}
