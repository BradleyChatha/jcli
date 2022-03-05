module jcli.commandgraph.wrapper;

import jcli.commandgraph;
import jcli.commandgraph.internal;

private alias State = MatchAndExecuteState;

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

// This is kind of what I mean by a type-safe wrapper, but it also needs getters for everything
// that would assert if the state is right and stuff like that.
// Currently, this one is only used for tests.
struct SimpleMatchAndExecuteHelper(alias Graph)
{
    alias bindArgument = jcli.argbinder.bindArgument!();
    alias _CommandTypeContext = CommandTypeContext!(Graph);
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