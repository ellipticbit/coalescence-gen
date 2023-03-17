import restforge.globals;
import restforge.model;
import restforge.generator;
import restforge.analyser;

import std.algorithm.iteration;
import std.conv;
import std.file;
import std.path;
import std.getopt;
import std.stdio;
import std.string;

int main(string[] args)
{
    writeln("Hotwire Web Service Code Generator");
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
    if(args.length < 4) {
        displayUsage();
        return 1;
    }

    //Determine if client or server run
    if(args[1].toLower() != "server" && args[1].toLower() != "client") {
        writefln("Encountered invalid argument '%s'. Expected 'server' or 'client'", args[1]);
        return 1;
    }
    if(args[1].toLower() == "server") serverGen = true;
    else if(args[1].toLower() == "client") clientGen = true;

    //Parse input path
    inputPath = buildNormalizedPath(getcwd(), args[2]);
    if(exists(inputPath)) {
        try {
            if(isDir(inputPath)) pathIsDir = true;
        } catch(Throwable) { }
    }
    else {
        writefln("Encountered invalid argument '%s'. Expected a valid local path. Attempted: %s", args[3], inputPath);
        return 1;
    }

    //Parse output path
    outputPath = args[3];
    outputPath = buildNormalizedPath(getcwd(), outputPath);

    //Parse options
    language = "CSharp"; //TODO: Hardwiring for now until other languages get added.
    if (args.length > 4)
    {
        auto opts = parseOptions(args[4..$]);
        if(opts is null)
        {
            writeln("opts is null");
            return 1;
        }

        options = opts;
    }

    //Load files
    loadFiles();

    //Do semantic analysis
    if(!analyse()) {
        writeln("Analysis failed.");
        return 1;
    }

    //Generate code and write it to the correct file
    generate();

    return 0;
}

private void loadFiles()
{
    if (pathIsDir)
    {
        auto rfFiles = dirEntries(inputPath, SpanMode.depth).filter!(f => f.name.endsWith(".sdl"));
        foreach(rf; rfFiles)
        {
            auto fqn = buildNormalizedPath(inputPath, rf.name);
			writeln("Input: " ~ fqn);
            string ofp = to!string(buildNormalizedPath(outputPath, to!string(asRelativePath(fqn, inputPath))));
            projectFiles ~= new ProjectFile(fqn, ofp);
        }
    }
    else
    {
        projectFiles ~= new ProjectFile(inputPath, outputPath);
    }
}