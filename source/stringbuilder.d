module hwgen.stringbuilder;

import core.vararg;
import std.conv;
import std.array;
import std.ascii;
import std.algorithm;
import std.typecons;

import std.stdio;

public class StringBuilder
{
private:
    char[] chars;
	bool useSpaces;
	int tabSpaces;

    @safe string newLine() {
/*
		version(Windows) {
			return "\r\n";
		} else {
			return "\n";
		}
*/
		return "\n";
    }

public:
    @property ulong length() { return chars.length; }

    @safe this() {
		this.useSpaces = false;
		this.tabSpaces = 4;
	}

    @safe this(string initialValue, bool useSpaces = false, int tabSpaces = 4) {
        chars = initialValue.dup;
		this.useSpaces = useSpaces;
		this.tabSpaces = tabSpaces;
    }

    @safe this(size_t initialCapacity, bool useSpaces = false, int tabSpaces = 4) {
        chars.reserve(initialCapacity);
		this.useSpaces = useSpaces;
		this.tabSpaces = tabSpaces;
    }

    @trusted override string toString() {
        return to!string(chars);
    }

    @trusted string toString(int start, int length) {
        return to!string(chars[start..length]);
    }

    @trusted static pure string format(string format, string[] args ...) {
        string x = format;
        int c = 0;
        foreach(t; args)
            x = std.array.replace(x, "{" ~ to!string(c++) ~ "}", t);
        return x;
    }

    @safe void append(T)(T value) {
        chars ~= to!string(value);
    }

    @safe void append(string format, string[] args ...) {
        chars ~= this.format(format, args);
    }

    @safe void appendLine() {
        chars ~= newLine();
    }

    @safe void appendLine(T)(T value) {
        chars ~= to!string(value) ~ newLine();
    }

    @safe void appendLine(string format, string[] args ...) {
        chars ~= this.format(format, args) ~ newLine();
    }

    @safe void replace(char oldValue, char newValue) {
        for(int i=0;i<chars.length;i++)
            if(chars[i] == oldValue)
                chars[i] = newValue;
    }

    @trusted void replace(string newValue, string oldValue) {
        chars = std.array.replace(chars, oldValue, newValue);
    }

    @safe void removeRight(int count) {
        chars = chars[0..$-count];
    }

    @safe void removeLeft(int count) {
        chars = chars[0+count..$];
    }

	@safe StringBuilder tabs(uint count)
	{
		if(useSpaces) {
			char[] tabs = new char[count * tabSpaces];
			for(uint i = 0; i < (count * tabSpaces); i++) {
				tabs[i] = ' ';
			}
			append(to!string(tabs));
		}
		else {
			char[] tabs = new char[count];
			for(uint i = 0; i < count; i++) {
				tabs[i] = '\t';
			}
			append(to!string(tabs));
		}

		return this;
	}

/* Doesn't work
    @safe void remove(ulong startIndex, ulong endIndex)
    {
        chars = std.algorithm.mutation.remove(chars, tuple(startIndex, endIndex));
    }
*/
}