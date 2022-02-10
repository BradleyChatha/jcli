module jcli.commandparser.parser;

import jcli.argbinder, jcli.argparser, jcli.core, jcli.introspect;
import std.conv : to;

/// This is needed mostly for testing purposes
enum CommandParsingErrorCode
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

private alias ErrorCode = CommandParsingErrorCode;

private struct WriterThing
{
    void opCall(T...)(ErrorCode errorCode, T args)
    {
        import std.stdio;
        writefln(args);
    }
}

// TODO: 
// Why does this template even exist?
// It should just be a normal templated function.
template CommandParser(alias CommandT_, alias ArgBinderInstance_ = ArgBinder!())
{
    alias CommandT          = CommandT_;
    alias ArgBinderInstance = ArgBinderInstance_;
    immutable commandInfo   = commandInfoFor!CommandT;

    static import std.stdio;
    static struct ParseResult
    {
        size_t errorCount;
        // TODO: we should take the command as a ref
        CommandT command;
        bool success() { return errorCount > 0; }
    }

    static ResultOf!CommandT parse
    (
        TErrorHandler
    )
    (
        scope string[] args,
        ref scope TErrorHandler errorHandlerFormatFunction = WriterThing()
    )
    {
        scope auto parser = argParser(args);
        const result = parse!(errorHandlerFormatFunction)(parser);
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
        ref scope TErrorHandler errorHandlerFormatFunction,
        ref scope TArgParser argParser
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

        if (currentPositionalArgIndex < commandInfo.requiredPositionalArgsCount)
        {
            enum string messageFormat =
            (){
                string ret = "Expected ";
                if (commandInfo.positionalArgs.length == commandInfo.numRequiredPositionalArgs)
                    ret ~= "exactly";
                else
                    ret ~= "at least";

                ret ~= "% positional arguments but got only %. The command takes the following positional arguments: ";

                {
                    import std.algorithm : map;
                    import std.string : join;
                    enum string argList = commandInfo.positionalArgs.map!(a => a.identifier).join(", ");
                    ret ~= argList;
                }
                return ret;
            }();

            errorHandlerFormatFunction(
                ErrorCode.tooFewPositionalArgumentsError,
                messageFormat,
                commandInfo.requiredPositionalArgsCount,
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

        result.errorCount = errorCounter;
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

    mixin template Things(Struct)
    {
        import std.algorithm;
        InMemoryErrorOutput output = createSink();
        auto parse(scope string[] args)
        {
            output.clear();
            return CommandParser!Struct.parse(args, output);
        }
    } 
}


unittest
{
    static struct S
    {
        @ArgPositional
        string a;
    }

    mixin Things!S;

    {
        // Ok
        const result = parse(["b"]);
        assert(result.isOk);
        assert(result.value.a == "b");
        assert(output.errorCodes[].length == 0);
    }
    {
        const result = parse(["-a", "b"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.unknownNamedArgumentError));
    }
    {
        const result = parse(["a", "b"]);
        assert(result.isError);
        assert(result.value.a == "a");
        assert(output.errorCodes[].canFind(ErrorCode.tooManyPositionalArgumentsError));
    }
    {
        const result = parse([]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.tooFewPositionalArgumentsError));
    }
}


unittest
{
    static struct S
    {
        @ArgNamed
        string a;
    }

    mixin Things!S;

    {
        const result = parse(["-a", "b"]);
        assert(result.isOk);
        assert(result.value.a == "b");
    }
    {
        const result = parse([]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.missingNamedArgumentsError));
    }
    {
        const result = parse(["-a"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.noValueForNamedArgumentError));
    }
    {
        const result = parse(["a"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.missingNamedArgumentsError));
    }
    {
        const result = parse(["-a", "b", "-a", "c"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.duplicateNamedArgumentError));
    }
    {
        const result = parse(["-b"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.missingNamedArgumentsError));
        assert(output.errorCodes[].canFind(ErrorCode.unknownNamedArgumentError));
    }
}

unittest
{
    static struct S
    {
        @ArgNamed
        string a = "Hello";
    }
    // TODO: 
    // The named argument has a default value, so it should be optional.
    // This equivalence should be tested elsewhere though.
}


unittest
{
    static struct S
    {
        @ArgNamed
        @(ArgFlags.count)
        string a;
    }
    // TODO: static assert the parse function does not compile.
}

unittest
{
    static struct S
    {
        @ArgNamed
        @(ArgFlags.optional)
        string a;
    }

    mixin Things!S;

    {
        const result = parse(["-a", "b"]);
        assert(result.isOk);
        assert(result.value.a == "b");
    }
    {
        const result = parse([]);
        assert(result.isOk);
        assert(result.value.a == typeof(result.value.a).init);
    }
    {
        const result = parse(["-a"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.noValueForNamedArgumentError));
    }
    {
        const result = parse(["-a", "b", "-a", "c"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.duplicateNamedArgumentError));
    }
}

unittest
{
    static struct S
    {
        @ArgNamed
        @(ArgFlags.aggregate)
        string[] a;
    }

    mixin Things!S;

    {
        const result = parse(["-a", "b"]);
        assert(result.isOk);
        assert(result.value.a == ["b"]);
    }
    {
        const result = parse([]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.missingNamedArgumentsError));
    }
    {
        const result = parse(["-a"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.noValueForNamedArgumentError));
    }
    {
        const result = parse(["-a", "b", "-a", "c"]);
        assert(result.isOk);
        assert(result.value.a == ["b", "c"]);
    }
}

