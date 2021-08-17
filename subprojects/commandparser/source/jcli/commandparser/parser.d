module jcli.commandparser.parser;

import jcli.argbinder, jcli.argparser, jcli.core, jcli.introspect, std;

struct CommandParser(alias CommandT_, alias ArgBinderInstance_ = ArgBinder!())
{
    alias CommandT          = CommandT_;
    alias CommandInfo       = commandInfoFor!CommandT;
    alias ArgBinderInstance = ArgBinderInstance_;

    static ResultOf!CommandT parse()(string[] args)
    {
        return parse(ArgParser(args));
    }

    static ResultOf!CommandT parse()(ArgParser parser)
    {
        CommandT command;

        enum MaxPositionals = CommandInfo.positionalArgs.length;
        size_t positionCount;
        Pattern[string] requiredNamed; // key is identifier
        bool[string] namedFound; // key is identifier, value is dummy.

        static foreach(arg; CommandInfo.namedArgs)
        {
            static if(!(arg.existence & ArgExistence.optional))
                requiredNamed[arg.identifier] = arg.uda.pattern;
        }

        while(!parser.empty)
        {
            auto arg = parser.front;
            scope(exit) parser.popFront();

            if(arg.fullSlice == "--")
            {
                static if(CommandInfo.rawArg != typeof(CommandInfo.rawArg).init)
                {
                    parser.popFront();
                    getArg!(CommandInfo.rawArg)(command) = parser;
                }
                break;
            }

            OuterSwitch: final switch(arg.kind) with(ArgParser.Result.Kind)
            {
                case rawText:
                    {
                        Switch: switch(positionCount)
                        {
                            static foreach(i, positional; CommandInfo.positionalArgs)
                            {
                                case i:
                                    auto result = ArgBinderInstance.bind!positional(arg.fullSlice, command);
                                    if(!result.isOk)
                                        return fail!CommandT(result.error);
                                    break Switch;
                            }

                            // I might be hitting a compiler bug, because without this, the "positionCount++" is sometimes,
                            // not all the time, but sometimes unreachable
                            case 200302104:
                                break;

                            default:
                                static if(CommandInfo.overflowArg == typeof(CommandInfo.overflowArg).init)
                                    return fail!CommandT("Too many positional arguments near '%s'. Expected %s".format(arg.fullSlice, MaxPositionals));
                                else
                                {
                                    getArg!(CommandInfo.overflowArg)(command) ~= arg.fullSlice;
                                    break;
                                }
                        }
                    }
                    positionCount++;
                    break;

                case argument:
                    static foreach(named; CommandInfo.namedArgs)
                    {
                        if(named.uda.pattern.match(arg.nameSlice, (named.config & ArgConfig.caseInsensitive) > 0).matched
                        || (named.scheme == ArgParseScheme.repeatableName && named.uda.pattern.patterns.any!(p => p.length == 1 && arg.nameSlice.all!(c => c == p[0]))))
                        {
                            static if(!(named.existence & ArgExistence.optional))
                                requiredNamed[named.identifier] = named.uda.pattern;
                            if((named.existence & ArgExistence.multiple) == 0)
                            {
                                enforce((named.identifier in namedFound) is null,
                                    "Named argument %s cannot be specified multiple times.".format(named.identifier)
                                );
                            }
                            namedFound[named.identifier] = true;

                            static if(named.scheme == ArgParseScheme.bool_)
                            {
                                static assert(named.action == ArgAction.normal, "ArgParseScheme.bool_ conflicts with anything that isn't ArgAction.normal.");

                                auto value = true;
                                auto copy = parser;
                                copy.popFront();
                                if(!copy.empty && copy.front.kind == rawText)
                                {
                                    if(copy.front.fullSlice == "true" || copy.front.fullSlice == "false")
                                    {
                                        parser.popFront(); // Keep main parser in sync
                                        value = copy.front.fullSlice.to!bool;
                                    }
                                }
                                getArg!named(command) = value;
                            }
                            else static if(named.scheme == ArgParseScheme.normal)
                            {
                                static if(named.action == ArgAction.normal)
                                {
                                    parser.popFront();
                                    if(parser.empty)
                                        return fail!CommandT("Expected value after argument "~arg.fullSlice~" but hit end of args.");
                                    if(parser.front.kind == argument)
                                        return fail!CommandT("Expected value after argument "~arg.fullSlice~" but instead got argument "~parser.front.fullSlice);

                                    auto result = ArgBinderInstance.bind!named(parser.front.fullSlice, command);
                                    if(!result.isOk)
                                        return fail!CommandT(result.error);
                                }
                                else static if(named.action == ArgAction.count)
                                    getArg!named(command)++;
                                else static assert(false, "Update me please.");
                            }
                            else static if(named.scheme == ArgParseScheme.repeatableName)
                            {
                                static assert(named.action == ArgAction.count, "ArgParseScheme.bool_ conflicts with anything that isn't ArgAction.count.");
                                getArg!named(command) += arg.nameSlice.length;
                            }
                            break OuterSwitch;
                        }
                    }
                    return fail!CommandT("Unknown argument: "~arg.fullSlice);
            }
        }

        Pattern[] notFound;
        foreach(k, v; requiredNamed)
        {
            if(!namedFound.byKey.any!(key => key == k))
                notFound ~= v;
        }

        if(notFound.length)
        {
            return fail!CommandT(
                "The following required arguments were not found: "
                ~notFound.fold!((a,b) => a.length ? a~", "~b.pattern : b.pattern)("")
            );
        }
        
        return ok(command);
    }
}

unittest
{
    @Command("ab")
    static struct S
    {
        @ArgPositional
        string s;


        @ArgNamed("abc")
        string a;

        @ArgNamed("b")
        @(ArgExistence.multiple)
        string b;

        @ArgNamed("c")
        bool c;

        @ArgNamed("d")
        bool d;

        @ArgNamed("e")
        bool e;

        @ArgPositional
        string f;

        @ArgNamed("v")
        @(ArgAction.count)
        int v;

        @ArgOverflow
        string[] overflow;

        @ArgRaw
        ArgParser raw;
    }

    alias parser = CommandParser!S;
    auto result = parser.parse([
        "abc", 
        "--abc=1", 
        "-b", "2", 
        "-b=3",
        "-c",
        "-d false",
        "-e arg2",
        "-vv",
        "-vvvv",
        "overflow1",
        "overflow2",
        "--",
        "raw 1",
        "raw 2",
    ]);
    assert(result.isOk, result.error);
    auto value = result.value;
    auto withoutRaw = value;
    withoutRaw.raw = ArgParser.init;
    assert(withoutRaw == S(
        "abc",
        "1",
        "3",
        true,
        false,
        true,
        "arg2",
        6,
        ["overflow1", "overflow2"],
    ), value.to!string);
    assert(value.raw.equal(ArgParser(["raw 1", "raw 2"])), value.raw.to!string);
}