module restforge.analyser;

import restforge.types;
import restforge.model;
import restforge.globals;
import restforge.generator;

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
	foreach(pf; projectFiles)
	{
		foreach(ns; pf.namespaces)
		{
			foreach(e; ns.enums)
			{
				if(!analyseEnum(e))
					return false;
			}
			foreach(m; ns.models)
			{
				if(!analyseModel(m))
					return false;
			}
			foreach(s; ns.services)
			{
				if(!analyseService(s))
					return false;
			}
			foreach(s; ns.sockets)
			{
				if(!analyseWebsocket(s))
					return false;
			}
		}
	}
	return true;
}

private bool analyseType(TypeComplex type, Namespace curns)
{
	if (typeid(type.type) == typeid(TypeCollection)) {
		return analyseType((cast(TypeCollection)type.type).collectionType, curns);
	} else if (typeid(type.type) == typeid(TypeDictionary)) {
		return analyseType((cast(TypeDictionary)type.type).keyType, curns) && analyseType((cast(TypeDictionary)type.type).valueType, curns);
	} else if (typeid(type.type) == typeid(TypeUnknown)) {
		type.type = analyseTypeUnknown(cast(TypeUnknown)type.type, curns);
		return type.type !is null;
	}

	return true;
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
	else
		namespace = curns.segments.join(".");

	Enumeration fe = searchEnums(namespace, name);
	Model fm = searchModels(namespace, name);

	if(fe is null && fm is null)
	{
		writeAnalyserError("Unable to locate type: " ~ type.typeName, type.sourceLocation);
		searchSuggest(cast(TypeUser)type, namespace, name);
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

			auto fe = searchEnums(ns, name);
			if (fe is null)
			{
				writeAnalyserError("Unable to locate enumeration: " ~ teavl, ev.sourceLocation);
				return false;
			}

			auto fev = fe.values.find!(a => a.name == value);
			if (fev.empty())
			{
				writeAnalyserError("Unable to locate enumeration value: " ~ value, ev.sourceLocation);
				return false;
			}

			eav.type = fe;
			eav.value = fev[0];
		}
	}

	return true;
}

public bool analyseModel(Model m)
{
	foreach(mm; m.members)
	{
		//Analyse the type
		if(!analyseType(mm.type, m.parent))
			return false;
	}

	if (m.members.any!(a => a.primaryKey && a.type.mode != TypeMode.Primitive)()) {
		writeAnalyserError(format("Primary Key for type '%s' must be a primitive type.", m.name), m.sourceLocation);
		return false;
	}

	return true;
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
	foreach(sm; s.server)
	{
		foreach(smp; sm.parameters) {
			if (analyseType(smp, s.parent)) hasErrors = true;
		}
		foreach(smp; sm.returns) {
			if (analyseType(smp, s.parent)) hasErrors = true;
		}
	}
	foreach(sm; s.client)
	{
		foreach(smp; sm.parameters) {
			if (analyseType(smp, s.parent)) hasErrors = true;
		}
		foreach(smp; sm.returns) {
			if (analyseType(smp, s.parent)) hasErrors = true;
		}
	}
	return true;
}

public Enumeration searchEnums(string namespace, string name)
{
	//Search the current namespace if no FQN is detected otherwise search all namespaces
	foreach(pf; projectFiles)
	{
		foreach(ns; pf.namespaces)
		{
			if (ns.name.toLower() != namespace.toLower())
				continue;

			foreach(m; ns.enums)
			{
				if (m.name == name)
					return m;
			}
		}
	}

	return null;
}

private Model searchModels(string namespace, string name)
{
	//Search the current namespace if no FQN is detected otherwise search all namespaces
	foreach(pf; projectFiles)
	{
		foreach(ns; pf.namespaces)
		{
			if (ns.name.toLower() != namespace.toLower())
				continue;

			foreach(m; ns.models)
			{
				if (m.name == name)
					return m;
			}
		}
	}

	return null;
}

private void searchSuggest(TypeUser type, string namespace, string name)
{
	//Suggestion search
	foreach(pf; projectFiles)
	{
		foreach(ns; pf.namespaces)
		{
			auto n1 = to!string(ns.name.toLower().dup().array().sort());
			auto n2 = to!string(namespace.toLower().dup().array().sort());
			if (ns.name.toLower() == namespace.toLower() || n1 == n2)
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
}
