module jcli.cli;

import jcli;

import std.stdio : writefln, writeln;

struct ExecuteCommandResult
{
    int exitCode;
    /// is null if no exception occured
    Exception exception;
}

ExecuteCommandResult executeCommand(T)(auto ref scope T command)
{
    try
    {
        static if (is(typeof(command.onExecute()) : int))
        {
            return typeof(return)(command.onExecute(), null);
        }
        else
        {
            command.onExecute();
            return typeof(return)(0, null);
        }
    }
    catch (Exception exc)
    {
        return typeof(return)(0, exc);
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
        auto result = executeCommand(a);
        assert(result.exitCode == 1);
        assert(result.exception is null);
    }
    {
        static struct A
        {
            static int onExecute() { return 1; }
        }
        auto a = A();
        auto result = executeCommand(a);
        assert(result.exitCode == 1);
        assert(result.exception is null);
    }
    {
        static struct A
        {
            void onExecute() {}
        }
        auto a = A();
        auto result = executeCommand(a);
        assert(result.exitCode == 0);
        assert(result.exception is null);
    }
    {
        static struct A
        {
            void onExecute() { throw new Exception("Hello"); }
        }
        auto a = A();
        auto result = executeCommand(a);
        assert(result.exception !is null);
    }
}

enum MatchAndExecuteState
{
    /// The initial state.
    initial = 0,

    /// ArgToken.Kind the error_ things.
    tokenizerError, 
    
    /// ?, ConsumeSingleArgumentResultKind.
    commandParsingError,
    
    /// transitions: -- parse & match -->matched|beforeFinalExecution|unmatched
    matchedRootCommand, 

    /// It's matched the next command by name.
    /// transitions: -- executePrevious -->intermediateExecutionResult
    matchedNextCommand, 

    /// When it does onExecute on parent command.
    /// transitions: -> matched|beforeFinalExecution|unmatched
    intermediateExecutionResult,

    /// Means it's consumed all of the arguments it can or should
    /// and right now it's a the point where it would execute the last thing.
    /// transitions: -> finalExecutionResult
    beforeFinalExecution,

    /// If this bit is set, any state after it will give invalid.
    terminalStateBit = 16,
    
    /// MatchAndExecuteErrorCode
    firstTokenNotCommand = terminalStateBit | 0,

    /// Misuse of the API.
    invalid = terminalStateBit | 1,

    /// Aka help SpecialThings.
    /// `help`: 
    /// May come up at any point. It means the current command asked for a help message.
    /// The help may be asked for at the top level, before any command has been matched.
    /// In that case, the command index will be -1.
    specialThing = terminalStateBit | 2, 


    /// It's not matched the next command, and there are extra unused arguments.
    /// notMatchedNextCommand -> doneWithoutExecuting|specialThing
    notMatchedNextCommand = terminalStateBit | 3,

    ///
    notMatchedRootCommand = terminalStateBit | 4,

    /// Happens in case a command was not matched, and no special thing
    /// was found after that.
    ///  transitions: -> invalid
    doneWithoutExecuting = terminalStateBit | 5,
    
    /// It's executed a terminal command (the tokenizer was empty).
    ///  transitions: -> invalid
    finalExecutionResult = terminalStateBit | 6,
}

private alias State = MatchAndExecuteState;

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
    MatchAndExecuteContext matchAndExecute
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
    MatchAndExecuteContext matchAndExecute(scope string[] args)
    {
        auto tokenizer = argTokenizer(args);
        return _matchAndExecute(tokenizer);
    }
    
    /// ditto
    /// Uses the default error handler. 
    MatchAndExecuteContext matchAndExecute(Tokenizer : ArgTokenizer!T, T)
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
                    // if (tokenizer.front.kind == Kind.namedArgumentValue)
                    // {
                    //     writeln("Please, do not give `help` a value.");
                    //     tokenizer.popFront();
                    // }

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

