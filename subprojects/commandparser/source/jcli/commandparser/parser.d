module jcli.commandparser.parser;

import jcli.argbinder, jcli.argparser, jcli.core, jcli.introspect;
import std.conv : to;

/// This is needed mostly for testing purposes
enum CommandParsingErrorCode
{
    none = 0,
    /// Since we don't need to test the underlying argument parser, this is a placeholder.
    /// Ideally, we should mirror those errors here, or something like that.
    argumentParserError = 1 << 0,
    ///
    tooManyPositionalArgumentsError = 1 << 1,
    /// Either trying to bind a positional argument or a named one.
    bindError = 1 << 2,
    ///
    duplicateNamedArgumentError = 1 << 3,
    ///
    countArgumentGivenValueError = 1 << 4,
    /// 
    noValueForNamedArgumentError = 1 << 5,
    ///
    unknownNamedArgumentError = 1 << 6,
    ///
    tooFewPositionalArgumentsError = 1 << 7,
    ///
    missingNamedArgumentsError = 1 << 8,
}

private alias ErrorCode = CommandParsingErrorCode;

struct DefaultParseErrorHandler
{
    const @safe:

    bool shouldRecord(ErrorCode errorCode)
    {
        return true;
    }
    void format(T...)(ErrorCode errorCode, T args)
    {
        import std.stdio;
        writefln(args);
    }
}

// TODO: 
// I think there is a solid reason to do a handler interface here.
// It would have the two methods like in the default handler above.
// The format method will have to be a vararg one.
// Why? To control the binary size. A couple of virtual calls for the errors will be
// better than generating code for this function twice, even tho meh I don't know.
// It isn't that big in code, but when instantiated for a large struct, it could bloat
// the binary size. 
// interface IRecordError{}

/// The errors are always recorded (or ignored) via a handler object.
struct ParseResult(CommandType)
{
    size_t errorCount;
    // TODO: we should take the command as a ref?
    CommandType value;
    
    @safe nothrow @nogc pure const:
    bool isOk() { return errorCount == 0; }
    bool isError() { return errorCount > 0; }
}

