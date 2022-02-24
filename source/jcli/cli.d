module jcli.cli;

import jcli;

import std.stdio : writefln, writeln;
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
        else static if (is(typeof(T.onExecute()) == void))
        {
            command.onExecute();
            return typeof(return)(0, null);
        }
        else
        {
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

// The name is subject to change.
ExecuteCommandResult executeCommandIntermediate(T)(auto ref scope T command)
{
    try
    {
        static if (is(typeof(command.onIntermediateExecute()) : int))
        {
            return typeof(return)(command.onIntermediateExecute(), null);
        }
        else static if (is(typeof(T.onIntermediateExecute()) == void))
        {
            command.onIntermediateExecute();
            return typeof(return)(0, null);
        }
        else
        {
            // Default to executing the command normally. (Maybe we shouldn't??)
            return executeCommand(command);
        }
    }
    catch (Exception exc)
    {
        return typeof(return)(0, exc);
    }
}

template CommandTypeContext(_Types...)
{
    alias Types = _Types;
    alias Graph = TypeGraph!Types;

    // I was debating the name for this function, I guess this one's alright 
    void executeWithCompileTimeTypeIndex
    (
        alias templateFunctionThatTakesTheCompileTimeIndex,
        // We need to pass the arguments explicitly, because of frame issues.
        // I'm glad it works with static functions tho, I really am.
        OtherArgsToPassToTemplateFunction...
    )
    (
        int currentTypeIndex,
        auto ref OtherArgsToPassToTemplateFunction args
    )
    {
        switch (currentTypeIndex)
        {
            static foreach (typeIndex, CurrentType; Types)
            {
                case cast(int) typeIndex:
                {
                    templateFunctionThatTakesTheCompileTimeIndex!(cast(int) typeIndex)(args);
                    return;
                }
            }
            default:
                assert(false);
        }
    }

    enum indexOf(Type) = Graph.getTypeIndexOf!Type;
    private enum isDefault(int index) = CommandInfo!(Types[index]).flags.has(CommandFlags.explicitlyDefault);
    alias defaultCommandIndices = Filter!(isDefault, aliasSeqOf!(Graph.rootTypeIndices));

    private alias getType(int typeIndex) = Types[typeIndex];
    alias toTypes(int[] indices) = staticMap!(getType, aliasSeqOf!(indices));
    
    // private alias getTypeNode(int typeIndex) = Types[typeIndex];
    import std.algorithm;
    alias toTypes(Graph.Node[] nodes) = staticMap!(getType, aliasSeqOf!(map!"a.typeIndex"(nodes)));
}

static scope struct IndexHelper(int typeIndex, alias CommandTypeContext) 
{
    static assert(CommandTypeContext.Types.length > typeIndex);
    alias Type = CommandTypeContext.Types[typeIndex];
    private MatchAndExecuteContext* _context;

    Type* opIndex(int index)
    {
        assert(_context._storage.length > index);
        assert(typeIndex == _context._storage[index].typeIndex);
        return cast(Type*) _context._storage[index].commandPointer;
    }

    int opDollar()
    {
        return cast(int) _context._storage.length;
    }

    Type* add()
    {
        auto t = new Type();
        _context._storage ~= MatchAndExecuteContext.StorageItem(typeIndex, cast(void*) t);
        return t;
    }
}

struct MatchAndParseContextWrapper(
    alias CommandTypeContext,
    // Either pointer to MatchAndExecuteContext, or that itself
    ContextType = MatchAndExecuteContext)
{
    ContextType _context;
    alias _context this;

    pure nothrow @nogc:

    auto contextPointer() inout
    {
        static if (is(ContextType : T*, T))
            return _context;
        else
            return &_context;
    }

    auto command(int typeIndex)()
    {
        return IndexHelper!(typeIndex, CommandTypeContext)(contextPointer);
    }

    auto command(CommandType)()
    {
        enum index = CommandTypeContext.indexOf!CommandType;
        return IndexHelper!(index, CommandTypeContext)(contextPointer);
    }

    SpecialThings specialThing() const
    {
        assert(_context._state == State.specialThing);
        return _context._specialThing;
    }
    
    inout(ExecuteCommandResult) executeCommandResult() inout
    {
        assert(_context._state == State.intermediateExecutionResult
            || _context._state == State.finalExecutionResult);
        return _context._executeCommandResult;
    }

    string matchedName() const
    {
        assert(_context._state == State.matchedNextCommand
            || _context._state == State.matchedRootCommand);
        return _context._matchedName;
    }
    
    string notMatchedName() const
    {
        assert(_context._state == State.notMatchedNextCommand
            || _context._state == State.notMatchedRootCommand);
        return _context._notMatchedName;
    }

    State state() const @safe { return _state; }

    // SumType-like match, maybe?
    // template match();
}

auto wrapContext(Types)(scope ref MatchAndExecuteContext context) return
{
    return *cast(MatchAndParseContextWrapper!Types*) &context;
}


enum MatchAndExecuteState
{
    /// The initial state.
    initial = 0,
    
    /// transitions: -- parse & match -->matched | beforeFinalExecution | notMatched
    matchedRootCommand, 

    /// It's matched the next command by name.
    /// transitions: -- executePrevious -->intermediateExecutionResult
    matchedNextCommand, 

    /// When it does `onExecute` on parent command.
    /// transitions: -> matched | beforeFinalExecution | notMatched
    intermediateExecutionResult,

    /// Means it's consumed all of the arguments it can or should
    /// and right now it's at the point where it would execute the last command.
    /// transitions: -> finalExecutionResult
    beforeFinalExecution,

    /// If this bit is set, any state after it will give invalid.
    terminalStateBit = 16,
    
    /// If there's no default command, but there are root-level named commands,
    /// the first expected token kind is `argumentValue`.
    /// This state is when the observed token kind is not that.
    firstTokenNotCommand = terminalStateBit | 0,

    /// Misuse of the API.
    invalid = terminalStateBit | 1,

    // TODO:
    // Do a function that would look for a help flag even after another error has occured,
    // consuming all tokens remaining in the tokenizer.

    /// Aka help, see SpecialThings.
    /// `help`: 
    /// May come up at any point. It means the current command asked for a help message.
    /// The help may be asked for at the top level, before any command has been matched.
    /// The actual command that requested the help is always the latest command in the
    /// `_storage`, unless there are no matched commands, in which case the help over 
    /// the top-level commands is being requested.
    specialThing = terminalStateBit | 2, 


    /// It's not matched the next command, and there are extra unused arguments.
    notMatchedNextCommand = terminalStateBit | 3,

    ///
    notMatchedRootCommand = terminalStateBit | 4,

    /// Happens in case a command was not matched, and no special thing
    /// was found after that.
    ///  transitions: -> invalid
    // doneWithoutExecuting = terminalStateBit | 5,
    
    /// It's executed a terminal command (the tokenizer was empty).
    finalExecutionResult = terminalStateBit | 6,

    /// ArgToken.Kind, the error_ things.
    tokenizerError = terminalStateBit | 7, 
    
    /// The errors are recorded on the handler for this one.
    /// I'm debating whether all errors should be handled via that.
    commandParsingError = terminalStateBit | 8,
}

private alias State = MatchAndExecuteState;

///
template matchAndExecuteAcrossModules(Modules...)
{
    alias bind = bindArgumentAcrossModules!Modules;
    alias Types = AllCommandsOf!Modules;
    alias matchAndExecuteAcrossModules = matchAndExecute!(bind, Types);
}

/// Constructs the graph of the given command types, ...
template matchAndExecute(alias bindArgument, CommandTypes...)
{
    private alias _matchAndExecute = .matchAndExecute!(bindArgument, CommandTypes);
    private alias _CommandTypeContext = CommandTypeContext!CommandTypes;

    /// Forwards.
    int matchAndExecute
    (
        Tokenizer : ArgTokenizer!T, T,
        TErrorHandler
    )
    (
        scope ref Tokenizer tokenizer,
        scope ref TErrorHandler errorHandler
    )
    {
        return MatchAndExecuteTypeContext!(bindArgument, _CommandTypeContext)
            .matchAndExecute(tokenizer, errorHandler);
    }

    /// Resolves the invoked command by parsing the arguments array.
    /// Executes the `onExecute` method of any intermediate commands (command groups).
    /// Returns the result of the execution, and whether there were errors.
    int matchAndExecute(scope string[] args)
    {
        auto tokenizer = argTokenizer(args);
        return _matchAndExecute(tokenizer);
    }
    
    /// ditto
    /// Uses the default error handler.
    int matchAndExecute(Tokenizer : ArgTokenizer!T, T)
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
        SpecialThings _specialThing;
        ExecuteCommandResult _executeCommandResult;
        string _matchedName;
        string _notMatchedName;
    }

    // TODO: maybe store them inline
    // TODO: 
    // calculate the max path length in the graph and set that as max size.
    // pass the max command cound as a template argument.
    struct StorageItem
    {
        int typeIndex;
        void* commandPointer;
    }
    StorageItem[] _storage;
}

