module binders;

import std.stdio : File;
import jaster.cli : ArgBinderFunc;

/++
 + Please review jaster.cli.binder.ArgBinder's documentation for detailed information.
 +
 + To be brief: An @ArgBinderFunc is used to convert a string (from the command line) into another type.
 + 
 + For example, if a command had an arg called "file", and it was of type "File", then an arg binder matching
 + the following signature is used to perform the conversion:
 +
 + void MyArgBinder(string argAsString, ref File outputData_StartsAs_TypeDotInit);
 + ++/

 // Arg binder that opens a file in read mode.
 @ArgBinderFunc
 void fileBinder(string arg, ref File output)
 {
     output = File(arg, "r");
 }