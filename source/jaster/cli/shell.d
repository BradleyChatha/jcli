module jaster.cli.shell;

/++
 + Contains utility functions regarding the Shell/process execution.
 + ++/
static final abstract class Shell
{
    import std.stdio : writeln, writefln;
    import std.traits : isInstanceOf;
    import jaster.cli.binder;

    struct Result
    {
        string output;
        int statusCode;
    }

    private static
    {
        string[] _locationStack;
    }

    /+ LOGGING +/
    public static
    {
        bool useVerboseOutput = false;

        void verboseLogfln(Args...)(string format, Args args)
        {
            if(Shell.useVerboseOutput)
                writefln(format, args);
        }
    }

    /+ COMMAND EXECUTION +/
    public static
    {
        Result execute(string command)
        {
            import std.process : executeShell;
            
            Shell.verboseLogfln("execute: %s", command);
            auto result = executeShell(command);
            Shell.verboseLogfln(result.output);

            return Result(result.output, result.status);
        }

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
        void pushLocation(string dir)
        {
            import std.file : chdir, getcwd;

            Shell.verboseLogfln("pushLocation: %s", dir);
            this._locationStack ~= getcwd();
            chdir(dir);
        }

        void popLocation()
        {
            import std.file : chdir;

            assert(this._locationStack.length > 0, 
                "The location stack is empty. This indicates a bug as there is a mis-match between `pushLocation` and `popLocation` calls."
            );

            Shell.verboseLogfln("popLocation: [dir after pop] %s", this._locationStack[$-1]);
            chdir(this._locationStack[$-1]);
            this._locationStack.length -= 1;
        }
    }

    /+ MISC +/
    public static
    {
        bool isInPowershell()
        {
            // Seems on Windows, powershell isn't used when using `execute`, even if the program itself is launched in powershell.
            version(Windows) return false;
            else return Shell.executeHasNonEmptyOutput("$verbosePreference");
        }

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

        void enforceCommandExists(string command)
        {
            import std.exception : enforce;
            enforce(Shell.doesCommandExist(command), "The command '"~command~"' does not exist or is not on the PATH.");
        }
    }
}