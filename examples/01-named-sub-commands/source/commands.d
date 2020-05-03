module commands;

import jaster.cli;

// For named/subcommands, provide a pattern as the first paramter.
//
// Patterns follow a really simple format:
//      - "abc" matches "abc"
//      - "abc|efg" matches either "abc" or "efg"
//
// So for this command, we match either "return" or "r"
@Command("return|r", "Returns a specific exit code.")
struct ReturnCommand
{
    @CommandPositionalArg(0, "code", "The code to return.")
    int code;

    int onExecute()
    {
        return this.code;
    }

    /++
     + EXAMPLE USAGE:
     +  test.exe return 0 -> status code 0
     +  test.exe r -1     -> status code -1
     + ++/
}