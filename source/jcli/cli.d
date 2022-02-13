module jcli.cli;

import jcli;

import std.algorithm;
import std.stdio : writefln, writeln;
import std.array;

// Needs a complete rewrite
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
            {
                this._resolver.add(
                    pattern.splitter(' ').array, 
                    info, 
                    &(AutoComplete!CommandT()).complete
                );
            }
            this._uniqueCommands ~= info;
        }
        else
            this._default = info;
    }

    private CommandExecute getOnExecute(alias CommandT)()
    {
        return (Tokenizer parser) 
        {
            alias CommandParser = jcli.commandparser.CommandParser!(CommandT, bindArgument);
            static DefaultParseErrorHandler dummy = DefaultParseErrorHandler();
            auto result = CommandParser.parse(parser, dummy);

            import std.exception : enforce;
            enforce(result.isOk);

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