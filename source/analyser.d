module hwgen.analyser;

import hwgen.types;
import hwgen.model;
import hwgen.globals;
import hwgen.generator;

import std.algorithm.searching;
import std.algorithm.sorting;
import std.algorithm.iteration;
import std.array;
import std.conv;
import std.stdio;
import std.file;
import std.uni;
import std.string;

public bool analyse()
{
	bool hasErrors = false;
	foreach(pf; projectFiles)
	{
		foreach(ns; pf.namespaces)
		{
			foreach(e; ns.enums)
			{
				if(analyseEnum(e))
					hasErrors = true;
			}
			foreach(m; ns.models)
			{
				if(analyseModel(m))
					hasErrors = true;
			}
			foreach(s; ns.services)
			{
				if(analyseService(s))
					hasErrors = true;
			}
			foreach(s; ns.sockets)
			{
				if(analyseWebsocket(s))
					hasErrors = true;
			}
		}
	}

	return hasErrors;
}

private bool analyseType(TypeComplex type, Namespace curns)
{
	if (typeid(type.type) == typeid(TypeCollection)) {
		return analyseType((cast(TypeCollection)type.type).collectionType, curns);
	} else if (typeid(type.type) == typeid(TypeDictionary)) {
		return analyseType((cast(TypeDictionary)type.type).keyType, curns) && analyseType((cast(TypeDictionary)type.type).valueType, curns);
	} else if (typeid(type.type) == typeid(TypeUnknown)) {
		type.type = analyseTypeUnknown(cast(TypeUnknown)type.type, curns);
		return type.type is null;
	}

	return false;
}

private TypeBase analyseTypeUnknown(TypeUnknown type, Namespace curns)
{
	auto sl = splitter(type.typeName, ".").array;
	string name = sl[sl.length-1];
	string namespace = string.init;
	if(sl.length > 1)
		foreach(s; sl[0..$-1])
			namespace ~= s ~ ".";
	if(namespace != string.init)
		namespace = to!string(namespace[0..$-1]);

	Enumeration fe = searchEnums(name, namespace);
	Model fm = searchModels(name, namespace);

	if(fe is null && fm is null)
	{
		writeAnalyserError("Unable to locate type: " ~ type.typeName, type.sourceLocation);
		searchSuggest(cast(TypeUser)type, name);
		return null;
	}

	if(fe !is null)
		return new TypeEnum(fe, type.sourceLocation);
	else {
		return new TypeModel(fm, type.sourceLocation);
	}
}

public bool analyseEnum(Enumeration e)
{
	bool hasErrors = false;

	foreach(ev; e.values)
	{
		if(ev.aggregate.length == 0)
			continue;

		foreach(eav; ev.aggregate)
		{
			auto teavl = eav.aggregateLabel;
			string value = eav.aggregateLabel[lastIndexOf(eav.aggregateLabel, '.')+1..$];
			eav.aggregateLabel = eav.aggregateLabel[0..lastIndexOf(eav.aggregateLabel, '.')];
			string name = eav.aggregateLabel[lastIndexOf(eav.aggregateLabel, '.')+1..$];
			string ns = eav.aggregateLabel[0..lastIndexOf(eav.aggregateLabel, '.')];
			eav.aggregateLabel = null;

			auto fe = searchEnums(name, ns);
			if (fe is null)
			{
				writeAnalyserError("Unable to locate enumeration: " ~ teavl, ev.sourceLocation);
				hasErrors = true;
			}

			auto fev = fe.values.find!(a => a.name == value);
			if (fev.empty())
			{
				writeAnalyserError("Unable to locate enumeration value: " ~ value, ev.sourceLocation);
				hasErrors = true;
			}

			eav.type = fe;
			eav.value = fev[0];
		}
	}

	return hasErrors;
}

public bool analyseModel(Model m)
{
	bool hasErrors = false;
	foreach(mm; m.members)
	{
		//Analyse the type
		if(analyseType(mm.type, m.parent))
			hasErrors = true;
	}

	if (m.members.any!(a => a.primaryKey && a.type.mode != TypeMode.Primitive)()) {
		writeAnalyserError(format("Primary Key for type '%s' must be a primitive type.", m.name), m.sourceLocation);
		hasErrors = true;
	}

	return hasErrors;
}

