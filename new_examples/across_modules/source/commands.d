module commands;

import jcli;
import std.stdio;

enum LogLevel
{
    // TODO: let the user add more info to these, should be really easy to add.
    // Examples:
    // @("Does stuff")
    // @Rename("debug")
    // @Hidden
    debug_,
    warning,
    error,
}

@CommandDefault("The common context, passed to all things")
struct CommonContext
{
    @(ArgConfig.optional)
    {
        @("The log level to apply.")
        auto logLevel = LogLevel.error;

        @("Path to temporary directory.")
        string tempPath;
    }

    // TODO: add a method that is called when the command is specifically a parent.
    void onExecute()
    {
        if (tempPath == "")
            tempPath = "temp";

        static import std.file;
        if (!std.file.exists(tempPath))
            std.file.mkdirRecurse(tempPath);

        if (logLevel == LogLevel.debug_)
            writeln("Just executed the common context's onExecute().");
    }
}

@Command("print", "Prints the number.")
struct Print
{
    @ParentCommand
    CommonContext* commonOps;

    @ArgPositional("The number to print.")
    int number;

    void onExecute()
    {
        writeln("number: ", number);

        if (commonOps.logLevel <= LogLevel.debug_)
            writeln("Temporary path: ", commonOps.tempPath);
    }
}


@Command("add", "Adds up two numbers.")
struct Add
{
    @ParentCommand
    CommonContext* commonOps;

    @ArgPositional("The first number.")
    int number1;
    
    @ArgPositional("The second number.")
    int number2;

    void onExecute()
    {
        writeln(number1 + number2);
    }
}