struct MatchAndExecuteContext
{
    State _state;

    union
    {
        ArgToken.Kind _tokenizerError;
        ConsumeSingleArgumentResultKind _commandParsingErrorKind;
        SpecialThings _specialThing;

        ExecuteCommandResult _executeCommandResult;

        string _matchedName;
        string _notMatchedName;
    }

    // TODO: maybe store them inline
    // TODO: calculate the max path length in the graph and set that as max size.
    struct StorageItem
    {
        int typeIndex;
        void* commandPointer;
    }
    StorageItem[] _storage;

    // void* latestCommand()
    // {
    //     assert(_currentCommandTypeGraphNode != -1);
    //     return _storage[$ - 1];
    // }


    const pure @safe nothrow @nogc:

    State state() { return _state; }
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
    alias Context = MatchAndExecuteContext;

    // These should be public to allow other modules to work with the context.
    // But we should also think about doing a typesafe wrapper over the context.
    auto addCommand(int typeIndex)(scope ref Context context)
    {
        alias Type = Types[typeIndex];
        // TODO: maybe add something fancier here later 
        auto t = new Type();
        context._storage ~= Context.StorageItem(typeIndex, cast(void*) t);
        return t;
    }

    auto getLatestCommand(int typeIndex)(scope ref Context context)
    {
        assert(context._storage.length > 0);
        return getCommand!typeIndex(context, cast(int) context._storage.length - 1);
    }

    auto getCommand(int typeIndex)(scope ref Context context, int index)
    {
        assert(context._storage.length > index);
        assert(typeIndex == context._storage[index].typeIndex);
        alias Type = Types[typeIndex];
        return cast(Type*) context._storage[index].commandPointer;
    }

    // Frame issues make us do the mixins.
    private string get_tryExecuteHandlerWithCompileTimeCommandIndexGivenRuntimeCommandIndex_MixinString(
        string variableName, string funcName, string currentTypeIndexName, int a = __LINE__)
    {
        import std.conv : to;
        string labelName = `__stuff` ~ a.to!string;

        return labelName ~ `: switch (` ~ currentTypeIndexName ~ `)
        {
            static foreach (_typeIndex, CurrentType; Types)
            {
                case cast(int) _typeIndex:
                {
                    ` ~ funcName ~ `!(cast(int) _typeIndex)();
                    ` ~ variableName ~ ` = true;
                    break ` ~ labelName ~ `;
                }
            }
            default:
            {
                ` ~ variableName ~ ` = false;
                break `  ~ labelName ~ `;
            }
        }`;
    }

    // private bool tryExecuteHandlerWithCompileTimeCommandIndexGivenRuntimeCommandIndex(alias templatedFunc)(int currentTypeIndex)
    // {
    //     switch (currentTypeIndex)
    //     {
    //         static foreach (typeIndex, CurrentType; Types)
    //         {
    //             case cast(int) typeIndex:
    //             {
    //                 templatedFunc!(cast(int) typeIndex)();
    //                 return true;
    //             }
    //         }
    //         default:
    //             return false;
    //     }
    // }

