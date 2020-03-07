module jaster.cli.util;

import std.experimental.logger : Logger;

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

    /+ USER INPUT +/
    public static
    {
        /++
         + Gets input from the user, and uses the given `ArgBinder` (or the default one, if one isn't passed) to
         + convert the string to a `T`.
         +
         + Notes:
         +  Because `ArgBinder` is responsible for the conversion, if for example you wanted `T` to be a custom struct,
         +  then you could create an `@ArgBinderFunc` to perform the conversion, and then this function (and all `Shell.getInput` variants)
         +  will be able to convert the user's input to that type.
         +
         +  See also the documentation for `ArgBinder`.
         +
         + Params:
         +  T       = The type to conver the string to, via `Binder`.
         +  Binder  = The `ArgBinder` that knows how to convert a string -> `T`.
         +  prompt  = The prompt to display to the user, note that no extra characters or spaces are added, the prompt is shown as-is.
         +
         + Returns:
         +  A `T` that was created by the user's input given to `Binder`.
         + ++/
        T getInput(T, Binder = ArgBinder!())(string prompt)
        if(isInstanceOf!(ArgBinder, Binder))
        {
            import std.string : chomp;
            import std.stdio  : readln, write;
            
            write(prompt);

            T value;
            Binder.bind(readln().chomp, value);

            return value;
        }

        /++
         + A variant of `Shell.getInput` that'll constantly prompt the user until they enter a non-null, non-whitespace-only string.
         +
         + Notes:
         +  The `Binder` is only used to convert a string to a string, in case there's some weird voodoo you want to do with it.
         + ++/
        string getInputNonEmptyString(Binder = ArgBinder!())(string prompt)
        {
            import std.algorithm : all;
            import std.ascii     : isWhite;

            string value;
            while(value.length == 0 || value.all!isWhite)
                value = Shell.getInput!(string, Binder)(prompt);

            return value;
        }

        /++
         + A variant of `Shell.getInput` that'll constantly prompt the user until they enter a value that doesn't cause an
         + exception (of type `Ex`) to be thrown by the `Binder`.
         + ++/
        T getInputCatchExceptions(T, Ex: Exception = Exception, Binder = ArgBinder!())(string prompt, void delegate(Ex) onException = null)
        {
            while(true)
            {
                try return Shell.getInput!(T, Binder)(prompt);
                catch(Ex ex)
                {
                    if(onException !is null)
                        onException(ex);
                }
            }
        }

        /++
         + A variant of `Shell.getInput` that'll constantly prompt the user until they enter a value from the given `list`.
         +
         + Behaviour:
         +  All items of `list` are converted to a string (via `std.conv.to`), and the user must enter the *exact* value of one of these
         +  strings for this function to return, so if you're wanting to use a struct then ensure you make `toString` provide a user-friendly
         +  value.
         +
         +  This function $(B does not) use `Binder` to provide the final value, it will instead simply return the appropriate
         +  item from `list`. This is because the value already exists (inside of `list`) so there's no reason to perform a conversion.
         +
         +  The `Binder` is only used to convert the user's input from a string into another string, in case there's any transformations
         +  you'd like to perform on it.
         +
         + Prompt:
         +  The prompt layout for this variant is a bit different than other variants.
         +
         +  `$prompt[$list[0], $list[1], ...]$promptPostfix`
         +
         +  For example `Choose colour[red, blue, green]: `
         + ++/
        T getInputFromList(T, Binder = ArgBinder!())(string prompt, T[] list, string promptPostfix = ": ")
        {
            import std.stdio     : write;
            import std.conv      : to;
            import std.exception : assumeUnique;

            auto listAsStrings = new string[list.length];
            foreach(i, item; list)
                listAsStrings[i] = item.to!string();

            // 2 is for the "[" and "]", list.length * 2 is for the ", " added between each item.
            // list.length * 10 is just to try and overallocate a little bit.
            char[] promptBuilder;
            promptBuilder.reserve(prompt.length + 2 + (list.length * 2) + (list.length * 10) + promptPostfix.length);

            promptBuilder ~= prompt;
            promptBuilder ~= "[";
            foreach(i, item; list)
            {
                promptBuilder ~= listAsStrings[i];
                if(i != list.length - 1)
                    promptBuilder ~= ", ";
            }
            promptBuilder ~= "]";
            promptBuilder ~= promptPostfix;

            prompt = promptBuilder.assumeUnique;
            while(true)
            {
                const input = Shell.getInput!(string, Binder)(prompt);
                foreach(i, str; listAsStrings)
                {
                    if(input == str)
                        return list[i];
                }
            }
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