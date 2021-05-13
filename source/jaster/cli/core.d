/// The default core provided by JCLI, the 'heart' of your command line tool.
module jaster.cli.core;

private
{
    import std.typecons : Flag;
    import std.traits   : isSomeChar, hasUDA;
    import jaster.cli.parser, jaster.cli.udas, jaster.cli.binder, jaster.cli.helptext, jaster.cli.resolver, jaster.cli.infogen, jaster.cli.commandparser, jaster.cli.result;
    import jaster.ioc;
}

public
{
    import std.typecons : Nullable;
}

/// 
alias IgnoreFirstArg = Flag!"ignoreFirst";

private alias CommandExecuteFunc = Result!int delegate(ArgPullParser parser, scope ref ServiceScope services, HelpTextBuilderSimple helpText);
private alias CommandCompleteFunc = void delegate(string[] before, string current, string[] after, ref char[] output);

/// See `CommandLineSettings.sink`
alias CommandLineSinkFunc = void delegate(string text);

/++
 + A service that allows commands to access the `CommandLineInterface.parseAndExecute` function of the command's `CommandLineInterface`.
 +
 + Notes:
 +  You **must** use `addCommandLineInterfaceService` to add the default implementation of this service into your `ServiceProvider`, you can of course
 +  create your own implementation, but note that `CommandLineInterface` has special support for the default implementation.
 +
 +  Alternatively, don't pass a `ServiceProvider` into your `CommandLineInterface`, and it'll create this service by itself.
 + ++/
interface ICommandLineInterface
{
    /// See: `CommandLineInterface.parseAndExecute`
    int parseAndExecute(string[] args, IgnoreFirstArg ignoreFirst = IgnoreFirstArg.yes);
}

private final class ICommandLineInterfaceImpl : ICommandLineInterface
{
    alias ParseAndExecuteT = int delegate(string[], IgnoreFirstArg);

    private ParseAndExecuteT _func;

    override int parseAndExecute(string[] args, IgnoreFirstArg ignoreFirst = IgnoreFirstArg.yes)
    {
        return this._func(args, ignoreFirst);
    }
}

/++
 + Returns:
 +  A Singleton `ServiceInfo` providing the default implementation for `ICommandLineInterface`.
 + ++/
ServiceInfo addCommandLineInterfaceService()
{
    return ServiceInfo.asSingleton!(ICommandLineInterface, ICommandLineInterfaceImpl);
}

/// ditto.
ServiceInfo[] addCommandLineInterfaceService(ref ServiceInfo[] services)
{
    services ~= addCommandLineInterfaceService();
    return services;
}

/+ COMMAND INFO CREATOR FUNCTIONS +/
private HelpTextBuilderSimple createHelpText(alias CommandT, alias ArgBinderInstance)(string appName)
{
    import jaster.cli.commandhelptext;
    return CommandHelpText!(CommandT, ArgBinderInstance).init.toBuilder(appName);
}

private CommandCompleteFunc createCommandCompleteFunc(alias CommandT, alias ArgBinderInstance)()
{
    import std.algorithm : filter, map, startsWith, splitter, canFind;
    import std.exception : assumeUnique;

    enum Info = getCommandInfoFor!(CommandT, ArgBinderInstance);

    return (string[] before, string current, string[] after, ref char[] output)
    {
        // Check if there's been a null ("--") or '-' ("---"), and if there has, don't bother with completion.
        // Because anything past that is of course, the raw arg list.
        if(before.canFind(null) || before.canFind("-"))
            return;

        // See if the previous value was a non-boolean argument.
        const justBefore               = ArgPullParser(before[$-1..$]).front;
        auto  justBeforeNamedArgResult = Info.namedArgs.filter!(a => a.uda.pattern.matchSpaceless(justBefore.value));
        if((justBefore.type == ArgTokenType.LongHandArgument || justBefore.type == ArgTokenType.ShortHandArgument)
        && (!justBeforeNamedArgResult.empty && justBeforeNamedArgResult.front.parseScheme != CommandArgParseScheme.bool_))
        {
            // TODO: In the future, add support for specifying values to a parameter, either static and/or dynamically.
            return;
        }

        // Otherwise, we either need to autocomplete an argument's name, or something else that's predefined.

        string[] names;
        names.reserve(Info.namedArgs.length * 2);

        foreach(arg; Info.namedArgs)
        {
            foreach(pattern; arg.uda.pattern.byEach)
            {
                // Reminder: Confusingly for this use case, arguments don't have their leading dashes in the before and after arrays.
                if(before.canFind(pattern) || after.canFind(pattern))
                    continue;

                names ~= pattern;
            }
        }

        foreach(name; names.filter!(n => n.startsWith(current)))
        {
            output ~= (name.length == 1) ? "-" : "--";
            output ~= name;
            output ~= ' ';
        }
    };
}

