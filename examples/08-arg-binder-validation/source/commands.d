module commands;

import std.typecons : Flag;
import jcli;

alias Even = Flag!"even";

// This is a validation struct
//
// It performs post-binding value validation (`postValidate`)
@PostValidator
struct Is
{
    import std.traits : isNumeric;

    // Because D is magical, you can store whatever state you want in UDAs, so validators get the same pleasure.
    Even isEven;

    ResultOf!void postValidate(T)(T number)
    if(isNumeric!T)
    {
        // Validators can create user-friendly error messages, instead of the ugly generated one.

        if(this.isEven)
            return number % 2 == 0 ? ResultOf!void.ok() : ResultOf!void.fail("Expected number to be even.");
        else
            return number % 2 == 1 ? ResultOf!void.ok() : ResultOf!void.fail("Expected number to be odd");
    }
}

@CommandDefault
struct DefaultCommand
{
    @ArgPositional("Even", "Should be even")
    @Is(Even.yes) // All you have to do is attach it like so!
    int evenNumber;

    @ArgPositional("Odd", "Should be odd")
    @Is(Even.no)
    int oddNumber;

    int onExecute()
    {
        return 0; // Return 0 on ok. CommandLineInterface will return -1 on validation error.
    }
}