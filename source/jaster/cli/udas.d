/// Contains UDAs and helpful templates.
module jaster.cli.udas;

private
{
    import std.typecons : Flag;
}

/++
 + Attach this to any struct/class that represents a command.
 +
 + See_Also:
 +  `jaster.cli.core.CommandLineInterface` for more details.
 + +/
struct CommandPattern
{
    /// The pattern to match against.
    string value;
}

/++
 + Attach this to any member field to mark it as a named argument.
 +
 + See_Also:
 +  `jaster.cli.core.CommandLineInterface` for more details.
 + +/
struct CommandNamedArg
{
    /// The pattern/"name" to match against.
    string pattern;

    /// The description of this argument.
    string description;
}

/++
 + Attach this to any member field to mark it as a positional argument.
 +
 + See_Also:
 +  `jaster.cli.core.CommandLineInterface` for more details.
 + +/
struct CommandPositionalArg
{
    /// The position this argument appears at.
    size_t position;

    /// The name of this argument. This is only used for the generated help text, and can be left null.
    string name;

    // The description of this argument.
    string description;
}

/++
 + Attach this to any free-standing function to mark it as an argument binder.
 +
 + See_Also:
 +  `jaster.cli.binder.ArgBinder` for more details.
 + ++/
struct ArgBinderFunc {}

/++
 + Gets a single specified `UDA` from the given `Symbol`.
 +
 + Assertions:
 +  If the given `Symbol` has either 0, or more than 1 instances of the specified `UDA`, a detailed error message will be displayed.
 + ++/
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