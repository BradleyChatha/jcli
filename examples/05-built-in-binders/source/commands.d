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
    @ArgNamed("bool|b", "Boolean arguments are implicitly true unless given true/false as a value.")
    @(ArgConfig.parseAsFlag)
    Nullable!bool b;

    @ArgNamed("int|i", "Integer argument (any numeric type is supported)")
    Nullable!int i;

    @ArgNamed("float|f", "Float argument (in fact _any_ type that can be passed to `std.conv.to!T(str)` will work!)")
    Nullable!float f;

    @ArgNamed("enum|e", "Enum arguments, for example, work with `str.to!Enum()`")
    Nullable!Colour e;

    @ArgNamed("string|s", "Strings are obviously supported")
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