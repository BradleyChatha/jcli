module commands;

import jcli;

// JCLI has full support for inheritence, allowing you to specify base commands.
//
// All public `@ArgNamed` and `@ArgPositional` args will be available to
// the inheriting command.
//
// Don't attach `@Command` onto base classes though.
abstract class BaseCommand
{
    @ArgNamed("offset", "An offset to apply to any calculations")
    Nullable!int offset;

    protected int add(int a, int b)
    {
        return a + b + this.offset.get(0);
    }
}

// Simply inherit from the BaseCommand, and things just work (tm)
@Command("add", "Adds two numbers together, and sets the status code to the sum.")
class AddCommand : BaseCommand
{
    @ArgPositional
    int a;

    @ArgPositional
    int b;

    int onExecute()
    {
        return super.add(this.a, this.b);
    }

    /++
     + EXAMPLE USAGE:
     +  test.exe add 1 2            -> status code 3
     +  test.exe add 1 2 --offset=7 -> status code 10
     + ++/
}