import hwgen.globals;
import hwgen.schema;
import hwgen.generator;
import hwgen.analyser;
import hwgen.utility;

import sdlang;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.conv;
import std.file;
import std.path;
import std.getopt;
import std.stdio;
import std.string;

int main(string[] args)
{
    writeln("Hotwire Code Generator");
    writeln("Version: ", appver);
    writeln();

    //Make sure there are enough arguments and display usage
    if(args.length == 1)
    {
        displayUsage();
        return 1;
    }
    if(args.length >= 2 && (args[1].toLower() == "-h" || args[1].toLower() == "--help")) {
        displayUsage();
        return 0;
    }

	string projectPath = string.init;
	string rootDir = getcwd();
	string dbdriver = string.init;
	string dbserver = string.init;
	string dbname = string.init;
	string dbuser = string.init;
	string dbpassword = string.init;

	//Read args
	for(int i = 1; i < args.length; i++) {
		if (args[i].toUpper() == "--root-directory".toUpper() || args[i].toUpper() == "-rd".toUpper()) rootDir = args[++i];
		if (args[i].toUpper() == "--project-file".toUpper() || args[i].toUpper() == "-pf".toUpper()) projectPath = args[++i];
		if (args[i].toUpper() == "--db-mssql".toUpper()) dbdriver = "ODBC Driver 17 for SQL Server";
		if (args[i].toUpper() == "--db-server".toUpper()) dbserver = args[++i];
		if (args[i].toUpper() == "--db-name".toUpper()) dbname = args[++i];
		if (args[i].toUpper() == "--db-user".toUpper()) dbuser = args[++i];
		if (args[i].toUpper() == "--db-password".toUpper()) dbpassword = args[++i];
	}

	//Get project directory
	if (!isAbsolute(rootDir)) {
		rootDir = buildNormalizedPath(getcwd(), rootDir);
	}
	if (!exists(rootDir)) {
		writeln("ERROR: Unable to locate project source directory: " ~ rootDir);
		return 2;
	}

	//Get project file path
	if (!projectPath.isNullOrWhitespace() && !isAbsolute(projectPath)) {
		projectPath = buildNormalizedPath(getcwd(), projectPath);
		if (!exists(projectPath)) {
			writeln("ERROR: Unable to locate project file: " ~ projectPath);
			return 2;
		}
	} else {
		projectPath = buildNormalizedPath(getcwd(), ".hotwire.sdl");
		if (!exists(projectPath)) {
			writeln("ERROR: Unable to locate project file: " ~ projectPath);
			return 2;
		}
	}

	// Load the project file.
	Tag projectTag = parseFile(projectPath).expectTag("project");
	if (projectTag is null) {
		writeln("ERROR: Invalid project file specified. No top-level project node was found.");
		return 3;
	}

	// Load schema from database if connection info is present.
	Schema[] dbSchema;
	if (dbdriver != string.init && dbserver != string.init && dbname != string.init && dbuser != string.init && dbpassword != string.init)  {

	}

	//Load files
	auto mergedSchema = loadFiles(rootDir, dbSchema);

	//Load project tag
	Project project = new Project(projectTag, mergedSchema, dbname, dirName(projectPath));

    //Do type analysis
    if(analyse(project)) {
        writeln("Type Analysis Failed.");
        return 1;
    }

    //Generate code and write it to the correct file
    generate(project);

    return 0;
}

private Schema[] loadFiles(string rootDir, Schema[] dbSchema)
{
	Schema[] tsl = dbSchema;
	auto rfFiles = dirEntries(rootDir, SpanMode.depth).filter!(f => f.name.endsWith(".sdl"));
	foreach(rf; rfFiles) {
		if (baseName(rf.name).toUpper() == ".hotwire.sdl".toUpper()) continue;
		writeln("Input: " ~ rf.name);
		Tag frt = parseFile(rf.name);
		foreach (t; frt.maybe.tags) {
			if (t.name.toUpper() == "project".toUpper()) continue;
			if (t.name.toUpper() != "namespace".toUpper()) {
				writeParseWarning("Found unrecognized root tag '" ~ t.name ~ "' in file '" ~ rf.name ~ "'. Skipping.", t.location);
				continue;
			}
			auto sn = t.expectValue!string();
			if (tsl.any!(a => a.name == sn)) {
				foreach (s; tsl) {
					if (s.name == sn) {
						s.merge(t);
						break;
					}
				}
			} else {
				tsl ~= new Schema(t);
			}
		}
	}
	return tsl;
}

private void displayUsage() {

}