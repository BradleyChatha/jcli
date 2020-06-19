/// Contains helpful templates relating to UDAs.
module jaster.cli.udas;

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
    import jaster.cli.core : Command;
    
    struct A {}

    @Command("One")
    struct B {}

    @Command("One")
    @Command("Two")
    struct C {}

    static assert(!__traits(compiles, getSingleUDA!(A, Command)));
    static assert(!__traits(compiles, getSingleUDA!(C, Command)));
    static assert(getSingleUDA!(B, Command).pattern == "One");
}