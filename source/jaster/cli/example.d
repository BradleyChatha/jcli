module jaster.cli.example;

import jaster.cli.udas;

@Command
@CommandName("publish")
@CommandDescription("Lreomaoromearipasfiaospigtn193n2093n0128goats")
struct PublishCommand
{
    @Argument
    @ArgumentIndex(0)
    @ArgumentRequired
    string exampleArgument;

    @Argument
    @ArgumentOption("e|example")
    @ArgumentRequired
    @ArgumentDescription("Some example argument.")
    int anotherExampleArgument;

    void onExecute()
    {
        import std.stdio;
        writeln("Arg1: ", this.exampleArgument, " | Arg2: ", this.anotherExampleArgument);
    }
}

@Command
@CommandGroup("env")
@CommandName("set")
@CommandDescription("SITBUSIBGASIGNdsIOOOOOOOOOOOOO")
struct EnvironmentSetCommand
{
    @Argument
    @ArgumentIndex(0)
    @ArgumentRequired
    @ArgumentDescription("The name of the env var to set.")
    string name;

    @Argument
    @ArgumentIndex(1)
    @ArgumentRequired
    @ArgumentDescription("The value to give the env var.")
    string value;

    void onExecute()
    {
        import std.stdio;
        writefln("Set var %s with value %s", this.name, this.value);
    }
}

void pseudoMain(string[] args)
{
    import jaster.cli.core;
    runCliCommands!
    (
        jaster.cli.example
    )();
}