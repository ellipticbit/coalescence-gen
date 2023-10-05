module coalescence.utility;

import coalescence.types;

import std.array;
import std.conv;
import std.string;

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
