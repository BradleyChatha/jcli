/// Contains a type that can parse data into a command.
module jaster.cli.commandparser;

import std.traits, std.algorithm, std.conv, std.format, std.typecons;
import jaster.cli.infogen, jaster.cli.binder, jaster.cli.result, jaster.cli.parser;

/++
 + A type that can parse an argument list into a command.
 +
 + Description:
 +  One may wonder, "what's the difference between `CommandParser` and `CommandLineInterface`?".
 +
 +  The answer is simple: `CommandParser` $(B only) performs argument parsing and value binding for a single command,
 +  whereas `CommandLineInterface` builds on top of `CommandParser` and several other components in order to support
 +  multiple commands via a complete CLI interface.
 +
 +  So in short, if all you want from JCLI is its command modeling and parsing abilties without all the extra faff
 +  provided by `CommandLineInterface`, and you're fine with performing execution by yourself, then you'll want to use
 +  this type.
 +
 + Commands_:
 +  Commands and arguments are defined in the same way as `CommandLineInterface` documents.
 +
 +  However, you don't need to define an `onExecute` function as this type has no concept of executing commands, only parsing them.
 +
 + Dependency_Injection:
 +  This is a feature provided by `CommandLineInterface`, not `CommandParser`.
 +
 +  Command instances must be constructed outside of `CommandParser`, as it has no knowledge on how to do this, it only knows how to parse data into it.
 +
 + Params:
 +  CommandT = The type of your command.
 +  ArgBinderInstance = The `ArgBinder` to use when binding arguments to the user provided values.
 + ++/
struct CommandParser(alias CommandT, alias ArgBinderInstance = ArgBinder!())
{
    /// The `CommandInfo` for the command being parsed. Special note is that this is compile-time viewable.
    enum Info = getCommandInfoFor!(CommandT, ArgBinderInstance);

    private static struct ArgRuntimeInfo(ArgInfoT)
    {
        ArgInfoT argInfo;
        bool wasFound;

        bool isNullable()
        {
            return (this.argInfo.existence & CommandArgExistence.optional) > 0;
        }
    }
    private auto argInfoOf(ArgInfoT)(ArgInfoT info) { return ArgRuntimeInfo!ArgInfoT(info); }

    /// Same as `parse` except it will automatically construct an `ArgPullParser` for you.
    Result!void parse(string[] args, ref CommandT commandInstance)
    {
        auto parser = ArgPullParser(args);
        return this.parse(parser, commandInstance);
    }

    /++
     + Parses the given arguments into your command instance.
     +
     + Description:
     +  This performs the full value parsing as described in `CommandLineInterface`.
     +
     + Notes:
     +  If the argument parsing fails, your command instance and parser $(B can be in a half-parsed state).
     +
     + Params:
     +  parser = The parser containing the argument tokens.
     +  commandInstance = The instance of your `CommandT` to populate.
     +
     + Returns:
     +  A successful result (`Result.isSuccess`) if argument parsing and binding succeeded, otherwise a failure result
     +  with an error (`Result.asFailure.error`) describing what happened. This error is user-friendly.
     +
     + See_Also:
     +  `jaster.cli.core.CommandLineInterface` as it goes over everything in detail.
     +
     +  This project's README also goes into detail about how commands are parsed.
     + ++/
    Result!void parse(ref ArgPullParser parser, ref CommandT commandInstance)
    {
        auto namedArgs = this.getNamedArgs();
        auto positionalArgs = this.getPositionalArgs();

        size_t positionalArgIndex = 0;
        bool breakOuterLoop = false;
        for(; !parser.empty && !breakOuterLoop; parser.popFront())
        {
            const token = parser.front();
            final switch(token.type) with(ArgTokenType)
            {
                case None: assert(false);
                case EOF: break;

                // Positional Argument
                case Text:
                    if(positionalArgIndex >= positionalArgs.length)
                    {
                        return typeof(return).failure(
                            "too many arguments starting at '%s'".format(token.value)
                        );
                    }

                    auto actionResult = positionalArgs[positionalArgIndex].argInfo.actionFunc(token.value, commandInstance);
                    positionalArgs[positionalArgIndex++].wasFound = true;

                    if(!actionResult.isSuccess)
                    {
                        return typeof(return).failure(
                            "positional argument %s ('%s'): %s"
                            .format(positionalArgIndex-1, positionalArgs[positionalArgIndex-1].argInfo.uda.name, actionResult.asFailure.error)
                        );
                    }
                    break;

                // Named Argument
                case LongHandArgument:
                    if(token.value == "-" || token.value == "") // --- || --
                    {
                        breakOuterLoop = true;                        
                        static if(!Info.rawListArg.isNull)
                            mixin("commandInstance.%s = parser.unparsedArgs;".format(Info.rawListArg.get.identifier));
                        break;
                    }
                    goto case;
                case ShortHandArgument:
                    const argIndex = namedArgs.countUntil!"a.argInfo.uda.pattern.matchSpaceless(b)"(token.value);
                    if(argIndex < 0)
                        return typeof(return).failure("unknown argument '%s'".format(token.value));

                    if(namedArgs[argIndex].wasFound && (namedArgs[argIndex].argInfo.existence & CommandArgExistence.multiple) == 0)
                        return typeof(return).failure("multiple definitions of argument '%s'".format(token.value));

                    namedArgs[argIndex].wasFound = true;
                    auto argParseResult = this.performParseScheme(parser, commandInstance, namedArgs[argIndex].argInfo);
                    if(!argParseResult.isSuccess)
                        return typeof(return).failure("named argument '%s': ".format(token.value)~argParseResult.asFailure.error);
                    break;
            }
        }

        auto validateResult = this.validateArgs(namedArgs, positionalArgs);
        return validateResult;
    }