    ///
    void advanceState
    (
        Tokenizer : ArgTokenizer!TRange, TRange,
        TErrorHandler
    )
    (
        scope ref Context context,
        scope ref ParsingContext parsingContext,
        scope ref Tokenizer tokenizer,
        scope ref TErrorHandler errorHandler
    )
    {
        if (context._state & State.terminalStateBit)
        {
            context._state = State.invalid;
            return;
        }

        bool tryMatchSpecialThingsAndResetContextAccordingly()
        {
            final switch (tryMatchSpecialThings(tokenizer))
            {
                case SpecialThings.help:
                {
                    context._specialThing = SpecialThings.help;
                    context._state = State.specialThing;
                    return true;
                }

                case SpecialThings.none:
                {
                    break;
                }
            }
            return false;
        }

        switch (context._state)
        {
            default:
                assert(0);

            case State.initial:
            {
                if (tryMatchSpecialThingsAndResetContextAccordingly())
                    return;

                ArgToken firstToken = tokenizer.front;
                if (firstToken.kind.doesNotHave(ArgToken.Kind.valueBit))
                {
                    context._state = State.firstTokenNotCommand;
                    return;
                }
                tokenizer.popFront();

                switch (firstToken.nameSlice)
                {
                    default:
                    {
                        // writeln("not matched input ", firstToken.nameSlice,
                        //     " the number of possible things is ", Graph.rootTypeIndices.length);
                        context._state = State.notMatchedRootCommand;
                        return;
                    }
                    static foreach (rootTypeIndex; Graph.rootTypeIndices)
                    {{
                        alias Type = Types[rootTypeIndex];

                        void doStuff()
                        {
                            addCommand!(cast(int) rootTypeIndex)(context);
                            context._state = State.matchedRootCommand;
                            resetNamedArgumentArrayStorage!Type(parsingContext);
                        }

                        static foreach (possibleName; CommandInfo!Type.general.uda.pattern)
                        {
                            case possibleName:
                            {
                                doStuff();
                                context._matchedName = possibleName;
                                return;
                            }
                        }
                    }}
                }
            }

            // Already added, executed, and set up the command, just initialize the latest command.
            case State.matchedRootCommand:
            case State.intermediateExecutionResult:
            {
                void fillLatestCommand(size_t typeIndex)()
                {
                    alias Type = Types[typeIndex];
                    alias CommandInfo = jcli.introspect.CommandInfo!Type;
                    alias ArgumentInfo = CommandInfo.Arguments;

                    Type* command = getLatestCommand!typeIndex(context);

                    bool maybeMatchNextCommandNameAndResetState(string nameSlice)
                    {
                        bool didMatchCommand;

                        // This one HAS to stay inlined. Otherwise you get frame issues.
                        // See the older code: https://github.com/BradleyChatha/jcli/blob/511a02fe8dcd2913333f463ab5ad60d56fdb7f89/source/jcli/cli.d#L371-L430
                        // TODO: Add better match logic here.
                        matchSwitch: switch (nameSlice)
                        {
                            default:
                            {
                                didMatchCommand = false;
                                break matchSwitch;
                            }
                            static foreach (childNodeIndex, childNode; Graph.Nodes[typeIndex])
                            {{
                                alias Type = Types[childNode.childIndex];
                                static foreach (possibleName; jcli.introspect.CommandInfo!Type.general.uda.pattern)
                                {
                                    case possibleName:
                                    {
                                        auto newCommand = addCommand!(childNode.childIndex)(context);
                                        
                                        static if (childNode.fieldIndex != -1)
                                            newCommand.tupleof[childNode.fieldIndex] = command;
                                        
                                        context._matchedName = possibleName;
                                        didMatchCommand = true;
                                        break matchSwitch;
                                    }
                                }
                                
                            }}
                        }

                        if (didMatchCommand)
                        {
                            maybeReportParseErrorsFromFinalContext!ArgumentInfo(parsingContext, errorHandler);
                            resetNamedArgumentArrayStorage!Type(parsingContext);
                            tokenizer.resetWithRemainingRange();
                            context._state = State.matchedNextCommand;
                        }

                        return didMatchCommand;
                    }
                    
                    // Matched the given command.
                    while (!tokenizer.empty)
                    {
                        if (tryMatchSpecialThingsAndResetContextAccordingly())
                            return;

                        const currentToken = tokenizer.front;

                        // Should be handled via the error handler.
                        // if (currentToken.kind.has(ArgToken.Kind.errorBit))
                        // {
                        //     context._state = State.tokenizerError;
                        //     return;
                        // }
                        auto consumeSingle()
                        { 
                            return consumeSingleArgumentIntoCommand!bindArgument(
                                parsingContext, *command, tokenizer, errorHandler);
                        }

                        if (currentToken.kind.has(ArgToken.Kind.errorBit))
                        {
                            // TODO: error handler integration not sure yet??
                            context._state = State.tokenizerError;
                            // context._tokenizerError = currentToken.kind;
                            return;
                        }

                        else if (currentToken.kind.has(ArgToken.Kind.valueBit) 
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
                            else if (parsingContext.currentPositionalArgIndex < ArgumentInfo.positional.length
                                || ArgumentInfo.takesOverflow)
                            {
                                // match, add
                                if (maybeMatchNextCommandNameAndResetState(currentToken.nameSlice))
                                {
                                    tokenizer.popFront();
                                    return;
                                }
                                const _ = consumeSingle();
                            }
                            else
                            {
                                // match, add
                                if (!maybeMatchNextCommandNameAndResetState(currentToken.nameSlice))
                                {
                                    context._state = State.notMatchedNextCommand;
                                    context._notMatchedName = currentToken.nameSlice;
                                }
                                tokenizer.popFront();
                                return;
                            }
                        }
                        else
                        {
                            const _ = consumeSingle();
                        }
                    }

                    maybeReportParseErrorsFromFinalContext!ArgumentInfo(parsingContext, errorHandler);

                    if (parsingContext.errorCounter > 0)
                    {
                        context._state = State.commandParsingError;
                        // context._commandParsingErrorKind =
                        return;
                    }

                    context._state = State.beforeFinalExecution;
                }

                bool matched;
                enum mixinString = get_tryExecuteHandlerWithCompileTimeCommandIndexGivenRuntimeCommandIndex_MixinString(
                    "matched", "fillLatestCommand", "context._storage[$ - 1].typeIndex");
                mixin(mixinString);

                // monkyyy's frame issues at play.
                // bool matched = tryExecuteHandlerWithCompileTimeCommandIndexGivenRuntimeCommandIndex!fillLatestCommand(
                //     context._currentCommandTypeIndex);

                assert(matched);
                return;
            }

            // Already added the command, but haven't executed the previous one 
            // or reset the context for the latest one.
            case State.matchedNextCommand:
            {
                void executeNextToLast(size_t typeIndex)()
                {
                    alias Type = Types[typeIndex];
                    auto command = getCommand!typeIndex(context, cast(int) context._storage.length - 2);
                    auto result = executeCommand(*command);
                    context._state = State.intermediateExecutionResult;
                    context._executeCommandResult = result;
                }

                bool didHandlerExecute;
                enum mixinString = get_tryExecuteHandlerWithCompileTimeCommandIndexGivenRuntimeCommandIndex_MixinString(
                    "didHandlerExecute", "executeNextToLast", "context._storage[$ - 2].typeIndex");
                mixin(mixinString);

                assert(didHandlerExecute);
                return;
            }

            case State.beforeFinalExecution:
            {
                void executeLast(size_t typeIndex)()
                {
                    auto command = getCommand!typeIndex(context, cast(int) context._storage.length - 1);
                    auto result = executeCommand(*command);
                    context._state = State.finalExecutionResult;
                    context._executeCommandResult = result;
                }
                
                bool didHandlerExecute;
                enum mixinString = get_tryExecuteHandlerWithCompileTimeCommandIndexGivenRuntimeCommandIndex_MixinString(
                    "didHandlerExecute", "executeLast", "context._storage[$ - 1].typeIndex");
                mixin(mixinString);

                // bool didHandlerExecute = tryExecuteHandlerWithCompileTimeCommandIndexGivenRuntimeCommandIndex!executeLast(
                //     context._currentCommandTypeIndex);
                // assert(didHandlerExecute);

                assert(didHandlerExecute);

                return;
            }
        }
    }

