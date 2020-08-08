<p align="center">
    <img src="https://i.imgur.com/nbQPhO9.png"/>
</p>

# Overview

![Tests](https://github.com/SealabJaster/jcli/workflows/Test%20LDC%20x64/badge.svg)
![Examples](https://github.com/SealabJaster/jcli/workflows/Test%20Examples/badge.svg)

JCLI is a library to aid in the creation of command line tooling, with an aim of being easy to use, while also allowing
the individual parts of the library to be used on their own, allowing more dedicated users some tools to create their own
customised core.

As a firm believer of good documentation, JCLI is completely documented with in-depth explanations where needed.

![Example gif](https://i.imgur.com/n5kCLVW.gif)

![Example gif 2](https://i.imgur.com/zLnHYg1.gif)

## Components

As mentioned, this library aims to also serve as a base for anyone who might need a more specialised 'core' for their application in the event that
the one provided by JCLI (via `CommandLineInterface`) doesn't live up to their needs, so the individual components are useable on their own:

* AnsiText - Fluently build up a piece of text containing Ansi escape codes, for the likes of colouring and styling your console output.
             **Windows ANSI support is automatically turned on.**

* Ansi parsing - Use helper ranges such as `asAnsiChars` and `asAnsiText` to fearlessly parse over text that may or may not contain ANSI encoded contents.

* ArgBinder - A simple helper struct which allows the user to define functions that binds a string (the arg) into a value of any type, so long
as that type has an `@ArgBinder` available. `ArgBinder` will automatically discover and choose which binders to use for any given type.

* ArgPullParser - An InputRange that parses the `args` parameter passed to the main function. **Note** that this function expects the data to be provided in the same
way as the main function's `args` parameter. e.g. ["env", "set", "--name=abc", "-v", "yada"] should be passed instead of ["env set --name=abc -v yada"].

* CommandLineInterface - This is the 'core' provided by JCLI, and is built up from every other component.
It will automatically discover structs/classes decorated with `@Command`; auto-generate help text; auto-bind and parse the command line
args; provides dependency injection (via JIOC), etc.

* HelpTextBuilder - As the name implies, it is used to create a help text. Comes with a 'technical' version for more fine-grained control, and a 'simple' version
for an easier-to-use, generically layed out help message. Content is provided by classes that inherit the `IHelpSectionContent` class, which
also provides a line-wrap helper function.

* IConfig & friends - Customisable configuration with selectable backends. For example, you could use the `AdaptableFileConfig` alongside the
`AsdfConfigAdapter` to serialise/deserialise your configuration using files and the asdf library.

* Shell - Contains a set of helper functions related to the shell. Highlights include `pushLocation` and `popLocation` (if you're familiar with Powershell's `Push-Location`, etc.); check if a command exists, and several functions to execute commands.

* TextBuffer - An ANSI-enabled text buffer which can be interfaced with using a `TextBufferWriter`, which allows editing of the `TextBuffer` as if it were a 2D grid of characters.

* UserIO - Get input and show output to the user. Optional colourful logging; debug-only and toggleable verbose logging; functions such as `getInput` and `getInputFromList` which
can make use of `ArgBinder` to perform conversions. Cursor control using ANSI CSI codes.

It's best to refer to the documentation of each component, as they go into much more detail than this brief overview.

Should `CommandLineInterface` not work to your expectations, then as mentioned the other components can be used to help you create your own solution.

I'd like this library to also touch upon other aspects of creating a command line tool (e.g. some of the stuff [scriptlike](https://code.dlang.org/packages/scriptlike) does, which I recommend using alongside this library for certain features such as its `Path` struct), but that's all in the future.

## Default Commands & Subcommands

JCLI has support for both a default command, and multiple sub-commands.

To create a default command - a command that is executed if no other sub-commands are used - make sure that when using `@Command()` that the name (the first parameter) is `null`.
e.g. `@Command()` or `@Command(null, "Some description")` would both create a default command.

For sub-commands, simply populate the name field of `@Command`, e.g. `@Command("et|execute task")` would create a sub-command that can be used as either `mytool.exe et` or `mytool.exe execute test`.

## Examples

There are documented examples within the [examples](https://github.com/SealabJaster/jcli/tree/master/examples) folder.

Other than there, here's a list of projects/scripts using JCLI:

* [JCLI's test runner](https://github.com/SealabJaster/jcli/blob/master/examples/test.d)

* [JCLI's manual/misc test program](https://github.com/SealabJaster/jcli_testerr)

## Changelog

I publish changelogs over at [my website](https://bradley.chatha.dev/Blog/JcliNews).

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
    // `Nullable` is publicly imported by JCLI for ease-of-use.
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

Create an instance of `CommandLineInterface`, passing it any modules containing commands or `@ArgBinder` functions into its template argument; call `parseAndExecute`
with the main function's `args`; return the resulting status code:

```d
import jaster.cli;
import mytool.commands;

int main(string[] args)
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

Please see [this](https://github.com/SealabJaster/jcli/tree/master/examples/05-dependency-injection) example for more information.

## Help text

`CommandLineInterface` will automatically generate help text for any given command, and if no command is specified (or found) then it'll show a list of all commands, or commands
similar to the arguments given to it.

Help text is shown either by using an unknown command, or passing either `-h` or `--help`. This does mean however that commands cannot use these as argument names.

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

## Versions

JCLI makes use of the `version` statement in various areas. Here is a list of all versions that JCLI utilises.

Any versions prefixed with `Have_` are automatically created by dub for each dependency in your project. For example, `Have_asdf` will be automatically
defined by dub if you have `asdf` as a dependency of your project. If you do not use dub then you'll have to manually specify these versions when relevant.

| Version       | Description                                                                                                                    |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| JCLI_Verbose  | When defined, enables certain verbose compile-time logging, such as how `ArgBinder` is deciding which `@ArgBinderFunc` to use. |
| Have_asdf     | Enables the `AsdfConfigAdapter`, which uses the `asdf` library to serialise the configuration value.                           |

## Contribution

I'm perfectly accepting of anyone wanting to contribute to this library, just note that it might take me a while to respond.

And please, if you have an issue, *create a Github issue for me*. I can't fix or prioritise issues that I don't know exist.
I tend to not care about issues when **I** run across them, but when **someone else** runs into them, then it becomes a much higher priority for me to address it.

Finally, if you use JCLI in anyway feel free to request for me to add your project into the `Examples` section. I'd really love to see how others are using my code :)
