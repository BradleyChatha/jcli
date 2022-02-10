module jcli.commandparser.parser;

import jcli.argbinder, jcli.argparser, jcli.core, jcli.introspect;
import std.conv : to;

/// This is needed mostly for testing purposes
enum ParseCommandErrorCode
{
    /// Since we don't need to test the underlying argument parser, this is a placeholder.
    /// Ideally, we should mirror those errors here, or something like that.
    argumentParserError,
    ///
    tooManyPositionalArgumentsError,
    /// Either trying to bind a positional argument or a named one.
    bindError,
    ///
    duplicateNamedArgumentError,
    /// TODO: this one should probably go to the argument binder, because
    /// it already knows how to handle bools.
    booleanFlagInvalidValueError,
    ///
    countArgumentGivenValueError,
    /// 
    noValueForNamedArgumentError,
    ///
    unknownNamedArgumentError,
    ///
    tooFewPositionalArgumentsError,
    ///
    missingNamedArgumentsError,
}

private alias ErrorCode = ParseCommandErrorCode;

private struct WriterThing
{
    void opCall(T...)(ErrorCode errorCode, T args)
    {
        import std.stdio;
        writefln(args);
    }
}

template CommandParser(alias CommandT_, alias ArgBinderInstance_ = ArgBinder!())
{
    alias CommandT          = CommandT_;
    alias ArgBinderInstance = ArgBinderInstance_;
    immutable commandInfo   = commandInfoFor!CommandT;

    static import std.stdio;
    static struct ParseResult
    {
        size_t errorCount;
        CommandT command;
        bool success() { return errorCount > 0; }
    }

    static ResultOf!CommandT parse
    (
        TErrorHandler
    )
    (
        string[] args,
        ref TErrorHandler errorHandlerFormatFunction = WriterThing()
    )
    {
        auto parser = argParser(args);
        auto result = parse!(errorHandlerFormatFunction)(parser);
        return result;
    }

    static ResultOf!CommandT parse
    (
        // TODO:
        // perhaps this should be a delegate?
        // but then it will have to take a var arg array, which is fine.
        TErrorHandler,
        TArgParser : ArgParser!T, T
    )
    (
        ref TErrorHandler errorHandlerFormatFunction,
        ref TArgParser argParser
    )
    {
        typeof(return) result;
        result.command = CommandT();

        static if (commandInfo.namedArgs.length > 0)
        {
            import std.bitmanip : BitArray;
            static size_t getNumberOfSizetsNecessaryToHoldBits(size_t numBits)
            {
                static size_t ceilDivide(size_t a, size_t b)
                {
                    return (a + b - 1) / b;
                }
                size_t numBytesToHoldBits = ceilDivide(numBits, 8);
                size_t numSizeTsToHoldBits = ceilDivide(numBytesToHoldBits, 8);
                return numSizeTsToHoldBits;
            }
            enum lengthOfBitArrayStorage = getNumberOfSizetsNecessaryToHoldBits(commandInfo.namedArgs.length);
            static assert(lengthOfBitArrayStorage > 0);

            // Is 0 if a required argument has been found, otherwise 1.
            // For non-required arguments this is always 0.
            size_t[lengthOfBitArrayStorage] requiredNamedArgHasNotBeenFoundBitArrayStorage;
            BitArray requiredNamedArgHasNotBeenFoundBitArray = BitArray(
                cast(void) requiredNamedArgHasNotBeenFoundBitArrayStorage, commandInfo.namedArgs.length);

            // Is 1 if an argument has been found at least once, otherwise 0.
            size_t[lengthOfBitArrayStorage] namedArgHasBeenFoundBitArrayStorage;
            BitArray namedArgHasBeenFoundBitArray = BitArray(
                cast(void) namedArgHasBeenFoundBitArrayStorage, commandInfo.namedArgs.length);
            
            static foreach (index, arg; commandInfo.namedArgs)
            {
                static if (!arg.flags.has(ArgFlags._optionalBit))
                {
                    requiredNamedArgHasNotBeenFoundBitArray[index] = true;
                }
            }
        }

        size_t currentPositionalArgIndex = 0;
        size_t errorCounter = 0;
        alias Kind = ArgToken.Kind;

        OuterLoop: while (!argParser.empty)
        {
            string currentArgToken = argParser.front;
            argParser.popFront();

            // Cannot be final, since there are flags.
            switch (currentArgToken.kind)
            {
                default:
                {
                    assert(0);
                }

                // if (currentArgToken.kind & Kind.errorBit)
                // {
                // }
                case Kind.error_inputAfterClosedQuote:
                case Kind.error_malformedQuotes:
                case Kind.error_noValueForNamedArgument:
                case Kind.error_singleDash:
                case Kind.error_spaceAfterAssignment:
                case Kind.error_spaceAfterDashes:
                case Kind.error_threeOrMoreDashes:
                case Kind.error_unclosedQuotes:
                {
                    // for now just log and go next
                    // TODO: better errors
                    errorHandlerFormatFunction(
                        ErrorCode.argumentParserError,
                        "An error has occured in the parser: %s",
                        currentArgToken.kind.stringof);
                    continue OuterLoop;
                }

                case Kind.twoDashesDelimiter:
                {
                    argParser.popFront();
                    if (commandInfo.takesRawArguments)
                    {
                        auto rawArgumentStrings = argParser.leftoverRange();
                        __traits(getMember, result.command, commandInfo.rawArgName) = rawArgumentStrings;
                    }
                    argParser = typeof(argParser).init;
                    break OuterLoop;
                }

                case Kind.namedArgumentValue:
                {
                    assert(false, "This one should be handled in the named argument section.");
                }

                // (currentArgToken.kind & (Kind._positionalArgumentBit | Kind.valueBit))
                //      == Kind._positionalArgumentBit | Kind.valueBit
                case Kind.namedArgumentValueOrPositionalArgument:
                case Kind.positionalArgument:
                {
                    InnerSwitch: switch (currentPositionalArgIndex)
                    {
                        default:
                        {
                            if (commandInfo.takesOverflowArgs)
                            {
                                __traits(getMember, result.command, commandInfo.overflowArgName)
                                    ~= currentArgToken.fullSlice;
                            }
                            else
                            {
                                errorHandlerFormatFunction(
                                    ErrorCode.tooManyPositionalArgumentsError,
                                    "Too many (%) positional arguments detected near %.",
                                    currentPositionalArgIndex,
                                    currentArgToken.fullSlice);
                                errorCounter += 1;
                            }
                            break InnerSwitch;
                        }
                        static foreach (positionalIndex, positional; commandInfo.positionalArgs)
                        {
                            case i:
                            {
                                // auto result = bindPositionalArg!positional(result.command, arg.valueSlice);
                                auto result = ArgBinderInstance.bind!positional(result.command, arg.valueSlice);
                                if (result.isError)
                                {
                                    errorHandlerFormatFunction(
                                        ErrorCode.bindError,
                                        "An error occured while trying to bind the positional argument % at index %: "
                                            ~ "%; Error code %.",
                                        positional.identifier, positionalIndex,
                                        result.error, result.errorCode);
                                    errorCounter += 1;
                                }
                                break InnerSwitch;
                            }
                        }
                    }

                    currentPositionalArgIndex++;
                    continue OuterLoop;
                }

                // currentArgToken.kind & Kind.argumentNameBit
                case Kind.fullNamedArgumentName:
                case Kind.shortNamedArgumentName:
                {
                    // Check if any of the arguments matched the name
                    static foreach (namedArgIndex, namedArgInfo; commandInfo.namedArgs)
                    {{
                        bool isMatch =
                        (){
                            import std.algorithm;
                            enum caseInsensitive = namedArgInfo.flags.has(ArgFlags._caseInsensitiveBit);
                            {
                                bool noMatches = namedArgInfo.pattern.matches!caseInsensitive(arg.nameSlice).empty;
                                if (!noMatches)
                                    return true;
                            }
                            static if (namedArgInfo.flags.has(ArgFlags._repeatableNameBit))
                            {
                                bool allSame = arg.valueSlice.all(arg.valueSlice[0]);
                                if (!allSame)
                                    return false;
                                bool noMatches = namedArgInfo.pattern.matches!caseInsensitive(arg.nameSlice[0]).empty;
                                return !noMatches;
                            }
                            else
                            {
                                return false;
                            }
                        }();

                        if (isMatch)
                        {
                            // if (namedArgInfo.existence & ArgExistence.optional)
                            // {
                            // }

                            static if (namedArgInfo.flags.doesNotHave(ArgFlags._multipleBit))
                            {
                                if (namedArgHasBeenFoundBitArray[namedArgIndex])
                                {
                                    errorHandlerFormatFunction(
                                        ErrorCode.duplicateNamedArgumentError,
                                        "Duplicate named argument %.",
                                        namedArgInfo.pattern.patterns[0]);
                                    errorCounter += 1;

                                    // Skip its value too
                                    if (!argParser.empty
                                        && argParser.front.kind == Kind.namedArgumentValue)
                                    {
                                        argParser.popFront();
                                    }
                                    continue OuterSwitch;
                                }
                            }
                            namedArgHasBeenFoundBitArray[namedArgInfo] = true;

                            static if (namedArgInfo.flags.has(ArgFlags._optionalBit))
                                requiredNamedArgHasNotBeenFoundBitArray[namedArgInfo] = true;

                            static if (namedArgInfo.flags.has(ArgFlags._parseAsFlagBit))
                            {
                                if (argParser.empty)
                                {
                                    __traits(getMember, result.command, namedArgInfo.identifier) = true;
                                    break OuterSwitch;
                                }

                                auto nextArgToken = argParser.front;
                                if ((nextArgToken.kind & Kind._namedArgumentValueBit) == 0)
                                {
                                    __traits(getMember, result.command, namedArgInfo.identifier) = true;
                                    continue OuterSwitch;
                                }

                                // TODO: Shouldn't we consider the case sensitivity here??
                                if (nextArgToken.valueSlice == "true")
                                {
                                    __traits(getMember, result.command, namedArgInfo.identifier) = true;
                                }
                                else if (nextArgToken.valueSlice == "false")
                                {
                                    __traits(getMember, result.command, namedArgInfo.identifier) = false;
                                }
                                else
                                {
                                    errorHandlerFormatFunction(
                                        ErrorCode.booleanFlagInvalidValueError,
                                        "Invalid value `%` for a boolean flag argument `%` (Expected either `true` of `false`)",
                                        nextArgToken.valueSlice,
                                        namedArgInfo.pattern.patters[0]);
                                    errorCounter += 1;
                                }

                                argParser.popFront();
                                continue OuterSwitch;
                            }

                            else static if (namedArgInfo.flags.has(ArgFlags._countBit))
                            {
                                alias TypeOfField = typeof(__traits(getMember, result.command, namedArgInfo.identifier));
                                static assert(__traits(isArithmetic, TypeOfField));
                                static if (namedArgInfo.flags.has(ArgFlags._canRedefineBit))
                                {
                                    const valueToAdd = cast(TypeOfField) currentArgToken.valueSlice.length;
                                }
                                else
                                {
                                    const valueToAdd = cast(TypeOfField) 1;
                                }
                                __traits(getMember, result.command, namedArgInfo.identifier) += valueToAdd;

                                if (argParser.empty)
                                    break OuterLoop;

                                auto nextArgToken = argParser.front;
                                if (nextArgToken.kind == Kind.namedArgumentValue)
                                {
                                    errorHandlerFormatFunction(
                                        ErrorCode.countArgumentGivenValueError,
                                        "The count argument % cannot be given a value, got %.",
                                        namedArgInfo.pattern.patterns[0],
                                        nextArgToken.valueSlice);
                                    errorCounter += 1;
                                    argParser.popFront();
                                }
                                continue OuterLoop;
                            }

                            else
                            {
                                static assert(namedArgInfo.flags.doesNotHave(ArgFlags._parseAsFlagBit));
                                
                                if (argParser.empty)
                                {
                                    errorHandlerFormatFunction(
                                        ErrorCode.noValueForNamedArgumentError,
                                        "Expected a value for the argument %.",
                                        namedArgInfo.pattern.patterns[0]);
                                    errorCounter++;
                                    break OuterLoop;
                                }

                                auto nextArgToken = argParser.front;
                                if ((nextArgToken & Kind._namedArgumentValueBit) == 0)
                                {
                                    errorHandlerFormatFunction(
                                        ErrorCode.noValueForNamedArgumentError,
                                        "Expected a value for the argument %, got %.",
                                        namedArgInfo.pattern.patterns[0],
                                        nextArgToken.valueSlice);
                                    errorCounter++;

                                    // Don't skip it, because it might be the name of another option.
                                    // argParser.popFront();
                                    
                                    continue OuterLoop;
                                }

                                {
                                    // NOTE: ArgFlags._accumulateBit should have been handled in the binder.
                                    auto result = ArgBinderInstance.bind!named(nextArgToken.valueSlice, command);
                                    if (result.isError)
                                    {
                                        errorHandlerFormatFunction(
                                            ErrorCode.bindError,
                                            "An error occured while trying to bind the named argument %: "
                                                ~ "%; Error code %.",
                                            positional.identifier,
                                            result.error, result.errorCode);
                                        errorCounter += 1;
                                    }
                                    argParser.popFront();
                                    continue OuterLoop;
                                }
                            }
                        }
                    }}

                    /// TODO: conditionally allow unknown arguments
                    errorHandlerFormatFunction(
                        ErrorCode.unknownNamedArgumentError,
                        "Unknown named argument `%`.",
                        currentArgToken.fullSlice);
                    errorCounter++;

                    if (argParser.empty)
                        break OuterLoop;

                    if (argParser.front.kind == Kind.namedArgumentValue)
                    {
                        argParser.popFront();
                        continue OuterLoop;
                    }
                }
            }
        }

        if (currentPositionalArgIndex < commandInfo.positionalArgs.length)
        {
            import std.algorithm : map;
            import std.string : join;
            enum string argList = commandInfo.positionalArgs.map!(a => a.identifier).join(", ");
            errorHandlerFormatFunction(
                ErrorCode.tooFewPositionalArgumentsError,
                "Expected % positional arguments but got only %. The command takes the following positional arguments: "
                    ~ argList,
                commandInfo.positionalArgs.length,
                currentPositionalArgIndex);
            errorCounter++;
        }

        if (requiredNamedArgHasNotBeenFoundBitArray.count > 0)
        {
            import std.array;

            // May want to return the whole thing here, but I think the first thing
            // in the pattern should be the most descriptive anyway so should be encouraged.
            string getPattern(size_t index)
            {
                return commandInfo.namedArgs[index].pattern.patterns[0];
            }

            auto failMessageBuilder = appender!string("The following required named arguments were not found: ");
            auto notFoundArgumentIndexes = requiredNamedArgHasNotBeenFoundBitArray.bitsSet;
            failMessageBuilder ~= getPattern(notFoundArgumentIndexes.front);
            notFoundArgumentIndexes.popFront();

            foreach (notFoundArgumentIndex; notFoundArgumentIndexes)
            {
                failMessageBuilder ~= ", ";
                failMessageBuilder ~= getPattern(notFoundArgumentIndex);
            }

            errorHandlerFormatFunction(
                ErrorCode.duplicateNamedArgumentError,
                failMessageBuilder[]);
            errorCounter++;
        }

        debug if (errorCounter > 0)
        {
            writeln(errorCounter, " errors have occured.");
        }

        result.success = errorCounter == 0;    
        return result;
    }
}


