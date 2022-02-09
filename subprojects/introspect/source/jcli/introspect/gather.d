module jcli.introspect.gather;

import jcli.introspect, jcli.core;
import std.traits;
import std.meta : AliasSeq;
import std.range : walkLength;

CommandInfo!CommandT commandInfoFor(CommandT)()
{
    typeof(return) ret;

    static assert(
        is(typeof(CommandUDAOf!CommandT)), 
        "You must use one of @Command or @DefaultCommand, but not both.");

    const CommandUda = CommandUDAOf!CommandT;
    static if(is(typeof(CommandUda) : CommandDefault))
        ret.isDefault = true;
    else
    {
        static assert(CommandUda.pattern.patterns.length > 0, "@Command must specify at least one pattern.");
        ret.pattern = CommandUda.pattern;
    }
    ret.description = CommandUda.description;

    // Find args.
    ret.namedArgs       = findArgs!(CommandT, ArgNamed);
    ret.positionalArgs  = findArgs!(CommandT, ArgPositional);
    auto raw            = findArgs!(CommandT, ArgRaw);
    auto overflow       = findArgs!(CommandT, ArgOverflow);

    if(ret.namedArgs.length == 0)
        ret.namedArgs = typeof(ret.namedArgs).init;
    if(ret.positionalArgs.length == 0)
        ret.positionalArgs = typeof(ret.positionalArgs).init;
    if(raw.length > 1)
        assert(false, "Only one symbol at most can be marked @ArgRaw");
    if(raw.length == 1)
        ret.rawArg = raw[0];
    if(overflow.length > 1)
        assert(false, "Only one symbol at most can be marked @ArgOverflow");
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

        static if(__traits(compiles, { enum a = Udas[0]; }))
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
                {
                    static if(uda & ArgConfig.canRedefine)
                        info.existence |= ArgExistence.multiple;

                    info.config = uda;
                }
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

template CommandUDAOf(Type)
{
    static foreach(uda; __traits(getAttributes, Symbol))
    {
        static if(is(Command == UDAInfo!uda.Type))
        {
            enum CommandUDAOf = UDAInfo!uda.Value;
        }
        static if(is(CommandDefault == UDAInfo!uda.Type))
        {
            enum CommandUDAOf = UDAInfo!uda.Value;
        }
    }
}

template UDAInfo(alias uda)
{
    static if(is(typeof(uda)))
    {
        alias Type = typeof(uda);
        enum Value = uda;
    }
    else
    {
        alias Type = uda;
        enum Value = uda.init;
    }
}
