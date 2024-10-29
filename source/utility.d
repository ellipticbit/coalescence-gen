module coalescence.utility;

import coalescence.globals;
import coalescence.types;

import std.array;
import std.conv;
import std.datetime;
import std.encoding;
import std.string;
public import std.typecons;

import sdlite;

public string cleanName(string name) {
	return name.replace(" ", "_")
			.replace("-", "_")
			.replace("[", string.init)
            .replace("]", string.init)
            .replace("{", string.init)
            .replace("}", string.init)
            .replace("(", string.init)
            .replace(")", string.init);
}

public bool isStringDictionary(TypeBase type)
{
    if(typeid(type) == typeid(TypeDictionary))
    {
        TypeDictionary td = cast(TypeDictionary)(type);
        if(getTypePrimitive(td.keyType) == TypePrimitives.String && getTypePrimitive(td.valueType) == TypePrimitives.String)
            return true;
    }
    return false;
}

public bool isNullOrEmpty(string str) {
	return (str is null || str == string.init);
}

public bool isNullOrWhitespace(string str) {
	return (str is null || str.strip() == string.init);
}

public string uppercaseFirst(string str) {
	if (isNullOrEmpty(str)) return string.init;
	dchar[] a = str.array;
	a[0] = toUpper(a[0]);
	return to!string(a);
}

public string lowercaseFirst(string str) {
	if (isNullOrEmpty(str)) return string.init;
	dchar[] a = str.array;
	a[0] = toLower(a[0]);
	return to!string(a);
}

public @trusted string stripBOM(string str) {
	ubyte[] bytes = cast(ubyte[])str;

	return cast(string)bytes[getBOM(bytes).sequence.length..$];
}

Nullable!SDLNode getNode(SDLNode node, string nodeName) {
	foreach(n; node.children) {
		if (n.qualifiedName == nodeName) return Nullable!SDLNode(n);
	}

	return Nullable!SDLNode();
}

SDLNode[] getNodes(SDLNode node, string namespace = string.init) {
	if (namespace == string.init) return node.children;

	SDLNode[] nodes;
	foreach(n; node.children) {
		if (n.namespace == namespace) nodes ~= n;
	}
	return nodes;
}

SDLValue[] getNodeValues(SDLNode node, string nodeName) {
	auto tn = getNode(node, nodeName);
	if (tn.isNull) return SDLValue[].init;
	return tn.get().values;
}

T getNodeAttributeValue(T)(SDLNode node, string nodeName, string attributeName, T defaultValue)
	if (is(T == string) ||
		is(T == immutable(ubyte)[]) ||
		is(T == int) ||
		is(T == long) ||
		is(T == long[2]) ||
		is(T == float) ||
		is(T == double) ||
		is(T == bool) ||
		is(T == SysTime) ||
		is(T == Date) ||
		is(T == Duration))
{
	auto tn = getNode(node, nodeName);
	if (tn.isNull) return defaultValue;

	foreach (attr; tn.get().attributes) {
		if (attr.name == attributeName) return attr.value.value!T();
	}

	return defaultValue;
}

SDLNode expectNode(SDLNode node, string nodeName) {
	auto tn = getNode(node, nodeName);
	if (tn.isNull) {
		writeParseError("Required Child Node not found: " ~ nodeName, node.location);
		throw new Exception("Required Child Node not found.");
	}

	return tn.get();
}

T expectAttributeValue(T)(SDLNode node, string name)
	if (is(T == string) ||
		is(T == immutable(ubyte)[]) ||
		is(T == int) ||
		is(T == long) ||
		is(T == long[2]) ||
		is(T == float) ||
		is(T == double) ||
		is(T == bool) ||
		is(T == SysTime) ||
		is(T == Date) ||
		is(T == Duration))
{
	auto attr = node.getAttribute(name, SDLValue.null_);
	if (attr == SDLValue.null_) {
		writeParseError("Required Attribute not found: " ~ name, node.location);
		throw new Exception("Required Attribute not found.");
	}

	return attr.value!T;
}

T getAttributeValue(T)(SDLNode node, string name, T defaultValue)
	if (is(T == string) ||
		is(T == immutable(ubyte)[]) ||
		is(T == int) ||
		is(T == long) ||
		is(T == long[2]) ||
		is(T == float) ||
		is(T == double) ||
		is(T == bool) ||
		is(T == SysTime) ||
		is(T == Date) ||
		is(T == Duration))
{
	return node.getAttribute(name, SDLValue(defaultValue)).value!T;
}

T expectValue(T)(SDLNode node, int index)
	if (is(T == string) ||
		is(T == immutable(ubyte)[]) ||
		is(T == int) ||
		is(T == long) ||
		is(T == long[2]) ||
		is(T == float) ||
		is(T == double) ||
		is(T == bool) ||
		is(T == SysTime) ||
		is(T == Date) ||
		is(T == Duration))
{
	if (index > node.values.length) {
		writeParseError("No Value found at index: " ~ to!string(index), node.location);
		throw new Exception("No Value found at specified index.");
	}

	return node.values[index].value!T();
}

T getValue(T)(SDLNode node, int index, T defaultValue)
	if (is(T == string) ||
		is(T == immutable(ubyte)[]) ||
		is(T == int) ||
		is(T == long) ||
		is(T == long[2]) ||
		is(T == float) ||
		is(T == double) ||
		is(T == bool) ||
		is(T == SysTime) ||
		is(T == Date) ||
		is(T == Duration))
{
	if (index > node.values.length) {
		return defaultValue;
	}

	return node.values[index].value!T();
}