version(unittest)
{
    struct InMemoryErrorOutput
    {
        import std.array;
        Appender!ErrorCode errorCodes;
        Appender!string result;

        import std.format : formattedWrite;
        void opCall(T...)(ErrorCode errorCode, T args)
        {
            errorCodes ~= errorCode;
            formattedWrite(result, args, "\n");
        }

        void clear()
        {
            errorCodes.clear();
            result.clear();
        }
    }

    InMemoryErrorOutput createSink()
    {
        import std.array;
        return InMemoryErrorOutput(appender!string);
    }
}


unittest
{
    import std.algorithm;

    static struct S
    {
        @ArgPositional
        string a;
    }

    InMemoryErrorOutput output = createSink();
    {
        // Ok
        output.clear();
        auto result = CommandParser!S.parse(["b"], output);
        assert(result.isOk);
        assert(result.value.a == "b");
        assert(output.errorCodes.length == 0);
    }
    {
        output.clear();
        auto result = CommandParser!S.parse(["-a", "b"], output);
        assert(result.isError);
        assert(output.errorCodes.canFind(ErrorCode.unknownNamedArgumentError));
    }
    {
        output.clear();
        auto result = CommandParser!S.parse(["a", "b"], output);
        assert(result.isError);
        assert(result.value.a == "a");
        assert(output.errorCodes.canFind(ErrorCode.tooManyPositionalArgumentsError));
    }
    {
        output.clear();
        auto result = CommandParser!S.parse([], output);
        assert(result.isError);
        assert(output.errorCodes.canFind(ErrorCode.tooFewPositionalArgumentsError));
    }
}


unittest
{
    static struct S
    {
        @ArgNamed("a", "")
        string a;
    }

    InMemoryErrorOutput output = createSink();
    {
        // Extra positional argument, 
        output.clear();
        auto result = CommandParser!S.parse(["b"], output);
        assert(result.isError);
        assert(result.value.a == "b");
    }
    {
        // Unexpected option
        output.clear();
        auto result = CommandParser!S.parse(["-a", "b"], output);
        assert(result.isError);
    }
    {
        // Overflow
        output.clear();
        auto result = CommandParser!S.parse(["a", "b"], output);
        assert(result.isError);
        assert(result.value.a == "a");
    }
}


unittest
{
    static struct S
    {
        @ArgPositional
        string a;
    }
}
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