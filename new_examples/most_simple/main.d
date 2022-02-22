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
    return executeSingleCommand!IsEvenCommand(args[1 .. $]);
}

// Or like this
// mixin SingleCommandMain!IsEvenCommand;
