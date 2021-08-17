module binders;

import std.stdio : File;
import jcli : Binder, ResultOf, ok, fail;

/++
 + Please review jcli.binder.ArgBinder's documentation for detailed information.
 +
 + To be brief: An @Binder is used to convert a string (from the command line) into another type.
 + 
 + For example, if a command had an arg called "file", and it was of type "File", then an arg binder matching
 + the following signature is used to perform the conversion:
 +
 + ResultOf!File MyArgBinder(string argAsString);
 + ++/

// Arg binder that opens a file in read mode.
@Binder
ResultOf!File fileBinder(string arg)
{
    try return ok!File(File(arg, "r"));
    catch(Exception) return fail!File("File does not exist.");
}