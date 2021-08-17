module jcli.introspect.gather;

import jcli.introspect, jcli.core, std;

CommandInfo!CommandT commandInfoFor(alias CommandT)()
{
    typeof(return) ret;

    // Find which command UDA they're using.
    static if(
        !__traits(compiles, oneOf!(CommandT, Command, CommandDefault))
    )
    {
        static assert(false, "oneOf won't compile. That likely means you have both @Command and @CommandDefault attached.");
    }
    const CommandUda = oneOf!(CommandT, Command, CommandDefault);
    static if(is(typeof(CommandUda) : CommandDefault))
        ret.isDefault = true;
    else
    {
        static assert(CommandUda.pattern.patterns.walkLength > 0, "@Command must specify at least one pattern.");
        ret.pattern = CommandUda.pattern;
    }
    ret.description = CommandUda.description;

    // Find args.
    ret.namedArgs       = findArgs!(CommandT, ArgNamed);
    ret.positionalArgs  = findArgs!(CommandT, ArgPositional);
    auto raw            = findArgs!(CommandT, ArgRaw);
    auto overflow       = findArgs!(CommandT, ArgOverflow);

    if(ret.namedArgs.length == 0) ret.namedArgs = typeof(ret.namedArgs).init;
    if(ret.positionalArgs.length == 0) ret.positionalArgs = typeof(ret.positionalArgs).init;
    if(raw.length > 1) assert(false, "Only one symbol at most can be marked @ArgRaw");
    if(raw.length == 1) ret.rawArg = raw[0];
    if(overflow.length > 1) assert(false, "Only one symbol at most can be marked @ArgOverflow");
    if(overflow.length == 1) ret.overflowArg = overflow[0];

    return ret;
}

private auto findArgs(alias CommandT, alias UDA)()
{
    ArgIntrospect!(UDA, CommandT)[] ret;

    alias SymbolsWithUda = getSymbolsByUDA!(CommandT, UDA);
    static foreach(symbol; SymbolsWithUda)
    {{
        alias Udas = getUDAs!(symbol, UDA);
        alias SymbolT = typeof(symbol);
        static assert(Udas.length == 1, "Only one @"~UDA.stringof~" can be attached.");

        alias SanityCheckUdas = AliasSeq!(
            getUDAs!(symbol, ArgNamed),
            getUDAs!(symbol, ArgPositional),
            getUDAs!(symbol, ArgRaw),
            getUDAs!(symbol, ArgOverflow),
        );
        static assert(SanityCheckUdas.length == 1, "Cannot mix multiple @ArgXXX UDAs together.");

        static if(__traits(compiles, { auto a = Udas[0]; }))
            enum Uda = Udas[0];
        else
            enum Uda = Udas[0].init;

        // Get main info.
        typeof(ret[0]) info;
        info.identifier = __traits(identifier, symbol);
        info.uda = Uda;

        // Get auxiliary udas
        static foreach(uda; __traits(getAttributes, symbol))
        {{
            static if(__traits(compiles, typeof(uda)))
            {
                alias UdaT = typeof(uda);
                static if(is(UdaT == ArgExistence))
                    info.existence |= uda;
                else static if(is(UdaT == ArgAction))
                    info.action = uda;
                else static if(is(UdaT == ArgConfig))
                    info.config = uda;
                else static if(is(UdaT == ArgGroup))
                    info.group = uda;
            }
        }}

        // Set certain flags depending on data type
        static if(isInstanceOf!(Nullable, SymbolT))
        {
            info.existence |= ArgExistence.optional;

            static if(is(SymbolT == Nullable!bool)) // Special case
                info.scheme = ArgParseScheme.bool_;
        }
        static if(is(SymbolT == bool))
        {
            info.existence |= ArgExistence.optional;
            info.scheme = ArgParseScheme.bool_;
        }
        if(info.action == ArgAction.count)
        {
            info.scheme = ArgParseScheme.repeatableName;
            info.existence |= ArgExistence.optional | ArgExistence.multiple;
        }

        ret ~= info;
    }}

    return ret;
}

private auto oneOf(alias Symbol, Udas...)()
{
    alias SymbolUdas = __traits(getAttributes, Symbol);
    static foreach(uda; SymbolUdas)
    {{
        static if(__traits(compiles, typeof(uda)))
        {
            alias UdaT = typeof(uda);
            enum UdaRet = uda;
        }
        else
        {
            alias UdaT = uda;
            enum UdaRet = uda.init;
        }

        static foreach(wanted; Udas)
        {
            static if(is(wanted == UdaT))
                return UdaRet;
        }
    }}
}