template CommandParser(CommandType, alias bindArgument = jcli.argbinder.bindArgument!())
{
    alias ArgumentInfo = jcli.introspect.CommandArgumentsInfo!CommandType;
    alias Result       = ParseResult!CommandType;

    static import std.stdio;
    ParseResult!CommandType parse(scope string[] args)
    {
        scope auto dummy = DefaultParseErrorHandler();
        return parse(args, dummy);
    }

    ParseResult!CommandType parse
    (
        TErrorHandler
    )
    (
        scope string[] args,
        ref scope TErrorHandler errorHandler
    )
    {
        scope auto parser = argTokenizer(args);
        return parse(parser, errorHandler);
    }

    ParseResult!CommandType parse
    (
        // TODO:
        // Perhaps this should be a delegate?
        // But then it will have to take a var arg array, which is fine.
        TErrorHandler,
        TArgTokenizer : ArgTokenizer!T, T
    )
    (
        ref scope TArgTokenizer tokenizer,
        ref scope TErrorHandler errorHandler
    )
    {
        auto command = CommandType();

        static if (ArgumentInfo.named.length > 0)
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
            enum lengthOfBitArrayStorage = getNumberOfSizetsNecessaryToHoldBits(ArgumentInfo.named.length);
            static assert(lengthOfBitArrayStorage > 0);

            // Is 0 if a required argument has been found, otherwise 1.
            // For non-required arguments this is always 0.
            size_t[lengthOfBitArrayStorage] requiredNamedArgHasNotBeenFoundBitArrayStorage;
            BitArray requiredNamedArgHasNotBeenFoundBitArray = BitArray(
                cast(void[]) requiredNamedArgHasNotBeenFoundBitArrayStorage, ArgumentInfo.named.length);

            // Is 1 if an argument has been found at least once, otherwise 0.
            size_t[lengthOfBitArrayStorage] namedArgHasBeenFoundBitArrayStorage;
            BitArray namedArgHasBeenFoundBitArray = BitArray(
                cast(void[]) namedArgHasBeenFoundBitArrayStorage, ArgumentInfo.named.length);
            
            static foreach (index, arg; ArgumentInfo.named)
            {
                static if (arg.flags.has(ArgFlags._requiredBit))
                {
                    requiredNamedArgHasNotBeenFoundBitArray[index] = true;
                }
            }
        }

        size_t currentPositionalArgIndex = 0;
        size_t errorCounter = 0;
        alias Kind = ArgToken.Kind;

        void recordError(T...)(ErrorCode code, auto ref T args)
        {
            if (errorHandler.shouldRecord(code))
            {
                errorHandler.format(code, args);
                errorCounter++;
            }
        }

        OuterLoop: while (!tokenizer.empty)
        {
            const currentArgToken = tokenizer.front;

            // This has to be handled before the switch, because we pop before the switch.
            if (currentArgToken.kind == Kind.twoDashesDelimiter)
            {
                static if (ArgumentInfo.takesRaw)
                {
                    auto rawArgumentStrings = tokenizer.leftoverRange();
                    command.getArgumentFieldRef!(ArgumentInfo.raw) = rawArgumentStrings;
                    // To the outside it looks like we have consumed all arguments.
                    tokenizer = typeof(tokenizer).init;
                }
                
                tokenizer.popFront();
                break OuterLoop;
            }

            tokenizer.popFront();

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
                    recordError(
                        ErrorCode.argumentParserError,
                        "An error has occured in the parser: %s",
                        currentArgToken.kind.stringof);
                    continue OuterLoop;
                }

                case Kind.namedArgumentValue:
                {
                    assert(false, "This one should have been handled in the named argument section.");
                }

                // (currentArgToken.kind & (Kind._positionalArgumentBit | Kind.valueBit))
                //      == Kind._positionalArgumentBit | Kind.valueBit
                case Kind.namedArgumentValueOrOrphanArgument:
                case Kind.positionalArgument:
                // TODO: imo orphan arguments should not be treated like positional ones.
                case Kind.orphanArgumentBit:
                {
                    InnerSwitch: switch (currentPositionalArgIndex)
                    {
                        default:
                        {
                            static if (ArgumentInfo.takesOverflow)
                            {
                                command.getArgumentFieldRef!(ArgumentInfo.overflow)
                                    ~= currentArgToken.fullSlice;
                            }
                            else
                            {
                                recordError(
                                    ErrorCode.tooManyPositionalArgumentsError,
                                    "Too many (%d) positional arguments detected near %s.",
                                    currentPositionalArgIndex,
                                    currentArgToken.fullSlice);
                            }
                            break InnerSwitch;
                        }
                        static foreach (positionalIndex, positional; ArgumentInfo.positional)
                        {
                            case positionalIndex:
                            {
                                auto result = bindArgument!positional(command, currentArgToken.valueSlice);
                                if (result.isError)
                                {
                                    recordError(
                                        ErrorCode.bindError,
                                        "An error occured while trying to bind the positional argument %s at index %d: "
                                            ~ "%s; Error code %d.",
                                        positional.identifier, positionalIndex,
                                        result.error, result.errorCode);
                                }
                                break InnerSwitch;
                            }
                        }
                    } // InnerSwitch

                    currentPositionalArgIndex++;
                    continue OuterLoop;
                }

                // currentArgToken.kind & Kind.argumentNameBit
                case Kind.fullNamedArgumentName:
                case Kind.shortNamedArgumentName:
                {
                    // Check if any of the arguments matched the name
                    static foreach (namedArgIndex, namedArgInfo; ArgumentInfo.named)
                    {{
                        if (isNameMatch!namedArgInfo(currentArgToken.nameSlice))
                        {
                            void recordBindError(R)(in R result)
                            {
                                recordError(
                                    ErrorCode.bindError,
                                    "An error occured while trying to bind the named argument %s: "
                                        ~ "%s; Error code %d.",
                                    namedArgInfo.identifier,
                                    result.error, result.errorCode);
                            }

                            static if (namedArgInfo.flags.doesNotHave(ArgFlags._multipleBit))
                            {
                                if (namedArgHasBeenFoundBitArray[namedArgIndex]
                                    // This error type being ignored means the user implicitly wants
                                    // all of the arguments to be processed as though they had the canRedefine bit.
                                    && errorHandler.shouldRecord(ErrorCode.duplicateNamedArgumentError))
                                {
                                    errorHandler.format(
                                        ErrorCode.duplicateNamedArgumentError,
                                        "Duplicate named argument %s.",
                                        namedArgInfo.name);
                                    errorCounter++;
                                    

                                    // Skip its value too
                                    if (!tokenizer.empty
                                        && tokenizer.front.kind == Kind.namedArgumentValue)
                                    {
                                        tokenizer.popFront();
                                    }
                                    continue OuterLoop;
                                }
                            }
                            namedArgHasBeenFoundBitArray[namedArgIndex] = true;

                            static if (namedArgInfo.flags.has(ArgFlags._requiredBit))
                                requiredNamedArgHasNotBeenFoundBitArray[namedArgIndex] = false;

                            static if (namedArgInfo.flags.has(ArgFlags._parseAsFlagBit))
                            {
                                // Default to setting the field to true, since it's defined.
                                // The only scenario where it should be false is if `--arg false` is used.
                                // TODO: 
                                // Allow custom flag values with a UDA.
                                // parseAsFlag should not be restricted to bool, ideally.
                                command.getArgumentFieldRef!namedArgInfo = true;

                                if (tokenizer.empty)
                                    break OuterLoop;

                                auto nextArgToken = tokenizer.front;
                                if (nextArgToken.kind.doesNotHave(Kind.valueBit))
                                    continue OuterLoop;

                                // Providing a value to a bool is optional, so to avoid producing an unwanted
                                // error, we need to white list the allowed values if it's not explicitly
                                // marked as the argument's value.
                                //
                                // Actually, no! This does not work, because custom converters exist.
                                // Imagine the user specified that bool to have a switch converter, aka on/off.
                                // We try and convert, we just swallow the error if it does not succeed.
                                //  
                                // If we want to not allocate the extra error string here, we could
                                // forward the error handler to the binder, maybe??
                                //
                                // if(nextArgToken.kind == Kind.namedArgumentValueOrOrphanArgument)
                                    // continue OuterLoop;

                                auto bindResult = bindArgument!namedArgInfo(command, nextArgToken.valueSlice);

                                // So there are 3 possibilities:
                                // 1. the value was compatible with the converter, and we got true or false.
                                if (bindResult.isOk)
                                {
                                    tokenizer.popFront();
                                    continue OuterLoop;
                                }

                                // 2. the value was not compatible with the converter, and we got an error.
                                // bindResult.isError is always true here.
                                else if (
                                    // so here we check if it had definitely been for this argument.
                                    // aka this will be true when `--arg=kek` is passed, but not when `--arg kek` is passed.
                                    nextArgToken.kind.doesNotHave(Kind.orphanArgumentBit))
                                {
                                    recordBindError(bindResult);
                                    tokenizer.popFront();
                                    continue OuterLoop;
                                }

                                // 3. It's an error, but the value can be interpreted as another sort of argument.
                                // For now, we consider orphan arguments to be just positional arguments, but not for long.
                                // `--arg kek` would get to this point and ignore the `kek`.
                                else
                                {
                                    continue OuterLoop;
                                }
                            }

                            else static if (namedArgInfo.argument.flags.has(ArgFlags._countBit))
                            {
                                alias TypeOfField = typeof(command.getArgumentFieldRef!namedArgInfo);
                                static assert(__traits(isArithmetic, TypeOfField));
                                
                                static if (namedArgInfo.argument.flags.has(ArgFlags._repeatableNameBit))
                                {
                                    const valueToAdd = cast(TypeOfField) currentArgToken.valueSlice.length;
                                }
                                else
                                {
                                    const valueToAdd = cast(TypeOfField) 1;
                                }
                                command.getArgumentFieldRef!namedArgInfo += valueToAdd;

                                if (tokenizer.empty)
                                    break OuterLoop;

                                auto nextArgToken = tokenizer.front;
                                if (nextArgToken.kind == Kind.namedArgumentValue)
                                {
                                    recordError(
                                        ErrorCode.countArgumentGivenValueError,
                                        "The count argument %s cannot be given a value, got %s.",
                                        namedArgInfo.name,
                                        nextArgToken.valueSlice);
                                    tokenizer.popFront();
                                }
                                continue OuterLoop;
                            }

                            else
                            {
                                static assert(namedArgInfo.flags.doesNotHave(ArgFlags._parseAsFlagBit));
                                
                                if (tokenizer.empty)
                                {
                                    recordError(
                                        ErrorCode.noValueForNamedArgumentError,
                                        "Expected a value for the argument %s.",
                                        namedArgInfo.name);
                                    break OuterLoop;
                                }

                                auto nextArgToken = tokenizer.front;
                                if ((nextArgToken.kind & Kind.namedArgumentValueBit) == 0)
                                {
                                    recordError(
                                        ErrorCode.noValueForNamedArgumentError,
                                        "Expected a value for the argument %s, got %s.",
                                        namedArgInfo.name,
                                        nextArgToken.valueSlice);

                                    // Don't skip it, because it might be the name of another option.
                                    // tokenizer.popFront();
                                    
                                    continue OuterLoop;
                                }

                                {
                                    // NOTE: ArgFlags._accumulateBit should have been handled in the binder.
                                    auto result = bindArgument!namedArgInfo(command, nextArgToken.valueSlice);
                                    if (result.isError)
                                        recordBindError(result);
                                    tokenizer.popFront();
                                    continue OuterLoop;
                                }
                            }
                        }
                    }} // static foreach

                    /// TODO: conditionally allow unknown arguments
                    recordError(
                        ErrorCode.unknownNamedArgumentError,
                        "Unknown named argument `%s`.",
                        currentArgToken.fullSlice);

                    if (tokenizer.empty)
                        break OuterLoop;

                    if (tokenizer.front.kind == Kind.namedArgumentValue)
                    {
                        tokenizer.popFront();
                        continue OuterLoop;
                    }
                }
            } // TokenKindSwitch
        } // OuterLoop

        if (currentPositionalArgIndex < ArgumentInfo.numRequiredPositionalArguments)
        {
            enum messageFormat =
            (){
                string ret = "Expected ";
                if (ArgumentInfo.positional.length == ArgumentInfo.numRequiredPositionalArguments)
                    ret ~= "exactly";
                else
                    ret ~= "at least";

                ret ~= " %d positional arguments but got only %d. The command takes the following positional arguments: ";

                {
                    import std.algorithm : map;
                    import std.string : join;
                    enum argList = ArgumentInfo.positional.map!(a => a.name).join(", ");
                    ret ~= argList;
                }
                return ret;
            }();

            recordError(
                ErrorCode.tooFewPositionalArgumentsError,
                messageFormat,
                ArgumentInfo.numRequiredPositionalArguments,
                currentPositionalArgIndex);
        }

        static if (ArgumentInfo.named.length > 0)
        {
            if (requiredNamedArgHasNotBeenFoundBitArray.count > 0
                && errorHandler.shouldRecord(ErrorCode.missingNamedArgumentsError))
            {
                import std.array;

                // May want to return the whole thing here, but I think the first thing
                // in the pattern should be the most descriptive anyway so should be encouraged.
                string getPattern(size_t index)
                {
                    return ArgumentInfo.named[index].name;
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

                errorHandler.format(
                    ErrorCode.missingNamedArgumentsError,
                    failMessageBuilder[]);
                errorCounter++;
            }
        }

        return typeof(return)(errorCounter, command);
    }
}


