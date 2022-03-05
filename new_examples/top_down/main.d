module new_examples.top_down.main;

int main(string[] args)
{
    // The top-down approach means all commands must list their subcommands.
    // In my opinion this one is easier to understand than the bottom-up approach,
    // because it is more explicit.
    // @ParentCommand attributes are ignored if you're taking this approach.

    /*
        Examples:

        top_down --help

        top_down print --help

        top_down print "Hello world!"

        top_down -silent print "Hello"

        top_down multiply --help

        top_down multiply 1 2

        top_down multiply 5 10 -reciprocal

        top_down multiply 5 0 -reciprocal

        top_down -s multiply 5 0 -reciprocal
    */
    import jcli : matchAndExecuteFromRootCommands;
    import jcli.argbinder : bindArgumentSimple;
    return matchAndExecuteFromRootCommands!(bindArgumentSimple, RootCommand)(args[1 .. $]);
}

import jcli.core.udas;
import jcli.core.flags : ArgConfig;
import std.stdio : writeln;

@CommandDefault("The root command, which gives some common context to the subcommands.")
@(Subcommands!(PrintCommand, MultiplyCommand))
struct RootCommand
{
    @ArgNamed("silent|s", "Silences all console logs (opt-in).")
    @(ArgConfig.parseAsFlag)
    bool silent;

    void onIntermediateExecute()
    {
        maybeWriteln("Intermediate execute...");
    }

    // Just forward all args to `writeln`.
    void maybeWriteln(Args...)(auto ref Args args)
    {
        if (!silent)
            writeln(args);
    }
}

// This subcommand is terminal = does not define any subcommands of its own.
// You can define subcommands to any level of depth.
// @(Subcommands!(SomeCommandA, SomeCommandB))
@Command("print", "Prints whatever it's given")
struct PrintCommand
{
    // @ParentCommand
    RootCommand* root;

    @ArgPositional("Some string that will be printed.")
    string whatever;

    void onExecute()
    {
        // I'm using the helper here, but you can still access `root.silent`
        root.maybeWriteln(whatever);
    }
}

@Command("multiply", "Multiplies the 2 given numbers")
struct MultiplyCommand
{
    RootCommand* root;

    @("Whether to return the reciprocal of the answer.")
    @(ArgConfig.parseAsFlag)
    bool reciprocal;
    
    // TODO:
    // Positional aggregate arguments are not supported currently.
    // Could mutiply up N numbers if we had that feature.

    // ArgGroup is a convenient way to add info to both of these arguments.
    @ArgGroup("numbers", "Numbers to multiply together")
    {
        @ArgPositional
        float a;

        @ArgPositional
        float b;
    }

    int onExecute()
    {
        float result = a * b;
        if (reciprocal)
        {
            import std.math;
            if (isClose(result, 0f))
            {
                root.maybeWriteln("Error: division by 0.");
                return 1;
            }
            result = 1 / result;
        }
        root.maybeWriteln(result);
        return 0;
    }
}