module jaster.cli.udas;

private
{
    import std.typecons : Flag;
}

alias IsRequired = Flag!"isArgRequired";

struct CommandPattern
{
    string value;
}

struct CommandNamedArg
{
    string pattern;
    string description;
    IsRequired isRequired;
}

struct CommandPositionalArg
{
    size_t position;
    string name;
    IsRequired isRequired;
}

struct ArgBinderFunc 
{
    
}

template getSingleUDA(alias Symbol, alias UDA)
{
    import std.traits : getUDAs;

    enum UDAs = getUDAs!(Symbol, UDA);
    static if(UDAs.length == 0)
        static assert(false, "The symbol `"~Symbol.stringof~"` does not have the `@"~UDA.stringof~"` UDA");
    else static if(UDAs.length > 1)
        static assert(false, "The symbol `"~Symbol.stringof~"` contains more than one `@"~UDA.stringof~"` UDA");

    enum getSingleUDA = UDAs[0];
}
///
unittest
{
    struct A {}

    @CommandPattern("One")
    struct B {}

    @CommandPattern("One")
    @CommandPattern("Two")
    struct C {}

    static assert(!__traits(compiles, getSingleUDA!(A, CommandPattern)));
    static assert(!__traits(compiles, getSingleUDA!(C, CommandPattern)));
    static assert(getSingleUDA!(B, CommandPattern).value == "One");
}