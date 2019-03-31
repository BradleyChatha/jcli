module jaster.cli.tests;

version(unittest):

import jaster.cli.udas, jaster.cli.core;

@Command
@CommandGroup("test")
@CommandName("param-option")
struct ParamOptionParseCommand
{
    @Argument
    @ArgumentOption("s|str")
    @ArgumentRequired
    string str;

    @Argument
    @ArgumentIndex(0)
    string str2;

    void onExecute()
    {
        assert(this.str == "Lalafell", this.str);
        assert(this.str2 == "Suck", this.str2);
    }
}
unittest
{
    void doTest(string option)
    {
        import std.algorithm : splitter;
        import std.array : array;
        auto args = ["test", "param-option"] ~ option.splitter(' ').array;
        runCliCommands!(jaster.cli.tests)(args);
    }

    // Test all supported permiations.
    doTest("-s Lalafell Suck");
    doTest("Suck -s=Lalafell");
    doTest("-sLalafell Suck");
    doTest("--str Lalafell Suck");
    doTest("--str=Lalafell Suck");

    runCliCommands!(jaster.cli.tests)(["--help"], IgnoreFirstArg.no);
    runCliCommands!(jaster.cli.tests)(["test", "--help"], IgnoreFirstArg.no);
    runCliCommands!(jaster.cli.tests)(["test", "param-option", "--help"], IgnoreFirstArg.no);
}