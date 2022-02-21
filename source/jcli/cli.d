module jcli.cli;

import jcli;
import jcli.introspect;

import std.algorithm;
import std.stdio : writefln, writeln;
import std.array;
import std.traits;
import std.meta;

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
    
    /// transitions: -- parse & match -->matched|beforeFinalExecute|unmatched
    matchedRootCommand, 

    /// It's matched the next command by name.
    /// transitions: -- executePrevious -->intermediateExecutionResult
    matchedNextCommand, 

    /// When it does onExecute on parent command.
    /// transitions: -> matched|beforeFinalExecute|unmatched
    intermediateExecutionResult,

    /// Means it's consumed all of the arguments it can or should
    /// and right now it's a the point where it would execute the last thing.
    /// transitions: -> finalExecutionResult
    beforeFinalExecute,

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

struct MatchAndExecuteContext
{
    State _state;
    int _currentCommandTypeIndex;

    union
    {
        ArgToken.Kind _tokenizerError;
        ConsumeSingleArgumentResultKind _commandParsingErrorKind;
        SpecialThings _specialThing;

        ExecuteCommandResult _executeCommandResult;

        struct
        {
            int _previousCommandTypeIndex;
            string _matchedName;
        }
        string _notMatchedName;
    }

    // TODO: maybe store them inline
    // TODO: calculate the max path length in the graph and set that as max size.
    void*[] _storage;

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

    private void addCommand(int typeIndex)(scope ref Context context)
    {
        alias Type = Types[typeIndex];
        // TODO: maybe add something fancier here later 
        auto t = new Type();
        context._storage ~= cast(void*) t;
        context._currentCommandTypeIndex = typeIndex;
    }

    private auto getLatestCommand(int typeIndex)(scope ref Context context)
    {
        assert(context._storage.length > 0);
        assert(typeIndex == context._currentCommandTypeIndex);
        alias Type = Types[typeIndex];
        return cast(Type*) context._storage[$ - 1];
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

    // Again, frame issues.
    private string tryMatchCommandByNameMixinText(
        string resultVariableName,
        string commandNameVariableName,
        string typeIndexVariableName,
        string functionVariableName,
        int a = __LINE__)
    {
        import std.conv : to;
        string labelName = `__stuff` ~ a.to!string;

        return `{` ~ labelName ~ `: switch (` ~ commandNameVariableName ~ `)
        {
            default:
            {
                ` ~ resultVariableName ~ ` = false;
                break `  ~ labelName ~ `;
            }
            static foreach (_childNodeIndex, _childNode; Graph.Nodes[` ~ typeIndexVariableName ~ `])
            {{
                alias Type = Types[_childNode.childIndex];
                static foreach (_possibleName; jcli.introspect.CommandInfo!Type.general.uda.pattern)
                {
                    case _possibleName:
                    {
                        ` ~ functionVariableName ~ `!_childNode(_possibleName);
                        ` ~ resultVariableName ~ ` = true;
                        break `  ~ labelName ~ `;
                    }
                }
                
            }}
        }}`;
    }

    /// `handlerTemplate` must take a template parameter of the type Node matched. 
    /// returns false if the handler was not called.
    private bool tryMatchCommandByName(size_t parentTypeIndex, alias handlerTemplate)(string commandName)
    {
        switch (commandName)
        {
            default:
                return false;
            static foreach (childNodeIndex, childNode; Graph.Nodes[parentTypeIndex])
            {{
                alias Type = Types[childNode.childIndex];
                static foreach (possibleName; CommandInfo!Type.general.uda.pattern)
                {
                    case possibleName:
                    {
                        handlerTemplate!childNode(possibleName);
                        return true;
                    }
                }
            }}
        }
    }

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
                        void nameMatchedHandler(TypeGraphNode node)(string matchedName)
                        {
                            addCommand!(node.childIndex)(context);
                            context._matchedName = matchedName;
                        }
                        bool didMatchCommand;
                        mixin(tryMatchCommandByNameMixinText(
                            "didMatchCommand",
                            "nameSlice",
                            "typeIndex",
                            "nameMatchedHandler"));
                        
                        // monkyyy's frame issues at play
                        // bool didMatchCommand = tryMatchCommandByName!(typeIndex, nameMatchedHandler)(nameSlice));

                        if (didMatchCommand)
                        {
                            maybeReportParseErrorsFromFinalContext!ArgumentInfo(parsingContext, errorHandler);
                            resetNamedArgumentArrayStorage!Type(parsingContext);
                            tokenizer.resetWithRemainingRange();
                            
                            context._state = State.matchedNextCommand;
                            // Save the previous so we can call the onExecute at a later step.
                            context._previousCommandTypeIndex = typeIndex;
                            return true;
                        }
                        return false;
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
                            else if (parsingContext.currentPositionalArgIndex < ArgumentInfo.positional.length
                                || ArgumentInfo.takesOverflow)
                            {
                                // match, add
                                if (maybeMatchNextCommandNameAndResetState(currentToken.nameSlice))
                                    return;
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

                    context._state = State.beforeFinalExecute;
                }

                bool matched;
                enum mixinString = get_tryExecuteHandlerWithCompileTimeCommandIndexGivenRuntimeCommandIndex_MixinString(
                    "matched", "fillLatestCommand", "context._currentCommandTypeIndex");
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
                    auto command = cast(Type*) context._storage[$ - 2];
                    auto result = executeCommand(*command);
                    context._state = State.intermediateExecutionResult;
                    context._executeCommandResult = result;
                }

