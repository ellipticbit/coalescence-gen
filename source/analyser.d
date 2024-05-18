module coalescence.analyser;

import coalescence.types;
import coalescence.schema;
import coalescence.globals;
import coalescence.generator;

import std.algorithm.searching;
import std.algorithm.sorting;
import std.algorithm.iteration;
import std.array;
import std.conv;
import std.stdio;
import std.file;
import std.uni;
import std.string;

public bool analyse(Project prj)
{
	bool hasErrors = false;
	//Only need to evaluate serverSchema as clientSchema is always a subset of serverSchema.
	foreach(ns; prj.serverSchema)
	{
		foreach(e; ns.enums.values)
		{
			if(analyseEnum(e))
				hasErrors = true;
		}
		foreach(m; ns.network.values)
		{
			if(analyseData(prj, m))
				hasErrors = true;
		}
		foreach(m; ns.tables.values)
		{
			if(analyseData(prj, m))
				hasErrors = true;
		}
		foreach(m; ns.views.values)
		{
			if(analyseData(prj, m))
				hasErrors = true;
		}
		foreach(m; ns.udts.values)
		{
			if(analyseData(prj, m))
				hasErrors = true;
		}
		foreach(s; ns.services.values)
		{
			if(analyseService(prj, s))
				hasErrors = true;
		}
		foreach(s; ns.sockets.values)
		{
			if(analyseWebsocket(prj, s))
				hasErrors = true;
		}
	}
	return hasErrors;
}

private bool analyseType(Project prj, TypeComplex type, Schema curns)
{
	if (typeid(type.type) == typeid(TypeCollection)) {
		return analyseType(prj, (cast(TypeCollection)type.type).collectionType, curns);
	} else if (typeid(type.type) == typeid(TypeDictionary)) {
		return analyseType(prj, (cast(TypeDictionary)type.type).keyType, curns) && analyseType(prj, (cast(TypeDictionary)type.type).valueType, curns);
	} else if (typeid(type.type) == typeid(TypeUnknown)) {
		type.type = analyseTypeUnknown(prj, cast(TypeUnknown)type.type);
		return type.type is null;
	}

	return false;
}

private TypeBase analyseTypeUnknown(Project prj, TypeUnknown type)
{
	auto sl = splitter(type.typeName, ".").array;
	string name = sl[sl.length-1];
	string namespace = string.init;
	if (sl.length > 1)
		foreach(s; sl[0..$-1])
			namespace ~= s ~ ".";
	if (namespace != string.init)
		namespace = to!string(namespace[0..$-1]);

	Enumeration fe = searchEnums(prj, name, namespace);
	DataObject fm = searchData(prj, name, namespace);

	if (fe is null && fm is null)
	{
		writeAnalyserError("Unable to locate type: " ~ type.typeName, type.sourceLocation);
		searchSuggest(prj, cast(TypeUser)type, name);
		return null;
	}

	if (fe !is null)
		return new TypeEnum(fe, type.sourceLocation);
	else {
		return new TypeModel(fm, type.sourceLocation);
	}
}

public bool analyseEnum(Enumeration e)
{
	bool hasErrors = false;
	bool hasDefaultValue = false;
	string dvName = string.init;

	foreach(ev; e.values)
	{
		if(ev.aggregate.length == 0)
			continue;

		foreach(eav; ev.aggregate)
		{
			string value = eav.aggregateLabel[lastIndexOf(eav.aggregateLabel, '.')+1..$];

			auto fev = e.values.find!(a => a.name == value);
			if (fev.empty())
			{
				writeAnalyserError("Unable to locate enumeration value: " ~ value, ev.sourceLocation);
				hasErrors = true;
			}

			eav.value = fev[0];
		}

		if (ev.isDefault && hasDefaultValue) {
			ev.isDefault = false;
			writeAnalyserWarning("HasDefaultValue defined value '" ~ ev.name ~ "' will be ignored and the value '" ~ dvName ~ "' will be used.", ev.sourceLocation);
		} else {
			hasDefaultValue = true;
			dvName = ev.name;
		}
	}

	return hasErrors;
}

public bool analyseData(Project prj, DataObject m)
{
	bool hasErrors = false;
	foreach(mm; m.members)
	{
		//Analyse the type
		if(analyseType(prj, mm.type, m.parent))
			hasErrors = true;
	}

	//Analyse modifications
	if (typeid(m) == typeid(DatabaseObject)) {
		auto x = cast(DatabaseObject)m;
		foreach(mm; x.modifications.additions)
		{
			//Analyse the type
			if(analyseType(prj, mm.type, m.parent))
				hasErrors = true;
		}
	}

	if (typeid(m) == typeid(Table)) {
		auto x = cast(Table)m;
		foreach(idx; x.indexes) {
			if (idx.columns.any!(a => a.type.type.mode != TypeMode.Primitive && a.type.type.mode != TypeMode.ByteArray)()) {
				writeAnalyserError(format("Primary Key index '%s' for data object '%s' must be a primitive type.", idx.name, x.name), x.sourceLocation);
				hasErrors = true;
			}
		}
	}

	return hasErrors;
}