version(unittest)
{
    import std.algorithm;
    import std.array;

    struct InMemoryErrorOutput
    {
        Appender!(ErrorCode[]) errorCodes;
        Appender!(char[]) result;

        bool shouldRecord(ErrorCode errorCode)
        {
            return true;
        }

        import std.format : formattedWrite;
        void format(T...)(ErrorCode errorCode, T args)
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
        return InMemoryErrorOutput(appender!(ErrorCode[]), appender!(char[]));
    }

    mixin template ParseBoilerplate(Struct)
    {
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

    mixin ParseBoilerplate!S;

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

    mixin ParseBoilerplate!S;

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
        @(ArgConfig.accumulate)
        string a;
    }
    // TODO: static assert the parse function does not compile.
}

unittest
{
    static struct S
    {
        @ArgNamed
        @(ArgConfig.optional)
        string a;
    }

    mixin ParseBoilerplate!S;

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
        @(ArgConfig.aggregate)
        string[] a;
    }

    mixin ParseBoilerplate!S;

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
        @(ArgConfig.aggregate | ArgConfig.optional)
        string[] a;
    }

    mixin ParseBoilerplate!S;

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
        @(ArgConfig.accumulate)
        int a;
    }

    mixin ParseBoilerplate!S;

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
        // Here, "b" is without a doubt a named argument value, so it produces a different error.
        const result = parse(["-a=b"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.countArgumentGivenValueError));
    }
    {
        // Does not imply repeatableName.
        const result = parse(["-aaa"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.unknownNamedArgumentError));
    }
    {
        // Still not allowed even with a number.
        const result = parse(["-a=3"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.countArgumentGivenValueError));
    }
}

