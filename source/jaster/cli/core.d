module jaster.cli.core;

private
{
    import std.traits : isSomeChar;
    import jaster.cli.parser, jaster.cli.udas, jaster.cli.binder, jaster.cli.helptext;
}

public
{
    import std.typecons : Nullable;
}

// Needs to be a class for a default ctor.
/++
 + Provides the functionality of parsing command line arguments, and then calling a command.
 +
 + Description:
 +  The `Modules` template parameter is used directly with `jaster.cli.binder.ArgBinder` to provide the arg binding functionality.
 +  Please refer to `ArgBinder`'s documentation if you are wanting to use custom made binder funcs.
 +
 +  Commands are detected by looking over every module in `Modules`, and within each module looking for types marked with `@Command`.
 +
 + Patterns:
 +  Patterns are pretty simple.
 +
 +  Example #1: The pattern "run" will match if the given command line args starts with "run".
 +
 +  Example #2: The pattern "run all" will match if the given command line args starts with "run all" (["run all"] won't work right now, only ["run", "all"] will)
 +
 +  Example #3: The pattern "r|run" will match if the given command line args starts with "r", or "run all".
 +
 +  Patterns with spaces are only allowed inside of `@Command` pattern UDAs. The `@CommandNamedArg` UDA is a bit more special.
 +
 +  For `@CommandNamedArg`, spaces are not allowed, since named arguments can't be split into spaces.
 +
 +  For `@CommandNamedArg`, patterns or subpatterns (When "|" is used to have multiple patterns) will be treated differently depending on their length.
 +  For patterns with only 1 character, they will be matched using short-hand argument form (See `ArgPullParser`'s documentation).
 +  For pattern with more than 1 character, they will be matched using long-hand argument form.
 +
 +  Example #4: The pattern (for `@CommandNamedArg`) "v|verbose" will match when either "-v" or "--verbose" is used.
 +
 + Commands:
 +  A command is a struct or class (class support coming soon) that is marked with `@Command`.
 +
 +  Commands have only one requirement - They have a function called `onExecute`.
 +
 +  The `onExecute` function is called whenever the command's pattern is matched with the command line arguments.
 +
 +  The `onExecute` function must be compatible with one of these signatures:
 +      `void onExecute();`
 +      `int onExecute();`
 +
 +  The signature that returns an `int` is used to return a custom status code.
 +
 +  If a command has it's pattern matched, then it's arguments will be parsed before `onExecute` is called.
 +
 +  Arguments are either positional (`@CommandPositionalArg`) or named (`@CommandNamedArg`).
 +
 + Positional_Arguments:
 +  A positional arg is an argument that appears in a certain 'position'. For example, imagine we had a command that we wanted to
 +  execute by using `"myTool create SomeFile.txt \"This is some content\""`.
 +
 +  The shell will pass `["create", "SomeFile.txt", "This is some content"]` to our program. We will assume we already have a command that will match with "create".
 +  We are then left with the other two strings.
 +
 +  `"SomeFile.txt"` is in the 0th position, so it's value will be binded to the field marked with `@CommandPositionalArg(0)`.
 +
 +  `"This is some content"` is in the 1st position, so it's value will be binded to the field marked with `@CommandNamedArg(1)`.
 +
 + Named_Arguments:
 +  A named arg is an argument that follows a name. Names are either in long-hand form ("--file") or short-hand form ("-f").
 +
 +  For example, imagine we execute a custom tool with `"myTool create -f=SomeFile.txt --content \"This is some content\""`.
 +
 +  The shell will pass `["create", "-f=SomeFile.txt", "--content", "This is some content"]`. Notice how the '-f' uses an '=' sign, but '--content' doesn't.
 +  This is because the `ArgPullParser` supports various different forms of named arguments (e.g. ones that use '=', and ones that don't).
 +  Please refer to it's documentation for more information.
 +
 +  Imagine we already have a command made that matches with "create". We are then left with the rest of the arguments.
 +
 +  "-f=SomeFile.txt" is parsed as an argument called "f" with the value "SomeFile.txt". Using the logic specified in the "Binding Arguments" section (below), 
 +  we perform the binding of "SomeFile.txt" to whichever field marked with `@CommandNamedArg` matches with the name "f".
 +
 +  ["--content", "This is some content"] is parsed as an argument called "content" with the value "This is some content". We apply the same logic as above.
 +
 + Binding_Arguments:
 +  Once we have matched a field marked with either `@CommandPositionalArg` or `@CommandNamedArg` with a position or name (respectively), then we
 +  need to bind the value to the field.
 +
 +  This is where the `ArgBinder` is used. First of all, please refer to it's documentation as it's kind of important.
 +  Second of all, we esentially generate a call similar to: `ArgBinderInstance.bind(myCommandInstance.myMatchedField, valueToBind)`
 +
 +  So imagine we have this field inside a command - `@CommandPositionalArg(0) myIntField;`
 +
 +  Now imagine we have the value "200" in the 0th position. This means it'll be matchd with `myIntField`.
 +
 +  This will esentially generate this call: `ArgBinderInstance.bind(myCommandInstance.myIntField, "200")`
 +
 +  From there, ArgBinder will do it's thing of binding/converting the string "200" into the integer 200
 +
 + Optional_And_Required_Arguments:
 +  By default, all arguments are required.
 +
 +  To make an optional argument, you must make it `Nullable`. For example, to have an optional in argument you'd use `Nullable!int` as the type.
 +
 +  Note that `Nullable` is publicly imported by this module, for ease of use.
 +
 +  Before a nullable argument is binded, it is first lowered down into it's base type before being passed to the `ArgBinder`.
 +  In other words, a `Nullable!int` argument will be treated as a normal `int` by the ArgBinder.
 +
 +  If there is a single required argument that is not provided by the user, then an exception is thrown (which in turn ends up showing an error message).
 +  This does not occur with missing optional arguments.
 +
 + Params:
 +  Modules = The modules that contain the commands and/or binder funcs to use.
 + +/
final class CommandLineInterface(Modules...)
{
    alias CommandExecuteFunc    = int function(ArgPullParser, ref string errorMessageIfThereWasOne);
    alias ArgValueSetterFunc(T) = void function(ArgToken, ref T);
    alias ArgBinderInstance     = ArgBinder!Modules;

    struct CommandInfo
    {
        Command pattern;
        HelpTextBuilderSimple helpText;
        CommandExecuteFunc doExecute;
    }

    // BUG?: Apparently the below code causes param mis-match errors. Compiler bug?
    // struct ArgInfo(UDA, T)
    // {
    //     UDA uda;
    //     ArgValueSetterFunc!T setter;
    //     bool wasFound; // For nullables, this is ignore. Otherwise, anytime this is false we need to throw.
    //     bool isNullable;
    //     bool isBool;
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
        bool isBool;
    }

    struct PositionalArgInfo(T)
    {
        CommandPositionalArg uda;
        ArgValueSetterFunc!T setter;
        bool wasFound; // For nullables, this is ignore. Otherwise, anytime this is false we need to throw.
        bool isNullable;
        bool isBool;
    }

    /+ VARIABLES +/
    private
    {
        CommandInfo[] _commands;
    }

    /+ PUBLIC INTERFACE +/
    public final
    {
        ///
        this()
        {
            static foreach(mod; Modules)
                this.addCommandsFromModule!mod();
        }
        
        /++
         + Parses the given `args`, and then executes the appropriate command (if one was found).
         +
         + Notes:
         +  If an exception is thrown, the error message is displayed on screen (as well as the stack trace, for non-release builds)
         +  and then -1 is returned.
         +
         + See_Also:
         +  The documentation for `ArgPullParser` to understand the format for `args`.
         +
         + Params:
         +  args = The args to parse.
         +
         + Returns:
         +  The status code returned by the command, or -1 if an exception is thrown.
         + +/
        int parseAndExecute(string[] args)
        {
            return this.parseAndExecute(ArgPullParser(args));
        } 

        /// ditto
        int parseAndExecute(ArgPullParser args)
        {
            import std.algorithm : filter;
            import std.exception : enforce;
            import std.stdio     : writefln;

            auto result = this._commands.filter!(c => matchSpacefullPattern(c.pattern.value, /*ref*/ args));
            enforce(!result.empty, "Unknown command: "~args.front.value);

            string errorMessage;
            auto statusCode = result.front.doExecute(args, /*ref*/ errorMessage);

            if(errorMessage !is null)
            {
                writefln("ERROR: %s", errorMessage);
                writefln(result.front.helpText.toString());
            }

            return statusCode;
        }
    }

    /+ PRIVATE FUNCTIONS +/
    private final
    {
        void addCommandsFromModule(alias Module)()
        {
            import std.traits : getSymbolsByUDA;

            static foreach(symbol; getSymbolsByUDA!(Module, Command))
            {
                static assert(is(symbol == struct), 
                    "Only structs can be marked with @Command (classes soon). Issue Symbol = " ~ __traits(identifier, symbol)
                );

                pragma(msg, "Found command: ", __traits(identifier, symbol));
                this.addCommand!symbol();
            }
        }

        void addCommand(alias T)()
        if(is(T == struct))
        {
            CommandInfo info;
            info.helpText  = this.createHelpText!T();
            info.pattern   = getSingleUDA!(T, Command);
            info.doExecute = this.createCommandExecuteFunc!T();
            this._commands ~= info;
        }

        HelpTextBuilderSimple createHelpText(alias T)()
        {
            import std.algorithm : splitter;
            import std.array     : array;

            // Get arg info.
            NamedArgInfo!T[] namedArgs;
            PositionalArgInfo!T[] positionalArgs;
            /*static member*/ getArgs(/*ref*/ namedArgs, /*ref*/ positionalArgs);

            // Get UDA
            enum UDA = getSingleUDA!(T, Command);
            auto builder = new HelpTextBuilderSimple();

            foreach(arg; namedArgs)
            {
                builder.addNamedArg(
                    arg.uda.pattern.splitter('|')
                                   .array,
                    arg.uda.description,
                    cast(ArgIsOptional)arg.isNullable
                );
            }

            foreach(arg; positionalArgs)
            {
                builder.addPositionalArg(
                    arg.uda.position,
                    arg.uda.description,
                    cast(ArgIsOptional)arg.isNullable,
                    arg.uda.name
                );
            }

            builder.commandName = UDA.value;
            builder.description = UDA.description;

            return builder;
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
                for(; !parser.empty; parser.popFront())
                {
                    const token = parser.front;
                    final switch(token.type) with(ArgTokenType)
                    {
                        case Text:
                            enforce(positionalArgIndex < positionalArgs.length, "Stray positional arg found: '"~token.value~"'");
                            positionalArgs[positionalArgIndex].setter(token, /*ref*/ commandInstance);
                            positionalArgs[positionalArgIndex++].wasFound = true;
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
                            
                            if(result.isBool) // Bools don't need to have a value specified, they just have to exist.
                                result.setter(ArgToken("true", ArgTokenType.Text), /*ref*/ commandInstance);
                            else
                            {
                                parser.popFront();
                                enforce(parser.front.type != ArgTokenType.EOF,
                                    "Named arg '"~result.uda.pattern~"' was specified, but wasn't given a value."
                                );

                                result.setter(parser.front, /*ref*/ commandInstance);
                            }
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
                        arg.isBool     = is(SymbolType == bool) || is(SymbolType == Nullable!bool);

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

    @Command("execute t|execute test|et|e test")
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

        int onExecute()
        {
            import std.conv : to;
            
            return (b.isNull || !c.isNull) ? 0
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
        assert(cli.parseAndExecute(["e", "test", "20", "-a 20", "-c"])     == 0); // -c is used
    }
}