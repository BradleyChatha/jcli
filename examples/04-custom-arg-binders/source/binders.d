module binders;

import std.stdio : File;
import jaster.cli : ArgBinderFunc, Result;

/++
 + Please review jaster.cli.binder.ArgBinder's documentation for detailed information.
 +
 + To be brief: An @ArgBinderFunc is used to convert a string (from the command line) into another type.
 + 
 + For example, if a command had an arg called "file", and it was of type "File", then an arg binder matching
 + the following signature is used to perform the conversion:
 +
 + Result!File MyArgBinder(string argAsString);
 + ++/

 // Arg binder that opens a file in read mode.
 @ArgBinderFunc
 Result!File fileBinder(string arg)
 {
    try return Result!File.success(File(arg, "r"));
    catch(Exception) return Result!File.failure("File does not exist.");
 }