unittest
{
    static struct S
    {
        @ArgNamed
        @(ArgConfig.accumulate | ArgConfig.optional)
        int a;
    }

    mixin ParseBoilerplate!S;

    {
        const result = parse([]);
        assert(result.isOk);
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
        @(ArgConfig.parseAsFlag)
        bool a;
    }

    mixin ParseBoilerplate!S;

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
        assert(output.errorCodes[].canFind(ErrorCode.bindError));
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
        string _;

        @ArgNamed("implicit")
        @(ArgConfig.parseAsFlag)
        bool a;
    }

    mixin ParseBoilerplate!S;

    {
        const result = parse(["-implicit", "positional"]);
        assert(result.isOk, output.result.data);
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

    mixin ParseBoilerplate!S;

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
        assert(output.errorCodes[].canFind(ErrorCode.tooFewPositionalArgumentsError));
    }
    {
        const result = parse(["a", "b", "c"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.tooManyPositionalArgumentsError));
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

    mixin ParseBoilerplate!S;

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
        assert(output.errorCodes[].canFind(ErrorCode.tooFewPositionalArgumentsError));
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
        assert(output.errorCodes[].canFind(ErrorCode.unknownNamedArgumentError));
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

    mixin ParseBoilerplate!S;

    {
        const result = parse(["a"]);
        assert(result.isOk);
        assert(result.value.a == "a");
        assert(result.value.raw == []);
    }
    {
        const result = parse(["c", "--", "d"]);
        assert(result.isOk);
        assert(result.value.raw == ["d"]);
    }
    {
        const result = parse(["c", "--", "- Stuff -"]);
        assert(result.isOk);
        assert(result.value.a == "c");
        assert(result.value.raw == ["- Stuff -"]);
    }
    {
        // Normally, non utf8 argument names are not supported, but here they are not parsed at all.
        const result = parse(["c", "--", "--Штука", "-物事"]);
        assert(result.isOk);
        assert(result.value.a == "c");
        assert(result.value.raw == ["--Штука", "-物事"]);
    }
}

