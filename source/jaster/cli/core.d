module jaster.cli.core;

private
{
    import std.traits : isSomeChar;
    import jaster.cli.parser, jaster.cli.udas, jaster.cli.binder;
}

public
{
    import std.typecons : Nullable;
}

// Needs to be a class for a default ctor.
final class CommandLineInterface(Modules...)
{
    alias CommandExecuteFunc    = int function(ArgPullParser, ref string errorMessageIfThereWasOne);
    alias ArgValueSetterFunc(T) = void function(ArgToken, ref T);
    alias ArgBinderInstance     = ArgBinder!Modules;

    struct CommandInfo
    {
        CommandPattern pattern;
        string helpText;
        CommandExecuteFunc doExecute;
    }

    // BUG?: Apparently the below code causes param mis-match errors. Compiler bug?
    // struct ArgInfo(UDA, T)
    // {
    //     UDA uda;
    //     ArgValueSetterFunc!T setter;
    //     bool wasFound; // For nullables, this is ignore. Otherwise, anytime this is false we need to throw.
    //     bool isNullable;
    // }
    // alias NamedArgInfo(T) = ArgInfo!(CommandNamedArg, T);
    // alias PositionalArgInfo(T) = ArgInfo!(CommandPositionalArg, T);

    // TODO: REMOVE THESE ONCE THE ABOVE CODE ACTUALLY WORKS.
    struct NamedArgInfo(T)
    {
        CommandNamedArg uda;
        ArgValueSetterFunc!T setter;
        bool wasFound; // For nullables, this is ignore. Otherwise, anytime this is false we need to throw.
        bool isNullable;
    }

    struct PositionalArgInfo(T)
    {
        CommandPositionalArg uda;
        ArgValueSetterFunc!T setter;
        bool wasFound; // For nullables, this is ignore. Otherwise, anytime this is false we need to throw.
        bool isNullable;
    }

    /+ VARIABLES +/
    private
    {
        CommandInfo[] _commands;
    }

    /+ PUBLIC INTERFACE +/
    public
    {
        this()
        {
            static foreach(mod; Modules)
                this.addCommandsFromModule!mod();
        }

        int parseAndExecute(string[] args)
        {
            return this.parseAndExecute(ArgPullParser(args));
        } 

        int parseAndExecute(ArgPullParser args)
        {
            import std.algorithm : filter;
            import std.exception : enforce;

            auto result = this._commands.filter!(c => matchSpacefullPattern(c.pattern.value, /*ref*/ args));
            enforce(!result.empty, "Unknown command: "~args.front.value);

            // TODO: Display error message on error.
            string errorMessage;
            return result.front.doExecute(args, /*ref*/ errorMessage);
        }
    }