                bool didHandlerExecute;
                enum mixinString = get_tryExecuteHandlerWithCompileTimeCommandIndexGivenRuntimeCommandIndex_MixinString(
                    "didHandlerExecute", "executeNextToLast", "context._previousCommandTypeIndex");
                mixin(mixinString);

                assert(didHandlerExecute);
                return;
            }

            case State.beforeFinalExecute:
            {
                void executeLast(size_t typeIndex)()
                {
                    auto command = getLatestCommand!typeIndex(context);
                    auto result = executeCommand(*command);
                    context._state = State.finalExecutionResult;
                    context._executeCommandResult = result;
                }
                
                bool didHandlerExecute;
                enum mixinString = get_tryExecuteHandlerWithCompileTimeCommandIndexGivenRuntimeCommandIndex_MixinString(
                    "didHandlerExecute", "executeLast", "context._currentCommandTypeIndex");
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
        Context context;
        while (!(context._state & State.terminalStateBit))
        {
            advanceState(context, tokenizer, errorHandler);
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
    auto createHelper(Types...)(string[] args)
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
        alias createHelper0 = createHelper!Types;

        with (createHelper([]))
        {
            assert(context.state == State.initial);
            advance();
            assert(context.state == State.firstTokenNotCommand);
        }
        with (createHelper0(["A"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._matchedName == "A");
            assert(context._storage.length == 1);
            // The position of A within Types.
            assert(context._currentCommandTypeIndex == 0);

            advance();
            assert(context.state == State.beforeFinalExecute);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == 1);
        }
        with (createHelper0(["B"]))
        {
            advance();
            assert(context.state == State.notMatchedRootCommand);
        }
        with (createHelper(["A", "-a="]))
        {
            advance();
            writeln(context);
            assert(context.state == State.matchedRootCommand);

            advance();

            writeln(context);
            // Currently the these errors get minimally reported.
            assert(context.state == State.commandParsingError);
        }
        with (createHelper0(["A", "b"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._matchedName == "A");
            assert(context._storage.length == 1);
            // The position of A within Types.
            assert(context._currentCommandTypeIndex == 0);

            // It parses until it finds the next command.
            // A does not get executed here.
            // A gets executed in a separate step.
            advance();
            // TODO: This should display something else, if there are no commands.
            assert(context.state == State.notMatchedNextCommand);
            assert(context._notMatchedName == "b");
        }
        with (createHelper0(["A", "A"]))
        {
            advance();

            advance();
            // Should not match itself
            assert(context.state == State.notMatchedNextCommand);
            assert(context._notMatchedName == "A");
        }
        with (createHelper0(["-h"]))
        {
            advance();
            assert(context.state == State.specialThing);
            assert(context._specialThing == SpecialThings.help);
        }
        with (createHelper0(["A", "-h"]))
        {
            advance();
            advance();
            assert(context.state == State.specialThing);
            assert(context._specialThing == SpecialThings.help);
        }
        with (createHelper0(["-flag"]))
        {
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
        alias createHelper0 = createHelper!Types;

        with (createHelper0(["A"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            auto a = cast(A*) context._storage[$ - 1];

            advance();
            assert(context.state == State.beforeFinalExecute);
            assert(a.b == "op");

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
        }
        with (createHelper0(["A", "other"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            auto a = cast(A*) context._storage[$ - 1];

            advance();
            assert(context.state == State.beforeFinalExecute);
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

        alias createHelper0 = createHelper!Types;

        with (createHelper0(["A"]))
        {
            advance();
            assert(context._currentCommandTypeIndex == AIndex);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
        }
        with (createHelper0(["B"]))
        {
            advance();
            assert(context._currentCommandTypeIndex == BIndex);

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
        alias createHelper0 = createHelper!Types;

        with (createHelper0(["A"]))
        {
            advance();

            advance();
            assert(context.state == State.beforeFinalExecute);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
        }
        with (createHelper0(["B"]))
        {
            advance();
            assert(context.state == State.notMatchedRootCommand);
        }
        with (createHelper0(["A", "B"]))
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
            assert(context.state == State.beforeFinalExecute);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == B.onExecute);
        }
        with (createHelper0(["A", "/h", "B"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);

            advance();
            assert(context.state == State.specialThing);
            assert(context._specialThing == SpecialThings.help);

            assert(tokenizer.front.valueSlice == "B");
        }
        with (createHelper0(["A", "C"]))
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
        alias createHelper0 = createHelper!Types;

        with (createHelper0(["A"]))
        {
            advance();

            advance();
            assert(context.state == State.beforeFinalExecute);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);

            assert((cast(A*) context._storage[$ - 1]).str == "op");
        }
        with (createHelper0(["A", "B"]))
        {
            advance();

            advance();
            assert(context.state == State.matchedNextCommand);
            assert(context._matchedName == "B");
        }
        with (createHelper0(["A", "ok"]))
        {
            advance();

            advance();
            assert(context.state == State.beforeFinalExecute);
            assert((cast(A*) context._storage[$ - 1]).str == "ok");

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
        }
        with (createHelper0(["A", "ok", "B"]))
        {
            advance();

            advance();
            assert(context.state == State.matchedNextCommand);
            assert(context._previousCommandTypeIndex == 0);
            assert((cast(A*) context._storage[$ - 2]).str == "ok");
            assert(context._currentCommandTypeIndex == 1);

            advance();
            assert(context.state == State.intermediateExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
            
            advance();
            assert(context.state == State.beforeFinalExecute);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == B.onExecute);
        }
        with (createHelper0(["A", "ok", "B", "kek"]))
        {
            advance();
            advance();

            advance();
            assert(context.state == State.intermediateExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
            
            advance();
            assert(context.state == State.commandParsingError);
            assert(errorHandler.hasError(CommandParsingErrorCode.tooManyPositionalArgumentsError));
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
        alias createHelper0 = createHelper!Types;

        with (createHelper0(["A"]))
        {
            advance();

            advance();
            assert(context.state == State.beforeFinalExecute);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);
        }
        with (createHelper0(["A", "a"]))
        {
            advance();

            advance();
            assert(context.state == State.beforeFinalExecute);

            advance();
            assert(context.state == State.finalExecutionResult);
            assert(context._executeCommandResult.exitCode == A.onExecute);

            assert((cast(A*) context._storage[$ - 1]).overflow == ["a"]);
        }
        with (createHelper0(["A", "B"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            advance();
            assert(context.state == State.matchedNextCommand);
            advance();
            assert(context.state == State.intermediateExecutionResult);
            advance();
            assert(context.state == State.beforeFinalExecute);
            advance();
            assert(context.state == State.finalExecutionResult);

            assert((cast(A*) context._storage[$ - 2]).overflow == []);
        }
        with (createHelper0(["A", "b", "B"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            advance();
            assert(context.state == State.matchedNextCommand);
            advance();
            assert(context.state == State.intermediateExecutionResult);
            advance();
            assert(context.state == State.beforeFinalExecute);
            advance();
            assert(context.state == State.finalExecutionResult);

            assert((cast(A*) context._storage[$ - 2]).overflow == ["b"]);
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
        alias createHelper0 = createHelper!Types;

        with (createHelper0(["A"]))
        {
            advance();
            assert(context.state == State.notMatchedRootCommand);
        }
        with (createHelper0(["name1"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._matchedName == "name1");
        }
        with (createHelper0(["name2"]))
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