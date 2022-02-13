module jcli.autocomplete.complete;

import jcli.core, jcli.introspect, jcli.argparser;

struct AutoComplete(alias CommandT)
{
    private
    {
        alias Info = CommandInfo!CommandT.Arguments;
    }

    string[] complete(string[] args)
    {
        // TODO: currently scrapped, needs more work considering the rewrite.
        static if (true)
        {
            return null;
        }
        else
        {
            string[] ret;
            size_t positionalCount;
            Pattern[] namedFound;
            
            // TODO: 
            // Map the indices perhaps?
            // There are so many things wrong with this code.
            typeof(Info.named[0])[Pattern] namedByPattern;
            typeof(Info.positional[0])[] positionalByPosition;

            static foreach(pos; Info.positional)
                positionalByPosition ~= pos;
            static foreach(named; Info.named)
                namedByPattern[named.pattern] = named;

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
                    typeof(Info.named[0]) argInfo;
                    foreach(pattern, arg; namedByPattern)
                    {
                        // TODO: this is a wtf
                        enum caseInsensitive = argInfo.flags.has(ArgFlags._caseInsensitiveBit);
                        if(pattern.matches!caseInsensitive(lastResult.nameSlice).matched)
                        {
                            namedFound ~= pattern;
                            argInfo = arg;
                            break;
                        }
                    }
                    
                    // Skip over the name
                    parser.popFront();

                    // Skip over its argument (what??)
                    if(parser.front.fullSlice.length 
                        && (parser.front.kind & ArgToken.Kind.valueBit))
                    {
                        lastResult = parser.front;
                        // TODO: Duplicate logic already present in the command parser.
                        if(argInfo.flags.has(ArgFlags._parseAsFlagBit) 
                            || (parser.front.fullSlice == "true" 
                                || parser.front.fullSlice == "false"))
                        {
                            parser.popFront();
                        }
                    }
                }
            }

            state = (lastResult.kind & ArgToken.Kind.argumentNameBit)
                ? State.lookingForNamedValue
                : State.lookingForPositionalOrNamed;

            if (state == State.lookingForNamedValue)
            {
                bool isBool = false;
                static foreach(named; Info.namedArgs)
                {
                    if(named.pattern.matches(lastResult.nameSlice).empty)
                    {
                        isBool = named.scheme == ArgParseScheme.bool_;

                        alias Symbol = getArgSymbol!named;

                        import std.traits : isInstanceOf;
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

                import std.algorithm;
                foreach(pattern; namedByPattern.byKey.filter!(k => !namedFound.canFind(k)))
                {
                    foreach(p; pattern.patterns.map!(p => p.length == 1 ? "-"~p : "--"~p))
                        ret ~= p;
                }
            }

            return ret;
        }
    }
}