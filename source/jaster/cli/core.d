module jaster.cli.core;

private
{
    import std.array     : array;
    import std.exception : enforce, assumeUnique;
    import std.algorithm : startsWith, filter, multiSort, SwapStrategy, map, any, countUntil;
    import std.range     : repeat, take;
    import std.format    : format;
    import std.uni       : toLower;
    import std.traits    : fullyQualifiedName, hasUDA, getUDAs, getSymbolsByUDA;
    import std.meta      : staticMap, Filter;
    import std.stdio     : writeln, writefln;
    import std.typecons  : Flag;
    import jaster.cli.udas;
}

template StringToMember(alias mod, string name)
{
    alias StringToMember = __traits(getMember, mod, name);
}

template GetUdaOrDefault(alias Symbol, alias Uda, Uda default_)
{
    static if(hasUDA!(Symbol, Uda))
        enum GetUdaOrDefault = getUDAs!(Symbol, Uda)[0];
    else
        enum GetUdaOrDefault = default_;
}

template GetAllCommands(alias Symbol)
{
    alias MapFunc(string Name) = StringToMember!(Symbol, Name);
    enum  FilterFunc(alias Member) = hasUDA!(Member, Command);
                
    alias GetAllCommands = Filter!(FilterFunc, staticMap!(MapFunc, __traits(allMembers, Symbol)));
}

// It's out here because the compiler throws a wobbly.
enum ArgFilterFunc(alias Member) = hasUDA!(Member, Argument);
template GetAllArugments(alias Symbol)
{    
    alias MapFunc(string Name) = StringToMember!(Symbol, Name);
                
    alias GetAllArugments = Filter!(ArgFilterFunc, staticMap!(MapFunc, __traits(allMembers, Symbol)));
}

alias IgnoreFirstArg = Flag!"ignoreFirst";

private class JCliRunner(CommandModules...)
{
    alias CommandExecuteFunc = void function(ref string[]);

    enum ArgumentType
    {
        Indexed,
        Option
    }

    struct ArgumentInfo
    {
        string name;
        string description;
        string typeNameShort;
        ArgumentType type;
        size_t indexedIndex = size_t.max; // Indexed arguments only.
        bool required;

        string getDisplayNameString()
        {
            return format("%s <%s>", this.name, this.typeNameShort);
        }
    }

    struct CommandInfo
    {
        string group;
        string name;
        string description;

        ArgumentInfo[] args;        
        CommandExecuteFunc onExecute; // Handles creation, arg parsing, and execution.

        string getDisplayNameString()
        {
            return (this.group.length > 0) ? this.group ~ " " ~ this.name : this.name;
        }
    }

    private
    {
        CommandInfo[] _commands;
    }

    this()
    {
        this.parseModules();

        // This is done so help text is generated in the right order.
        this._commands.multiSort!("a.name < b.name", "a.group.length == 0 || a.group < b.group", SwapStrategy.unstable);
    }

    public
    {
        void executeFromArgs(string[] args, IgnoreFirstArg ignoreFirst = IgnoreFirstArg.yes)
        {
            // To avoid having to write logic just to accomadate args being a length of 0 later on, it's easier
            // to just check here.
            if(args.length == 0 || (args.length == 1 && ignoreFirst))
            {
                writeln("ERROR: No arguments were given.");
                writeln(this.createOverallHelpText());
                return;
            }

            // If we're passed args directly from main, then args[0] will be the path to the program, so we just
            // want to ignore it.
            // Unlike std.getopt however, we actually give the user a choice on whether to do this T.T
            if(ignoreFirst)
                args = args[1..$];

            CommandInfo command;

            if(args[0] == "--help" || args[0] == "-h")
            {
                writeln(this.createOverallHelpText());
                return;
            }
            
            // Lookup the command
            try command = this.doLookup(args);
            catch(Exception ex)
            {
                writeln("ERROR: ", ex.msg);
                writeln(this.createOverallHelpText());
                return;
            }

            // This differs from the check just above in that this activates for when "--help" is used for
            // any arg position that isn't the first one (aka, the command arg position).
            if(args.any!(a => a == "--help" || a == "-h"))
            {
                writeln(this.createCommandDetailedHelpText(command));
                return;
            }

            // Then execute it
            try command.onExecute(args);
            catch(Exception ex)
            {
                writeln("ERROR: ", ex.msg);
                writeln(this.createCommandDetailedHelpText(command));

                debug writeln(ex.info);
                return;
            }
        }
    }