    private Result!void performParseScheme(ref ArgPullParser parser, ref CommandT commandInstance, NamedArgumentInfo!CommandT argInfo)
    {
        final switch(argInfo.parseScheme) with(CommandArgParseScheme)
        {
            case default_: return this.parseDefault(parser, commandInstance, argInfo);
            case allowRepeatedName: return this.parseRepeatableName(parser, commandInstance, argInfo);
            case bool_: return this.parseBool(parser, commandInstance, argInfo);
        }
    }

    private Result!void parseBool(ref ArgPullParser parser, ref CommandT commandInstance, NamedArgumentInfo!CommandT argInfo)
    {
        // Bools have special support:
        //  If they are defined, they are assumed to be true, however:
        //      If the next token is Text, and its value is one of a predefined list, then it is then sent to the ArgBinder instead of defaulting to true.

        auto parserCopy = parser;
        parserCopy.popFront();

        if(parserCopy.empty
        || parserCopy.front.type != ArgTokenType.Text
        || !["true", "false"].canFind(parserCopy.front.value))
            return argInfo.actionFunc("true", /*ref*/ commandInstance);

        auto result = argInfo.actionFunc(parserCopy.front.value, /*ref*/ commandInstance);
        parser.popFront(); // Keep the main parser up to date.

        return result;
    }

    private Result!void parseDefault(ref ArgPullParser parser, ref CommandT commandInstance, NamedArgumentInfo!CommandT argInfo)
    {
        parser.popFront();

        if(parser.front.type == ArgTokenType.EOF)
            return typeof(return).failure("defined without a value.");
        else if(parser.front.type != ArgTokenType.Text)
            return typeof(return).failure("expected a value, not an argument name.");

        return argInfo.actionFunc(parser.front.value, /*ref*/ commandInstance);
    }

    private Result!void parseRepeatableName(ref ArgPullParser parser, ref CommandT commandInstance, NamedArgumentInfo!CommandT argInfo)
    {
        auto parserCopy  = parser;
        auto incrementBy = 1;
        
        // Support "-vvvvv" syntax.
        parserCopy.popFront();
        if(parser.front.type == ArgTokenType.ShortHandArgument 
        && parserCopy.front.type == ArgTokenType.Text
        && parserCopy.front.value.all!(c => c == parser.front.value[0]))
        {
            incrementBy += parserCopy.front.value.length;
            parser.popFront(); // keep main parser up to date.
        }

        // .actionFunc will perform an increment each call.
        foreach(i; 0..incrementBy)
            argInfo.actionFunc(null, /*ref*/ commandInstance);

        return Result!void.success();
    }

    private ArgRuntimeInfo!(NamedArgumentInfo!CommandT)[] getNamedArgs()
    {
        typeof(return) toReturn;

        foreach(arg; Info.namedArgs)
        {
            arg.uda.pattern.assertNoWhitespace();
            toReturn ~= this.argInfoOf(arg);
        }

        // TODO: Forbid arguments that have the same pattern and/or subpatterns.

        return toReturn;
    }

    private ArgRuntimeInfo!(PositionalArgumentInfo!CommandT)[] getPositionalArgs()
    {
        typeof(return) toReturn;

        foreach(arg; Info.positionalArgs)
            toReturn ~= this.argInfoOf(arg);

        toReturn.sort!"a.argInfo.uda.position < b.argInfo.uda.position"();
        foreach(i, arg; toReturn)
        {
            assert(
                arg.argInfo.uda.position == i, 
                "Expected positional argument %s to take up position %s, not %s."
                .format(toReturn[i].argInfo.uda.name, i, arg.argInfo.uda.position)
            );
        }

        // TODO: Make sure there are no optional args appearing before any mandatory ones.

        return toReturn;
    }
    
