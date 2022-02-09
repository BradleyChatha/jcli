module jcli.commandparser.parser;

import jcli.argbinder, jcli.argparser, jcli.core, jcli.introspect;
import std.conv : to;

template CommandParser(alias CommandT_, alias ArgBinderInstance_ = ArgBinder!())
{
    alias CommandT          = CommandT_;
    alias ArgBinderInstance = ArgBinderInstance_;
    immutable commandInfo = commandInfoFor!CommandT;

    static import std.stdio;
    static struct ParseResult
    {
        bool success;
        CommandT command;
    }

    static ResultOf!CommandT parse(alias errorHandlerFormatFunction = std.stdio.writefln)(string[] args)
    {
        auto parser = ArgParser(args);
        auto result = parse!(errorHandlerFormatFunction)(parser);
        // All arguments must have been consumed.
        if (!result.success && !parser.empty)
        {
            import std.range : walkLength;
            errorHandlerFormatFunction("The command was given extra %d arguments.", parser.walkLength);
            result.success = false;
        }
        return result;
    }

    static ResultOf!CommandT parse(alias errorHandlerFormatFunction = std.stdio.writefln)(ref ArgParser parser)
    {
        import std.algorithm;
        import std.format : format;
        import std.exception : enforce;
        import std.bitmanip : BitArray;

        typeof(return) result;
        result.success = true;
        result.command = CommandT();

        static size_t getNumberOfSizetsNecessaryToHoldBits(size_t numBits)
        {
            static size_t ceilDivide(size_t a, size_t b)
            {
                return (a + b - 1) / b;
            }
            enum numBytesToHoldBits = ceilDivide(numBits, 8);
            enum numSizeTsToHoldBits = ceilDivide(numBytesToHoldBits, 8);
            return numSizeTsToHoldBits;
        }
        size_t[getNumberOfSizetsNecessaryToHoldBits(commandInfo.namedArgs.length)] 
            nameNotFoundBitArrayStorage;
        BitArray nameNotFoundBitArray = BitArray(
            cast(void) nameNotFoundBitArrayStorage, commandInfo.namedArgs.length);

        static foreach(index, arg; commandInfo.namedArgs)
        {
            static if(!(arg.existence & ArgExistence.optional))
                nameNotFoundBitArray[index] = true;
        }

        size_t positionCount;
        while(!parser.empty)
        {
            string arg = parser.front;
            scope(exit)
                parser.popFront();

            if(arg.fullSlice == "--")
            {
                static if(commandInfo.rawArg != typeof(commandInfo.rawArg).init)
                {
                    parser.popFront();
                    __traits(getMember, result.command, commandInfo.rawArg) = parser;
                }
                break;
            }

            OuterSwitch: 
            final switch(arg.kind)
            with(ArgParser.Result.Kind)
            {
                case rawText:
                {
                    Switch: switch(positionCount)
                    {
                        static foreach(i, positional; commandInfo.positionalArgs)
                        {
                            case i:
                                auto result = ArgBinderInstance.bind!positional(arg.fullSlice, result.command);
                                if(!result.isOk)
                                    return fail!CommandT(result.error, result.errorCode);
                                break Switch;
                        }

                        // I might be hitting a compiler bug, because without this, the "positionCount++" is sometimes,
                        // not all the time, but sometimes unreachable
                        // case 200302104:
                        //     break;

                        default:
                        {
                            static if(commandInfo.overflowArg == typeof(commandInfo.overflowArg).init)
                            {
                                enum maxPositionals = commandInfo.positionalArgs.length;
                                return fail!CommandT("Too many positional arguments near '%s'. Expected %d positional arguments.".format(arg.fullSlice, maxPositionals));
                            }
                            else
                            {
                                getArg!(commandInfo.overflowArg)(command) ~= arg.fullSlice;
                                break Switch;
                            }
                        }
                    }
                    
                    positionCount++;
                    break;
                }

                case argument:
                    static foreach(namedArgIndex, named; commandInfo.namedArgs)
                    {{
                        bool isEligible = (){
                            enum caseInsensitive = (named.config & ArgConfig.caseInsensitive) > 0;
                            {
                                bool noMatches = named.uda.pattern.matches!caseInsensitive(arg.nameSlice).empty;
                                if (!noMatches)
                                    return true;
                            }
                            static if (ArgParseScheme.repeatableName)
                            {
                                bool allSame = arg.nameSlice.all(arg.nameSlice[0]);
                                if (!allSame)
                                    return false;
                                bool noMatches = named.uda.pattern.matches!caseInsensitive(arg.nameSlice[0]).empty;
                                return !noMatches;
                            }
                            else
                            {
                                return false;
                            }
                        }();

                        if (isEligible)
                        {
                            if((named.existence & ArgExistence.multiple) == 0)
                            {
                                enforce((named.identifier in namedFound) is null,
                                    "Named argument %s cannot be specified multiple times.".format(named.identifier)
                                );
                            }
                            nameNotFoundBitArray[namedArgIndex] = false;

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
                                __traits(getMember, result.command, named) = value;
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
                                        return fail!CommandT(result.error, result.errorCode);
                                }
                                else static if(named.action == ArgAction.count)
                                {
                                    __traits(getMember, result.command, named)++;
                                }
                                else static assert(false, "Update me please.");
                            }
                            else static if(named.scheme == ArgParseScheme.repeatableName)
                            {
                                static assert(named.action == ArgAction.count, "ArgParseScheme.bool_ conflicts with anything that isn't ArgAction.count.");
                                __traits(getMember, result.command, named) += arg.nameSlice.length;
                            }
                            break OuterSwitch;
                        }
                    }}
                    return fail!CommandT("Unknown argument: "~arg.fullSlice);
            }
        }

        enforce(
            positionCount >= commandInfo.positionalArgs.length,
            "Expected %s positional arguments but got %s instead. Missing the following required positional arguments:%s".format(
                commandInfo.positionalArgs.length, positionCount,
                commandInfo.positionalArgs[positionCount..$]
                           .map!(arg => arg.uda.name.length ? arg.uda.name : "NO_NAME")
                           .fold!((a,b) => a~" "~b)("")
            )
        );

        if (nameNotFoundBitArray.count > 0)
        {
            import std.array;

            // May want to return the whole thing here, but I think the first thing
            // in the pattern should be the most descriptive anyway so should be encouraged.
            string getPattern(size_t index)
            {
                return commandInfo.namedArgs[index].uda.pattern.patterns[0];
            }

            auto failMessageBuilder = appender!string("The following required named arguments were not found: ");
            auto notFoundArgumentIndexes = nameNotFoundBitArray.bitsSet;
            failMessageBuilder ~= getPattern(notFoundArgumentIndexes.front);
            notFoundArgumentIndexes.popFront();

            foreach (notFoundArgumentIndex; notFoundArgumentIndexes)
            {
                failMessageBuilder ~= ", ";
                failMessageBuilder ~= getPattern(notFoundArgumentIndex);
            }

            return fail!CommandT(failMessageBuilder[]);
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

    S withoutRaw = result.value;
    // withoutRaw.raw = ArgParser.init;

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
    ), result.value.to!string);
    import std.algorithm : equal;
    assert(result.value.raw.equal(ArgParser(["raw 1", "raw 2"])), result.value.raw.to!string);
}