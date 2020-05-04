module jaster.cli.userio;

import jaster.cli.ansi;
import std.experimental.logger : LogLevel;

final static class UserIO
{
    /++++++++++++++++
     +++   VARS   +++
     ++++++++++++++++/
    private static
    {
        UserIOConfig _config;
    }

    public static
    {
        UserIOConfigBuilder configure()
        {
            return UserIOConfigBuilder();
        }
    }

    /+++++++++++++++++
     +++  LOGGING  +++
     +++++++++++++++++/
    public static
    {
        void log(const char[] output, LogLevel level)
        {
            import std.stdio : writeln;

            if(cast(int)level < UserIO._config.global.minLogLevel)
                return;

            if(!UserIO._config.global.useColouredText)
            {
                writeln(output);
                return;
            }

            AnsiText colouredOutput;
            switch(level) with(LogLevel)
            {
                case trace:     colouredOutput = output.ansi.fg(Ansi4Bit.BrightBlack); break;
                case warning:   colouredOutput = output.ansi.fg(Ansi4Bit.Yellow);      break;
                case error:     colouredOutput = output.ansi.fg(Ansi4Bit.Red);         break;
                case critical:  
                case fatal:     colouredOutput = output.ansi.fg(Ansi4Bit.BrightRed);   break;

                default: break;
            }

            if(colouredOutput == colouredOutput.init)
                colouredOutput = output.ansi;

            writeln(colouredOutput);
        }

        void logf(Args...)(const char[] format, LogLevel level, Args args)
        {
            import std.format : format;

            UserIO.log(format(format, args), level);
        }

        void debugf(Args...)(const char[] format, LogLevel level, Args args)
        {
            debug UserIO.logf(format, level, args);
        }

        void verbosef(Args...)(const char[] format, LogLevel level, Args args)
        {
            if(UserIO._config.global.useVerboseLogging)
                UserIO.logf(format, level, args);
        }

        /// Used for the helper aliases.
        void logfTemplate(LogLevel level, Args...)(const char[] format, Args args)
        {
            UserIO.logf(format, level, args);
        }

        /// ditto.
        void debugfTemplate(LogLevel level, Args...)(const char[] format, Args args)
        {
            UserIO.debugf(format, level, args);
        }

        /// ditto
        void verbosefTemplate(LogLevel level, Args...)(const char[] format, Args args)
        {
            UserIO.verbosef(format, level, args);
        }

        // I'm not auto-generating these, as I want autocomplete (e.g. vscode) to be able to pick these up.
        alias logTracef(Args...)    = logfTemplate!(LogLevel.trace, Args);
        alias logInfof(Args...)     = logfTemplate!(LogLevel.info, Args);
        alias logWarningf(Args...)  = logfTemplate!(LogLevel.warning, Args);
        alias logErrorf(Args...)    = logfTemplate!(LogLevel.error, Args);
        alias logCriticalf(Args...) = logfTemplate!(LogLevel.critical, Args);
        alias logFatalf(Args...)    = logfTemplate!(LogLevel.fatal, Args);

        alias debugTracef(Args...)    = debugfTemplate!(LogLevel.trace, Args);
        alias debugInfof(Args...)     = debugfTemplate!(LogLevel.info, Args);
        alias debugWarningf(Args...)  = debugfTemplate!(LogLevel.warning, Args);
        alias debugErrorf(Args...)    = debugfTemplate!(LogLevel.error, Args);
        alias debugCriticalf(Args...) = debugfTemplate!(LogLevel.critical, Args);
        alias debugFatalf(Args...)    = debugfTemplate!(LogLevel.fatal, Args);

        alias verboseTracef(Args...)    = verbosefTemplate!(LogLevel.trace, Args);
        alias verboseInfof(Args...)     = verbosefTemplate!(LogLevel.info, Args);
        alias verboseWarningf(Args...)  = verbosefTemplate!(LogLevel.warning, Args);
        alias verboseErrorf(Args...)    = verbosefTemplate!(LogLevel.error, Args);
        alias verboseCriticalf(Args...) = verbosefTemplate!(LogLevel.critical, Args);
        alias verboseFatalf(Args...)    = verbosefTemplate!(LogLevel.fatal, Args);
    }

    /+++++++++++++++
     +++  INPUT  +++
     +++++++++++++++/
    public static
    {
        /++
         + Gets input from the user, and uses the given `ArgBinder` (or the default one, if one isn't passed) to
         + convert the string to a `T`.
         +
         + Notes:
         +  Because `ArgBinder` is responsible for the conversion, if for example you wanted `T` to be a custom struct,
         +  then you could create an `@ArgBinderFunc` to perform the conversion, and then this function (and all `UserIO.getInput` variants)
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
         + A variant of `UserIO.getInput` that'll constantly prompt the user until they enter a non-null, non-whitespace-only string.
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
                value = UserIO.getInput!(string, Binder)(prompt);

            return value;
        }

        /++
         + A variant of `UserIO.getInput` that'll constantly prompt the user until they enter a value that doesn't cause an
         + exception (of type `Ex`) to be thrown by the `Binder`.
         + ++/
        T getInputCatchExceptions(T, Ex: Exception = Exception, Binder = ArgBinder!())(string prompt, void delegate(Ex) onException = null)
        {
            while(true)
            {
                try return UserIO.getInput!(T, Binder)(prompt);
                catch(Ex ex)
                {
                    if(onException !is null)
                        onException(ex);
                }
            }
        }

        /++
         + A variant of `UserIO.getInput` that'll constantly prompt the user until they enter a value from the given `list`.
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
                const input = UserIO.getInput!(string, Binder)(prompt);
                foreach(i, str; listAsStrings)
                {
                    if(input == str)
                        return list[i];
                }
            }
        }
    }
}

private struct UserIOConfigScope
{
    bool useVerboseLogging;
    bool useColouredText;
    LogLevel minLogLevel;
}

private struct UserIOConfig
{
    UserIOConfigScope global;
}

struct UserIOConfigBuilder
{
    private ref UserIOConfigScope getScope()
    {
        // For future purposes.
        return UserIO._config.global;
    }

    UserIOConfigBuilder useColouredText(bool value = true)
    {
        this.getScope().useColouredText = value;
        return this;
    }

    UserIOConfigBuilder useVerboseLogging(bool value = true)
    {
        this.getScope().useVerboseLogging = value;
        return this;
    }

    UserIOConfigBuilder useMinimumLogLevel(LogLevel level)
    {
        this.getScope().minLogLevel = level;
        return this;
    }
}