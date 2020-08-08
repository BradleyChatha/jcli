/// Contains functions for getting input, and sending output to the user.
module jaster.cli.userio;

import jaster.cli.ansi, jaster.cli.binder;
import std.experimental.logger : LogLevel;
import std.traits : isInstanceOf;

/++
 + Provides various utilities:
 +  - Program-wide configuration via `UserIO.configure`
 +  - Logging, including debug-only and verbose-only logging via `logf`, `debugf`, and `verbosef`
 +  - Logging helpers, for example `logTracef`, `debugInfof`, and `verboseErrorf`.
 +  - Easily getting input from the user via `getInput`, `getInputNonEmptyString`, `getInputFromList`, and more.
 + ++/
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
        /++
         + Configure the settings for `UserIO`, can be called multiple times.
         +
         + Returns:
         +  A `UserIOConfigBuilder`, which is a fluent-builder based struct used to set configuration options.
         + ++/
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
        /++
         + Logs the given `output` to the console, as long as `level` is >= the configured minimum log level.
         +
         + Configuration:
         +  If `UserIOConfigBuilder.useColouredText` (see `UserIO.configure`) is set to `true`, then the text will be coloured
         +  according to its log level.
         +
         +  trace - gray;
         +  info - default;
         +  warning - yellow;
         +  error - red;
         +  critical & fatal - bright red.
         +
         +  If `level` is lower than `UserIOConfigBuilder.useMinimumLogLevel`, then no output is logged.
         +
         + Params:
         +  output = The output to display.
         +  level  = The log level of this log.
         + ++/
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
                case trace:     colouredOutput = output.ansi.fg(Ansi4BitColour.brightBlack); break;
                case warning:   colouredOutput = output.ansi.fg(Ansi4BitColour.yellow);      break;
                case error:     colouredOutput = output.ansi.fg(Ansi4BitColour.red);         break;
                case critical:  
                case fatal:     colouredOutput = output.ansi.fg(Ansi4BitColour.brightRed);   break;

                default: break;
            }

            if(colouredOutput == colouredOutput.init)
                colouredOutput = output.ansi;

            writeln(colouredOutput);
        }

        /// Variant of `UserIO.log` that uses `std.format.format` to format the final output.
        void logf(Args...)(const char[] fmt, LogLevel level, Args args)
        {
            import std.format : format;

            UserIO.log(format(fmt, args), level);
        }

        /// Variant of `UserIO.logf` that only shows output in non-release builds.
        void debugf(Args...)(const char[] format, LogLevel level, Args args)
        {
            debug UserIO.logf(format, level, args);
        }

        /// Variant of `UserIO.logf` that only shows output if `UserIOConfigBuilder.useVerboseLogging` is set to `true`.
        void verbosef(Args...)(const char[] format, LogLevel level, Args args)
        {
            if(UserIO._config.global.useVerboseLogging)
                UserIO.logf(format, level, args);
        }

        /// Logs an exception, using the given `LogFunc`, as an error.
        ///
        /// Prefer the use of `logException`, `debugException`, and `verboseException`.
        void exception(alias LogFunc)(Exception ex)
        {
            LogFunc(
                "----EXCEPTION----\nFile: %s\nLine: %s\nType: %s\nMessage: '%s'\nTrace: %s",
                ex.file,
                ex.line,
                ex.classinfo,
                ex.msg,
                ex.info
            );
        }

        // I'm not auto-generating these, as I want autocomplete (e.g. vscode) to be able to pick these up.

        /// Helper functions for `logf`, to easily use a specific log level.
        void logTracef   (Args...)(const char[] format, Args args){ UserIO.logf(format, LogLevel.trace, args);    }
        /// ditto
        void logInfof    (Args...)(const char[] format, Args args){ UserIO.logf(format, LogLevel.info, args);     }
        /// ditto
        void logWarningf (Args...)(const char[] format, Args args){ UserIO.logf(format, LogLevel.warning, args);  }
        /// ditto
        void logErrorf   (Args...)(const char[] format, Args args){ UserIO.logf(format, LogLevel.error, args);    }
        /// ditto
        void logCriticalf(Args...)(const char[] format, Args args){ UserIO.logf(format, LogLevel.critical, args); }
        /// ditto
        void logFatalf   (Args...)(const char[] format, Args args){ UserIO.logf(format, LogLevel.fatal, args);    }
        /// ditto
        alias logException = exception!logErrorf;

        /// Helper functions for `debugf`, to easily use a specific log level.
        void debugTracef   (Args...)(const char[] format, Args args){ UserIO.debugf(format, LogLevel.trace, args);    }
        /// ditto
        void debugInfof    (Args...)(const char[] format, Args args){ UserIO.debugf(format, LogLevel.info, args);     }
        /// ditto
        void debugWarningf (Args...)(const char[] format, Args args){ UserIO.debugf(format, LogLevel.warning, args);  }
        /// ditto
        void debugErrorf   (Args...)(const char[] format, Args args){ UserIO.debugf(format, LogLevel.error, args);    }
        /// ditto
        void debugCriticalf(Args...)(const char[] format, Args args){ UserIO.debugf(format, LogLevel.critical, args); }
        /// ditto
        void debugFatalf   (Args...)(const char[] format, Args args){ UserIO.debugf(format, LogLevel.fatal, args);    }
        /// ditto
        alias debugException = exception!debugErrorf;

        /// Helper functions for `verbosef`, to easily use a specific log level.
        void verboseTracef   (Args...)(const char[] format, Args args){ UserIO.verbosef(format, LogLevel.trace, args);    }
        /// ditto
        void verboseInfof    (Args...)(const char[] format, Args args){ UserIO.verbosef(format, LogLevel.info, args);     }
        /// ditto
        void verboseWarningf (Args...)(const char[] format, Args args){ UserIO.verbosef(format, LogLevel.warning, args);  }
        /// ditto
        void verboseErrorf   (Args...)(const char[] format, Args args){ UserIO.verbosef(format, LogLevel.error, args);    }
        /// ditto
        void verboseCriticalf(Args...)(const char[] format, Args args){ UserIO.verbosef(format, LogLevel.critical, args); }
        /// ditto
        void verboseFatalf   (Args...)(const char[] format, Args args){ UserIO.verbosef(format, LogLevel.fatal, args);    }
        /// ditto
        alias verboseException = exception!verboseErrorf;
    }

    /+++++++++++++++++
     +++  CURSOR   +++
     +++++++++++++++++/
    public static
    {
        @safe
        private void singleArgCsiCommand(char command)(size_t n)
        {
            import std.conv   : to;
            import std.stdio  : write;
            import std.format : sformat;

            enum FORMAT_STRING = "\033[%s"~command;
            enum SIZET_LENGTH  = size_t.max.to!string.length;

            char[SIZET_LENGTH] buffer;
            const used = sformat!FORMAT_STRING(buffer, n);

            // Pretty sure this is safe right? It copies the buffer, right?
            write(used);
        }

        // Again, not auto generated since I don't trust autocomplete to pick up aliases properly.

        /++
         + Moves the console's cursor down and moves the cursor to the start of that line.
         +
         + Params:
         +  lineCount = The amount of lines to move down.
         + ++/
        @safe
        void moveCursorDownByLines(size_t lineCount) { UserIO.singleArgCsiCommand!'E'(lineCount); }

        /++
         + Moves the console's cursor up and moves the cursor to the start of that line.
         +
         + Params:
         +  lineCount = The amount of lines to move up.
         + ++/
        @safe
        void moveCursorUpByLines(size_t lineCount) { UserIO.singleArgCsiCommand!'F'(lineCount); }
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
    bool useColouredText = true;
    LogLevel minLogLevel;
}

private struct UserIOConfig
{
    UserIOConfigScope global;
}

/++
 + A struct that provides an easy and fluent way to configure how `UserIO` works.
 + ++/
struct UserIOConfigBuilder
{
    private ref UserIOConfigScope getScope()
    {
        // For future purposes.
        return UserIO._config.global;
    }

    /++
     + Determines whether `UserIO.log` uses coloured output based on log level.
     + ++/
    UserIOConfigBuilder useColouredText(bool value = true)
    {
        this.getScope().useColouredText = value;
        return this;
    }

    /++
     + Determines whether `UserIO.verbosef` and friends are allowed to output anything at all.
     + ++/
    UserIOConfigBuilder useVerboseLogging(bool value = true)
    {
        this.getScope().useVerboseLogging = value;
        return this;
    }

    /++
     + Sets the minimum log level. Any logs must be >= this `level` in order to be printed out on screen.
     + ++/
    UserIOConfigBuilder useMinimumLogLevel(LogLevel level)
    {
        this.getScope().minLogLevel = level;
        return this;
    }
}