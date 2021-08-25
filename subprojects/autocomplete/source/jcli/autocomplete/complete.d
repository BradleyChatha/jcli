module jcli.autocomplete.complete;

import jcli.core, jcli.introspect, jcli.argparser, std;

struct AutoComplete(alias CommandT)
{
    private
    {
        alias Info = commandInfoFor!CommandT;
    }

    string[] complete(string[] args)
    {
        string[] ret;
        size_t positionalCount;
        Pattern[] namedFound;
        typeof(Info.namedArgs[0])[Pattern] namedByPattern;
        typeof(Info.positionalArgs[0])[] positionalByPosition;

        static foreach(pos; Info.positionalArgs)
            positionalByPosition ~= pos;
        static foreach(named; Info.namedArgs)
            namedByPattern[named.uda.pattern] = named;

        enum State
        {
            lookingForNamedValue,
            lookingForPositionalOrNamed
        }

        State state;
        auto parser = ArgParser(args);
        ArgParser.Result lastResult;

        while(!parser.empty)
        {
            lastResult = parser.front;

            if(lastResult.kind == ArgParser.Result.Kind.rawText)
            {
                positionalCount++;
                parser.popFront();
            }
            else
            {
                typeof(Info.namedArgs[0]) argInfo;
                foreach(pattern, arg; namedByPattern)
                {
                    if(pattern.match(lastResult.nameSlice).matched)
                    {
                        namedFound ~= pattern;
                        argInfo = arg;
                        break;
                    }
                }
                
                // Skip over the name
                parser.popFront();

                // Skip over its argument
                if(parser.front.fullSlice.length && parser.front.kind == ArgParser.Result.Kind.rawText)
                {
                    lastResult = parser.front;
                    if(argInfo.scheme != ArgParseScheme.bool_ || (parser.front.fullSlice == "true" || parser.front.fullSlice == "false"))
                        parser.popFront();
                }
            }
        }

        state = (lastResult.kind == ArgParser.Result.Kind.argument)
            ? State.lookingForNamedValue
            : State.lookingForPositionalOrNamed;

        if(state == State.lookingForNamedValue)
        {
            bool isBool = false;
            static foreach(named; Info.namedArgs)
            {
                if(named.uda.pattern.match(lastResult.nameSlice).matched)
                {
                    isBool = named.scheme == ArgParseScheme.bool_;

                    alias Symbol = getArgSymbol!named;
                    static if(isInstanceOf!(Nullable, typeof(Symbol)))
                        alias SymbolT = typeof(typeof(Symbol)().get());
                    else
                        alias SymbolT = typeof(Symbol);

                    // Enums are a special case
                    static if(is(SymbolT == enum))
                    {
                        static foreach(name; __traits(allMembers, SymbolT))
                            ret ~= name;
                    }

                    static foreach(uda; __traits(getAttributes, Symbol))
                    {
                        // TODO:
                    }
                }
            }

            if(ret.length == 0)
            {
                if(isBool)
                    ret ~= ["true", "false"];
                else
                    ret ~= "[Value for argument "~lastResult.nameSlice~"]";
            }
        }
        else
        {
            if(positionalCount < positionalByPosition.length)
            {
                foreach(pos; positionalByPosition[positionalCount..$])
                    ret ~= "<"~pos.uda.name~">";
            }

            foreach(pattern; namedByPattern.byKey.filter!(k => !namedFound.canFind(k)))
            {
                foreach(p; pattern.patterns.map!(p => p.length == 1 ? "-"~p : "--"~p))
                    ret ~= p;
            }
        }

        return ret;
    }
}