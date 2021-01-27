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

    // Check if they created an instance `@UDA()`
    //
    // or if they just attached the type itself `@UDA`
    static if(__traits(compiles, {enum UDAs = getUDAs!(Symbol, UDA);}))
        enum UDAs = getUDAs!(Symbol, UDA);
    else
        enum UDAs = [UDA.init];
    
    static if(UDAs.length == 0)
        static assert(false, "The symbol `"~Symbol.stringof~"` does not have the `@"~UDA.stringof~"` UDA");
    else static if(UDAs.length > 1)
        static assert(false, "The symbol `"~Symbol.stringof~"` contains more than one `@"~UDA.stringof~"` UDA");

    enum getSingleUDA = UDAs[0];
}
///
version(unittest)
{
    import jaster.cli.infogen : Command;

    private struct A {}

    @Command("One")
    private struct B {}

    @Command("One")
    @Command("Two")
    private struct C {}
}

unittest
{
    import jaster.cli.infogen : Command;

    static assert(!__traits(compiles, getSingleUDA!(A, Command)));
    static assert(!__traits(compiles, getSingleUDA!(C, Command)));
    static assert(getSingleUDA!(B, Command).pattern.pattern == "One");
}

/++
 + Sometimes code needs to support both `@UDA` and `@UDA()`, so this template is used
 + to ensure that the given `UDA` is an actual object, not just a type.
 + ++/
template ctorUdaIfNeeded(alias UDA)
{
    import std.traits : isType;
    static if(isType!UDA)
        enum ctorUdaIfNeeded = UDA.init;
    else
        alias ctorUdaIfNeeded = UDA;
}

/++
 + Gets all symbols that have specified UDA from all specified modules
 + ++/
template getSymbolsByUDAInModules(alias attribute, Modules...)
{
    import std.meta: AliasSeq;
    import std.traits: getSymbolsByUDA;

    static if(Modules.length == 0)
    {
        alias getSymbolsByUDAInModules = AliasSeq!();
    }
    else
    {
        alias tail = getSymbolsByUDAInModules!(attribute, Modules[1 .. $]);

        alias getSymbolsByUDAInModules = AliasSeq!(getSymbolsByUDA!(Modules[0], attribute), tail);
    }
}

unittest
{
    import std.meta: AliasSeq;
    import jaster.cli.infogen : Command;

    static assert(is(getSymbolsByUDAInModules!(Command, jaster.cli.udas) == AliasSeq!(B, C)));
    static assert(is(getSymbolsByUDAInModules!(Command, jaster.cli.udas, jaster.cli.udas) == AliasSeq!(B, C, B, C)));
}
