import coalescence.globals;
import coalescence.schema;
import coalescence.generator;
import coalescence.analyser;
import coalescence.utility;

import coalescence.database.mssql.schemareader;

import sdlite;
import ddbc;

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
    writeln("Coalescence Code Generator - v", appver);
    writeln("Copyright (C) 2024 EllipticBit LLC, All Rights Reserved.");
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
	bool dbmssql = false;
	string dbserver = string.init;
	string dbname = string.init;
	string dbuser = string.init;
	string dbpassword = string.init;

	//Read args
	for(int i = 1; i < args.length; i++) {
		if (args[i].toUpper() == "--root-directory".toUpper() || args[i].toUpper() == "-rd".toUpper()) rootDir = args[++i];
		if (args[i].toUpper() == "--project-file".toUpper() || args[i].toUpper() == "-pf".toUpper()) projectPath = args[++i];
		if (args[i].toUpper() == "--db-mssql".toUpper()) dbmssql = true;
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
		projectPath = buildNormalizedPath(rootDir, projectPath);
		if (!exists(projectPath)) {
			writeln("ERROR: Unable to locate project file: " ~ projectPath);
			return 2;
		}
	} else {
		projectPath = buildNormalizedPath(rootDir, ".coalescence.sdl");
		if (!exists(projectPath)) {
			writeln("ERROR: Unable to locate project file: " ~ projectPath);
			return 2;
		}
	}

	// Load the project file.
	SDLNode[] projectTags = parseFile(projectPath);

	if (projectTags.length == 0 || projectTags[0].name != "project") {
		writeln("ERROR: Invalid project file specified. No top-level project node was found.");
		return 3;
	}

	// Load schema from database if connection info is present.
	Schema[] dbSchema;
	if (dbserver != string.init && dbuser != string.init && dbpassword != string.init)  {
		if (dbmssql) {
			string connectionStr = (dbname != string.init) ?
				"ddbc:odbc://" ~ dbserver ~ "?database=" ~ dbname ~ ",user=" ~ dbuser ~ ",password=" ~ dbpassword ~ ",ssl=true,driver=ODBC Driver 17 for SQL Server" :
				"ddbc:odbc://" ~ dbserver ~ "?user=" ~ dbuser ~ ",password=" ~ dbpassword ~ ",ssl=true,driver=ODBC Driver 17 for SQL Server";
			auto connection = createConnection(connectionStr);
			scope(exit) connection.close();

			dbSchema = readMssqlSchemata(connection);
		}
	}

	//Load files
	auto mergedSchema = loadFiles(rootDir, dbSchema);

	//Load project tag
	Project project = new Project(projectTags[0], mergedSchema, dbname, dirName(projectPath));

	if (errorCount > 0) return errorCount;

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
		if (baseName(rf.name).toUpper() == ".coalescence.sdl".toUpper()) continue;
		writeln("Input:\t" ~ rf.name);
		SDLNode[] frt = parseFile(rf.name);
		foreach (t; frt) {
			if (t.name.toUpper() == "project".toUpper()) continue;
			if (t.name.toUpper() != "namespace".toUpper()) {
				writeParseWarning("Found unrecognized root tag '" ~ t.name ~ "' in file '" ~ rf.name ~ "'. Skipping.", t.location);
				continue;
			}
			auto sn = t.expectValue!string(0);
			if (tsl.any!(a => a.name.toUpper() == sn.toUpper())) {
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

private SDLNode[] parseFile(string path) {
	import std.ascii : newline;
	import std.array;

	auto sdlFile = File(path, "r");
	scope(exit) {
		sdlFile.close();
	}

	string sdl = to!string(sdlFile.byLine().joiner(newline).array);

	SDLNode[] docNodes;
	parseSDLDocument!((n) { docNodes ~= n; })(sdl, baseName(path));

	return docNodes;
}

private void displayUsage() {

}