# Overview

JCLI is a library to aid in the creation of command line tooling, with an aim of being easy to use, while also allowing
the individual parts of the library to be used on their own, allowing more dedicated users some tools to create their own
customised core.

## Components

I'll refer to the 'individual parts' as 'components', as that makes sense to me:

* ArgBinder - A simple helper struct which allows the user to define functions that binds a string (the arg) into a value of any type, so long
              as that type has an `@ArgBinder` available. `ArgBinder` will automatically discover and choose which binders to use for any given type.

* CommandLineInterface - This is the 'core' provided by JCLI, and is built up from every other component. 
                         It will automatically discover structs/classes decorated with `@Command`; auto-generate help text; auto-bind and parse the command line
                         args; provides dependency injection (via JIOC), etc.

* HelpTextBuilder - As the name implies, it is used to create a help text. Comes with a 'technical' version for more fine-grained control, and a 'simple' version
                    for an easier-to-use, generically layed out help message. Content is provided by classes that inherit the `IHelpSectionContent` class, which
                    also provides a line-wrap helper function.

* ArgPullParser - An InputRange that parses the `args` parameter passed to the main function. **Note** that this function expects the data to be provided in the same
                  way as the main function's `args` parameter. e.g. ["env", "set", "--name=abc", "-v", "yada"] should be passed instead of ["env set --name=abc -v yada"].

* Shell - Contains a set of helper functions related to the shell. Highlights include `pushLocation` and `popLocation` (if you're familiar with Powershell's `Push-Location`,              etc.); check if a command exists; toggleable logging functions, and several functions to execute commands.

It's best to refer to the documentation of each comment, as they go into much more detail than this brief overview.

Should `CommandLineInterface` not work to your expectations, then as mentioned the other components can be used to help you create your own solution.

I'd like this library to also touch upon other aspects of creating a command line tool (e.g. some of the stuff [scriptlike](https://code.dlang.org/packages/scriptlike) does, which I recommend using alongside this library for certain features such as its `Path` struct), but that's all in the future.

## Quick Start

Include this library in your project (e.g. `dub add jcli`).

Create a class or struct; attach `@Command("commandname")` onto it; add as many public variables as you want, with `@CommandNamedArg` or `@CommandPositionalArg` attached; 
add an `onExecute` function that returns either `void` or `int`:

```d
module mytool.commands;

import jaster.cli;

// Matches: mytool compile all
//          mytool compile
//          mytool ct
@Command("compile all|compile|ct")
struct CompileCommand
{
    // Use `Nullable` for optional arguments.
    // `std.nullable` is publicly imported by JCLI for ease-of-use.
    @CommandNamedArg("o|output", "Where to place the compiled output")
    Nullable!string output;

    @CommandPositionalArg(0, "The file to compile")
    string toCompile;

    int onExecute()
    {
        import std.file : exists;

        if(!exists(this.toCompile))
            return -1; // Return an int if you want to control the exit code.

        // do compile
        return 0;
    }
}
```

Create an instance of `CommandLineInterface`, passing it any modules containing commands or `@ArgBinder` functions into its template argument; call `parseAndExecute` #
with the main function's `args`; return the resulting status code:

```d
import jaster.cli;
import mytool.commands;

void main(string[] args)
{
    auto runner = new CommandLineInterface!(
        mytool.commands
    );

    auto statusCode = runner.parseAndExecute(args);
    return statusCode;
}
```

Fin.

## Dependency Injection

You can add the [JIOC](https://code.dlang.org/packages/jioc) library into your project, and then create and pass a `ServiceProvider` into the constructor
of `CommandLineInterface`. Afterwards, all command objects are created with dependency injection via JIOC's `Injector.construct`.

This is the *only* way `CommandLineInterface` is able to pass data into a command's constructor.

## Help text

`CommandLineInterface` will automatically generate help text for any given command, and if no command is specified (or found) then it'll show a list of all commands, or commands
similar to the arguments given to it.

Help text is shown eiter by using an unknown command, or passing either `-h` or `--help`. This does mean however that commands cannot use these as argument names.

Here is an example of the help text for a specific command:

```text
> .\aim.exe secrets set -h
Usage: secrets set {0/name} {1/value} <[v|verbose]>

Description:
        Sets the value of a secret.

Positional Args:
    0,name                       - The name of the secret to set the value of.
    1,value                      - The value to give the secret.

Named Args:
    -v,--verbose                 - Show verbose output.
```

Here is an example of the help text listing commands that are similar to the arguments provided:

```text
> .\aim.exe deploy -h

Available commands:
    deploy init                  - Initialises a deployment project.
    deploy pack                  - Creates a package that can then be deployed to a server.
    deploy trigger               - Triggers a deployment attempt.
```

```text
> .\aim.exe secrets -h

Available commands:
    secrets define               - Defines a new secret.
    secrets get                  - Gets the value of a secret.
    secrets list                 - Lists all defined secrets.
    secrets set                  - Sets the value of a secret.
    secrets undefine             - Undefines an already defined secret.
    secrets verify               - Verifies that all non-optional secrets have been given a value.
```

And of course, if you provide no other arguments other than `-h`, then every command will be listed instead.

## Limitations of CommandLineInterface

* (Will be fixed soon, I'm just lazy) There is no way to specify a 'default' command - an unnamed command that'll run just from the tool being used in the first place.

## Contribution

I'm perfectly accepting of anyone wanting to contribute to this library, just note that it might take me a while to respond.
