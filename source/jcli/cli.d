module jcli.cli;

import jcli;
import jcli.introspect;

import std.algorithm;
import std.stdio : writefln, writeln;
import std.array;
import std.traits;
import std.meta;


int executeCommand(T)(ref scope T command)
{
    try
    {
        static if (is(typeof(command.onExecute()) : int))
        {
            return command.onExecute();
        }
        else
        {
            command.onExecute();
            return 0;
        }
    }
    catch (Exception exc)
    {
        // for now, just print it
        writeln(exc);
        return cast(int) ErrorCode.caughtException;
    }
}
unittest
{
    {
        static struct A
        {
            int onExecute() { return 1; }
        }
        auto a = A();
        assert(executeCommand(a) == 1);
    }
    {
        static struct A
        {
            static int onExecute() { return 1; }
        }
        auto a = A();
        assert(executeCommand(a) == 1);
    }
    {
        static struct A
        {
            void onExecute() {}
        }
        auto a = A();
        assert(executeCommand(a) == 0);
    }
}


struct MatchAndExecuteResult
{
    int exitCode;
    bool allExecuted;
}

enum MatchAndExecuteErrorCode
{
    theBit = 128,
    intermediateErrors = theBit | 1,
    firstTokenNotCommand = theBit | 2,
    unmatchedThing = theBit | 3,
    caughtException = theBit | 4,
    unmatchedCommandName = theBit | 5,
}
private alias ErrorCode = MatchAndExecuteErrorCode;

///
template matchAndExecuteAccrossModules(Modules...)
{
    alias bind = bindArgumentAcrossModules!Modules;
    alias Types = AllCommandsOf!Modules;
    alias matchAndExecuteAccrossModules = matchAndExecute!(bind, Types);
}

/// Constructs the graph of the given command types, ...
template matchAndExecute(alias bindArgument, CommandTypes...)
{
    private alias _matchAndExecute = .matchAndExecute!(bindArgument, CommandTypes);

    /// Forwards to `MatchAndExecuteTypeContext!Types.matchAndExecute`.
    MatchAndExecuteResult matchAndExecute
    (
        Tokenizer : ArgTokenizer!T, T,
        TErrorHandler
    )
    (
        scope ref Tokenizer tokenizer,
        scope ref TErrorHandler errorHandler
    )
    {
        return MatchAndExecuteTypeContext!(bindArgument, CommandTypes)
            .matchAndExecute(tokenizer, errorHandler);
    }

    /// Resolves the invoked command by parsing the arguments array,
    /// executes the `onExecute` method of any intermediary command groups,
    /// Returns the result of the execution, and whether there were errors.
    MatchAndExecuteResult matchAndExecute(scope string[] args)
    {
        auto tokenizer = argTokenizer(args);
        return _matchAndExecute(tokenizer);
    }
    
    /// ditto
    /// Uses the default error handler. 
    MatchAndExecuteResult matchAndExecute(Tokenizer : ArgTokenizer!T, T)
    (
        scope ref Tokenizer tokenizer
    )
    {
        auto handler = DefaultParseErrorHandler();
        return _matchAndExecute(tokenizer, handler);
    }
}

enum SpecialThings
{
    none = 0,
    help = 1
}

SpecialThings tryMatchSpecialThings(Tokenizer : ArgTokenizer!TRange, TRange)
(
    ref scope Tokenizer tokenizer
)
{
    alias Kind = ArgToken.Kind;
    const currentToken = tokenizer.front;

    outerSwitch: switch (currentToken.kind)
    {
        case Kind.fullNamedArgumentName:
        case Kind.shortNamedArgumentName:
        {
            switch (currentToken.nameSlice)
            {
                case "help":
                case "h":
                {
                    tokenizer.popFront();
                    
                    // TODO: handle this better
                    if (tokenizer.front.kind == Kind.namedArgumentValue)
                    {
                        writeln("Please, do not give `help` a value.");
                        tokenizer.popFront();
                    }

                    return SpecialThings.help;
                }
                default:
                    break outerSwitch;
            }
        }

        case Kind.orphanArgument:
        case Kind.positionalArgument:
        {
            switch (currentToken.nameSlice)
            {
                case "/?":
                case "/help":
                case "/h":
                {
                    tokenizer.popFront();
                    return SpecialThings.help;
                }
                default:
                    break outerSwitch;
            }
        }

        default:
            break;
    }

    return SpecialThings.none;
}


