module commands;

import jaster.cli;

@Command("insensitive", "A command with insensitive argument names.")
struct InsensitiveCommand
{
    @CommandNamedArg("abc")
    @(CommandArgConfig.caseInsensitive)
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

@Command("redefine", "A command that can have its arguments redefined.")
struct RedefineCommand
{
    @CommandNamedArg("abc")
    @(CommandArgConfig.canRedefine)
    int abc;

    int onExecute() { return abc; }
}

@Command("no-redefine", "A Command that cannot have its arguments redefined (default).")
struct NoRedefineCommand
{
    @CommandNamedArg("abc")
    int abc;

    void onExecute(){}
}