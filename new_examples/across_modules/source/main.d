import jcli;

int main(string[] args)
{
    // The idea of this one is that all of the commands in the given modules will
    // get registered at compile time. In this case, we give it just a single module,
    // `commands`, but you can imagine having multiple.

    /*
        Examples:

        across_modules -help

        across_modules add -help
        
        across_modules add 1 2

        across_modules -logLevel warning add 1 2

        across_modules print -help

        across_modules print "Hello world!"

    */

    static import commands;
    return matchAndExecuteAcrossModules!(commands)(args[1 .. $]);
}
