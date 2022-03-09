import jcli.core;

@("Hello")
struct SomeCommand
{
    @ArgNamed("Named")
    @(ArgConfig.caseInsensitive | ArgConfig.optional)
    int stuff;

    @ArgPositional("Positional")
    int[] things;

    @("Aggregate")
    @(ArgConfig.aggregate)
    int[] stuffs;


    @("Simple named syntax")
    string named2 = "123";
}

void main()
{
    // If you want to iterate through all commands of a module, you can use
    // alias AllCommands = jcli.introspect.AllCommandsOf!(Modules)
    // static foreach (Command; AllCommands)
    
    import jcli.introspect;
    import std.stdio;

    {
        alias CommandInfo = jcli.introspect.CommandInfo!SomeCommand;
        writeln("Description: ", CommandInfo.description);
        writeln("UDA:         ", CommandInfo.udaValue);
        writeln("Flags:       ", CommandInfo.flags.toFlagsString());
    }
    {
        alias ArgumentsInfo = CommandArgumentsInfo!SomeCommand;
        writeln("\nNamed argument count: ", ArgumentsInfo.named.length);

        foreach (immutable NamedArgumentInfo named; ArgumentsInfo.named)
        {
            writeln();
            writeln("Name:        ", named.name);
            writeln("Description: ", named.description);
            writeln("Pattern:     ", named.pattern);
            writeln("Flags:       ", named.flags.toFlagsString());
            writeln("Identifier:  ", named.identifier);
            writeln("Group:       ", named.group);
        }

        writeln("\nPositional argument count: ", ArgumentsInfo.positional.length);

        foreach (immutable PositionalArgumentInfo positional; ArgumentsInfo.positional)
        {
            writeln();
            writeln("Name:        ", positional.name);
            writeln("Description: ", positional.description);
            // writeln("Pattern:     ", positional.pattern);
            writeln("Flags:       ", positional.flags.toFlagsString());
            writeln("Identifier:  ", positional.identifier);
            writeln("Group:       ", positional.group);
        }

        writeln();
        
        static if (ArgumentsInfo.takesRaw)
            writeln("Raw argument: ", ArgumentsInfo.raw);
        
        static if (ArgumentsInfo.takesOverflow)
            writeln("Overflow argument: ", ArgumentsInfo.overflow);

        writeln("Required positional arguments count: ", ArgumentsInfo.numRequiredPositionalArguments);
    }
}