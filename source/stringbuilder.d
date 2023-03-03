module restforge.stringbuilder;

import core.vararg;
import std.conv;
import std.array;
import std.ascii;
import std.algorithm;
import std.typecons;

public class StringBuilder
{
private:
    char[] chars;

public:
    @property ulong length() { return chars.length; }

    @safe this() {    }

    @safe this(string initialValue) {
        chars = initialValue.dup;
    }

    @safe this(size_t initialCapacity) {
        chars.reserve(initialCapacity);
    }

    @trusted override string toString() {
        return to!string(chars[0..$]);
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

/* Doesn't work
    @safe void remove(ulong startIndex, ulong endIndex)
    {
        chars = std.algorithm.mutation.remove(chars, tuple(startIndex, endIndex));
    }
*/
    private @safe string newLine()
    {
        return "\n";
    }
}