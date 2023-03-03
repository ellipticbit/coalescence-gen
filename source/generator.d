module restforge.generator;

import restforge.model;
import restforge.globals;
import restforge.languages.csharp.aspnetcore.generator;

import std.stdio;
import std.uni;

public void generate()
{
	foreach(f; projectFiles) {
		generateCSharp(f);
	}
}

public bool isValidLanguage(string lang)
{
    return isCSharpLang(lang);
}

public void displayUsage()
{
    writeln("Usage: lexicon <server/client> <input file/directory> <output file/directory> [options]");
    writeln();
    displayCSharpOptions();
}

private void displayLanguages()
{
    writeln("Supported Langages / Frameworks:");
    writeln("    C# / ASP.NET Core:          CS, CSharp");
}

public string getFqn(Namespace n) {
	string fqn = string.init;
	foreach (s; n.segments) {
		fqn ~= s ~ ".";
	}
	return fqn[0..$-1];
}

public string getFqn(Enumeration e) {
	return e.parent.getFqn() ~ "." ~ e.name;
}

public string getFqn(Model m) {
	return m.parent.getFqn() ~ "." ~ m.name;
}

public string[string] parseOptions(string[] args)
{
    if(isCSharpLang(language)) {
        return parseCSharpOptions(args);
    }

    return string[string].init;
}