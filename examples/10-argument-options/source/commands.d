module commands;

import jcli;

@Command("insensitive", "A command with insensitive argument names.")
struct InsensitiveCommand
{
    @ArgNamed("abc")
    @(ArgConfig.caseInsensitive)
    int abc;

    void onExecute(){}
}

@Command("sensitive", "A command with sensitive (default) argument names.")
struct SensitiveCommand
{
    @ArgNamed("abc")
    int abc;

    void onExecute(){}
}

@Command("redefine", "A command that can have its arguments redefined.")
struct RedefineCommand
{
    @ArgNamed("abc")
    @(ArgConfig.canRedefine)
    int abc;

    int onExecute() { return abc; }
}

@Command("no-redefine", "A Command that cannot have its arguments redefined (default).")
struct NoRedefineCommand
{
    @ArgNamed("abc")
    int abc;

    void onExecute(){}
}