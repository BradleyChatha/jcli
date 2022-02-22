import jcli;

import std.stdio;

// TODO: 
// Allow the @("description") syntax for all commands, but this needs a bit more internal rework.
// And what should that mean exactly? Maybe only allow that syntax for commands used in the simple API's?
@CommandDefault("Asserts the number is even.")
struct IsEvenCommand
{
    @("The number to assert")
    int number;

    @("Whether to reverse the logic (assert that it's false)")
    @(ArgConfig.parseAsFlag)
    bool reverse;

    @("What error code to return if it's odd")
    @(ArgConfig.caseInsensitive)
    int errorCodeIfOdd = 1; // is implied optional.


    int onExecute()
    {
        writeln("Got arguments number = ", number, 
            ", reverse = ", reverse, 
            ", errorCodeIfOdd = ", errorCodeIfOdd);

        bool isOdd = number & 1;
        
        if (reverse)
        {
            if (!isOdd)
                return errorCodeIfOdd;
        }
        else if (isOdd)
        {
            return errorCodeIfOdd;
        }

        return 0;
    }
}

int main(string[] args)
{
    // TODO: should be way simpler.
    // TODO: another wrapper that handles help, return code, etc.
    // As is, this is too much detail for the user.
    auto context = matchAndExecute!(bindArgumentSimple, IsEvenCommand)(args[1 .. $]);

    // TODO: should use a typesafe wrapper
    if (context.state == MatchAndExecuteState.finalExecutionResult)
        return context._executeCommandResult.exitCode;
    return -1;

    // TODO: simple API like this, which should not require any command UDA's.
    // return executeSingleCommand!Command()
}

// Or like this
// mixin singleCommandMain!Command;