    ///
    Context matchAndExecute
    (
        Tokenizer : ArgTokenizer!TRange, TRange,
        TErrorHandler,
    )
    (
        scope ref Tokenizer tokenizer,
        scope ref TErrorHandler errorHandler
    )
    {
        ParsingContext parsingContext;
        Context context;

        while (!(context._state & State.terminalStateBit))
        {
            advanceState(context, parsingContext, tokenizer, errorHandler);
        }
        return context;
    }
}

struct SimpleMatchAndExecuteHelper(Types...)
{
    alias bindArgument = jcli.argbinder.bindArgument!();
    alias TypeContext = MatchAndExecuteTypeContext!(bindArgument, Types);

    MatchAndExecuteContext context;
    TypeContext.ParsingContext parsingContext;
    ArgTokenizer!(string[]) tokenizer;
    ErrorCodeHandler errorHandler;


    this(string[] args)
    {
        tokenizer = argTokenizer(args);
        parsingContext = TypeContext.ParsingContext();
        context = MatchAndExecuteContext();
        errorHandler = createErrorCodeHandler();
    }

    void advance()
    {
        TypeContext.advanceState(context, parsingContext, tokenizer, errorHandler);
    }
}

unittest
{
    import std.meta;

    auto createHelperThing(Types...)(string[] args)
    {
        return SimpleMatchAndExecuteHelper!Types(args);
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

        alias Types = AliasSeq!A;
        alias createHelper = createHelperThing!Types;

        with (createHelper([]))
        {
            assert(context.state == State.initial);
            advance();
            assert(context.state == State.firstTokenNotCommand);
        }
        with (createHelper(["A"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._matchedName == "A");
            assert(context._storage.length == 1);
            // The position of A within Types.
            assert(context._storage[$ - 1].typeIndex == 0);

            advance();
            assert(context.state == State.beforeFinalExecution);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == 1);
        }
        with (createHelper(["B"]))
        {
            advance();
            assert(context.state == State.notMatchedRootCommand);
        }
        with (createHelper(["A", "-a="]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);

            advance();

            // Currently the these errors get minimally reported ???
            // this this is a bit of wtf and not fully done.
            assert(context.state == State.tokenizerError);
            assert(tokenizer.front.kind == ArgToken.Kind.error_noValueForNamedArgument);
        }
        with (createHelper(["A", "b"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._matchedName == "A");
            assert(context._storage.length == 1);
            // The position of A within Types.
            assert(context._storage[$ - 1].typeIndex == 0);

            // It parses until it finds the next command.
            // A does not get executed here.
            // A gets executed in a separate step.
            advance();
            // TODO: This should display something else, if there are no commands.
            assert(context.state == State.notMatchedNextCommand);
            assert(context._notMatchedName == "b");
        }
        with (createHelper(["A", "A"]))
        {
            advance();

            advance();
            // Should not match itself
            assert(context.state == State.notMatchedNextCommand);
            assert(context._notMatchedName == "A");
        }
        with (createHelper(["-h"]))
        {
            advance();
            assert(context.state == State.specialThing);
            assert(context._specialThing == SpecialThings.help);
        }
        with (createHelper(["A", "-h"]))
        {
            advance();
            advance();
            assert(context.state == State.specialThing);
            assert(context._specialThing == SpecialThings.help);
        }
        with (createHelper(["A", "-flag"]))
        {
            advance();
            advance();
            assert(context.state == State.commandParsingError);
            assert(errorHandler.hasError(CommandParsingErrorCode.unknownNamedArgumentError));
        }
    }
    {
        @Command
        static struct A
        {
            @ArgPositional
            string b = "op";

            static int onExecute()
            {
                return 1;
            }
        }

        alias Types = AliasSeq!(A);
        alias createHelper = createHelperThing!Types;

        with (createHelper(["A"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            auto a = cast(A*) context._storage[$ - 1].commandPointer;

            advance();
            assert(context.state == State.beforeFinalExecution);
            assert(a.b == "op");

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
        }
        with (createHelper(["A", "other"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            auto a = cast(A*) context._storage[$ - 1].commandPointer;

            advance();
            assert(context.state == State.beforeFinalExecution);
            assert(a.b == "other");

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
        }
    }
    {
        @Command
        static struct A
        {
            static int onExecute()
            {
                return 1;
            }
        }

        @Command
        static struct B
        {
            static int onExecute()
            {
                return 2;
            }
        }

        alias Types = AliasSeq!(A, B);
        enum AIndex = 0;
        enum BIndex = 1;

        alias createHelper = createHelperThing!Types;

        with (createHelper(["A"]))
        {
            advance();
            assert(context._storage[$ - 1].typeIndex == AIndex);

            advance();
            assert(context.state == State.beforeFinalExecution);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
        }
        with (createHelper(["B"]))
        {
            advance();
            assert(context._storage[$ - 1].typeIndex == BIndex);

            advance();
            assert(context.state == State.beforeFinalExecution);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == B.onExecute);
        }
    }
    {
        @Command
        static struct A
        {
            static int onExecute()
            {
                return 1;
            }
        }
        @Command
        static struct B
        {
            @ParentCommand
            A* a;

            static int onExecute()
            {
                return 2;
            }
        }

        alias Types = AliasSeq!(A, B);
        alias createHelper = createHelperThing!Types;

        with (createHelper(["A"]))
        {
            advance();

            advance();
            assert(context.state == State.beforeFinalExecution);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
        }
        with (createHelper(["B"]))
        {
            advance();
            assert(context.state == State.notMatchedRootCommand);
        }
        with (createHelper(["A", "B"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);

            advance();
            assert(context.state == State.matchedNextCommand);
            assert(context._matchedName == "B");

            advance();
            assert(context.state == State.intermediateExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
            
            advance();
            assert(context.state == State.beforeFinalExecution);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == B.onExecute);
        }
        with (createHelper(["A", "/h", "B"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);

            advance();
            assert(context.state == State.specialThing);
            assert(context._specialThing == SpecialThings.help);

            assert(tokenizer.front.valueSlice == "B");
        }
        with (createHelper(["A", "C"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);

            advance();
            assert(context.state == State.notMatchedNextCommand);
        }
    }
    {
        @Command
        static struct A
        {
            @ArgPositional
            string str = "op";

            static int onExecute()
            {
                return 1;
            }
        }
        @Command
        static struct B
        {
            @ParentCommand
            A* a;

            static int onExecute()
            {
                return 2;
            }
        }

        alias Types = AliasSeq!(A, B);
        alias createHelper = createHelperThing!Types;

        with (createHelper(["A"]))
        {
            advance();

            advance();
            assert(context.state == State.beforeFinalExecution);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);

            assert((cast(A*) context._storage[$ - 1].commandPointer).str == "op");
        }
        with (createHelper(["A", "B"]))
        {
            advance();

            advance();
            assert(context.state == State.matchedNextCommand);
            assert(context._matchedName == "B");
        }
        with (createHelper(["A", "ok"]))
        {
            advance();

            advance();
            assert(context.state == State.beforeFinalExecution);
            assert((cast(A*) context._storage[$ - 1].commandPointer).str == "ok");

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
        }
        with (createHelper(["A", "ok", "B"]))
        {
            advance();

            advance();
            assert(context.state == State.matchedNextCommand);
            assert(context._storage[$ - 1].typeIndex == 1);
            assert(context._storage[$ - 2].typeIndex == 0);
            assert((cast(A*) context._storage[$ - 2].commandPointer).str == "ok");

            advance();
            assert(context.state == State.intermediateExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
            
            advance();
            assert(context.state == State.beforeFinalExecution);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == B.onExecute);
        }
        with (createHelper(["A", "ok", "B", "kek"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);

            advance();
            assert(context.state == State.matchedNextCommand);

            advance();
            assert(context.state == State.intermediateExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);

            advance();
            assert(context.state == State.notMatchedNextCommand);
            assert(context._notMatchedName == "kek");
            // assert(errorHandler.hasError(CommandParsingErrorCode.tooManyPositionalArgumentsError));
        }
    }
    {
        @Command
        static struct A
        {
            static int onExecute()
            {
                return 1;
            }
        }
        @Command
        static struct B
        {
            @ParentCommand
            A* a;

            @ArgPositional
            string str = "op";

            static int onExecute()
            {
                return 2;
            }
        }

        alias Types = AliasSeq!(A, B);
        alias createHelper = createHelperThing!Types;

        with (createHelper(["A", "B"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);

            advance();
            assert(context.state == State.matchedNextCommand);

            advance();
            assert(context.state == State.intermediateExecutionResult);

            advance();
            assert(context.state == State.beforeFinalExecution);

            advance();
            assert(context.state == State.finalExecutionResult);

            auto b = cast(B*) context._storage[$ - 1].commandPointer;
            assert(b.str == "op");
            assert(cast(void*) b.a == context._storage[$ - 2].commandPointer);
        }
        with (createHelper(["A", "B", "kek"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);

            advance();
            assert(context.state == State.matchedNextCommand);

            advance();
            assert(context.state == State.intermediateExecutionResult);
            
            advance();
            assert(context.state == State.beforeFinalExecution);
            
            advance();
            assert(context.state == State.finalExecutionResult);

            assert((cast(B*) context._storage[$ - 1].commandPointer).str == "kek");
        }
    }
    {
        @Command
        static struct A
        {
            @ArgOverflow
            string[] overflow;

            static int onExecute()
            {
                return 1;
            }
        }
        @Command
        static struct B
        {
            @ParentCommand
            A* a;

            static int onExecute()
            {
                return 2;
            }
        }

        alias Types = AliasSeq!(A, B);
        alias createHelper = createHelperThing!Types;

        with (createHelper(["A"]))
        {
            advance();

            advance();
            assert(context.state == State.beforeFinalExecution);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
        }
        with (createHelper(["A", "a"]))
        {
            advance();

            advance();
            assert(context.state == State.beforeFinalExecution);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);

            assert((cast(A*) context._storage[$ - 1].commandPointer).overflow == ["a"]);
        }
        with (createHelper(["A", "B"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            advance();
            assert(context.state == State.matchedNextCommand);
            advance();
            assert(context.state == State.intermediateExecutionResult);
            advance();
            assert(context.state == State.beforeFinalExecution);
            advance();
            assert(context.state == State.finalExecutionResult);

            assert((cast(A*) context._storage[$ - 2].commandPointer).overflow == []);
        }
        with (createHelper(["A", "b", "B"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            advance();
            assert(context.state == State.matchedNextCommand);
            advance();
            assert(context.state == State.intermediateExecutionResult);
            advance();
            assert(context.state == State.beforeFinalExecution);
            advance();
            assert(context.state == State.finalExecutionResult);

            assert((cast(A*) context._storage[$ - 2].commandPointer).overflow == ["b"]);
        }
    }
    {
        @Command("name1|name2")
        static struct A
        {
            static int onExecute()
            {
                return 1;
            }
        }

        alias Types = AliasSeq!(A);
        alias createHelper = createHelperThing!Types;

        with (createHelper(["A"]))
        {
            advance();
            assert(context.state == State.notMatchedRootCommand);
        }
        with (createHelper(["name1"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._matchedName == "name1");
        }
        with (createHelper(["name2"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._matchedName == "name2");
        }
        // TODO: 
        // Partial matches option, autoresolve option.
        // Propagate it with the context.
    }
}
unittest
{
    static int test;
    @Command
    static struct A
    {
        void onExecute()
        {
            test = 1;
        }
    }
    // Just to make sure it compiles
    matchAndExecute!(bindArgument!(), A)(["A"]);
    assert(test == 1);
}
