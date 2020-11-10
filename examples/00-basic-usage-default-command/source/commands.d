module commands;

import jaster.cli;

// Use either a struct or class. JCLI supports both (including inheritence).
@CommandDefault("Asserts that the given number is even.")
struct AssertEvenCommand
{
    // Positional args are args that aren't defined by a command line flag.
    //
    // i.e. "mytool.exe abc 123" - 'abc' is the 0th positional arg, '123' is the 1st, etc.
    @CommandPositionalArg(0, "number", "The number to assert.")
    int number; // Conversions are performed via `ArgBinder`, which is a topic for a different example.

    // Named args are args that are defined by a command line flag.
    //
    // Optional arguments can be defined by using `Nullable`, which is publicly imported.
    //
    // Boolean named args are special as they don't require a value to follow it. Simply providing
    // the arg's name will set it to true.
    //
    // i.e. "mytool.exe -a 20 --value 400" - '-a 20' assigns '20' to the arg named 'a', ditto for '--value 400'
    @CommandNamedArg("reverse", "If specified, then assert that the number is ODD instead.")
    Nullable!bool reverse;

    // Return either int or void. Use `int` if you want to control the exit code.
    int onExecute()
    {
        auto passedAssert = (this.reverse.get(false))
                            ? this.number % 2 == 1
                            : this.number % 2 == 0;

        return (passedAssert) ? 0 : 128; // 128 on error.
    }

    /++
     + EXAMPLE USAGE:
     +  test.exe 20           -> status code 0
     +  test.exe 21           -> status code 128
     +  test.exe 20 --reverse -> status code 128
     +  test.exe 21 --reverse -> status code 0
     + ++/
}