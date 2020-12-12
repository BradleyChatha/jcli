module jaster.cli.infogen.udas;

import std.meta : staticMap, Filter;
import std.traits;
import jaster.cli.infogen, jaster.cli.udas;

struct CommandDefault
{
    string description = "N/A";
}

struct Command
{
    Pattern pattern;
    string description;

    this(string pattern, string description = "N/A")
    {
        this.pattern = Pattern(pattern);
        this.description = description;
    }
}

struct CommandNamedArg
{
    Pattern pattern;
    string description;

    this(string pattern, string description = "N/A")
    {
        this.pattern = Pattern(pattern);
        this.description = description;
    }
}

struct CommandPositionalArg
{
    size_t position;
    string name = "VALUE";
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

enum isSomeCommand(alias CommandT) = hasUDA!(CommandT, Command) || hasUDA!(CommandT, CommandDefault);

enum isSymbol(alias ArgT) = __traits(compiles, __traits(getAttributes, ArgT));

enum isRawListArgument(alias ArgT) = isSymbol!ArgT && hasUDA!(ArgT, CommandRawListArg); // Don't include in isSomeArgument
enum isNamedArgument(alias ArgT) = isSymbol!ArgT && hasUDA!(ArgT, CommandNamedArg);
enum isPositionalArgument(alias ArgT) = isSymbol!ArgT && hasUDA!(ArgT, CommandPositionalArg);
enum isSomeArgument(alias ArgT) = isNamedArgument!ArgT || isPositionalArgument!ArgT;

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