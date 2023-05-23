module hwgen.generator;

import hwgen.schema;
import hwgen.globals;
import hwgen.languages.csharp.generator;

import std.stdio;
import std.uni;

public void generate(Project prj)
{
	foreach(csopts; prj.csharpOptions) {
		generateCSharp(prj, csopts);
	}
}
