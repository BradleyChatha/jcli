module commands;

import jaster.cli;

/++

Imagine this scenario: You're making the next dub, and you get to the point where you need
to support the ability to pass arbitrary arguments to the program you're running via dub
e.g "dub run -- these --are=passed to the -p rogram".

Notice how after the double dash "--" we enter what JCLI refers to as the Raw Arg List. A list
of arguments that JCLI completely ignores and will pass over to your program directly.

To gain access to the raw arg list, all you need to do is add a `string[]` variable marked with `@CommandRawArg`,
and then this variable's value will contain the entirety of the raw arg list.

++/

@CommandDefault("Runs a command with the given arguments.")
struct RunCommand
{
    @CommandPositionalArg(0, "command", "The command to run.")
    string command;

    @CommandRawArg
    string[] args;

    void onExecute()
    {
        UserIO.logInfof("Running command '%s' with arguments %s", this.command, args);
    }

    /++
     + EXAMPLE USAGE:
     +  test.exe echo -- Some args -> Running command 'echo' with arguments ["Some", "args"]
     +  test.exe noarg             -> Running command 'noarg' with arguments []
     + ++/
}