public bool analyseService(HttpService s)
{
	bool hasErrors = false;
	foreach(sm; s.methods)
	{
		foreach(smp; sm.route) {
			if (analyseType(smp, s.parent)) hasErrors = true;
			if (smp.type.mode != TypeMode.Primitive && smp.type.mode != TypeMode.ByteArray) {
				hasErrors = true;
				writeAnalyserError("Parameter '" ~ smp.name ~ "' of Member '" ~ sm.name ~ "' must be a primitive type.", smp.sourceLocation);
			}
			if (!sm.routeParts.any!(a => a == smp.name.toLower())) {
				hasErrors = true;
				writeAnalyserError("Unable to locate corresponding route part for route type: " ~ smp.name, smp.sourceLocation);
			}
		}
		foreach(smp; sm.query) {
			if (analyseType(smp, s.parent)) hasErrors = true;
			if (smp.type.mode != TypeMode.Collection && smp.type.mode != TypeMode.Primitive && smp.type.mode != TypeMode.ByteArray) {
				hasErrors = true;
				writeAnalyserError("Parameter '" ~ smp.name ~ "' of Member '" ~ sm.name ~ "' must be either a collection or primitive type.", smp.sourceLocation);
			}
		}
		foreach(smp; sm.header) {
			if (analyseType(smp, s.parent)) hasErrors = true;
			if (smp.type.mode != TypeMode.Collection && smp.type.mode != TypeMode.Primitive && smp.type.mode != TypeMode.ByteArray) {
				hasErrors = true;
				writeAnalyserError("Parameter '" ~ smp.name ~ "' of Member '" ~ sm.name ~ "' must be either a collection or primitive type.", smp.sourceLocation);
			}
		}
		foreach(smp; sm.content) {
			if (analyseType(smp, s.parent)) hasErrors = true;
		}
		foreach(smp; sm.returns) {
			if (analyseType(smp, s.parent)) hasErrors = true;
		}
	}
	return hasErrors;
}

public bool analyseWebsocket(WebsocketService s)
{
	bool hasErrors = false;
	int[string] snl;
	int[string] cnl;
	foreach(ns; s.namespaces) {
		foreach(sm; ns.server)
		{
			if ((sm.name in snl) is null) {
				snl[sm.name] = 1;
			} else {
				snl[sm.name] += 1;
			}
			if (snl[sm.name] > 1) sm.socketName ~= "-" ~ to!string(snl[sm.name]);

			foreach(smp; sm.parameters) {
				if (analyseType(smp, s.parent)) hasErrors = true;
			}
			foreach(smp; sm.returns) {
				if (analyseType(smp, s.parent)) hasErrors = true;
			}
		}
		foreach(sm; ns.client)
		{
			if ((sm.name in cnl) is null) {
				cnl[sm.name] = 1;
			} else {
				cnl[sm.name] += 1;
			}
			if (cnl[sm.name] > 1) sm.socketName ~= "-" ~ to!string(cnl[sm.name]);

			foreach(smp; sm.parameters) {
				if (analyseType(smp, s.parent)) hasErrors = true;
			}
			foreach(smp; sm.returns) {
				if (analyseType(smp, s.parent)) hasErrors = true;
			}
		}
	}
	return hasErrors;
}

public Enumeration searchEnums(string name, string namespace = string.init)
{
	Enumeration[] matches;

	//Search the current namespace if no FQN is detected otherwise search all namespaces
	foreach(pf; projectFiles)
	{
		foreach(ns; pf.namespaces)
		{
			if (namespace != string.init && ns.name.toLower() != namespace.toLower())
				continue;

			foreach(m; ns.enums)
			{
				if (m.name == name)
					matches ~= m;
			}
		}
	}

	return matches.length != 1 ? null : matches[0];
}

private Model searchModels(string name, string namespace = string.init)
{
	Model[] matches;

	//Search the current namespace if no FQN is detected otherwise search all namespaces
	foreach(pf; projectFiles)
	{
		foreach(ns; pf.namespaces)
		{
			if (namespace != string.init && ns.name.toLower() != namespace.toLower())
				continue;

			foreach(m; ns.models)
			{
				if (m.name == name)
					matches ~= m;
			}
		}
	}

	return matches.length != 1 ? null : matches[0];
}

private void searchSuggest(TypeUser type, string name)
{
	//Suggestion search
	foreach(pf; projectFiles)
	{
		foreach(ns; pf.namespaces)
		{
			foreach(m; ns.enums)
			{
				auto s1 = to!string(m.name.toLower().dup().array().sort());
				auto s2 = to!string(name.toLower().dup().array().sort());
				if (m.name.toLower() == name.toLower() || s1 == s2)
					writeTypeErrorSuggest(type, m.getFqn());
			}
			foreach(m; ns.models)
			{
				auto s1 = to!string(m.name.toLower().dup().array().sort());
				auto s2 = to!string(name.toLower().dup().array().sort());
				if (m.name.toLower() == name.toLower() || s1 == s2)
					writeTypeErrorSuggest(type, m.getFqn());
			}
		}
	}
}
