module jcli.commandgraph.cli;

import jcli.commandgraph;
import jcli.commandgraph.internal;
import jcli.commandgraph.graph;

import std.stdio : writefln, writeln;

private alias State = MatchAndExecuteState;

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
    alias Graph = DegenerateCommandTypeGraph!TCommand;
    alias TypeContext = MatchAndExecuteTypeContext!(bindArgument, CommandTypeContext!Graph);

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


/// Uses the bottom-up command gathering approach.
template matchAndExecuteAcrossModules(Modules...)
{
    alias bind = bindArgumentAcrossModules!Modules;
    alias Types = AllCommandsOf!Modules;
    alias matchAndExecuteAcrossModules = matchAndExecute!(bind, BottomUpCommandTypeGraph!Types);
}

/// Uses the top-down approach, and the given bind argument function.
/// You don't need to scan the modules to do the top-down approach.
template matchAndExecuteFromRootCommands(alias bindArgument, RootCommandTypes...)
{
    alias matchAndExecuteFromRootCommands = matchAndExecute!(bindArgument, TopDownCommandTypeGraph!RootCommandTypes);
}

/// Constructs the graph of the given command types, ...
template matchAndExecute(alias bindArgument, alias Graph)
{
    private alias _matchAndExecute = .matchAndExecute!(bindArgument, Graph);
    private alias _CommandTypeContext = CommandTypeContext!(Graph);

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