unittest
{
    static struct S
    {
        @ArgNamed
        @(ArgConfig.repeatableName | ArgConfig.optional)
        int a;
    }
    
    mixin ParseBoilerplate!S;

    {
        const result = parse([]);
        assert(result.isOk);
        assert(result.value.a == 0);
    }
    {
        const result = parse(["-a"]);
        assert(result.isOk);
        assert(result.value.a == 1);
    }
    {
        const result = parse(["-aaa"]);
        assert(result.isOk);
        assert(result.value.a == 3);
    }
    {
        const result = parse(["-aaa", "-a"]);
        assert(result.isError);
        assert(output.errorCodes[].canFind(ErrorCode.duplicateNamedArgumentError));
    }
}

unittest
{
    static struct S
    {
        @ArgNamed
        int a;
    }
    
    struct TestErrorHandler
    {
        ErrorCode ignoredErrorCodes;
        Appender!(ErrorCode[]) errorCodes;

        bool shouldRecord(ErrorCode errorCode)
        {
            return (errorCode & ignoredErrorCodes) == 0;
        }

        void format(T...)(ErrorCode errorCode, T args)
        {
            errorCodes ~= errorCode;
        }

        void clear()
        {
            errorCodes.clear();
        }
    }

    static auto parse(scope string[] args, ref TestErrorHandler handler)
    {
        handler.clear();
        return CommandParser!S.parse(args, handler);
    }
    auto handler = TestErrorHandler(ErrorCode.none, appender!(ErrorCode[]));

    {
        handler.ignoredErrorCodes = ErrorCode.duplicateNamedArgumentError;
        const result = parse(["-a=2", "-a=3"], handler);
        assert(result.isOk);
        assert(result.value.a == 3);
    }
}