unittest
{
    static struct S
    {
        @ArgNamed
        @(ArgFlags.aggregate | ArgFlags.optional)
        string[] a;
    }

    mixin Things!S;

    {
        const result = parse(["-a", "b"]);
        assert(result.isOk);
        assert(result.value.a == ["b"]);
    }
    {
        const result = parse([]);
        assert(result.isOk);
        assert(result.value.a == []);
    }
    {
        const result = parse(["-a", "b", "-a", "c"]);
        assert(result.isOk);
        assert(result.value.a == ["b", "c"]);
    }
}

unittest
{
    static struct S
    {
        @ArgNamed
        @(ArgFlags.accumulate)
        int a;
    }

    mixin Things!S;

    {
        const result = parse(["-a"]);
        assert(result.isOk);
        assert(result.value.a == 1);
    }
    {
        const result = parse([]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.missingNamedArgumentsError));
    }
    {
        const result = parse(["-a", "-a"]);
        assert(result.isOk);
        assert(result.value.a == 2);
    }
    {
        // Here, "b" can be either a value to "-a" or a positional argument.
        // Since "-a" does not expect a value, it should be treated as a positional argument.
        const result = parse(["-a", "b"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.tooManyPositionalArgumentsError));
    }
    {
        // Here, "b" is unequivocally a named argument value, so it produces a different error.
        const result = parse(["-a=b"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.countArgumentGivenValueError));
    }
}

unittest
{
    static struct S
    {
        @ArgNamed
        @(ArgFlags.accumulate | ArgFlags.optional)
        int a;
    }

    mixin Things!S;

    {
        const result = parse([]);
        assert(result.isError);
        assert(result.value.a == 0);
    }
    {
        const result = parse(["-a", "-a"]);
        assert(result.isOk);
        assert(result.value.a == 2);
    }
}

unittest
{
    static struct S
    {
        @ArgNamed
        @(ArgFlags.parseAsFlag)
        bool a;
    }

    mixin Things!S;

    {
        const result = parse([]);
        assert(result.isOk);
        assert(result.value.a == false);
    }
    {
        const result = parse(["-a", "true"]);
        assert(result.isOk);
        assert(result.value.a == true);
    }
    {
        const result = parse(["-a", "false"]);
        assert(result.isOk);
        assert(result.value.a == false);
    }
    {
        const result = parse(["-a", "stuff"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.tooManyPositionalArgumentsError));
    }
    {
        const result = parse(["-a=stuff"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.booleanFlagInvalidValueError));
    }
    {
        const result = parse(["-a", "-a"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.duplicateNamedArgumentError));
    }
}

unittest
{
    static struct S
    {
        @ArgPositional
        string a;
        
        // should be implied
        // @(ArgFlags.optional)

        @ArgPositional
        string b = "Hello";
    }

    mixin Things!S;

    {
        const result = parse(["a"]);
        assert(result.isOk);
        assert(result.value.a == "a");
        assert(result.value.b == "Hello");
    }
    {
        const result = parse(["c", "d"]);
        assert(result.isOk);
        assert(result.value.a == "c");
        assert(result.value.b == "d");
    }
    {
        const result = parse([]);
        assert(result.isError);
        assert(output.errorCode[].canFind(ErrorCode.tooFewPositionalArgumentsError));
    }
    {
        const result = parse(["a", "b", "c"]);
        assert(result.isError);
        assert(output.errorCode[].canFind(ErrorCode.tooManyPositionalArgumentsError));
    }
}

unittest
{
    static struct S
    {
        @ArgPositional
        string a;
        
        @ArgOverflow
        string[] overflow;
    }

    mixin Things!S;

    {
        const result = parse(["a"]);
        assert(result.isOk);
        assert(result.value.a == "a");
        assert(result.value.overflow == []);
    }
    {
        const result = parse(["c", "d"]);
        assert(result.isOk);
        assert(result.value.a == "c");
        assert(result.value.overflow == ["d"]);
    }
    {
        const result = parse([]);
        assert(result.isError);
        assert(output.errorCode[].canFind(ErrorCode.tooFewPositionalArgumentsError));
    }
    {
        const result = parse(["a", "b", "c"]);
        assert(result.isOk);
        assert(result.value.a == "a");
        assert(result.value.overflow == ["b", "c"]);
    }
    {
        const result = parse(["a", "b", "-c"]);
        assert(result.isError);
        assert(output.errorCode[].canFind(ErrorCode.unknownNamedArgumentError));
    }
}

unittest
{
    static struct S
    {
        @ArgPositional
        string a;
        
        @ArgRaw
        string[] raw;
    }

    mixin Things!S;

    {
        const result = parse(["a"]);
        assert(result.isOk);
        assert(result.value.a == "a");
        assert(result.value.raw == []);
    }
    {
        const result = parse(["c", "d"]);
        assert(result.isOk);
        assert(result.value.raw == ["d"]);
    }
    {
        const result = parse(["c", "- Stuff -"]);
        assert(result.isOk);
        assert(result.value.a == "c");
        assert(result.value.raw == ["- Stuff -"]);
    }
    {
        // Normally, non utf8 argument names are not supported, but here they are not parsed at all.
        const result = parse(["c", "--Штука", "-物事"]);
        assert(result.isOk);
        assert(result.value.a == "c");
        assert(result.value.raw == ["--Штука", "-物事"]);
    }
}