// TODO: better name
template MatchAndExecuteTypeContext(alias bindArgument, Types...)
{
    alias Graph = TypeGraph!Types;
    enum maxNamedArgCount = 
    (){
        size_t result = 0;
        static foreach (Type; Types)
        {
            import std.algorithm.comparison : max;
            result = max(result, CommandInfo!Type.Arguments.named.length);
        }
        return result;
    }();
    alias ParsingContext = CommandParsingContext!maxNamedArgCount;
    alias Result = MatchAndExecuteResult;

    ///
    Result matchAndExecute
    (
        Tokenizer : ArgTokenizer!TRange, TRange,
        TErrorHandler,
    )
    (
        scope ref Tokenizer tokenizer,
        scope ref TErrorHandler errorHandler
    )
    {
        ArgToken firstToken = tokenizer.front;
        if (firstToken.kind.doesNotHave(ArgToken.Kind.valueBit))
            return Result(cast(int) ErrorCode.firstTokenNotCommand, false);
        tokenizer.popFront();

        ParsingContext parsingContext;

        switch (firstToken.nameSlice)
        {
            static foreach (RootType; Graph.RootTypes)
            {
                static foreach (possibleName; CommandInfo!RootType.general.uda.pattern)
                {
                    case possibleName:
                }
                {
                    auto command = RootType();
                    resetNamedArgumentArrayStorage!RootType(parsingContext);

                    // This has executed all commands, inlcuding this one, recursively
                    // Maybe print the rest of the arguments, might be helpful idk.
                    return matchNextTokenLoopAndExecute(
                        parsingContext, tokenizer, command, errorHandler);
                }
            }
            default:
            {
                return Result(cast(int) ErrorCode.unmatchedCommandName, false);
            }
        }
    }

    ///
    Result matchNextTokenLoopAndExecute
    (
        CurrentCommandType,
        Tokenizer : ArgTokenizer!TRange, TRange,
        TErrorHandler
    )
    (
        ref scope ParsingContext parsingContext,
        ref scope Tokenizer tokenizer,
        ref scope CurrentCommandType command,
        ref scope TErrorHandler errorHandler
    )
    {
        alias CommandInfo = jcli.introspect.CommandInfo!CurrentCommandType;
        alias ArgumentInfo = CommandInfo.Arguments;

        auto consumeSingle()
        { 
            return consumeSingleArgumentIntoCommand!bindArgument(
                parsingContext, command, tokenizer, errorHandler);
        }
        
        // Matched the given command.
        while (!tokenizer.empty)
        {
            final switch (tryMatchSpecialThings(tokenizer))
            {
                case SpecialThings.help:
                {
                    writeln("Help message goes here?");
                    continue;
                }

                case SpecialThings.none:
                {
                    break;
                }
            }

            const currentToken = tokenizer.front;

            if (currentToken.kind.has(ArgToken.Kind.valueBit) 
                && currentToken.kind.hasEither(
                    ArgToken.Kind.positionalArgumentBit | ArgToken.Kind.orphanArgumentBit))
            {
                // 3 posibilities
                // 1. Not all required positional arguments have been read, in which case we read that.
                // 2. All required positional arguments have been read, but there are still optional ones,
                //    in which case we try to match command first before reading on.
                // 3. All possibile positional args have been read, so just match the name.
                if (parsingContext.currentPositionalArgIndex < ArgumentInfo.numRequiredPositionalArguments)
                {
                    const _ = consumeSingle();
                }
                else if (parsingContext.currentPositionalArgIndex < ArgumentInfo.positional.length)
                {
                    {
                        auto r = tryExecuteRecursively(parsingContext, tokenizer, command, errorHandler);
                        if (r.matched)
                            return r.result;
                    }

                    const _ = consumeSingle();
                }
                else
                {
                    auto r = tryExecuteRecursively(parsingContext, tokenizer, command, errorHandler);
                    if (r.matched)
                        return r.result;

                    // There is an extra unmatched argument thing.
                    writeln("Unmatched thing ", tokenizer.front.fullSlice, ", not implemented fully.");
                    return Result(cast(int) ErrorCode.unmatchedThing, false);
                }
            }
            else
            {
                const _ = consumeSingle();
            }
        }

        maybeReportParseErrorsFromFinalContext!ArgumentInfo(parsingContext, errorHandler);

        // In essence, we're the leaf node here, so we have to execute ourselves.
        if (parsingContext.errorCounter == 0)
        {
            const r = executeCommand(command);
            return Result(r, true);
        }

        return Result(cast(int) ErrorCode.intermediateErrors, false);
    }

    struct TryResult
    {
        Result result;
        bool matched;
    }

    ///
    TryResult tryExecuteRecursively
    (
        ParentCommandType,
        Tokenizer : ArgTokenizer!TRange, TRange,
        TErrorHandler
    )
    (
        ref scope ParsingContext parsingContext,
        ref scope Tokenizer tokenizer,
        ref scope ParentCommandType parentCommand,
        ref scope TErrorHandler errorHandler
    )
    {
        alias ArgumentsInfo = CommandInfo!ParentCommandType.Arguments;

        // Returns 0 if should continue doing stuff.
        int prepareToExecute()
        {
            tokenizer.popFront();
            
            maybeReportParseErrorsFromFinalContext!ArgumentsInfo(parsingContext, errorHandler);
            if (parsingContext.errorCounter > 0)
            {
                // TODO: 
                // report that a subcommand was matched, but the previous command
                // was not initilialized correctly.
                return cast(int) ErrorCode.intermediateErrors;
            }

            {
                int exitCode = executeCommand(parentCommand);
                if (exitCode != 0)
                    return exitCode;
            }

            resetNamedArgumentArrayStorage!ArgumentsInfo(parsingContext);
            return 0;
        }

        switch (tokenizer.front.nameSlice)
        {
            static foreach (childField; Graph.getChildCommandFieldsOf!ParentCommandType)
            {{
                alias Type = __traits(parent, childField);

                static foreach (possibleName; CommandInfo!Type.general.uda.pattern)
                {
                    case possibleName:
                }
                {                    
                    {
                        int r = prepareToExecute();
                        if (r != 0)
                        {
                            const match = true;
                            const allExecuted = false;
                            return TryResult(Result(r, allExecuted), match);
                        }
                    }
                    
                    auto command = Type();
                    // This method probably cannot work with dll's.
                    // With dll's we need a more dynamic approach.
                    __traits(child, command, childField) = &parentCommand;

                    return TryResult(
                        matchNextTokenLoopAndExecute(
                            parsingContext, tokenizer, command, errorHandler),
                        true);
                }
            }}
            default:
            {
                TryResult returnValue;
                returnValue.matched = false;
                return returnValue;
            }
        }
    }
}
unittest
{
    alias bindArgument = jcli.argbinder.bindArgument!();
    auto exec(Types...)(scope string[] args)
    {
        return matchAndExecute!(bindArgument, Types)(args);
    }

    {
        @Command
        static struct A
        {
            int onExecute()
            {
                return 1;
            }
        }

        static assert(CommandInfo!A.general.uda.pattern[0] == "A");

        alias Types = AliasSeq!A;
        {
            auto result = exec!Types([]);
            assert(!result.allExecuted);
            assert(result.exitCode == cast(int) ErrorCode.firstTokenNotCommand);
        }
        {
            auto result = exec!Types(["A"]);
            assert(result.allExecuted);
            assert(result.exitCode == 1);
        }
    }
    {
        @Command("other")
        static struct A
        {
            int onExecute()
            {
                return 1;
            }
        }

        alias Types = AliasSeq!A;
        auto result = exec!Types(["other"]);
        assert(result.allExecuted);
        assert(result.exitCode == 1);
    }

    // With a parent
    {
        @Command
        static struct A
        {
            int onExecute()
            {
                return 0;
            }
        }
        
        @Command
        static struct B
        {
            @ParentCommand
            A* a;

            int onExecute()
            {
                return 1;
            }
        }

        alias Types = AliasSeq!(A, B);
        alias exec0 = exec!Types;
        {
            auto result = exec0(["A"]);
            assert(result.allExecuted);
            assert(result.exitCode == 0);
        }
        {
            auto result = exec0(["A", "B"]);
            assert(result.allExecuted);
            assert(result.exitCode == 1);
        }
    }
}
unittest
{
    alias bindArgument = jcli.argbinder.bindArgument!();
    // Parent with intermediate arguments
    {
        @Command
        static struct A
        {
            @ArgPositional
            string p;

            static int onExecute()
            {
                return 0;
            }
        }
        
        @Command
        static struct B
        {
            // The pointer things as is are weird.
            // We should split up the execution functions.
            // It would return intermediate matched objects.
            // You could then put them in a Variant array
            // (or like in an array where the elements have a fixed max size),
            // and call the actual function via an adapter that would cast and call.
            @ParentCommand
            A* a;


            static int onExecute()
            {
                return 1;
            }
        }

        import std.algorithm;

        alias Types = AliasSeq!(A, B);
        auto errorHandler = createErrorCodeHandler();
        auto exec0(scope string[] args)
        {
            auto tokenizer = argTokenizer(args);
            return matchAndExecute!(bindArgument, Types)(tokenizer, errorHandler);
        }

        {
            auto result = exec0(["A"]);
            assert(!result.allExecuted);
            assert(result.exitCode == ErrorCode.intermediateErrors);
            assert(errorHandler.hasError(CommandParsingErrorCode.tooFewPositionalArgumentsError));
        }
        {
            // The sad thing is that it does not return the executed command rn.
            auto result = exec0(["A", "B"]);
            assert(result.allExecuted);
            assert(result.exitCode == 0);
        }
        {
            auto result = exec0(["A", "1", "B"]);
            assert(result.allExecuted);
            assert(result.exitCode == 1);
        }
    }
}


