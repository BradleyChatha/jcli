module commands;

import jcli;

enum Colour
{
    red,
    green,
    blue,
    none
}

@Command("echo", "Echos all of its parameters.")
struct EchoCommand
{
    @ArgNamed("b|bool", "Boolean arguments are implicitly true unless given true/false as a value.")
    Nullable!bool b;

    @ArgNamed("i|int", "Integer argument (any numeric type is supported)")
    Nullable!int i;

    @ArgNamed("f|float", "Float argument (in fact _any_ type that can be passed to `std.conv.to!T(str)` will work!)")
    Nullable!float f;

    @ArgNamed("e|enum", "Enum arguments, for example, work with `str.to!Enum()`")
    Nullable!Colour e;

    @ArgNamed("s|string", "Strings are obviously supported")
    Nullable!string s;

    void onExecute()
    {
        import std;
        writefln(
            "b:     %s\n"
           ~"i:     %s\n"
           ~"f:     %s\n"
           ~"s:     %s\n"
           ~"e:     %s\n",
            this.b.get(true),
            this.i.get(0),
            this.f.get(0),
            this.s.get("null"),
            this.e.get(Colour.none)
        );
    }
}