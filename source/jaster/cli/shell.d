/// Contains functions for interacting with the shell.
module jaster.cli.shell;

/++
 + Contains utility functions regarding the Shell/process execution.
 + ++/
static final abstract class Shell
{
    import std.stdio : writeln, writefln;
    import std.traits : isInstanceOf;
    import jaster.cli.binder;
    import jaster.cli.userio : UserIO;

    /// The result of executing a process.
    struct Result
    {
        /// The output produced by the process.
        string output;

        /// The status code returned by the process.
        int statusCode;
    }

    private static
    {
        string[] _locationStack;
    }

    /+ LOGGING +/
    public static
    {
        deprecated("Use UserIO.configure().useVerboseLogging")
        bool useVerboseOutput = false;

        deprecated("Use UserIO.verbosef, or one of its helper functions.")
        void verboseLogfln(Args...)(string format, Args args)
        {
            if(Shell.useVerboseOutput)
                writefln(format, args);
        }
    }

    /+ COMMAND EXECUTION +/
    public static
    {
        /++
         + Executes a command via `std.process.executeShell`, and collects its results.
         +
         + Params:
         +  command = The command string to execute.
         +
         + Returns:
         +  The `Result` of the execution.
         + ++/
        Result execute(string command)
        {
            import std.process : executeShell;

            UserIO.verboseTracef("execute: %s", command);
            auto result = executeShell(command);
            UserIO.verboseTracef(result.output);

            return Result(result.output, result.status);
        }

        /++
         + Executes a command via `std.process.executeShell`, enforcing that the process' exit code was 0.
         +
         + Throws:
         +  `Exception` if the process' exit code was anything other than 0.
         +
         + Params:
         +  command = The command string to execute.
         +
         + Returns:
         +  The `Result` of the execution.
         + ++/
        Result executeEnforceStatusZero(string command)
        {
            import std.format    : format;
            import std.exception : enforce;

            auto result = Shell.execute(command);
            enforce(result.statusCode == 0,
                "The command '%s' did not return status code 0, but returned %s."
                .format(command, result.statusCode)
            );

            return result;
        }

        /++
         + Executes a command via `std.process.executeShell`, enforcing that the process' exit code was >= 0.
         +
         + Notes:
         +  Positive exit codes may still indicate an error.
         +
         + Throws:
         +  `Exception` if the process' exit code was anything other than 0 or above.
         +
         + Params:
         +  command = The command string to execute.
         +
         + Returns:
         +  The `Result` of the execution.
         + ++/
        Result executeEnforceStatusPositive(string command)
        {
            import std.format    : format;
            import std.exception : enforce;

            auto result = Shell.execute(command);
            enforce(result.statusCode >= 0,
                "The command '%s' did not return a positive status code, but returned %s."
                .format(command, result.statusCode)
            );

            return result;
        }

        /++
         + Executes a command via `std.process.executeShell`, and checks to see if the output was empty.
         +
         + Params:
         +  command = The command string to execute.
         +
         + Returns:
         +  Whether the process' output was either empty, or entirely made up of white space.
         + ++/
        bool executeHasNonEmptyOutput(string command)
        {
            import std.ascii     : isWhite;
            import std.algorithm : all;

            return !Shell.execute(command).output.all!isWhite;
        }
    }

    /+ WORKING DIRECTORY +/
    public static
    {
        /++
         + Pushes the current working directory onto a stack, and then changes directory.
         +
         + Usage:
         +  Use `Shell.popLocation` to go back to the previous directory.
         +
         +  Combining `pushLocation` with `scope(exit) Shell.popLocation` is a good practice.
         +
         + See also:
         +  Powershell's `Push-Location` cmdlet.
         +
         + Params:
         +  dir = The directory to change to.
         + ++/
        void pushLocation(string dir)
        {
            import std.file : chdir, getcwd;

            UserIO.verboseTracef("pushLocation: %s", dir);
            this._locationStack ~= getcwd();
            chdir(dir);
        }

        /++
         + Pops the working directory stack, and then changes the current working directory to it.
         +
         + Assertions:
         +  The stack must not be empty.
         + ++/
        void popLocation()
        {
            import std.file : chdir;

            assert(this._locationStack.length > 0, 
                "The location stack is empty. This indicates a bug as there is a mis-match between `pushLocation` and `popLocation` calls."
            );

            UserIO.verboseTracef("popLocation: [dir after pop] %s", this._locationStack[$-1]);
            chdir(this._locationStack[$-1]);
            this._locationStack.length -= 1;
        }
    }

    public static
    {
        deprecated("Moved to UserIO - use UserIO.getInput")
        T getInput(T, Binder = ArgBinder!())(string prompt)
        if(isInstanceOf!(ArgBinder, Binder))
        {
            assert(false, "Use UserIO.getInput");
        }

        deprecated("Moved to UserIO - use UserIO.getInputNonEmptyString")
        string getInputNonEmptyString(Binder = ArgBinder!())(string prompt)
        {
            assert(false, "Use UserIO.getInputNonEmptyString");
        }

        deprecated("Moved to UserIO - use UserIO.getInputCatchExceptions")
        T getInputCatchExceptions(T, Ex: Exception = Exception, Binder = ArgBinder!())(string prompt, void delegate(Ex) onException = null)
        {
            assert(false, "Use UserIO.getInputCatchExceptions");
        }

        deprecated("Moved to UserIO - use UserIO.getInputFromList")
        T getInputFromList(T, Binder = ArgBinder!())(string prompt, T[] list, string promptPostfix = ": ")
        {
            assert(false, "Use UserIO.getInputFromList");
        }
    }

    /+ MISC +/
    public static
    {
        /++
         + $(B Tries) to determine if the current shell is Powershell.
         +
         + Notes:
         +  On Windows, this will always be `false` because Windows.
         + ++/
        bool isInPowershell()
        {
            // Seems on Windows, powershell isn't used when using `execute`, even if the program itself is launched in powershell.
            version(Windows) return false;
            else return Shell.executeHasNonEmptyOutput("$verbosePreference");
        }

        /++
         + $(B Tries) to determine if the given command exists.
         +
         + Notes:
         +  In Powershell, `Get-Command` is used.
         +
         +  On Linux, `which` is used.
         +
         +  On Windows, `where` is used.
         +
         + Params:
         +  command = The command/executable to check.
         +
         + Returns:
         +  `true` if the command exists, `false` otherwise.
         + ++/
        bool doesCommandExist(string command)
        {
            if(Shell.isInPowershell)
                return Shell.executeHasNonEmptyOutput("Get-Command "~command);

            version(linux)
                return Shell.executeHasNonEmptyOutput("which "~command);
            else version(Windows)
            {
                import std.algorithm : startsWith;

                auto result = Shell.execute("where "~command);
                if(result.output.length == 0)
                    return false;

                if(result.output.startsWith("INFO: Could not find files"))
                    return false;

                return true;
            }
            else
                static assert(false, "`doesCommandExist` is not implemented for this platform. Feel free to make a PR!");
        }

        /++
         + Enforce that the given command/executable exists.
         +
         + Throws:
         +  `Exception` if the given `command` doesn't exist.
         +
         + Params:
         +  command = The command to check for.
         + ++/
        void enforceCommandExists(string command)
        {
            import std.exception : enforce;
            enforce(Shell.doesCommandExist(command), "The command '"~command~"' does not exist or is not on the PATH.");
        }
    }
}