// Needs a complete rework.
final class CommandLineInterface(Modules...)
{
    alias Tokenizer     = ArgTokenizer!(string[]);
    alias bindArgument  = bindArgumentAcrossModules!Modules;

    private alias CommandExecute = int delegate(Tokenizer);
    private alias CommandHelp    = string delegate();

    private struct CommandInfo
    {
        CommandExecute onExecute;
        CommandHelp onHelp;
        Pattern pattern;
        string description;
    }

    private
    {
        Resolver!CommandInfo _resolver;
        CommandInfo[] _uniqueCommands;
        CommandInfo _default;
        string _appName;
    }

    this()
    {
        this._resolver = new typeof(_resolver)();
        static foreach(mod; Modules)
            this.findCommands!mod;

        import std.file : thisExePath;
        import std.path : baseName;
        this._appName = thisExePath().baseName;
    }

    int parseAndExecute(string[] args, bool ignoreFirstArg = true)
    {
        return this.parseAndExecute(argTokenizer(ignoreFirstArg ? args[1..$] : args));
    }

    int parseAndExecute(Tokenizer tokenizer)
    {
        auto tokenizerCopy = tokenizer;
        if(tokenizer.empty)
            tokenizer = argTokenizer(["-h"]);

        string[] args;
        auto command = this.resolveCommand(tokenizer);
        args = tokenizer.map!(token => token.fullSlice).array;
        if(command.kind == command.Kind.partial || command == typeof(command).init)
        {
            if(this._default == CommandInfo.init)
            {
                HelpText help = HelpText.make(Console.screenSize.x);
                
                if(tokenizerCopy.empty || tokenizerCopy == argTokenizer(["-h"]))
                    help.addHeader("Available commands:");
                else
                {
                    help.addLineWithPrefix(this._appName~": ", "Unknown command", AnsiStyleSet.init.fg(Ansi4BitColour.red));
                    help.addLine(null);
                    help.addHeader("Did you mean:");
                }
                // foreach(comm; this._uniqueCommands)
                //     help.addArgument(comm.name, [HelpTextDescription(0, comm.description)]);
                writeln(help.finish());
                return -1;
            }
            else
            {
                if(this.hasHelpArgument(tokenizer) && !tokenizerCopy.empty)
                {
                    writeln(this._default.onHelp());
                    return 0;
                }

                try return this._default.onExecute(tokenizerCopy);
                catch(ResultException ex)
                {
                    writefln("%s: %s", this._appName.ansi.fg(Ansi4BitColour.red), ex.msg);
                    debug writeln("[debug-only] JCLI has displayed this exception in full for your convenience.");
                    debug writeln(ex);
                    return ex.errorCode;
                }
                catch(Exception ex)
                {
                    writefln("%s: %s", this._appName.ansi.fg(Ansi4BitColour.red), ex.msg);
                    debug writeln("[debug-only] JCLI has displayed this exception in full for your convenience.");
                    debug writeln(ex);
                    return -1;
                }
            }
        }

        if(this.hasHelpArgument(tokenizer))
        {
            writeln(command.fullMatchChain[$-1].userData.onHelp());
            return 0;
        }
        else if(args.length && args[$-1] == "--__jcli:complete")
        {
            args = args[0..$-1];

            if(command.valueProvider)
                writeln(command.valueProvider(args));
            else
                writeln("Command does not contain a value provider.");
            return 0;
        }

        try return command.fullMatchChain[$-1].userData.onExecute(tokenizer);
        catch(ResultException ex)
        {
            writefln("%s: %s", this._appName.ansi.fg(Ansi4BitColour.red), ex.msg);
            debug writeln("[debug-only] JCLI has displayed this exception in full for your convenience.");
            debug writeln(ex);
            return ex.errorCode;
        }
        catch(Exception ex)
        {
            writefln("%s: %s", this._appName.ansi.fg(Ansi4BitColour.red), ex.msg);
            debug writeln("[debug-only] JCLI has displayed this exception in full for your convenience.");
            debug writeln(ex);
            return -1;
        }
    }
    
