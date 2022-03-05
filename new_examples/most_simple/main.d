int main(string[] args)
{
    /*
        Examples:
        
        most_simple -help

        most_simple -number 1

        most_simple --number 2 -reverse

        most_simple --number=3 --reverse false

        most_simple --number 4 --errorCodeIfOdd 7
    */
    import jcli : executeSingleCommand;
    return executeSingleCommand!IsEvenCommand(args[1 .. $]);
}

// Or like this
// mixin SingleCommandMain!IsEvenCommand;


import jcli.core.udas : ArgNamed, ArgPositional;
import jcli.core.flags : ArgConfig;

// This string uda gets interpreted as the help message for the command.
// It can only be applied in the simple case where you use `executeSingleCommand`,
// with `matchAndExecuteCommand` you will have to be more specific (see the corresponding examples).
@("Asserts the number is even.")
struct IsEvenCommand
{
    // A string UDA defines a required named argument with the same name as the field (`number`).
    // You can alternatively use the ArgNamed UDA, like this:
    // ArgNamed("number", "The number to assert")
    @("The number to assert")
    int number;

    // Again, I'm using the same short form to declare a named argument with the name `reverse`.
    // The `parseAsFlag` UDA means that it will be treated like a boolean flag, like `-i` in `dmd -i`,
    // implies optional.
    @("Whether to reverse the logic (assert that it's false)")
    @(ArgConfig.parseAsFlag)
    bool reverse;

    @("What error code to return if it's odd")
    @(ArgConfig.caseInsensitive)
    int errorCodeIfOdd = 1; // is implied optional.


    // This is the function that gets executed when args have been matched successfully.
    // This function should return the error code, or be void.
    // In this case, we obviously return an error code.
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
