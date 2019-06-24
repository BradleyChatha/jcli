module jaster.cli.util;

/++
 + Contains utility functions regarding the Shell/process execution.
 + ++/
static final abstract class Shell
{
    import std.stdio : writeln, writefln;

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

        void verboseLogf(Args...)(string format, Args args)
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
            
            Shell.verboseLogf("execute: %s", command);
            auto result = executeShell(command);
            Shell.verboseLogf(result.output);

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

            Shell.verboseLogf("pushLocation: %s", dir);
            this._locationStack ~= getcwd();
            chdir(dir);
        }

        void popLocation()
        {
            import std.file : chdir;

            assert(this._locationStack.length > 0, 
                "The location stack is empty. This indicates a bug as there is a mis-match between `pushLocation` and `popLocation` calls."
            );

            Shell.verboseLogf("popLocation: [dir after pop] %s", this._locationStack[$-1]);
            chdir(this._locationStack[$-1]);
            this._locationStack.length -= 1;
        }
    }

    /+ USER INPUT +/
    public static
    {
        T getInput(T)(string prompt)
        {
            import std.string : chomp;
            import std.stdio  : readln, write;
            import std.conv   : to;
            
            write(prompt);
            return readln().chomp.to!T;
        }
    }

    /+ MISC +/
    public static
    {
        bool isInPowershell()
        {
            return Shell.executeHasNonEmptyOutput("$verbosePreference");
        }

        bool doesCommandExist(string command)
        {
            if(Shell.isInPowershell)
                return Shell.executeHasNonEmptyOutput("Get-Command "~command);

            version(linux)
                return Shell.executeHasNonEmptyOutput("which "~command);
            else version(Windows)
                return Shell.executeHasNonEmptyOutput("where "~command);
            else
                static assert(false, "`doesCommandExist` is not implemented for this platform. Feel free to make a PR!");
        }

        void enforceCommandExists(string command)
        {
            import std.exception : enforce;
            enforce(Shell.doesCommandExist(command),
                "The command '"~command~"' does not exist or is not on the PATH."
            );
        }
    }
}