public bool analyseService(Project prj, HttpService s)
{
	bool hasErrors = false;
	foreach(sm; s.methods)
	{
		foreach(smp; sm.route) {
			if (analyseType(prj, smp, s.parent)) hasErrors = true;
			if (smp.type.mode != TypeMode.Primitive && smp.type.mode != TypeMode.Enum) {
				hasErrors = true;
				writeAnalyserError("Parameter '" ~ smp.name ~ "' of Member '" ~ sm.name ~ "' must be a primitive or enum type.", smp.sourceLocation);
			}
			if (!sm.routeParts.any!(a => a.toLower() == smp.name.toLower())) {
				hasErrors = true;
				writeAnalyserError("Unable to locate corresponding route part for route type: " ~ smp.name, smp.sourceLocation);
			}
		}
		foreach(smp; sm.query) {
			if (analyseType(prj, smp, s.parent)) hasErrors = true;
			if (smp.type.mode != TypeMode.Collection && smp.type.mode != TypeMode.Primitive && smp.type.mode != TypeMode.Enum) {
				hasErrors = true;
				writeAnalyserError("Parameter '" ~ smp.name ~ "' of Member '" ~ sm.name ~ "' must be either a collection or primitive type.", smp.sourceLocation);
			}
		}
		foreach(smp; sm.header) {
			if (analyseType(prj, smp, s.parent)) hasErrors = true;
			if (smp.type.mode != TypeMode.Collection && smp.type.mode != TypeMode.Primitive && smp.type.mode != TypeMode.ByteArray && smp.type.mode != TypeMode.Enum) {
				hasErrors = true;
				writeAnalyserError("Parameter '" ~ smp.name ~ "' of Member '" ~ sm.name ~ "' must be either a collection or primitive type.", smp.sourceLocation);
			}
		}
		foreach(smp; sm.content) {
			if (analyseType(prj, smp, s.parent)) hasErrors = true;
		}
		foreach(smp; sm.returns) {
			if (analyseType(prj, smp, s.parent)) hasErrors = true;
		}
	}
	return hasErrors;
}

public bool analyseWebsocket(Project prj, WebsocketService s)
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
				if (analyseType(prj, smp, s.parent)) hasErrors = true;
			}
			foreach(smp; sm.returns) {
				if (analyseType(prj, smp, s.parent)) hasErrors = true;
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
				if (analyseType(prj, smp, s.parent)) hasErrors = true;
			}
			foreach(smp; sm.returns) {
				if (analyseType(prj, smp, s.parent)) hasErrors = true;
			}
		}
	}
	return hasErrors;
}

public Enumeration searchEnums(Project prj, string name, string namespace = string.init)
{
	Enumeration[] matches;

	//Search the current namespace if no FQN is detected otherwise search all namespaces
	foreach(ns; prj.serverSchema)
	{
		if (namespace != string.init && ns.name.toLower() != namespace.toLower())
			continue;

		foreach(m; ns.enums)
		{
			if (m.name == name)
				matches ~= m;
		}
	}

	return matches.length != 1 ? null : matches[0];
}

private DataObject searchData(Project prj, string name, string namespace = string.init)
{
	DataObject[] matches;

	//Search the current namespace if no FQN is detected otherwise search all namespaces
	foreach(ns; prj.serverSchema)
	{
		if (namespace != string.init && ns.name.toLower() != namespace.toLower())
			continue;

		foreach(m; ns.network)
		{
			if (m.name == name)
				matches ~= m;
		}
		foreach(m; ns.tables)
		{
			if (m.name == name)
				matches ~= m;
		}
		foreach(m; ns.views)
		{
			if (m.name == name)
				matches ~= m;
		}
		foreach(m; ns.udts)
		{
			if (m.name == name)
				matches ~= m;
		}
	}

	return matches.length != 1 ? null : matches[0];
}

private void searchSuggest(Project prj, TypeUser type, string name)
{
	//Suggestion search
	foreach(ns; prj.serverSchema)
	{
		foreach(m; ns.enums)
		{
			auto s1 = to!string(m.name.toLower().dup().array().sort());
			auto s2 = to!string(name.toLower().dup().array().sort());
			if (m.name.toLower() == name.toLower() || s1 == s2)
				writeTypeErrorSuggest(type, m.fullName());
		}
		foreach(m; ns.network)
		{
			auto s1 = to!string(m.name.toLower().dup().array().sort());
			auto s2 = to!string(name.toLower().dup().array().sort());
			if (m.name.toLower() == name.toLower() || s1 == s2)
				writeTypeErrorSuggest(type, m.fullName());
		}
		foreach(m; ns.tables)
		{
			auto s1 = to!string(m.name.toLower().dup().array().sort());
			auto s2 = to!string(name.toLower().dup().array().sort());
			if (m.name.toLower() == name.toLower() || s1 == s2)
				writeTypeErrorSuggest(type, m.fullName());
		}
		foreach(m; ns.views)
		{
			auto s1 = to!string(m.name.toLower().dup().array().sort());
			auto s2 = to!string(name.toLower().dup().array().sort());
			if (m.name.toLower() == name.toLower() || s1 == s2)
				writeTypeErrorSuggest(type, m.fullName());
		}
		foreach(m; ns.udts)
		{
			auto s1 = to!string(m.name.toLower().dup().array().sort());
			auto s2 = to!string(name.toLower().dup().array().sort());
			if (m.name.toLower() == name.toLower() || s1 == s2)
				writeTypeErrorSuggest(type, m.fullName());
		}
	}
}