    ResolveResult!CommandInfo resolveCommand(ref Tokenizer tokenizer)
    {
        // NOTE: Could just return a tuple if we should always allocate, like this:
        // static struct Result
        // {
        //     string[] args;
        //     ResolveResult!CommandInfo info;
        // }
        // Or even return the arguments as a range.
        // The user can do .array themselves.

        typeof(return) lastPartial;
        string[] command;

        while (true)
        {
            if (tokenizer.empty)
                return lastPartial;
            if (!(tokenizer.front.kind & ArgToken.Kind.valueBit))
                return lastPartial;

            command ~= tokenizer.front.fullSlice;
            auto result = this._resolver.resolve(command);

            if(result.kind == result.Kind.partial)
                lastPartial = result;
            else
            {
                tokenizer.popFront();
                return result;
            }

            tokenizer.popFront();
        }
    }

    private bool hasHelpArgument(Tokenizer parser)
    {
        return parser
                .filter!(r => r.kind & ArgToken.Kind.argumentNameBit)
                .any!(r => r.nameSlice == "h" || r.nameSlice == "help");
    }

    private void findCommands(alias Module)()
    {
        static foreach(member; __traits(allMembers, Module))
        {{
            alias Symbol = __traits(getMember, Module, member);
            
            import std.traits : hasUDA;
            static if(hasUDA!(Symbol, Command) || hasUDA!(Symbol, CommandDefault))
                this.getCommand!Symbol;
        }}
    }