private CommandExecuteFunc createCommandExecuteFunc(alias CommandT, alias ArgBinderInstance)(CommandLineSettings settings)
{
    import std.format    : format;
    import std.algorithm : filter, map;
    import std.exception : enforce, collectException;

    enum Info = getCommandInfoFor!(CommandT, ArgBinderInstance);

    // This is expecting the parser to have already read in the command's name, leaving only the args.
    return (ArgPullParser parser, scope ref ServiceScope services, HelpTextBuilderSimple helpText)
    {
        if(containsHelpArgument(parser))
        {
            settings.sink.get()(helpText.toString() ~ '\n');
            return Result!int.success(0);
        }

        // Cross-stage state.
        CommandT commandInstance;

        // Create the command and fetch its arg info.
        commandInstance = Injector.construct!CommandT(services);
        static if(is(T == class))
            assert(commandInstance !is null, "Dependency injection failed somehow.");

        // Execute stages
        auto commandParser = CommandParser!(CommandT, ArgBinderInstance)();
        auto parseResult = commandParser.parse(parser, commandInstance);
        if(!parseResult.isSuccess)
            return Result!int.failure(parseResult.asFailure.error);

        return onExecuteRunCommand!CommandT(/*ref*/ commandInstance);
    };
}

private Result!int onExecuteRunCommand(alias T)(ref T commandInstance)
{
    static assert(
        __traits(compiles, commandInstance.onExecute())
     || __traits(compiles, { int code = commandInstance.onExecute(); }),
        "Unable to call the `onExecute` function for command `"~__traits(identifier, T)~"` please ensure it's signature matches either:"
        ~"\n\tvoid onExecute();"
        ~"\n\tint onExecute();"
    );

    try
    {
        static if(__traits(compiles, {int i = commandInstance.onExecute();}))
            return Result!int.success(commandInstance.onExecute());
        else
        {
            commandInstance.onExecute();
            return Result!int.success(0);
        }
    }
    catch(Exception ex)
    {
        auto error = ex.msg;
        debug error ~= "\n\nSTACK TRACE:\n" ~ ex.info.toString(); // trace info
        return Result!int.failure(error);
    }
}


/++
 + Settings that can be provided to `CommandLineInterface` to change certain behaviour.
 + ++/
struct CommandLineSettings
{
    /++
     + The name of your application, this is only used when displaying error messages and help text.
     +
     + If left as `null`, then the executable's name is used instead.
     + ++/
    Nullable!string appName;

    /++
     + Whether or not `CommandLineInterface` should provide bash completion. Defaults to `false`.
     +
     + See_Also: The README for this project.
     + ++/
    bool bashCompletion = false;