    private
    {
        // Help text for all overall commands.
        string createOverallHelpText()
        {
            import std.array : appender;

            // For padding.
            auto largestSize = this._commands.map!(c => c.getDisplayNameString()).getLargestStringSize() + 1; // + 1 since we're including the postfix space.

            auto help = appender!(char[]);
            help.reserve(4096);
            help.put("Commands Available:\n");
            
            foreach(arr; this._commands.map!(c => this.createCommandBriefHelpText(c, largestSize)))
                help.put(arr);

            return help.data.assumeUnique;
        }

        string createCommandBriefHelpText(CommandInfo command, size_t largestSize)
        {
            return format("\t%s%s- %s\n",
                           command.getDisplayNameString(),
                           ' '.repeat(largestSize - command.getDisplayNameString().length),
                           command.description
                         );
        }

        string createCommandDetailedHelpText(CommandInfo command)
        {
            import std.array : appender;
            
            auto largestSize = command.args.map!(a => a.getDisplayNameString()).getLargestStringSize() + 1;
            auto help = appender!(char[]);
            help.reserve(4096);

            // TODO: Change "[Arguments]" to directly include the actual indexed arguments.
            //       e.g. "Usage: ... [arg1] [arg2] <optionalArg3>"
            help.put(format("Usage: %s [Options] [Arguments]\n", command.getDisplayNameString()));

            // TODO: Sort by name.
            help.put("Valid [Options]:\n");
            foreach(arg; command.args.filter!(a => a.type == ArgumentType.Option))
            {
                help.put(format("\t%s%s- %s%s\n",
                    arg.getDisplayNameString(),
                    ' '.repeat(largestSize - arg.getDisplayNameString().length),
                    (arg.required) ? "[Required] " : "",
                    arg.description
                ));
            }

            // TODO: Remove code duplication, or complete the other TODO at the top.
            help.put("Valid [Arguments] In Order:\n");
            foreach(arg; command.args.filter!(a => a.type == ArgumentType.Indexed))
            {
                help.put(format("\t%s%s- %s%s\n",
                    arg.getDisplayNameString(),
                    ' '.repeat(largestSize - arg.getDisplayNameString().length),
                    (arg.required) ? "[Required] " : "",
                    arg.description
                ));
            }

            return help.data.assumeUnique;
        }

        CommandInfo doLookup(ref string[] args)
        {
            /++
            Lookup rules:
                All args are temp converted to lower case for lookup purposes.

                Lookup rules are done in the same order as listed.

                [Command Group]
                - Take the 0th argument.
                - Look over all commands and find all commands that have the 0th argument match their command group.
                - Take the 1st arg (if it exists, otherwise goto the [No Command Group] stage.
                - Look over all commands that match the command group, and then find the command that matches the 1st arg.
                    - TODO: Ensure there are no duplicate commands when parsing modules.
                - Execute the command if it exists, otherwise show an error and the help text.

                [No Command Group]
                - Take the 0th argument
                - Look over all commands for the command that matches the arg.
                - Execute the command if it exists, otherwise show an error and the help text.
            ++/
            
            auto arg = args[0].toLower();
            
            // [Command Group]
            if(args.length > 1)
            {
                auto commandsInGroup = this._commands.filter!(c => c.group == arg);

                if(!commandsInGroup.empty)
                {
                    auto command = commandsInGroup.filter!(c => c.name == args[1].toLower());
                    enforce(!command.empty, format("No command called '%s %s'", arg, args[1]));

                    args.removeAt(0);
                    args.removeAt(0);
                    return command.front;
                }

                // Fall through into [No Command Group]
            }

            // [No Command Group]
            auto command = this._commands.filter!(c => c.name == arg);
            enforce(!command.empty, "No command called '%s'".format(arg));

            args.removeAt(0);
            return command.front;
        }

        void parseModules()
        {
            static foreach(mod; CommandModules)
            {{
                pragma(msg, "[JCli] Info: Processing module "~fullyQualifiedName!mod);

                // Get all commands.
                alias Members = GetAllCommands!mod;
                static if(Members.length == 0)
                    pragma(msg, "[JCli] Warning: Module "~fullyQualifiedName!mod~" contains no commands.");

                // Process all commands.
                static foreach(command; Members)
                {{
                    static assert(
                        is(command == struct), 
                        "Currently, commands can only be structs. Command "~fullyQualifiedName!command~" however is not a struct."
                    );

                    pragma(msg, "[JCli] Info: Found command "~fullyQualifiedName!command);

                    CommandInfo info;
                    info.group       = GetUdaOrDefault!(command, CommandGroup, CommandGroup("")).group;
                    info.name        = GetUdaOrDefault!(command, CommandName, CommandName(__traits(identifier, command))).name;
                    info.description = GetUdaOrDefault!(command, CommandDescription, CommandDescription("N/A")).description;
                    info.onExecute   = this.createOnExecute!command;
                    info.group       = info.group.toLower();
                    info.name        = info.name.toLower();

                    // Process all arguments
                    static foreach(arg; GetAllArugments!command)
                    {{
                        ArgumentInfo argInfo;

                        // TODO: Check to make sure ArgumentIndex and ArgumentOption are mutually exclusive.

                        static if(hasUDA!(arg, ArgumentIndex))
                        {
                            enum IndexInfo = getUDAs!(arg, ArgumentIndex)[0];
                            argInfo.type = ArgumentType.Indexed;
                            argInfo.indexedIndex = IndexInfo.index;
                            argInfo.name = __traits(identifier, arg);
                        }
                        else static if(hasUDA!(arg, ArgumentOption))
                        {
                            enum OptionInfo = getUDAs!(arg, ArgumentOption)[0];
                            argInfo.type = ArgumentType.Option;
                            argInfo.name = OptionInfo.option;
                        }
                        else static assert(false, format("Argument %s doesn't have either @ArgumentOption nor @ArgumentIndex", fullyQualifiedName!arg));

                        argInfo.description = GetUdaOrDefault!(arg, ArgumentDescription, ArgumentDescription("N/A")).description;
                        argInfo.required = hasUDA!(arg, ArgumentRequired);
                        argInfo.typeNameShort = typeof(arg).stringof;
                        info.args ~= argInfo;
                    }}

                    this._commands ~= info;
                }}
            }}
        }

        static CommandExecuteFunc createOnExecute(alias Command)()
        {
            // TODO: For the love of god, split this function up.
            //       I'm 100% sure the actual arg parsing part can be put into it's own function.
            //       The further arg handling afterwards can probably also be moved, it'll just have a ton of parameters.
            alias Arguments         = getSymbolsByUDA!(Command, Argument);
            alias IndexArguments    = Filter!(IsIndexedArgument, Arguments);
            alias OptionArguments   = Filter!(IsOptionArgument, Arguments);
            alias RequiredArguments = Filter!(IsRequiredArgument, Arguments);

            // TODO: Version flag for this, and all other pragma(msg)s. (mostly this one though).
            // Possible TODO: A library that handles this for us.
            debug pragma(msg, format("[JCli] Debug: Out of %s arguments. %s are indexed. %s are options.",
                                     Arguments.length, IndexArguments.length, OptionArguments.length                         
            ));

            return (ref string[] args)
            {
                Command commandObject;

                // If their fully qualified name is still in here, then they haven't been provided yet.
                string[] requiredArgNames;
                static foreach(required; RequiredArguments)
                    requiredArgNames ~= fullyQualifiedName!required;

                // Helper funcs
                void removeArg(ref size_t i, string requiredName = null)
                {
                    args.removeAt(i--);

                    if(requiredName != null)
                    {
                        auto pos = requiredArgNames.countUntil(requiredName);
                        assert(pos != -1);

                        requiredArgNames.removeAt(pos);
                    }
                }

                // For loop instead of foreach since we'll be modifying the array as we go along.
                size_t indexedIndex = 0; // Used to keep track of which indexed argument we're using.
                for(size_t i = 0; i < args.length; i++)
                {
                    // Types of args:
                    //     [Short hand] -c       || -c <Value>       || -c=<Value>       || -c<Value>
                    //     [Full]       --config || --config <Value> || --config=<Value>
                    //               Bool only^^
                    //     [Indexed]    my.exe **arg0** --option **arg1**
                    
                    auto arg = args[i];

                    bool   isIndexed = true;
                    string optionName;      // Option arguments only. The name has the dashes stripped off. Length of 1 is short hand, anymore is long form.
                    string valueString;     // Shared

                    // Full
                    if(arg.startsWith("--"))
                    {
                        enforce(arg.length > 2, "There is a stray '--', likely meaning a messed up long-form argument.");
                        isIndexed = false;
                        
                        // Find where the name ends and the value begins.
                        size_t optionNameEnd = size_t.max; // If it stays size_t.max, that means there's no value attached.
                        char splitChar = '\0';
                        foreach(argI, argChar; arg)
                        {
                            if(argChar == '=' || argChar == ' ')
                            {
                                splitChar = argChar;
                                optionNameEnd = argI;
                                optionName = arg[2..optionNameEnd];
                                break;
                            }
                            else if(argI == arg.length - 1)
                            {
                                optionName = arg[2..$];
                                break;
                            }
                        }

                        // Read in the value.
                        if(splitChar == '=')
                        {
                            size_t valueStringStart = optionNameEnd + 1; // + 1 to skip the = sign.
                            if(optionNameEnd != size_t.max && valueStringStart < arg.length)
                                valueString = arg[valueStringStart..$];
                        }
                        else if(i + 1 < args.length)
                        {
                            // TODO: Think about how this fucks up the boolean ones...
                            //       Only way around it is a forward lookup here, or before, to create a list of names that are boolean values.
                            auto val = args[++i];
                            if(val.startsWith("-") || val.startsWith("--")) // This can be avoided when we have the lookup code done.
                                --i;
                            else
                                valueString = val;
                        }
                    }
                    // Short hand
                    else if(arg.startsWith("-"))
                    {
                        enforce(arg.length > 1, "There is a stray '-', likely meaning a messed up short-hand argument.");
                        isIndexed = false;
                        optionName = arg[1..2];

                        if(arg.length != 2) // If it's 2, then it's likely a boolean option, or has a space between it's argument. (and if not, we validate that a bit later on)
                        {
                            size_t startIndex = (arg[2] == '=')
                                                ? 3 : 2;
                            
                            valueString = arg[startIndex..$];
                        }
                        else if(i + 1 < args.length)
                        {
                            auto val = args[++i];
                            if(val.startsWith("-") || val.startsWith("--")) // This can be avoided when we have the lookup code done.
                                --i;
                            else
                                valueString = val;
                        }
                    }
                    // Indexed
                    else
                    {
                        isIndexed = true;
                        valueString = arg;
                    }

                    // Parse the argument.
                    bool argHandled = false;
                    static foreach(argument; Arguments)
                    {{
                        static if(IsOptionArgument!argument)
                        {
                            enum Option = getUDAs!(argument, ArgumentOption)[0];
                            if(!argHandled && !isIndexed && Option.isValidOption(optionName))
                            {
                                removeArg(i, (IsRequiredArgument!argument) ? fullyQualifiedName!argument : "");
                                parseIntoObject!(Command, argument)(commandObject, valueString);
                                argHandled = true;
                            }
                        }
                        else static if(IsIndexedArgument!argument)
                        {
                            enum Index = getUDAs!(argument, ArgumentIndex)[0];
                            if(!argHandled && isIndexed && indexedIndex == Index.index)
                            {
                                removeArg(i, (IsRequiredArgument!argument) ? fullyQualifiedName!argument : "");
                                indexedIndex++;
                                parseIntoObject!(Command, argument)(commandObject, valueString);
                                argHandled = true;
                            }
                        }
                        else static assert(false, format("Argument %s doesn't have either @ArgumentOption or @ArgumentIndex", fullyQualifiedName!argument));
                    }}
                    
                    if(argHandled)
                        continue;

                    throw new Exception(
                        (isIndexed)
                        ? format("Stray argument: %s | %s", valueString, args)
                        : format("Unrecognised option: %s = %s | %s", optionName, valueString, args)
                    );
                }

                enforce(requiredArgNames.length == 0, format("The following required args are missing: %s", requiredArgNames));

                commandObject.onExecute();
            };
        }

        static void parseIntoObject(alias Command, alias Argument)(ref Command commandObject, string valueString)
        {
            alias ArgType = typeof(Argument);

            void setValue(T)(T value)
            {
                mixin("commandObject."~__traits(identifier, Argument)~" = value;");
            }

            static if(is(ArgType == string))
                setValue(valueString);
            else static assert(false, "Unsupported argument type: "~ArgType.stringof~" for arg "~__traits(identifier, Argument));
        }
    }
}

// These have to be global otherwise the compiler shouts at me.
enum IsIndexedArgument(alias Symbol)   = hasUDA!(Symbol, ArgumentIndex);
enum IsOptionArgument(alias Symbol)    = hasUDA!(Symbol, ArgumentOption);
enum IsRequiredArgument(alias Symbol)  = hasUDA!(Symbol, ArgumentRequired);

void runCliCommands(CommandModules...)(string[] args, IgnoreFirstArg ignoreFirst = IgnoreFirstArg.yes)
{
    auto runner = new JCliRunner!CommandModules;
    runner.executeFromArgs(args);
}

alias Test = runCliCommands!(jaster.cli.udas);

private size_t getLargestStringSize(R)(R range)
{
    size_t largest = 0;
    foreach(str; range)
    {
        if(str.length > largest)
            largest = str.length;
    }

    return largest;
}


//////////////////////////////////////////////////////////////////
// Some useful code I stole from some other one of my projects. //
//////////////////////////////////////////////////////////////////

import std.range : isRandomAccessRange, ElementType;

/++
 + Determines the behaviour of `removeAt`.
 + ++/
enum RemovePolicy
{
    /++
     + Replaces the element at the given index with the last element in the range.
     +
     + Faster than moveRight, but can leave things out of order.
     + Also reduces the range's length by 1.
     + ++/
    moveLast,