    // TODO: this is already implemented in the introspect, needs rework
    private void getCommand(alias CommandT)()
    {
        CommandInfo info;
        info.onHelp = getOnHelp!CommandT();
        info.onExecute = getOnExecute!CommandT();

        import std.traits : getUDAs, hasUDA;
        static if(hasUDA!(CommandT, Command))
        {
            info.pattern = getUDAs!(CommandT, Command)[0].pattern;
            info.description = getUDAs!(CommandT, Command)[0].description;
            foreach(pattern; info.pattern)
                this._resolver.add(
                    pattern.splitter(' ').array, 
                    info, 
                    &(AutoComplete!CommandT()).complete
                );
            this._uniqueCommands ~= info;
        }
        else
            this._default = info;
    }

    private CommandExecute getOnExecute(alias CommandT)()
    {
        return (Tokenizer parser) 
        {
            scope auto dummy = DefaultParseErrorHandler();
            auto result = parseCommand!(CommandT, bindArgument)(parser, dummy);

            if(!result.isOk) // Error is already printed
                return -1;

            static if(is(typeof(result.value.onExecute()) == int))
            {
                return result.value.onExecute();
            }
            else
            {
                result.value.onExecute();
                return 0;
            }
        };
    }

    private CommandHelp getOnHelp(alias CommandT)()
    {
        return ()
        {
            return CommandHelpText!CommandT().generate();
        };
    }
}

