module commands;

import jcli.core.udas;
import jcli.core.flags;

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

// This default command will be matched every time, so the named arguments
// will be processed before any named subcommands execute.
// Aka `program_name --logLevel=warning subcommand_name` will bind `LogLevel.warning`
// to the field `logLevel`, and then try to match the subcommand with the name `subcommand_name`. 
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

    // This method is called when the command is called as a terminal command.
    // An example in this case would be `./program_name`
    void onExecute()
    {
        writeln("TODO: display help message when the command is called without a child command argument.");
    }

    // TODO: allow freestanding functions as callbacks (this is more involved to implement).

    // An example: `./program_name print -number 1`.
    // So before the arguments to `print` get parsed, this method gets invoked first.
    void onIntermediateExecute()
    {
        if (tempPath == "")
            tempPath = "temp";

        static import std.file;
        if (!std.file.exists(tempPath))
            // Commented-out, so that it's not annoying
            // std.file.mkdirRecurse(tempPath);
            writeln("Temp path: ", tempPath);

        if (logLevel == LogLevel.debug_)
            writeln("Just executed the common context's onExecute().");
    }
}

@Command("print", "Prints the number.")
struct Print
{
    // This UDA adds this command (print) as a subcommand of the default command (CommonContext).
    @ParentCommand
    CommonContext* commonOps;

    @ArgPositional("The number to print.")
    int number;

    // Examples:
    // program_name print 1
    // program_name -logLevel=error print 2
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
    // This UDA adds this command (add) as a subcommand of the default command (CommonContext).
    @ParentCommand
    CommonContext* commonOps;

    @ArgPositional("The first number.")
    int number1;
    
    @ArgPositional("The second number.")
    int number2;

    // Examples:
    // program_name add 1 2
    // program_name -logLevel=error add 1 2
    void onExecute()
    {
        writeln(number1 + number2);
    }
}
