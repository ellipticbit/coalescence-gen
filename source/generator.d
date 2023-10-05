module coalescence.generator;

import coalescence.schema;
import coalescence.globals;
import coalescence.languages.csharp.generator;

import std.stdio;
import std.uni;

public void generate(Project prj)
{
	foreach(csopts; prj.csharpOptions) {
		generateCSharp(prj, csopts);
	}
}