version(unittest):
@Command("assert even|ae|a e", "Asserts that the given number is even.")
private struct AssertEvenCommand
{
    @ArgPositional("number", "The number to assert.")
    int number;

    @ArgNamed("reverse|r", "If specified, then assert that the number is ODD instead.")
    @(ArgConfig.parseAsFlag)
    Nullable!bool reverse;

    int onExecute()
    {
        auto passedAssert = (this.reverse.get(false))
                            ? this.number % 2 == 1
                            : this.number % 2 == 0;

        return (passedAssert) ? 0 : 128;
    }
}

@Command("echo")
private struct EchoCommand
{
    @ArgOverflow
    string[] overflow;

    int onExecute()
    {
        foreach(value; overflow)
            writeln(value);
        return 69;
    }
}

unittest
{
    auto cli = new CommandLineInterface!(jcli.cli);

    {
        auto p = argTokenizer(["a"]);
        const r = cli.resolveCommand(p);
        assert(r.kind == r.Kind.partial);
        assert(r.fullMatchChain.length == 1);
        assert(r.fullMatchChain[0].fullMatchString == "a");
        assert(r.partialMatches.length == 2);
        assert(r.partialMatches[0].fullMatchString == "assert");
        assert(r.partialMatches[1].fullMatchString == "ae");
    }

    foreach(args; [["ae", "2"], ["assert", "even", "2"], ["a", "e", "2"]])
    {
        import std.conv : to;

        auto p = argTokenizer(args);
        const r = cli.resolveCommand(p);
        assert(r.kind == r.Kind.full);
        assert(r.fullMatchChain.length + 1 == args.length);
        assert(r.fullMatchChain.map!(fm => fm.fullMatchString).equal(args[0..$-1]));
        assert(p.front.fullSlice == "2", p.to!string);
        assert(r.fullMatchChain[$-1].userData.onExecute(p) == 0);
    }

    foreach(args; [["ae", "1", "--reverse"], ["a", "e", "-r", "1"]])
    {
        auto p = argTokenizer(args);
        const r = cli.resolveCommand(p);
        assert(r.kind == r.Kind.full);
        assert(r.fullMatchChain[$-1].userData.onExecute(p) == 0);
    }

    {
        assert(cli.parseAndExecute(["assert", "even", "2"], false) == 0);
        assert(cli.parseAndExecute(["assert", "even", "1", "-r"], false) == 0);
        assert(cli.parseAndExecute(["assert", "even", "2", "-r"], false) == 128);
        assert(cli.parseAndExecute(["assert", "even", "1"], false) == 128);
    }

    // Commented out to stop it from writing output.
    // assert(cli.parseAndExecute(["assrt", "evn", "20"], false) == 69);
}