    private Result!void validateArgs(
        ArgRuntimeInfo!(NamedArgumentInfo!CommandT)[] namedArgs,
        ArgRuntimeInfo!(PositionalArgumentInfo!CommandT)[] positionalArgs
    )
    {
        import std.algorithm : filter, map;
        import std.format    : format;
        import std.exception : assumeUnique;

        char[] error;
        error.reserve(512);

        // Check for missing args.
        auto missingNamedArgs      = namedArgs.filter!(a => !a.isNullable && !a.wasFound);
        auto missingPositionalArgs = positionalArgs.filter!(a => !a.isNullable && !a.wasFound);
        if(!missingNamedArgs.empty)
        {
            foreach(arg; missingNamedArgs)
            {
                const name = arg.argInfo.uda.pattern.defaultPattern;
                error ~= (name.length == 1) ? "-" : "--";
                error ~= name;
                error ~= ", ";
            }
        }
        if(!missingPositionalArgs.empty)
        {
            foreach(arg; missingPositionalArgs)
            {
                error ~= "<";
                error ~= arg.argInfo.uda.name;
                error ~= ">, ";
            }
        }

        if(error.length > 0)
        {
            error = error[0..$-2]; // Skip extra ", "
            return Result!void.failure("missing required arguments " ~ error.assumeUnique);
        }

        return Result!void.success();
    }
}

version(unittest):

// For the most part, these are just some choice selections of tests from core.d that were moved over.

// NOTE: The only reason it can see and use private @Commands is because they're in the same module.
@Command("", "This is a test command")
private struct CommandTest
{
    // These are added to test that they are safely ignored.
    alias al = int;
    enum e = 2;
    struct S
    {
    }
    void f () {}

    @CommandNamedArg("a|avar", "A variable")
    int a;

    @CommandPositionalArg(0, "b")
    Nullable!string b;

    @CommandNamedArg("c")
    Nullable!bool c;
}
@("General test")
unittest
{
    auto command = CommandParser!CommandTest();
    auto instance = CommandTest();

    resultAssert(command.parse(["-a 20"], instance));
    assert(instance.a == 20);
    assert(instance.b.isNull);
    assert(instance.c.isNull);

    instance = CommandTest.init;
    resultAssert(command.parse(["20", "--avar 20"], instance));
    assert(instance.a == 20);
    assert(instance.b.get == "20");

    instance = CommandTest.init;
    resultAssert(command.parse(["-a 20", "-c"], instance));
    assert(instance.c.get);
}

@Command("booltest", "Bool test")
private struct BoolTestCommand
{
    @CommandNamedArg("a")
    bool definedNoValue;

    @CommandNamedArg("b")
    bool definedFalseValue;

    @CommandNamedArg("c")
    bool definedTrueValue;

    @CommandNamedArg("d")
    bool definedNoValueWithArg;

    @CommandPositionalArg(0)
    string comesAfterD;
}
@("Test that booleans are handled properly")
unittest
{
    auto command = CommandParser!BoolTestCommand();
    auto instance = BoolTestCommand();

    resultAssert(command.parse(["-a", "-b=false", "-c", "true", "-d", "Lalafell"], instance));
    assert(instance.definedNoValue);
    assert(!instance.definedFalseValue);
    assert(instance.definedTrueValue);
    assert(instance.definedNoValueWithArg);
    assert(instance.comesAfterD == "Lalafell");
}

@Command("rawListTest", "Test raw lists")
private struct RawListTestCommand
{
    @CommandNamedArg("a")
    bool dummyThicc;

    @CommandRawListArg
    string[] rawList;
}
@("Test that raw lists work")
unittest
{
    CommandParser!RawListTestCommand command;
    RawListTestCommand instance;

    resultAssert(command.parse(["-a", "--", "raw1", "raw2"], instance));
    assert(instance.rawList == ["raw1", "raw2"], "%s".format(instance.rawList));
}

@ArgValidator
private struct Expect(T)
{
    T value;

    Result!void onValidate(T boundValue)
    {
        import std.format : format;

        return this.value == boundValue
        ? Result!void.success()
        : Result!void.failure("Expected value to equal '%s', not '%s'.".format(this.value, boundValue));
    }
}

@Command("validationTest", "Test validation")
private struct ValidationTestCommand
{
    @CommandPositionalArg(0)
    @Expect!string("lol")
    string value;
}
@("Test ArgBinder validation integration")
unittest
{
    CommandParser!ValidationTestCommand command;
    ValidationTestCommand instance;

    resultAssert(command.parse(["lol"], instance));
    assert(instance.value == "lol");
    
    assert(!command.parse(["nan"], instance).isSuccess);
}

@Command("arg action count", "Test that the count arg action works")
private struct ArgActionCount
{
    @CommandNamedArg("c")
    @(CommandArgAction.count)
    int c;
}
@("Test that CommandArgAction.count works.")
unittest
{
    CommandParser!ArgActionCount command;

    void test(string[] args, int expectedCount)
    {
        ArgActionCount instance;
        resultAssert(command.parse(args, instance));
        assert(instance.c == expectedCount);
    }

    ArgActionCount instance;

    test([], 0);
    test(["-c"], 1);
    test(["-c", "-c"], 2);
    test(["-ccccc"], 5);
    assert(!command.parse(["-ccv"], instance).isSuccess); // -ccv -> [name '-c', positional 'cv']. -1 because too many positional args.
    test(["-c", "cccc"], 5); // Unfortunately this case also works because of limitations in ArgPullParser
}