    /++
     + Moves every element that is to the right of the element in the given index, to
     + the left by 1 space.
     +
     + Slower than moveLast, but will preserve the order of elements.
     + Also reduces the range's length by 1.
     + ++/
    moveRight,

    /++
     + Replaces the element at the given index with a default value.
     +
     + If the element is a class, `null` is used.
     + Otherwise, `ElementType.init` is used.
     +
     + Doesn't alter the length of the range, but does leave a possibly unwanted value.
     + ++/
    defaultify
}

/++
 + Removes an element at a given index.
 +
 + Params:
 +  range  = The RandomAccessRange to remove the element from.
 +  index  = The index of the element to remove.
 +  policy = What behaviour the function should use to remove the element.
 +
 + Returns:
 +  `range`
 + ++/
Range removeAt(Range)(auto ref Range range, size_t index, RemovePolicy policy = RemovePolicy.moveRight)
if(isRandomAccessRange!Range)
{
    assert(index < range.length);

    // Built-in arrays don't support .popBack
    // User-made RandomAccessRanges do
    // So this function just chooses the right one.
    void popBack()
    {
        static if(is(typeof({Range r; r.popBack();})))
            range.popBack();
        else static if(is(typeof({Range r; r.length -= 1;})))
            range.length -= 1;
        else
            static assert(false, "Type '" ~ Range.stringof ~ "' does not support a way of shortening it's length");
    }

    alias ElementT    = ElementType!Range;
    const isLastIndex = (index == range.length);

    final switch(policy) with(RemovePolicy)
    {
        case defaultify:
            static if(is(ElementT == class))
                ElementT value = null;
            else
                ElementT value = ElementT.init;

            range[index] = value;
            break;

        case moveLast:
            if(!isLastIndex)
                range[index] = range[$ - 1];

            popBack();
            break;

        case moveRight:
            if(!isLastIndex)
            {
                for(size_t i = index + 1; i < range.length; i++)
                {
                    if(i == 0) continue;

                    range[i - 1] = range[i];
                }
            }

            popBack();
            break;
    }

    return range;
}
///
unittest
{
    import std.array;
    assert([0, 1, 2, 3, 4, 5].removeAt(2, RemovePolicy.moveLast)   == [0, 1, 5, 3, 4]);
    assert([0, 1, 2, 3, 4, 5].removeAt(2, RemovePolicy.moveRight)  == [0, 1, 3, 4, 5]);
    assert([0, 1, 2, 3, 4, 5].removeAt(2, RemovePolicy.defaultify) == [0, 1, 0, 3, 4, 5]);
}