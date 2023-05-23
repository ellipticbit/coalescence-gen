module hwgen.utility;

import hwgen.types;

import std.array;
import std.string;

public string cleanName(string name) {
	return name.replace(" ", "_")
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
