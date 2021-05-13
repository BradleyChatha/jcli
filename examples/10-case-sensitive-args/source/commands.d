module commands;

import jaster.cli;

@Command("insensitive", "A command with insensitive argument names.")
struct InsensitiveCommand
{
    @CommandNamedArg("abc")
    @(CommandArgCase.insensitive)
    int abc;

    void onExecute(){}
}

@Command("sensitive", "A command with sensitive (default) argument names.")
struct SensitiveCommand
{
    @CommandNamedArg("abc")
    int abc;

    void onExecute(){}
}