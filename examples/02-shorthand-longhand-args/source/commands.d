module commands;

import jaster.cli;

@Command("return|r", "Returns a specific exit code.")
struct ReturnCommand
{
    // Similar to commands, named args can also be given patterns.
    //
    // Names with more than one character use longhand: "--code"
    // Names with only one character use shorthand:     "-c"
    //
    // Checkout jaster.cli.parser.ArgPullParser's documentation to see all valid argument forms (e.g. "-c VALUE" and "-c=VALUE" are both supported).
    @CommandNamedArg("code|c", "The code to return.")
    int code;

    int onExecute()
    {
        return this.code;
    }

    /++
     + EXAMPLE USAGE:
     +  test.exe return --code 0 -> status code 0
     +  test.exe r -c=-1         -> status code -1
     + ++/
}