// TODO: better name
template MatchAndExecuteTypeContext(alias bindArgument, alias CommandTypeContext)
{
    // TODO: should probably take this graph as an argument
    alias Graph = CommandTypeContext.Graph;
    enum maxNamedArgCount = 
    (){
        size_t result = 0;
        static foreach (Type; CommandTypeContext.Types)
        {
            import std.algorithm.comparison : max;
            result = max(result, CommandArgumentsInfo!Type.named.length);
        }
        return result;
    }();
    alias ParsingContext = CommandParsingContext!maxNamedArgCount;
    alias Context = MatchAndExecuteContext;

    auto commandIndexer(int typeIndex)(ref scope Context context)
    {
        return IndexHelper!(typeIndex, CommandTypeContext)(&context);
    }

    void parseCommandAndMatchNextCommand
    (
        size_t typeIndex,
        Tokenizer : ArgTokenizer!TRange, TRange,
        TErrorHandler
    )
    (
        scope ref Context context,
        scope ref ParsingContext parsingContext,
        scope ref Tokenizer tokenizer,
        scope ref TErrorHandler errorHandler,
    )
    {
        alias Type = CommandTypeContext.Types[typeIndex];
        alias ArgumentsInfo = CommandArgumentsInfo!Type;
        Type* command = commandIndexer!typeIndex(context)[$ - 1];

        enum childCommandsCount = Graph.Adjacencies[typeIndex].length;

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
                static foreach (childNodeIndex, childNode; Graph.Adjacencies[typeIndex])
                {{
                    alias Type = CommandTypeContext.Types[childNode.typeIndex];
                    static foreach (possibleName; CommandInfo!Type.udaValue.pattern)
                    {
                        case possibleName:
                        {
                            auto newCommand = commandIndexer!(childNode.typeIndex)(context).add();
                            
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
                maybeReportParseErrorsFromFinalContext!ArgumentsInfo(parsingContext, errorHandler);
                resetNamedArgumentArrayStorage!ArgumentsInfo(parsingContext);
                tokenizer.resetWithRemainingRange();
                context._state = State.matchedNextCommand;
            }

            return didMatchCommand;
        }
        
        // Matched the given command.
        while (!tokenizer.empty)
        {
            if (tryMatchSpecialThingsAndResetContextAccordingly(context, tokenizer))
                return;

            const currentToken = tokenizer.front;

            auto consumeSingle()
            { 
                return consumeSingleArgumentIntoCommand!bindArgument(
                    parsingContext, *command, tokenizer, errorHandler);
            }

            static if (0)
            {
                if (currentToken.kind.has(ArgToken.Kind.errorBit))
                {
                    // TODO: error handler integration, not sure yet??
                    context._state = State.tokenizerError;
                    // context._tokenizerError = currentToken.kind;
                    return;
                }
            }

            // We don't bother with subcommands if the current command has no children.
            // Is this a hack? I'm not sure.
            static if (childCommandsCount == 0)
            {
                const _ = consumeSingle();
                continue;
            }

            else if (currentToken.kind.has(ArgToken.Kind.valueBit)  // @suppress(dscanner.suspicious.static_if_else)
                && currentToken.kind.hasEither(
                    ArgToken.Kind.positionalArgumentBit | ArgToken.Kind.orphanArgumentBit))
            {
                // 3 posibilities
                // 1. Not all required positional arguments have been read, in which case we read that.
                // 2. All required positional arguments have been read, but there are still optional ones,
                //    in which case we try to match command first before reading on.
                // 3. All possibile positional args have been read, so just match the name.
                if (parsingContext.currentPositionalArgIndex < ArgumentsInfo.numRequiredPositionalArguments)
                {
                    const _ = consumeSingle();
                }
                else if (parsingContext.currentPositionalArgIndex < ArgumentsInfo.positional.length
                    || ArgumentsInfo.takesOverflow)
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

        maybeReportParseErrorsFromFinalContext!ArgumentsInfo(parsingContext, errorHandler);

        if (parsingContext.errorCounter > 0)
        {
            context._state = State.commandParsingError;
            return;
        }

        context._state = State.beforeFinalExecution;
    }

    void setMatchedRootCommand(int typeIndex)(
        scope ref Context context,
        scope ref ParsingContext parsingContext,
        string matchedName = "")
    {
        commandIndexer!typeIndex(context).add();

        context._state = State.matchedRootCommand;
        context._matchedName = matchedName;

        alias ArgumentInfo = CommandArgumentsInfo!(CommandTypeContext.Types[typeIndex]);
        resetNamedArgumentArrayStorage!ArgumentInfo(parsingContext);
    }

    bool tryMatchSpecialThingsAndResetContextAccordingly
    (
        Tokenizer : ArgTokenizer!TRange, TRange,
    )
    (
        scope ref Context context,
        scope ref Tokenizer tokenizer,
    )
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

        switch (context._state)
        {
            default:
                assert(0);

            case State.initial:
            {
                // For now calculate it here, but ideally we should have a wrapper for
                // command types. (It's not the graph, graph does not have to think about that).
                // Also, I think no validation of duplicate default commands is done,
                // but it shouldn't happen on this layer of things either.
                enum hasDefaultCommand = CommandTypeContext.defaultCommandIndices.length > 0;

                void matchDefaultCommand()
                {
                    // Match the root default commands, even without name.
                    foreach (rootTypeIndex; CommandTypeContext.defaultCommandIndices)
                        setMatchedRootCommand!rootTypeIndex(context, parsingContext, "");
                }

                if (tokenizer.empty)
                {
                    static if (hasDefaultCommand)
                        matchDefaultCommand();
                    else
                        context._state = State.firstTokenNotCommand;
                    return;
                }

                if (tryMatchSpecialThingsAndResetContextAccordingly(context, tokenizer))
                    return;

                ArgToken firstToken = tokenizer.front;

                // Try to interpret the first argument as the command name.
                if (firstToken.kind.has(ArgToken.Kind.valueBit))
                {
                    switch (firstToken.nameSlice)
                    {
                        default:
                        {
                            break;
                        }
                        static foreach (rootTypeIndex; Graph.rootTypeIndices)
                        {{
                            alias Type = CommandTypeContext.Types[rootTypeIndex];
                            alias Info = CommandInfo!Type;

                            // The default commands don't even have their name in the UDA.
                            static if (Info.flags.has(CommandFlags.commandAttribute) && 
                                // Hack so that single commands work.
                                !Info.flags.has(CommandFlags.explicitlyDefault))
                            {
                                static foreach (possibleName; Info.udaValue.pattern)
                                {
                                    case possibleName:
                                    {
                                        setMatchedRootCommand!rootTypeIndex(context, parsingContext, possibleName);
                                        tokenizer.popFront();
                                        return;
                                    }
                                }
                            }
                        }}
                    }
                }

                static if (hasDefaultCommand)
                {
                    matchDefaultCommand();
                }
                else if (firstToken.kind.has(ArgToken.Kind.valueBit)) // @suppress(dscanner.suspicious.static_if_else)
                {
                    context._state = State.notMatchedRootCommand;
                    tokenizer.popFront();
                }
                else
                {
                    context._state = State.firstTokenNotCommand;
                }
                return;
            }

            // Already added, executed the parent command, and set up the new command,
            // just initialize the latest command.
            case State.matchedRootCommand:
            case State.intermediateExecutionResult:
            {
                CommandTypeContext.executeWithCompileTimeTypeIndex!parseCommandAndMatchNextCommand(
                    context._storage[$ - 1].typeIndex, context, parsingContext, tokenizer, errorHandler);
                return;
            }

            // Already added the command, but haven't executed the previous one.
            case State.matchedNextCommand:
            {
                static void executeNextToLast(size_t typeIndex)(ref scope Context context)
                {
                    auto command = commandIndexer!typeIndex(context)[$ - 2];
                    auto result = executeCommandIntermediate(*command);
                    context._state = State.intermediateExecutionResult;
                    context._executeCommandResult = result;
                }

                CommandTypeContext.executeWithCompileTimeTypeIndex!executeNextToLast(
                    context._storage[$ - 2].typeIndex, context);

                return;
            }

            case State.beforeFinalExecution:
            {
                static void executeLast(size_t typeIndex)(ref scope Context context)
                {
                    auto command = commandIndexer!typeIndex(context)[$ - 1];
                    auto result = executeCommand(*command);
                    context._state = State.finalExecutionResult;
                    context._executeCommandResult = result;
                }

                CommandTypeContext.executeWithCompileTimeTypeIndex!executeLast(
                    context._storage[$ - 1].typeIndex, context);

                return;
            }
        }
    }

    // TODO: pull this out into a standalone function.
    ///
    int matchAndExecute
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

        do
        {
            advanceState(context, parsingContext, tokenizer, errorHandler);

            // TODO: handle this better.
            if (context._state == State.intermediateExecutionResult)
            {
                if (context._executeCommandResult.exception !is null)
                {
                    writeln(context._executeCommandResult.exception);
                    return -1;
                }
                if (context._executeCommandResult.exitCode != 0)
                {
                    writeln("Command execution failed");
                    return context._executeCommandResult.exitCode;
                }
            }
        }
        while (!(context._state & State.terminalStateBit));

        // TODO: print better help here.
        static void printCommandHelpForTypes(Types...)()
        {
            string getName(Type)()
            {
                static if (CommandInfo!Type.flags.has(CommandFlags.explicitlyDefault))
                    return "default";
                else
                    return CommandInfo!Type.udaValue.name;
            }

            enum maxNameLength =
            (){
                int result = 0;
                static foreach (Type; Types)
                {
                    import std.algorithm.comparison : max;
                    result = max(result, cast(int) getName!Type.length);
                }
                return result;
            }();

            static foreach (Type; Types)
            {{
                alias Info = CommandInfo!Type;
                // TODO: format this better.
                writefln!"%*s  %s"(maxNameLength, getName!Type ~ ":", Info.description);
            }}
        }

        static void printHelpForRootTypes()
        {
            printCommandHelpForTypes!(
                CommandTypeContext.toTypes!(Graph.rootTypeIndices));
        }

        static void printHelpForCommand(int typeIndex)()
        {
            alias Type = CommandTypeContext.Types[typeIndex];
            CommandHelpText!Type help;
            writeln(help.generate());
        }

        static void printHelpForTypeAndChildren(int typeIndex)()
        {
            alias childNodes = Alias!(Graph.Adjacencies[typeIndex]);
            static if (childNodes.length > 0)
            {
                alias Types = CommandTypeContext.toTypes!childNodes;
                printCommandHelpForTypes!Types();
            }

            alias Info = CommandArgumentsInfo!(CommandTypeContext.Types[typeIndex]);
            static if (childNodes.length == 0 || Info.takesSomeArguments)
            {
                printHelpForCommand!typeIndex();
            }
        }

        // TODO: switch over the terminal states here, see `executeSingleCommand`.
        // TODO: a better implementation.
        switch (context._state)
        {
            default:
                assert(0, "Not all terminal states handled.");

            case State.firstTokenNotCommand:
            {
                writeln("The first token in the arguments must the name of a subcommand. "
                    ~ "The allowed commands:\n");
                printHelpForRootTypes();
                return -1;
            }

            case State.invalid:
                assert(0, "The context came to an invalid state — internal API misuse.");

            case State.notMatchedRootCommand:
            {
                printHelpForRootTypes();
                return -1;
            }
            
            case State.notMatchedNextCommand:
            {
                import std.traits;
                CommandTypeContext.executeWithCompileTimeTypeIndex!printHelpForTypeAndChildren(
                    context._storage[$ - 1].typeIndex);
                return -1;
            }

            case State.specialThing:
            {
                switch (context._specialThing)
                {
                    default:
                        assert(0, "Some special thing was not been properly handled");

                    case SpecialThings.help:
                    {
                        if (context._storage.length == 0)
                        {
                            printHelpForRootTypes();
                        }
                        else
                        {
                            CommandTypeContext.executeWithCompileTimeTypeIndex!printHelpForTypeAndChildren(
                                context._storage[$ - 1].typeIndex);
                        }
                        return 0;
                    }
                }
            }
            
            case State.finalExecutionResult:
            {
                if (context._executeCommandResult.exception !is null)
                {
                    writeln(context._executeCommandResult.exception);
                    return -1;
                }
                return context._executeCommandResult.exitCode;
            }
            
            case State.tokenizerError:
            case State.commandParsingError:
            {
                // TODO: exhaust the tokenizer to try to find a help request
                while (!tokenizer.empty)
                {
                    auto specialThing = tryMatchSpecialThingsAndResetContextAccordingly(context, tokenizer);
                    final switch (specialThing)
                    {
                        case SpecialThings.none:
                        {
                            tokenizer.popFront();
                            break;
                        }
                        case SpecialThings.help:
                        {
                            if (context._storage.length == 0)
                            {
                                printHelpForRootTypes();
                            }
                            else
                            {
                                CommandTypeContext.executeWithCompileTimeTypeIndex!printHelpForTypeAndChildren(
                                    context._storage[$ - 1].typeIndex);
                            }
                            return -1;
                        }
                    }
                }
                return -1;
            }
        }
    }
}

// This is kind of what I mean by a type-safe wrapper, but it also needs getters for everything
// that would assert if the state is right and stuff like that.
// Currently, this one is only used for tests.
struct SimpleMatchAndExecuteHelper(Types...)
{
    alias bindArgument = jcli.argbinder.bindArgument!();
    alias _CommandTypeContext = CommandTypeContext!(Types);
    alias TypeContext = MatchAndExecuteTypeContext!(bindArgument, _CommandTypeContext);

    MatchAndParseContextWrapper!_CommandTypeContext context;
    TypeContext.ParsingContext parsingContext;
    ArgTokenizer!(string[]) tokenizer;
    ErrorCodeHandler errorHandler;


    this(string[] args)
    {
        tokenizer = argTokenizer(args);
        parsingContext = TypeContext.ParsingContext();
        context = MatchAndParseContextWrapper!_CommandTypeContext();
        errorHandler = createErrorCodeHandler();
    }

    void advance()
    {
        TypeContext.advanceState(context, parsingContext, tokenizer, errorHandler);
    }
}

unittest
{
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
            // assert(context.state == State.tokenizerError);
            // assert(tokenizer.front.kind == ArgToken.Kind.error_noValueForNamedArgument);
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
            assert(context.state == State.commandParsingError);
            assert(errorHandler.hasError(CommandParsingErrorCode.tooManyPositionalArgumentsError));
        }
        with (createHelper(["A", "A"]))
        {
            advance();

            advance();
            // Should not match itself
            assert(context.state == State.commandParsingError);
            assert(errorHandler.hasError(CommandParsingErrorCode.tooManyPositionalArgumentsError));
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
            auto a = context.command!(A)[$ - 1];

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
            auto a = context.command!(A)[$ - 1];

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

            assert(context.command!(A)[$ - 1].str == "op");
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
            assert(context.command!(A)[$ - 1].str == "ok");

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
            assert(context.command!(A)[$ - 2].str == "ok");

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
            assert(context.state == State.commandParsingError);
            assert(errorHandler.hasError(CommandParsingErrorCode.tooManyPositionalArgumentsError));
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

            auto b = context.command!(B)[$ - 1];
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

            assert(context.command!(B)[$ - 1].str == "kek");
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

            assert(context.command!(A)[$ - 1].overflow == ["a"]);
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

            assert(context.command!(A)[$ - 2].overflow == []);
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

            assert(context.command!(A)[$ - 2].overflow == ["b"]);
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
    {
        // This command will match even without the user explicitly specifying its name.
        @CommandDefault
        static struct A
        {
            void onExecute() {}
        }

        // This command is also a top-level command, but it will match only if the name
        // matches.
        @Command
        static struct B
        {
            void onExecute() {}
        }

        // This command is a child command of A.
        @Command
        static struct C
        {
            @ParentCommand
            A* a;
            void onExecute() {}
        }

        alias Types = AliasSeq!(A, B, C);
        alias createHelper = createHelperThing!Types;

        enum AIndex = 0;
        enum BIndex = 1;
        enum CIndex = 2;

        with (createHelper([]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._storage[$ - 1].typeIndex == AIndex);
        }
        with (createHelper(["A"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._storage[$ - 1].typeIndex == AIndex);
            
            advance();
            assert(context.state == State.notMatchedNextCommand);
        }
        with (createHelper(["B"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._storage[$ - 1].typeIndex == BIndex);
        }
        with (createHelper(["C"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._storage[$ - 1].typeIndex == AIndex);

            advance();
            assert(context.state == State.matchedNextCommand);
            assert(context._storage[$ - 1].typeIndex == CIndex);
        }
        with (createHelper(["kek"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._storage[$ - 1].typeIndex == AIndex);
            
            advance();
            assert(context.state == State.notMatchedNextCommand);
        }
    }
    {
        @CommandDefault
        static struct A
        {
            @ArgNamed
            string hello;

            void onExecute() {}
        }
        
        alias Types = AliasSeq!(A);
        alias createHelper = createHelperThing!Types;
        
        with (createHelper(["-kek"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._storage[$ - 1].typeIndex == 0);
            
            advance();
            assert(context.state == State.commandParsingError);
        }
        with (createHelper(["-hello", "kek"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);
            assert(context._storage[$ - 1].typeIndex == 0);
            
            advance();
            assert(context.state.beforeFinalExecution);

            auto a = context.command!(A)[$ - 1];
            assert(a.hello == "kek");
            
            advance();
            assert(context.state.finalExecutionResult);
        }
    }
    {
        @Command
        static struct A
        {
            @("Named")
            string b;
        }

        alias Types = AliasSeq!(A);
        alias createHelper = createHelperThing!Types;

        with (createHelper(["A"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);

            advance();
            assert(context.state == State.commandParsingError);
            assert(errorHandler.hasError(CommandParsingErrorCode.missingNamedArgumentsError));
        }
        with (createHelper(["A", "-b"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);

            advance();
            assert(context.state == State.commandParsingError);
            assert(errorHandler.hasError(CommandParsingErrorCode.noValueForNamedArgumentError));
        }
        with (createHelper(["A", "-b", "c"]))
        {
            advance();
            assert(context.state == State.matchedRootCommand);

            advance();
            assert(context.state == State.beforeFinalExecution);

            auto a = context.command!(A)[$ - 1];
            assert(a.b == "c");
        }
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

/// Don't forget to cut off the executable name: args = arg[1 .. $];
int executeSingleCommand(TCommand)(scope string[] args)
{
    auto defaultHandler = DefaultParseErrorHandler();
    return executeSingleCommand!TCommand(args, defaultHandler);
}

/// ditto
int executeSingleCommand
(
    TCommand,
    TErrorHandler
)
(
    scope string[] args,
    ref scope TErrorHandler errorHandler
)
{
    alias bindArgument = jcli.argbinder.bindArgument!();
    alias Types = AliasSeq!(TCommand);
    alias TypeContext = MatchAndExecuteTypeContext!(bindArgument, CommandTypeContext!Types);

    TypeContext.ParsingContext parsingContext;
    MatchAndExecuteContext context;
    auto tokenizer = argTokenizer(args);
    
    // This basically fools the state machine into thinking it's already matched the root command.
    {
        enum commandTypeIndex = 0;
        TypeContext.setMatchedRootCommand!commandTypeIndex(context, parsingContext);
    }

    // Do the normal workflow until we reach a terminal state.
    while (!(context._state & State.terminalStateBit))
    {
        TypeContext.advanceState(context, parsingContext, tokenizer, errorHandler);
    }

    switch (context._state)
    {
        default:
            assert(0, "Not all terminal states handled.");

        // This one is only issued when matching the root command, so it should never be hit.
        case State.firstTokenNotCommand:

        case State.invalid:
        case State.notMatchedNextCommand:
        case State.notMatchedRootCommand:
            assert(0, "The context came to an invalid state — internal API misuse.");

        case State.specialThing:
        {
            switch (context._specialThing)
            {
                default:
                    assert(0, "Some special thing was not been properly handled");

                case SpecialThings.help:
                {
                    import jcli.helptext;
                    // writeHelpText!TCommand()
                    CommandHelpText!TCommand help;
                    writeln(help.generate());
                    return 0;
                }
            }
        }
        case State.finalExecutionResult:
        {
            if (context._executeCommandResult.exception !is null)
            {
                writeln(context._executeCommandResult.exception);
                return -1;
            }
            return context._executeCommandResult.exitCode;
        }
        case State.tokenizerError:
        case State.commandParsingError:
        {
            return -1;
        }
    }
}

unittest
{
    @Command("Hello")
    static struct A
    {
        @ArgPositional("Error to return")
        int err;

        int onExecute() { return err; }
    }

    {
        auto errorHandler = ErrorCodeHandler();
        assert(executeSingleCommand!A(["11"], errorHandler) == 11);
    }
    {
        auto errorHandler = ErrorCodeHandler();
        assert(executeSingleCommand!A(["0"], errorHandler) == 0);
    }
    {
        auto errorHandler = ErrorCodeHandler();
        assert(executeSingleCommand!A([], errorHandler) != 0);
        assert(errorHandler.hasError(CommandParsingErrorCode.tooFewPositionalArgumentsError));
    }
    {
        auto errorHandler = ErrorCodeHandler();
        assert(executeSingleCommand!A(["A"], errorHandler) != 0);
        assert(errorHandler.hasError(CommandParsingErrorCode.bindError));
    }
    {
        auto errorHandler = ErrorCodeHandler();
        // Will print some garbage, but it's fine.
        assert(executeSingleCommand!A(["-h"], errorHandler) == 0);
    }
}

unittest
{
    @Command("Hello")
    static struct A
    {
        @("Error to return")
        int err;

        int onExecute() { return err; }
    }
    
    {
        auto errorHandler = ErrorCodeHandler();
        assert(executeSingleCommand!A(["-err", "11"], errorHandler) == 11);
    }
    {
        auto errorHandler = ErrorCodeHandler();
        assert(executeSingleCommand!A(["-err", "0"], errorHandler) == 0);
    }
    {
        auto errorHandler = ErrorCodeHandler();
        assert(executeSingleCommand!A(["-err"], errorHandler) != 0);
        assert(errorHandler.hasError(CommandParsingErrorCode.noValueForNamedArgumentError));
    }
    {
        auto errorHandler = ErrorCodeHandler();
        assert(CommandArgumentsInfo!A.named[0].flags.has(ArgFlags._requiredBit));
        assert(executeSingleCommand!A([], errorHandler) != 0);
        assert(errorHandler.hasError(CommandParsingErrorCode.missingNamedArgumentsError));
    }
}

mixin template SingleCommandMain(TCommand)
{
    int main(string[] args)
    {
        return executeSingleCommand!TCommand(args[1 .. $]);
    }
}