    /++
     + A user-defined sink to call whenever `CommandLineInterface` itself (not it's subcomponents or commands) wants to
     + output text.
     +
     + If left as `null`, then a default sink is made where `std.stdio.write` is used.
     +
     + Notes:
     +  Strings passed to this function will already include a leading new line character where needed.
     + ++/
    Nullable!CommandLineSinkFunc sink;
}

/++
 + Provides the functionality of parsing command line arguments, and then calling a command.
 +
 + Description:
 +  The `Modules` template parameter is used directly with `jaster.cli.binder.ArgBinder` to provide the arg binding functionality.
 +  Please refer to `ArgBinder`'s documentation if you are wanting to use custom made binder funcs.
 +
 +  Commands are detected by looking over every module in `Modules`, and within each module looking for types marked with `@Command` and matching their patterns
 +  to the given input.
 +
 + Patterns:
 +  Patterns are pretty simple.
 +
 +  Example #1: The pattern "run" will match if the given command line args starts with "run".
 +
 +  Example #2: The pattern "run all" will match if the given command line args starts with "run all" (["run all"] won't work right now, only ["run", "all"] will)
 +
 +  Example #3: The pattern "r|run" will match if the given command line args starts with "r", or "run".
 +
 +  Longer patterns take higher priority than shorter ones.
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
 +  Internally, `CommandResolver` is used to perform command resolution, and a solution custom to `CommandLineInterface` is used for everything else
 +  regarding patterns.
 +
 +  Patterns are normally case sensitive ("abc" != "abC"), but that can be changed for named arguments by attaching `@(CommandArgCase.insensitive)` to 
 +  a named argument. e.g. `@CommandNamedArg("ABC") @(CommandArgCase.insensitive) int abc;` would match any variation of "ABC".
 +
 + Commands:
 +  A command is a struct or class that is marked with `@Command`.
 +
 +  A default command can be specified using `@CommandDefault` instead.
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
 +  If a command has its pattern matched, then its arguments will be parsed before `onExecute` is called.
 +
 +  Arguments are either positional (`@CommandPositionalArg`) or named (`@CommandNamedArg`).
 +
 + Dependency_Injection:
 +  Whenever a command object is created, it is created using dependency injection (via the `jioc` library).
 +
 +  Each command is given its own service scope, even when a command calls another command.
 +
 + Positional_Arguments:
 +  A positional arg is an argument that appears in a certain 'position'. For example, imagine we had a command that we wanted to
 +  execute by using `"myTool create SomeFile.txt \"This is some content\""`.
 +
 +  The shell will pass `["create", "SomeFile.txt", "This is some content"]` to our program. We will assume we already have a command that will match with "create".
 +  We are then left with the other two strings.
 +
 +  `"SomeFile.txt"` is in the 0th position, so its value will be binded to the field marked with `@CommandPositionalArg(0)`.
 +
 +  `"This is some content"` is in the 1st position, so its value will be binded to the field marked with `@CommandPositionalArg(1)`.
 +
 + Named_Arguments:
 +  A named arg is an argument that follows a name. Names are either in long-hand form ("--file") or short-hand form ("-f").
 +
 +  For example, imagine we execute a custom tool with `"myTool create -f=SomeFile.txt --content \"This is some content\""`.
 +
 +  The shell will pass `["create", "-f=SomeFile.txt", "--content", "This is some content"]`. Notice how the '-f' uses an '=' sign, but '--content' doesn't.
 +  This is because the `ArgPullParser` supports various different forms of named arguments (e.g. ones that use '=', and ones that don't).
 +  Please refer to its documentation for more information.
 +
 +  Imagine we already have a command made that matches with "create". We are then left with the rest of the arguments.
 +
 +  "-f=SomeFile.txt" is parsed as an argument called "f" with the value "SomeFile.txt". Using the logic specified in the "Binding Arguments" section (below), 
 +  we perform the binding of "SomeFile.txt" to whichever field marked with `@CommandNamedArg` matches with the name "f".
 +
 +  `["--content", "This is some content"]` is parsed as an argument called "content" with the value "This is some content". We apply the same logic as above.
 +
 + Binding_Arguments:
 +  Once we have matched a field marked with either `@CommandPositionalArg` or `@CommandNamedArg` with a position or name (respectively), then we
 +  need to bind the value to the field.
 +
 +  This is where the `ArgBinder` is used. First of all, please refer to its documentation as it's kind of important.
 +  Second of all, we esentially generate a call similar to: `ArgBinderInstance.bind(myCommandInstance.myMatchedField, valueToBind)`
 +
 +  So imagine we have this field inside a command - `@CommandPositionalArg(0) int myIntField;`
 +
 +  Now imagine we have the value "200" in the 0th position. This means it'll be matchd with `myIntField`.
 +
 +  This will esentially generate this call: `ArgBinderInstance.bind(myCommandInstance.myIntField, "200")`
 +
 +  From there, ArgBinder will do its thing of binding/converting the string "200" into the integer 200.
 +
 +  `ArgBinder` has support for user-defined binders (in fact, all of the built-in binders use this mechanism!). Please
 +  refer to its documentation for more information, or see example-04.
 +
 +  You can also specify validation for arguments, by attaching structs (that match the definition specified in `ArgBinder`'s documentation) as
 +  UDAs onto your fields.
 +
 +  $(B Beware) you need to attach your validation struct as `@Struct()` (or with args) and not `@Struct`, notice the first one has parenthesis.
 +
 + Boolean_Binding:
 +  Bool arguments have special logic in place.
 +
 +  By only passing the name of a boolean argument (e.g. "--verbose"), this is treated as setting "verbose" to "true" using the `ArgBinder`.
 +
 +  By passing a value alongside a boolean argument that is either "true" or "false" (e.g. "--verbose true", "--verbose=false"), then the resulting
 +  value is passed to the `ArgBinder` as usual. In other words, "--verbose" is equivalent to "--verbose true".
 +
 +  By passing a value alongside a boolean argument that $(B isn't) one of the preapproved words then: The value will be treated as a positional argument;
 +  the boolean argument will be set to true.
 +
 +  For example, "--verbose" sets "verbose" to "true". Passing "--verbose=false/true" will set "verbose" to "false" or "true" respectively. Passing
 +  "--verbose push" would leave "push" as a positional argument, and then set "verbose" to "true".
 +
 +  These special rules are made so that boolean arguments can be given an explicit value, without them 'randomly' treating positional arguments as their value.
 +
 + Optional_And_Required_Arguments:
 +  By default, all arguments are required.
 +
 +  To make an optional argument, you must make it `Nullable`. For example, to have an optional `int` argument you'd use `Nullable!int` as the type.
 +
 +  Note that `Nullable` is publicly imported by this module, for ease of use.
 +
 +  Before a nullable argument is binded, it is first lowered down into its base type before being passed to the `ArgBinder`.
 +  In other words, a `Nullable!int` argument will be treated as a normal `int` by the ArgBinder.
 +
 +  If **any** required argument is not provided by the user, then an exception is thrown (which in turn ends up showing an error message).
 +  This does not occur with missing optional arguments.
 +
 + Raw_Arguments:
 +  For some applications, they may allow the ability for the user to provide a set of unparsed arguments. For example, dub allows the user
 +  to provide a set of arguments to the resulting output, when using the likes of `dub run`, e.g. `dub run -- value1 value2 etc.`
 +
 +  `CommandLineInterface` also provides this ability. You can use either the double dash like in dub ('--') or a triple dash (legacy reasons, '---').
 +
 +  After that, as long as your command contains a `string[]` field marked with `@CommandRawListArg`, then any args after the triple dash are treated as "raw args" - they
 +  won't be parsed, passed to the ArgBinder, etc. they'll just be passed into the variable as-is.
 +
 +  For example, you have the following member in a command `@CommandRawListArg string[] rawList;`, and you are given the following command - 
 +  `["command", "value1", "--", "rawValue1", "rawValue2"]`, which will result in `rawList`'s value becoming `["rawValue1", "rawValue2"]`
 +
 + Arguments_Groups:
 +  Arguments can be grouped together so they are displayed in a more logical manner within your command's help text.
 +
 +  The recommended way to make an argument group, is to create an `@CommandArgGroup` UDA block:
 +
 +  ```
 +  @CommandArgGroup("Debug", "Flags relating the debugging.")
 +  {
 +      @CommandNamedArg("trace|t", "Enable tracing") Nullable!bool trace;
 +      ...
 +  }
 +  ```
 +
 +  While you *can* apply the UDA individually to each argument, there's one behaviour that you should be aware of - the group's description
 +  as displayed in the help text will use the description of the $(B last) found `@CommandArgGroup` UDA.
 +
 + Params:
 +  Modules = The modules that contain the commands and/or binder funcs to use.
 +
 + See_Also:
 +  `jaster.cli.infogen` if you'd like to introspect information about commands yourself.
 +
 +  `jaster.cli.commandparser` if you only require the ability to parse commands.
 + +/
final class CommandLineInterface(Modules...)
{
    private alias DefaultCommands = getSymbolsByUDAInModules!(CommandDefault, Modules);
    static assert(DefaultCommands.length <= 1, "Multiple default commands defined " ~ DefaultCommands.stringof);

    static if(DefaultCommands.length > 0)
    {
        static assert(is(DefaultCommands[0] == struct) || is(DefaultCommands[0] == class),
            "Only structs and classes can be marked with @CommandDefault. Issue Symbol = " ~ __traits(identifier, DefaultCommands[0])
        );
        static assert(!hasUDA!(DefaultCommands[0], Command),
            "Both @CommandDefault and @Command are used for symbol " ~ __traits(identifier, DefaultCommands[0])
        );
    }

    alias ArgBinderInstance = ArgBinder!Modules;

    private enum Mode
    {
        execute,
        complete,
        bashCompletion
    }

    private enum ParseResultType
    {
        commandFound,
        commandNotFound,
        showHelpText
    }

    private struct ParseResult
    {
        ParseResultType type;
        CommandInfo     command;
        string          helpText;
        ArgPullParser   argParserAfterAttempt;
        ArgPullParser   argParserBeforeAttempt;
        ServiceScope    services;
    }

    private struct CommandInfo
    {
        Pattern               pattern; // Patterns (and their helper functions) are still being kept around, so previous code can work unimpeded from the migration to CommandResolver.
        string                description;
        HelpTextBuilderSimple helpText;
        CommandExecuteFunc    doExecute;
        CommandCompleteFunc   doComplete;
    }

    /+ VARIABLES +/
    private
    {
        CommandResolver!CommandInfo _resolver;
        CommandLineSettings         _settings;
        ServiceProvider             _services;
        Nullable!CommandInfo        _defaultCommand;
    }

    /+ PUBLIC INTERFACE +/
    public final
    {
        this(ServiceProvider services = null)
        {
            this(CommandLineSettings.init, services);
        }

        /++
         + Params:
         +  services = The `ServiceProvider` to use for dependency injection.
         +             If this value is `null`, then a new `ServiceProvider` will be created containing an `ICommandLineInterface` service.
         + ++/
        this(CommandLineSettings settings, ServiceProvider services = null)
        {
            import std.algorithm : sort;
            import std.file      : thisExePath;
            import std.path      : baseName;
            import std.stdio     : write;

            if(settings.appName.isNull)
                settings.appName = thisExePath.baseName;

            if(settings.sink.isNull)
                settings.sink = (string str) { write(str); };

            if(services is null)
                services = new ServiceProvider([addCommandLineInterfaceService()]);

            this._services = services;
            this._settings = settings;
            this._resolver = new CommandResolver!CommandInfo();

            addDefaultCommand();

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
         +  args        = The args to parse.
         +  ignoreFirst = Whether to ignore the first value of `args` or not.
         +                If `args` is passed as-is from the main function, then the first value will
         +                be the path to the executable, and should be ignored.
         +
         + Returns:
         +  The status code returned by the command, or -1 if an exception is thrown.
         + +/
        int parseAndExecute(string[] args, IgnoreFirstArg ignoreFirst = IgnoreFirstArg.yes)
        {
            if(ignoreFirst)
            {
                if(args.length <= 1)
                    args.length = 0;
                else
                    args = args[1..$];
            }

            return this.parseAndExecute(ArgPullParser(args));
        } 

        /// ditto
        int parseAndExecute(ArgPullParser args)
        {
            import std.algorithm : filter, any;
            import std.exception : enforce;
            import std.format    : format;

            if(args.empty && this._defaultCommand.isNull)
            {
                this.writeln(this.makeErrorf("No command was given."));
                this.writeln(this.createAvailableCommandsHelpText(args, "Available commands").toString());
                return -1;
            }

            Mode mode = Mode.execute;

            if(this._settings.bashCompletion && args.front.type == ArgTokenType.Text)
            {
                if(args.front.value == "__jcli:complete")
                    mode = Mode.complete;
                else if(args.front.value == "__jcli:bash_complete_script")
                    mode = Mode.bashCompletion;
            }

            ParseResult parseResult;

            parseResult.argParserBeforeAttempt = args; // If we can't find the exact command, sometimes we can get a partial match when showing help text.
            parseResult.type                   = ParseResultType.commandFound; // Default to command found.
            auto result                        = this._resolver.resolveAndAdvance(args);

            if(!result.success || result.value.type == CommandNodeType.partialWord)
            {
                if(args.containsHelpArgument())
                {
                    parseResult.type = ParseResultType.showHelpText;
                    if(!this._defaultCommand.isNull)
                        parseResult.helpText ~= this._defaultCommand.get.helpText.toString();

                    if(this._resolver.finalWords.length > 0)
                        parseResult.helpText ~= this.createAvailableCommandsHelpText(parseResult.argParserBeforeAttempt, "Available commands").toString();
                }
                else if(this._defaultCommand.isNull)
                {
                    parseResult.type      = ParseResultType.commandNotFound;
                    parseResult.helpText ~= this.makeErrorf("Unknown command '%s'.\n", parseResult.argParserBeforeAttempt.front.value);
                    parseResult.helpText ~= this.createAvailableCommandsHelpText(parseResult.argParserBeforeAttempt).toString();
                }
                else
                    parseResult.command = this._defaultCommand.get;
            }
            else
                parseResult.command = result.value.userData;

            parseResult.argParserAfterAttempt = args;
            parseResult.services              = this._services.createScope(); // Reminder: ServiceScope uses RAII.

            // Special support: For our default implementation of `ICommandLineInterface`, set its value.
            auto proxy = cast(ICommandLineInterfaceImpl)parseResult.services.getServiceOrNull!ICommandLineInterface();
            if(proxy !is null)
                proxy._func = &this.parseAndExecute;

            final switch(mode) with(Mode)
            {
                case execute:        return this.onExecute(parseResult);
                case complete:       return this.onComplete(parseResult);
                case bashCompletion: return this.onBashCompletionScript();
            }
        }
    }

    /+ COMMAND DISCOVERY AND REGISTRATION +/
    private final
    {
        void addDefaultCommand()
        {
            static if(DefaultCommands.length > 0)
                _defaultCommand = getCommand!(DefaultCommands[0]);
        }

        void addCommandsFromModule(alias Module)()
        {
            import std.traits : getSymbolsByUDA;

            static foreach(symbol; getSymbolsByUDA!(Module, Command))
            {{
                static assert(is(symbol == struct) || is(symbol == class),
                    "Only structs and classes can be marked with @Command. Issue Symbol = " ~ __traits(identifier, symbol)
                );

                enum Info = getCommandInfoFor!(symbol, ArgBinderInstance);

                auto info = getCommand!(symbol);
                info.pattern = Info.pattern;
                info.description = Info.description;

                foreach(pattern; info.pattern.byEach)
                    this._resolver.define(pattern, info);
            }}
        }

        CommandInfo getCommand(T)()
        {
            CommandInfo info;
            info.helpText   = createHelpText!(T, ArgBinderInstance)(this._settings.appName.get);
            info.doExecute  = createCommandExecuteFunc!(T, ArgBinderInstance)(this._settings);
            info.doComplete = createCommandCompleteFunc!(T, ArgBinderInstance)();

            return info;
        }
    }

    /+ MODE EXECUTORS +/
    private final
    {
        int onExecute(ref ParseResult result)
        {
            final switch(result.type) with(ParseResultType)
            {
                case showHelpText:
                    this.writeln(result.helpText);
                    return 0;

                case commandNotFound:
                    this.writeln(result.helpText);
                    return -1;

                case commandFound: break;
            }

            auto statusCode = result.command.doExecute(result.argParserAfterAttempt, result.services, result.command.helpText);
            if(!statusCode.isSuccess)
            {
                this.writeln(this.makeErrorf(statusCode.asFailure.error));
                return -1;
            }

            return statusCode.asSuccess.value;
        }

        int onComplete(ref ParseResult result)
        {
            // Parsing here shouldn't be affected by user-defined ArgBinders, so stuff being done here is done manually.
            // This way we gain reliability.
            //
            // Since this is also an internal function, error checking is much more lax.
            import std.array     : array;
            import std.algorithm : map, filter, splitter, equal, startsWith;
            import std.conv      : to;
            import std.stdio     : writeln; // Planning on moving this into its own component soon, so we'll just leave this writeln here.

            // Expected args:
            //  [0]    = COMP_CWORD
            //  [1..$] = COMP_WORDS
            result.argParserAfterAttempt.popFront(); // Skip __jcli:complete
            auto cword = result.argParserAfterAttempt.front.value.to!uint;
            result.argParserAfterAttempt.popFront();
            auto  words = result.argParserAfterAttempt.map!(t => t.value).array;

            cword -= 1;
            words = words[1..$]; // [0] is the exe name, which we don't care about.
            auto before  = words[0..cword];
            auto current = (cword < words.length)     ? words[cword]      : [];
            auto after   = (cword + 1 < words.length) ? words[cword+1..$] : [];

            auto beforeParser = ArgPullParser(before);
            auto commandInfo  = this._resolver.resolveAndAdvance(beforeParser);

            // Can't find command, so we're in "display command name" mode.
            if(!commandInfo.success || commandInfo.value.type == CommandNodeType.partialWord)
            {
                char[] output;
                output.reserve(1024); // Gonna be doing a good bit of concat.

                // Special case: When we have no text to look for, just display the first word of every command path.
                if(before.length == 0 && current is null)
                    commandInfo.value = this._resolver.root;

                // Otherwise try to match using the existing text.

                // Display the word of all children of the current command word.
                //
                // If the current argument word isn't null, then use that as a further filter.
                //
                // e.g.
                // Before  = ["name"]
                // Pattern = "name get"
                // Output  = "get"
                foreach(child; commandInfo.value.children)
                {
                    if(current.length > 0 && !child.word.startsWith(current))
                        continue;

                    output ~= child.word;
                    output ~= " ";
                }

                writeln(output);
                return 0;
            }

            // Found command, so we're in "display possible args" mode.
            char[] output;
            output.reserve(1024);

            commandInfo.value.userData.doComplete(before, current, after, /*ref*/ output); // We need black magic, so this is generated in addCommand.
            writeln(output);

            return 0;
        }

        int onBashCompletionScript()
        {
            import std.stdio : writefln;
            import std.file  : thisExePath;
            import std.path  : baseName;
            import jaster.cli.views.bash_complete : BASH_COMPLETION_TEMPLATE;

            const fullPath = thisExePath;
            const exeName  = fullPath.baseName;

            writefln(BASH_COMPLETION_TEMPLATE,
                exeName,
                fullPath,
                exeName,
                exeName
            );
            return 0;
        }
    }

    /+ UNCATEGORISED HELPERS +/
    private final
    {
        HelpTextBuilderTechnical createAvailableCommandsHelpText(ArgPullParser args, string sectionName = "Did you mean")
        {
            import std.array     : array;
            import std.algorithm : filter, sort, map, splitter, uniq;

            auto command = this._resolver.root;
            auto result  = this._resolver.resolveAndAdvance(args);
            if(result.success)
                command = result.value;

            auto builder = new HelpTextBuilderTechnical();
            builder.addSection(sectionName)
                   .addContent(
                       new HelpSectionArgInfoContent(
                           command.finalWords
                                  .uniq!((a, b) => a.userData.pattern == b.userData.pattern)
                                  .map!(c => HelpSectionArgInfoContent.ArgInfo(
                                       [c.userData.pattern.byEach.front],
                                       c.userData.description,
                                       ArgIsOptional.no
                                  ))
                                  .array
                                  .sort!"a.names[0] < b.names[0]"
                                  .array, // eww...
                            AutoAddArgDashes.no
                       )
            );

            return builder;
        }

        string makeErrorf(Args...)(string formatString, Args args)
        {
            import std.format : format;
            return "%s: %s".format(this._settings.appName.get, formatString.format(args));
        }

        void writeln(string str)
        {
            assert(!this._settings.sink.isNull, "The ctor should've set this.");

            auto sink = this._settings.sink.get();
            assert(sink !is null, "The sink was set, but it's still null.");

            sink(str);
            sink("\n");
        }
    }
}

// HELPER FUNCS

private bool containsHelpArgument(ArgPullParser args)
{
    import std.algorithm : any;

    return args.any!(t => t.type == ArgTokenType.ShortHandArgument && t.value == "h"
                       || t.type == ArgTokenType.LongHandArgument && t.value == "help");
}

version(unittest)
{
    import jaster.cli.result;
    private alias InstansiationTest = CommandLineInterface!(jaster.cli.core);

    @CommandDefault("This is the default command.")
    private struct DefaultCommandTest
    {
        @CommandNamedArg("var", "A variable")
        int a;

        int onExecute()
        {
            return a % 2 == 0
            ? a
            : 0;
        }
    }

    @("Default command test")
    unittest
    {
        auto cli = new CommandLineInterface!(jaster.cli.core);
        assert(cli.parseAndExecute(["--var 1"], IgnoreFirstArg.no) == 0);
        assert(cli.parseAndExecute(["--var 2"], IgnoreFirstArg.no) == 2);
    }

    @Command("arg group test", "Test arg groups work")
    private struct ArgGroupTestCommand
    {
        @CommandPositionalArg(0)
        string a;

        @CommandNamedArg("b")
        string b;

        @CommandArgGroup("group1", "This is group 1")
        {
            @CommandPositionalArg(1)
            string c;

            @CommandNamedArg("d")
            string d;
        }

        void onExecute(){}
    }
    @("Test that @CommandArgGroup is handled properly.")
    unittest
    {
        import std.algorithm : canFind;

        // Accessing a lot of private state here, but that's because we don't have a mechanism to extract the output properly.
        auto cli = new CommandLineInterface!(jaster.cli.core);
        auto helpText = cli._resolver.resolve("arg group test").value.userData.helpText;

        assert(helpText.toString().canFind(
            "group1:\n"
           ~"    This is group 1\n"
           ~"\n"
           ~"    VALUE"
        ));
    }

    @("Test that CommandLineInterface's sink works")
    unittest
    {
        import std.algorithm : canFind;

        string log;

        CommandLineSettings settings;
        settings.sink = (string str) { log ~= str; };

        auto cli = new CommandLineInterface!(jaster.cli.core)(settings);
        cli.parseAndExecute(["--help"], IgnoreFirstArg.no);

        assert(log.length > 0);
        assert(log.canFind("arg group test"), log); // The name of that unittest command has no real reason to change or to be removed, so I feel safe relying on it.
    }
}
