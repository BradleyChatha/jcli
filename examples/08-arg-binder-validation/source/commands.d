module commands;

import std.typecons : Flag;
import jaster.cli;

alias Even = Flag!"even";

// This is a validation struct
//
// It performs value validation (`onValidate`)
@ArgValidator
struct Is
{
    import std.traits : isNumeric;

    // Because D is magical, you can store whatever state you want in UDAs, so validators get the same pleasure.
    Even isEven;

    Result!void onValidate(T)(T number)
    if(isNumeric!T)
    {
        // Validators can create user-friendly error messages, instead of the ugly generated one.

        if(this.isEven)
            return number % 2 == 0 ? Result!void.success() : Result!void.failure("Expected number to be even.");
        else
            return number % 2 == 1 ? Result!void.success() : Result!void.failure("Expected number to be odd");
    }
}

@CommandDefault
struct DefaultCommand
{
    @CommandPositionalArg(0, "Even", "Should be even")
    @Is(Even.yes) // All you have to do is attach it like so!
    int evenNumber;

    @CommandPositionalArg(1, "Odd", "Should be odd")
    @Is(Even.no)
    int oddNumber;

    int onExecute()
    {
        return 0; // Return 0 on success. CommandLineInterface will return -1 on validation error.
    }
}