    /+ PRIVATE FUNCTIONS +/
    private
    {
        void addCommandsFromModule(alias Module)()
        {
            import std.traits : getSymbolsByUDA;

            static foreach(symbol; getSymbolsByUDA!(Module, CommandPattern))
            {
                static assert(is(symbol == struct), 
                    "Only structs can be marked with @CommandPattern (maybe classes soon). Issue Symbol = " ~ __traits(identifier, symbol)
                );

                this.addCommand!symbol();
            }
        }

        void addCommand(alias T)()
        if(is(T == struct))
        {
            CommandInfo info;
            info.helpText  = "TODO";
            info.pattern   = getSingleUDA!(T, CommandPattern);
            info.doExecute = this.createCommandExecuteFunc!T;
            this._commands ~= info;
        }

        CommandExecuteFunc createCommandExecuteFunc(alias T)()
        {
            import std.format    : format;
            import std.algorithm : filter, map;
            import std.exception : enforce;

            // This is expecting the parser to have already read in the command's name, leaving only the args.
            return (ArgPullParser parser, ref string executionError)
            {
                T commandInstance;
                
                // Get arg info.
                NamedArgInfo!T[] namedArgs;
                PositionalArgInfo!T[] positionalArgs;
                /*static member*/ getArgs(/*ref*/ namedArgs, /*ref*/ positionalArgs);

                // Parse args.
                size_t positionalArgIndex = 0;
                for(auto token = parser.front; !parser.empty; parser.popFront())
                {
                    final switch(token.type) with(ArgTokenType)
                    {
                        case Text:
                            enforce(positionalArgIndex < positionalArgs.length, "Stray positional arg found: '"~token.value~"'");
                            namedArgs[positionalArgIndex].setter(token, /*ref*/ commandInstance);
                            namedArgs[positionalArgIndex++].wasFound = true;
                            break;

                        case LongHandArgument:
                        case ShortHandArgument:
                            NamedArgInfo!T result;
                            foreach(ref arg; namedArgs)
                            {
                                if(/*static member*/matchSpacelessPattern(arg.uda.pattern, token.value))
                                {
                                    arg.wasFound = true;
                                    result = arg;
                                    break;
                                }
                            }
                            enforce(result != NamedArgInfo!T.init, "Unknown named argument: '"~token.value~"'");
                            
                            parser.popFront(); // TODO: Handle EOF
                                               // TODO: Handle bools
                            result.setter(parser.front, /*ref*/ commandInstance);
                            break;

                        case None:
                            throw new Exception("An Unknown error occured when parsing the arguments.");

                        case EOF:
                            break;
                    }
                }

                // Check for missing args.
                auto missingNamedArgs      = namedArgs.filter!(a => !a.isNullable && !a.wasFound);
                auto missingPositionalArgs = positionalArgs.filter!(a => !a.isNullable && !a.wasFound);
                enforce(missingNamedArgs.empty, "Missing(prelim error message): %s".format(missingNamedArgs.map!(a => a.uda.pattern)));
                enforce(missingPositionalArgs.empty, "Missing(prelim error message): %s".format(missingNamedArgs.map!(a => a.uda.pattern)));

                // Execute the command.
                static assert(__traits(compiles, commandInstance.onExecute()),
                    "Unable to call the `onExecute` function for command `"~__traits(identifier, T)~"` please ensure it's signature matches either:"
                   ~"\n\tvoid onExecute();"
                   ~"\n\tint onExecute();"
                );

                try
                {
                    static if(__traits(compiles, {int i = commandInstance.onExecute();}))
                        return commandInstance.onExecute();
                    else 
                    {
                        commandInstance.onExecute();
                        return 0;
                    }
                }
                catch(Exception ex)
                {
                    executionError = ex.msg;
                    debug executionError ~= ex.info.toString(); // trace info
                    return -1;
                }
            };
        }

        static bool matchSpacelessPattern(string pattern, string toTestAgainst)
        {
            import std.algorithm : splitter, any;

            return pattern.splitter("|").any!(str => str == toTestAgainst);
        }
        ///
        unittest
        {
            assert(matchSpacelessPattern("v|verbose", "v"));
            assert(matchSpacelessPattern("v|verbose", "verbose"));
            assert(!matchSpacelessPattern("v|verbose", "lalafell"));
        }

        static bool matchSpacefullPattern(string pattern, ref ArgPullParser parser)
        {
            import std.algorithm : splitter;

            foreach(subpattern; pattern.splitter("|"))
            {
                auto savedParser = parser.save();
                bool isAMatch = true;
                foreach(split; subpattern.splitter(" "))
                {
                    // import std.stdio;
                    // writeln(subpattern, " > ", split, " > ", savedParser.front, " > ", savedParser.empty, " > ", (savedParser.front.type == ArgTokenType.Text && savedParser.front.value == split));

                    if(savedParser.empty
                    || !(savedParser.front.type == ArgTokenType.Text && savedParser.front.value == split))
                    {
                        isAMatch = false;
                        break;
                    }

                    savedParser.popFront();
                }

                if(isAMatch)
                {
                    parser = savedParser;
                    return true;
                }
            }

            return false;
        }
        ///
        unittest
        {
            // Test empty parsers.
            auto parser = ArgPullParser([]);
            assert(!matchSpacefullPattern("v", parser));

            // Test that the parser's position is moved forward correctly.
            parser = ArgPullParser(["v", "verbose"]);
            assert(matchSpacefullPattern("v", parser));
            assert(matchSpacefullPattern("verbose", parser));
            assert(parser.empty);

            // Test that a parser that fails to match isn't moved forward at all.
            parser = ArgPullParser(["v", "verbose"]);
            assert(!matchSpacefullPattern("lel", parser));
            assert(parser.front.value == "v");

            // Test that a pattern with spaces works.
            parser = ArgPullParser(["give", "me", "chocolate"]);
            assert(matchSpacefullPattern("give me", parser));
            assert(parser.front.value == "chocolate");

            // Test that multiple patterns work.
            parser = ArgPullParser(["v", "verbose"]);
            assert(matchSpacefullPattern("lel|v|verbose", parser));
            assert(matchSpacefullPattern("lel|v|verbose", parser));
            assert(parser.empty);
        }

        static void getArgs(T)(ref NamedArgInfo!T[] namedArgs, ref PositionalArgInfo!T[] positionalArgs)
        {
            import std.format : format;
            import std.meta   : staticMap, Filter;
            import std.traits : isType, hasUDA, isInstanceOf, ReturnType, Unqual;

            alias NameToMember(string Name) = __traits(getMember, T, Name);
            alias MemberNames               = __traits(allMembers, T);
            alias MemberSymbols             = staticMap!(NameToMember, MemberNames);

            static foreach(symbol_SOME_RANDOM_CRAP; MemberSymbols) // The postfix is necessary so the below `if` works, without forcing the user to not use the name 'symbol' in their code.
            {{
                // Skip over aliases, nested types, and enums.
                static if(!isType!symbol_SOME_RANDOM_CRAP
                       && !is(symbol_SOME_RANDOM_CRAP == enum)
                       && __traits(identifier, symbol_SOME_RANDOM_CRAP) != "symbol_SOME_RANDOM_CRAP"
                )
                {
                    // I wish there were a convinent way to 'continue' a static foreach...

                    alias Symbol     = symbol_SOME_RANDOM_CRAP;
                    alias SymbolType = typeof(Symbol);
                    const SymbolName = __traits(identifier, Symbol);

                    // I feel I'm overthinking this entire thing.
                    const IS_FIELD_MIXIN = format("%s a; a = %s.init;", SymbolType.stringof, SymbolType.stringof);
                    static if(__traits(compiles, { mixin(IS_FIELD_MIXIN); })
                           && (hasUDA!(Symbol, CommandNamedArg) || hasUDA!(Symbol, CommandPositionalArg))
                    ) 
                    {
                        static if(hasUDA!(Symbol, CommandNamedArg))
                        {
                            NamedArgInfo!T arg;
                            arg.uda = getSingleUDA!(Symbol, CommandNamedArg);
                        }
                        else static if(hasUDA!(Symbol, CommandPositionalArg))
                        {
                            PositionalArgInfo!T arg;
                            arg.uda = getSingleUDA!(Symbol, CommandPositionalArg);
                        }
                        else static assert(false, "Bug with parent if statement.");

                        arg.setter = (ArgToken tok, ref T commandInstance)
                        {
                            import std.exception : enforce;
                            import std.conv : to;
                            assert(tok.type == ArgTokenType.Text, tok.to!string);

                            static if(isInstanceOf!(Nullable, SymbolType))
                            {
                                // The Unqual removes the `inout` that `get` uses.
                                alias SymbolUnderlyingType = Unqual!(ReturnType!(SymbolType.get));

                                SymbolUnderlyingType proxy;
                                ArgBinderInstance.bind(tok.value, /*ref*/ proxy);

                                mixin("commandInstance.%s = proxy;".format(SymbolName));
                            }
                            else
                                ArgBinderInstance.bind(tok.value, /*ref*/ mixin("commandInstance.%s".format(SymbolName)));
                        };
                        arg.isNullable = isInstanceOf!(Nullable, SymbolType);

                        static if(hasUDA!(Symbol, CommandNamedArg)) namedArgs ~= arg;
                        else                                        positionalArgs ~= arg;
                    }
                }
            }}
        }
    }
}

version(unittest)
{
    private alias InstansiationTest = CommandLineInterface!(jaster.cli.core);

    @CommandPattern("execute t|execute test|et|e test")
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

        int onExecute()
        {
            import std.conv : to;

            return (b.isNull) ? 0
                              : (b.get() == a.to!string) ? 1
                                                         : -1;
        }
    }

    unittest
    {
        auto cli = new CommandLineInterface!(jaster.cli.core);

        assert(cli.parseAndExecute(["execute", "t", "-a 20"])              == 0); // b is null
        assert(cli.parseAndExecute(["execute", "test", "20", "--avar 21"]) == -1); // a and b don't match
        assert(cli.parseAndExecute(["et", "20", "-a 20"])                  == 1); // a and b match
    }
}