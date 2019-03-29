module jaster.cli.core;

private
{
    import std.exception : enforce;
    import std.algorithm : startsWith;
    import std.format    : format;
    import std.uni       : toLower;
    import std.traits    : fullyQualifiedName, hasUDA, getUDAs, getSymbolsByUDA;
    import std.meta      : staticMap, Filter;
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

alias IgnoreFirstArg = Flag!"ignoreFirst";

private class JCliRunner(CommandModules...)
{
    alias CommandExecuteFunc = void function(ref string[]);

    struct CommandInfo
    {
        string group;
        string name;
        string description;
        
        CommandExecuteFunc onExecute; // Handles creation, arg parsing, and execution.
    }

    private
    {
        CommandInfo[] _commands;
    }

    this()
    {
        this.parseModules();
    }

    public
    {
        void executeFromArgs(string[] args, IgnoreFirstArg ignore = IgnoreFirstArg.yes)
        {
            
        }
    }

    private
    {
        void parseModules()
        {
            static foreach(mod; CommandModules)
            {{
                pragma(msg, "[JCli] Info: Processing module "~fullyQualifiedName!mod);

                // Get all commands.
                alias MapFunc(string Name) = StringToMember!(mod, Name);
                enum  FilterFunc(alias Member) = hasUDA!(Member, Command);
                
                alias Members = Filter!(FilterFunc, staticMap!(MapFunc, __traits(allMembers, mod)));
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

                    info.group = info.group.toLower();
                    info.name  = info.name.toLower();

                    this._commands ~= info;
                }}
            }}
        }

        static CommandExecuteFunc createOnExecute(alias Command)()
        {
            alias Arguments         = getSymbolsByUDA!(Command, Argument);
            alias IndexArguments    = Filter!(IsIndexedArgument, Arguments);
            alias OptionArguments   = Filter!(IsOptionArgument, Arguments);
            alias RequiredArguments = Filter!(IsRequiredArgument, Arguments);

            debug pragma(msg, format("[JCli] Debug: Out of %s arguments. %s are indexed. %s are options.",
                                     Arguments.length, IndexArguments.length, OptionArguments.length                         
            ));

            // TODO: Check to make sure ArgumentIndex and ArgumentOption are mutually exclusive.

            return (ref string[] args)
            {
                Command commandObject;

                // If their fully qualified name is still in here, then they haven't been provided yet.
                string[] requiredArgNames;
                static foreach(required; RequiredArguments)
                    requiredArgNames ~= fullyQualifiedName!required;

                // Helper funcs
                void removeArg(ref size_t i)
                {
                    args.removeAt(i--);
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
                        size_t optionNameEnd = size_t.max; // If it stays size_t.max, that means there's no value attach, and is likely a boolean option.
                        foreach(argI, argChar; arg)
                        {
                            if(argChar == '=' || argChar == ' ')
                            {
                                optionNameEnd = argI;
                                optionName = arg[2..optionNameEnd];
                                break;
                            }
                        }
                        
                        // Read in the value.
                        size_t valueStringStart = optionNameEnd + 1; // + 1 to skip the space or = sign.
                        if(optionNameEnd != size_t.max && valueStringStart < arg.length)
                            valueString = arg[valueStringStart..$];
                    }
                    // Short hand
                    else if(arg.startsWith("-"))
                    {
                        enforce(arg.length > 1, "There is a stray '-', likely meaning a messed up short-hand argument.");
                        isIndexed = false;
                        optionName = arg[1..2];

                        if(arg.length != 2) // If it's 2, then it's likely a boolean option (and if not, we validate that a bit later on)
                        {
                            size_t startIndex = (arg[2] == ' ' || arg[2] == '=')
                                                ? 3 : 2;
                            
                            valueString = arg[startIndex..$];
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
                                removeArg(i);
                                parseIntoObject!(Command, argument)(commandObject, valueString);
                                argHandled = true;
                            }
                        }
                        else static if(IsIndexedArgument!argument)
                        {
                            enum Index = getUDAs!(argument, ArgumentIndex)[0];
                            if(!argHandled && isIndexed && indexedIndex == Index.index)
                            {
                                removeArg(i);
                                indexedIndex++;
                                parseIntoObject!(Command, argument)(commandObject, valueString);
                                argHandled = true;
                            }
                        }
                        else static assert(false, format("Argument %s doesn't have either @ArgumentOption or @ArgumentIndex", fullyQualifiedName!argument));
                    }}
                    
                    if(argHandled)
                        continue;

                    // TODO: Display help text
                    throw new Exception(
                        (isIndexed)
                        ? format("Stray argument: %s", valueString)
                        : format("Unrecognised option: %s = %s", optionName, valueString)
                    );
                }

                // TODO: Display help text.
                enforce(requiredArgNames.length != 0, format("The following required args are missing: %s", requiredArgNames));

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
        }
    }
}

// These have to be global otherwise the compiler shouts at me.
enum IsIndexedArgument(alias Symbol)   = hasUDA!(Symbol, ArgumentIndex);
enum IsOptionArgument(alias Symbol)    = hasUDA!(Symbol, ArgumentOption);
enum IsRequiredArgument(alias Symbol)  = hasUDA!(Symbol, ArgumentRequired);

void runCliCommands(CommandModules...)()
{
    auto runner = new JCliRunner!CommandModules;
}

import jaster.cli.example;
alias Test = runCliCommands!(jaster.cli.udas, jaster.cli.example);




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