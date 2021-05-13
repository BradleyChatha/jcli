/// Contains the UDAs used and recognised by infogen, and any systems built on top of it.
module jaster.cli.infogen.udas;

import std.meta : staticMap, Filter;
import std.traits;
import jaster.cli.infogen, jaster.cli.udas;

/++
 + Attach this to any struct/class that represents the default command.
 +
 + See_Also:
 +  `jaster.cli
 + ++/
struct CommandDefault
{
    /// The command's description.
    string description = "N/A";
}

/++
 + Attach this to any struct/class that represents a command.
 +
 + See_Also:
 +  `jaster.cli.core.CommandLineInterface` for more details.
 + +/
struct Command
{
    /// The pattern used to match against this command. Can contain spaces.
    Pattern pattern;

    /// The command's description.
    string description;

    ///
    this(string pattern, string description = "N/A")
    {
        this.pattern = Pattern(pattern);
        this.description = description;
    }
}

/++
 + Attach this to any member field to mark it as a named argument.
 +
 + See_Also:
 +  `jaster.cli.core.CommandLineInterface` for more details.
 + +/
struct CommandNamedArg
{
    /// The pattern used to match against this argument. Cannot contain spaces.
    Pattern pattern;

    /// The argument's description.
    string description;

    ///
    this(string pattern, string description = "N/A")
    {
        this.pattern = Pattern(pattern);
        this.description = description;
    }
}

/++
 + Attach this to any member field to mark it as a positional argument.
 +
 + See_Also:
 +  `jaster.cli.core.CommandLineInterface` for more details.
 + +/
struct CommandPositionalArg
{
    /// The position that this argument appears at.
    size_t position;

    /// The name of this argument. Used during help-text generation.
    string name = "VALUE";

    /// The description of this argument.
    string description = "N/A";
}

/++
 + Attach this to any member field to add it to a help text group.
 +
 + See_Also:
 +  `jaster.cli.core.CommandLineInterface` for more details.
 + +/
struct CommandArgGroup
{
    /// The name of the group to put the arg under.
    string name;

    /++
     + The description of the group.
     +
     + Notes:
     +  The intended usage of this UDA is to apply it to a group of args at the same time, instead of attaching it onto
     +  singular args:
     +
     +  ```
     +  @CommandArgGroup("group1", "Some description")
     +  {
     +      @CommandPositionalArg...
     +  }
     +  ```
     + ++/
    string description;
}

/++
 + Attach this onto a `string[]` member field to mark it as the "raw arg list".
 +
 + TLDR; Given the command `"tool.exe command value1 value2 --- value3 value4 value5"`, the member field this UDA is attached to
 + will be populated as `["value3", "value4", "value5"]`
 + ++/
struct CommandRawListArg {}

/++
 + Attach any value from this enum onto an argument to specify what parsing action should be performed on it.
 + ++/
enum CommandArgAction
{
    /// Perform the default parsing action.
    default_,

    /++
     + Increments an argument for every time it is defined inside the parameters.
     +
     + Arg Type: Named
     + Value Type: Any type that supports `++`.
     + Arg becomes optional: true
     + ++/
    count,
}

/++
 + Attach any value from this enum onto an argument to specify whether it is case sensitive or not.
 + ++/
enum CommandArgCase
{
    ///
    sensitive,
    ///
    insensitive,
}

// Legacy, keep undocumented.
alias CommandRawArg = CommandRawListArg;

enum isSomeCommand(alias CommandT) = hasUDA!(CommandT, Command) || hasUDA!(CommandT, CommandDefault);

enum isSymbol(alias ArgT) = __traits(compiles, __traits(getAttributes, ArgT));

enum isRawListArgument(alias ArgT)    = isSymbol!ArgT && hasUDA!(ArgT, CommandRawListArg); // Don't include in isSomeArgument
enum isNamedArgument(alias ArgT)      = isSymbol!ArgT && hasUDA!(ArgT, CommandNamedArg);
enum isPositionalArgument(alias ArgT) = isSymbol!ArgT && hasUDA!(ArgT, CommandPositionalArg);
enum isSomeArgument(alias ArgT)       = isNamedArgument!ArgT || isPositionalArgument!ArgT;

package template getCommandArguments(alias CommandT)
{
    static assert(is(CommandT == struct) || is(CommandT == class), "Only classes or structs can be used as commands.");
    static assert(isSomeCommand!CommandT, "Type "~CommandT.stringof~" is not marked with @Command or @CommandDefault.");

    alias toSymbol(string name) = __traits(getMember, CommandT, name);
    alias Members = staticMap!(toSymbol, __traits(allMembers, CommandT));
    alias getCommandArguments = Filter!(isSomeArgument, Members);
}
///
unittest
{
    @CommandDefault
    static struct C 
    {
        @CommandNamedArg int a;
        @CommandPositionalArg int b;
        int c;
    }

    static assert(getCommandArguments!C.length == 2);
    static assert(getNamedArguments!C.length == 1);
    static assert(getPositionalArguments!C.length == 1);
}

package alias getNamedArguments(alias CommandT) = Filter!(isNamedArgument, getCommandArguments!CommandT);
package alias getPositionalArguments(alias CommandT) = Filter!(isPositionalArgument, getCommandArguments!CommandT);