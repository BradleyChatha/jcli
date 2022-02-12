<p align="center">
    <img src="https://i.imgur.com/nbQPhO9.png"/>
</p>

# Overview

![Tests](https://github.com/BradleyChatha/jcli/workflows/Test%20LDC%20x64/badge.svg)
![Build and Test](https://github.com/BradleyChatha/jcli/actions/workflows/unittests.yaml/badge.svg)

** As of v0.20.0 JCLI is using a fully rewritten code base, which has major breaking changes. **

JCLI is a library to aid in the creation of command line tooling, with an aim of being easy to use, while also allowing
the individual parts of the library to be used on their own, aiding more dedicated users in creation of their own CLI core.

As a firm believer of good documentation, JCLI is completely documented with in-depth explanations where needed. In-browser documentation can be found [here](https://jcli.dpldocs.info/jcli.html) (new code base doesn't have docs yet, will come soon (tm)).

Tested on Windows and Ubuntu 18.04.

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
  - [Creating a default command](#creating-a-default-command)
  - [Positional Arguments](#positional-arguments)
  - [Registering commands](#registering-commands)
  - [Running the program](#running-the-program)
  - [Named arguments](#named-arguments)
  - [Optional Arguments](#optional-arguments)
  - [Arguments with multiple names](#arguments-with-multiple-names)
  - [Named Commands](#named-commands)
  - [User Defined argument binding](#user-defined-argument-binding)
  - [User Defined argument validation](#user-defined-argument-validation)
  - [Per-argument binding](#per-argument-binding)
  - [Unparsed Raw Arg List](#unparsed-raw-arg-list)
  - [Inheritance](#inheritance)
  - [Argument groups](#argument-groups)
  - [Bash Completion](#bash-completion)
  - [Argument parsing actions](#argument-parsing-actions)
    - [ArgAction.count](#argactioncount)
  - [Command Introspection](#command-introspection)
  - [Light-weight command parsing](#light-weight-command-parsing)
  - [Light-weight command help text](#light-weight-command-help-text)
  - [Argument configuration](#argument-configuration)
    - [ArgConfig.caseInsensitive](#argconfigcaseinsensitive)
    - [ArgConfig.canRedefine](#argconfigcanredefine)
- [Using JCLI without Dub](#using-jcli-without-dub)
- [Contributing](#contributing)

    * Advanced usage:
        1. [User Defined argument binding](#user-defined-argument-binding)
        1. [User Defined argument validation](#user-defined-argument-validation)
        1. [Per-Argument binding](#per-argument-binding)
        1. [Dependency Injection](#dependency-injection)
        1. [Calling a command from another command](#calling-a-command-from-another-command)
        1. [Configuration](#configuration)
        1. [Inheritance](#inheritance)
        1. [Argument groups](#argument-groups)
        1. [Bash Completion](#bash-completion)
            1. [Using eval](#using-eval)
            1. [Using bash-completion](#using-bash-completion)
        1. [Argument parsing actions](#argument-parsing-actions)
            1. [ArgAction.count](#ArgActioncount)
        1. [Command Introspection](#command-introspection)
        1. [Light-weight command parsing](#light-weight-command-parsing)
        1. [Light-weight command help text](#light-weight-command-help-text)
        1. [Using a custom sink in CommandLineInterface](#using-a-custom-sink-in-commandlineinterface)
        1. [Argument configuration](#argument-configuration)
            1. [ArgConfig.caseInsensitive](#ArgConfigcaseinsensitive)
            1. [ArgConfig.canRedefine](#ArgConfigcanredefine)
1. [Using JCLI without Dub](#using-jcli-without-dub)
1. [Contributing](#contributing)

# Features

* Building:

    * This library was primarily built using [Meson](https://mesonbuild.com) as the build system, so should be fully integratable into other Meson projects.

    * All individual parts of this library are intended to be reusable. Allowing you to build your own CLI core using these already-made components, if desired.

    * All individual parts of this library are split into sub packages, so you can only include what you need if you're not using the main `jcli` package.

* Argument parsing:

    * Named and positional arguments.

    * Boolean arguments (flags).

    * Optional arguments using the standard `Nullable` type.

    * User-Defined argument binding (string -> any_type_you_want) - blanket and per-argument.

    * User-Defined argument validation (via UDAs that follow a convention).

    * Pass through unparsed arguments (`./mytool parsed args -- these are unparsed args`).

    * Capture overflowed arguments (`./mytool arg1 arg2 overflow1 overflow2`)

    * Automatic error messages for missing and malformed arguments.

* Commands:

    * Standard command line format (`./mytool command args --flag=value ...`).

    * Automatic command dispatch.

    * Defined using UDAs, and are automatically discovered.

    * Supports a default command.

    * Supports named commands that allow for multiple words and per-command argument parsing.

    * ~~Support for command inheritance~~ (currently broken).

    * Only `structs` are allowed for the moment.

* Help text:

    * Automatically generated with slight ability for customisation.

    * Works for the default command.

    * Works for exact matches for named commands.

    * Works for partial matches for named commands.

    * Arguments can be displayed in organised groups.

* Utilities:

    * Bash completion support.

    * Decent support for writing and parsing ANSI text via [jcli](https://github.com/BradleyChatha/jcli).

    * An ANSI-enabled text buffer, for easier and efficient control over coloured, non-uniform text output.

# Quick Start

*This is a brief overview, for slightly more in-depth examples please look at the fully-documented [examples](https://github.com/BradleyChatha/jcli/tree/master/examples) folder.*

## Creating a default command

The default command is the command that is ran when you don't specify any named command. e.g. `mytool 60 20 --some=args` would call the default command if it exists:

```d
// inside of app.d
module app;
import jcli

@CommandDefault("The default command.")
struct DefaultCommand
{
    int onExecute()
    {
        return 0;
    }
}
```

The `@CommandDefault` is a UDA (User Defined Attribute) where the first parameter is the command's description.

All commands must define an `onExecute` function, which either returns `void`, or an `int` that will be used as the program's exit/status code.

As a side note, an initial dub project does not include the `module app;` statement shown in the example above. I've added it as we'll need to directly reference the module in a later section.

## Positional Arguments

To start off, let's make our default command take a number as a positional arg. If this number is even then return `1`, otherwise return `0`.

Positional arguments are expected to exist in a specific position within the arguments passed to your program.

For example the command `mytool 60 yoyo true` would have `60` in the 0th position, `yoyo` in the 1st position, and `true` in the 2nd position:

```d
@CommandDefault("The default command.")
struct DefaultCommand
{
    @ArgPositional("number", "The number to check.")
    int number;

    int onExecute()
    {
        return number % 2 == 0 ? 1 : 0;
    }
}
```

We create the field member `int number;` and decorate it with the `@ArgPositional` UDA to specify it as a positional argument.

The first parameter is an optional name we can give the parameter, which is shown in the command's help text, but serves no other function.

The last parameter is simply a description.

An example of the help text is shown in the [Running your program](#running-your-program) section, which demonstrates why
you should provide a name to positional arguments.

The position of a positional argument is defined by the order it appears in your command, relative to other positional arguments.

For example:

```d
@CommandDefault
struct Command
{
    @ArgPositional // I'm at position 0
    int one;
    
    @ArgPositional // I'm at position 1
    int two;

    @ArgPositional // I'm at position 2
    int three;
}

// myTool.exe one two three
```

## Registering commands

To use our new command, we just need to register it first:

```d
module app;

import jcli;
import std.stdio;

// This is still in app.d
int main(string[] args)
{
    auto executor = new CommandLineInterface!(app);
    const statusCode = executor.parseAndExecute(args);

    writefln("Program exited with status code %s", statusCode);

    return statusCode;
}

// Imagine our previous command code is here.
```

Our main function is defined to return an `int` (status code) while also taking in any arguments passed to us via the `args` parameter.

First, we create `executor` which is a `CommandLineInterface` instance. To discover commands, it must know which modules to look in. Remember at the start I told you to write `module app;` at the start of the file? So what we're doing here is passing our module called `app` into `CommandLineInterface`, so that it can find all our commands there.

For future reference, you can pass any amount of modules into `CommandLineInterface`, not just a single one.

Second, we call `executor.parseAndExecute(args)`, which returns a status code that we store into the variable `statusCode`. This `parseAndExecute` function will parse the arguments given to it; figure out which command to call; create an instance of that command; fill out the command's argument members, and then finally call the command's `onExecute` function. The rest is pretty self explanatory.

Your app.d file should look something like [this](https://pastebin.com/PhRFtW9G).

## Running the program

First, let's have a look at the help text for our default command:

```bash
$> ./mytool --help
mytool DEFAULT number

Description:
    The default command.

Positional Arguments:
    number                 The number to check.
```

So we can see that the help text matches the structure of our `DefaultCommand` struct.

Next, let's try out our command!

```bash
# Even number
$> ./mytool 60
Program exited with status code 1

# Odd number
$> ./mytool 59
Program exited with status code 0

# No number
$> ./mytool
temp.exe: Expected 1 positional arguments but got 0 instead. Missing the following required positional arguments: number
Program exited with status code -1

# Too many numbers
$> ./mytool 1 2
temp.exe: Too many positional arguments near '2'. Expected 1 positional arguments.
Program exited with status code -1
```

Excellent, we can see that with little to no work, our command performs as expected while rejecting invalid use cases.

## Named arguments

Now let's add a mode that will enable reversed output (return `1` for odd number and `0` for even). To do this we should add a named argument called `--mode` that maps directly to an `enum`:

```d
enum Mode
{
    normal,  // Even returns 1. Odd returns 0.
    reversed // Even returns 0. Odd returns 1.
}

@CommandDefault("The default command.")
struct DefaultCommand
{
    @ArgPositional("number", "The number to check.")
    int number;

    @ArgNamed("mode", "Which mode to use.")
    Mode mode;

    int onExecute()
    {
        if(this.mode == Mode.normal)
            return number % 2 == 0 ? 1 : 0;
        else
            return number % 2;
    }
}
```

Inside `DefaultCommand` we create a member field called `mode` that is decorated with the `@ArgNamed` UDA and has enum type. JCLI knows how to convert an argument value into an enum value.

The first parameter is the name of the argument, which is actually important this time as this determines what name the user needs to use.

The second parameter is just the description.

Then inside of `onExecute` we just check what `mode` was set to and do stuff based off of its value.

Let's have a quick look at the help text first, to see the changes being reflected:

```bash
$> ./mytool --help
temp.exe DEFAULT number --mode

Description:
    The default command.

Positional Arguments:
    number                 The number to check.

Named Arguments:
    --mode                 Which mode to use.
```

And now let's test our functionality:

```bash
# JCLI supports most common argument styles.

# Even (Normal)
$> mytool 60 --mode normal
Program exited with status code 1

# Even (Reversed)
$> mytool 60 --mode=reversed
Program exited with status code 0

# Bad value for mode
$> mytool 60 --mode non_existing_mode
temp.exe: Mode does not have a member named 'non_existing_mode'
Program exited with status code -1

# Can safely assume Odd behaves properly.

# Now, we haven't marked --mode as optional, so...
$> mytool 60
temp.exe: The following required named arguments were not found: mode
Program exited with status code -1
```

We can see that `--mode` is working as expected, however notice that in the last case, the user isn't allowed to leave out `--mode` since it's not marked as optional.

## Optional Arguments

JCLI supports optional arguments through the standard [Nullable](https://dlang.org/phobos/std_typecons.html#Nullable) type. Note that only Named arguments can be optional for now (technically, Positional arguments can be optional in certain use cases, but it's not supported... yet).

So to make our `mode` argument optional, we need to make it `Nullable`:

```d
@CommandDefault("The default command.")
struct DefaultCommand
{
    @ArgPositional("number", "The number to check.")
    int number;

    @ArgNamed("mode", "Which mode to use.")
    Nullable!Mode mode;

    int onExecute()
    {
        if(this.mode.get(Mode.normal) == Mode.normal)
            return number % 2 == 0 ? 1 : 0;
        else
            return number % 2;
    }
}
```

The other change we've made is that `onExecute` now uses `mode.get(Mode.normal)` which returns `Mode.normal` if the `--mode` option is not provided.

First, let's look at the help text, as it very slightly changes for nullable arguments:

```bash
$> ./mytool --help
temp.exe DEFAULT number [--mode]

Description:
    The default command.

Positional Arguments:
    number                 The number to check.

Named Arguments:
    --mode                 Which mode to use.
```

Notice the "Usage" line. `--mode` has now become `[--mode]` to indicate it is optional.

So now let's test that the argument is now optional:

```bash
# Even (implicitly Normal)
$> ./mytool 60
Program exited with status code 1

# Even (Reversed)
$> ./mytool 60 --mode reversed
Program exited with status code 0
```

## Arguments with multiple names

While `--mode` is nice and descriptive, it'd be nice if we could also refer to it via `-m` wouldn't it?

Here is where the very simple concept of "patterns" comes into play. At the moment, and honestly for the foreseeable future, patterns are just strings with a pipe ('|') between each different value:

```d
@CommandDefault("The default command.")
struct DefaultCommand
{
    @ArgNamed("mode|m", "Which mode to use.")
    Nullable!Mode mode;

    // omitted as it's unchanged...
}
```

All we've done is changed `@ArgNamed`'s name from `"mode"` to `"mode|m"`, which basically means that we can use *either* `--mode` or `-m` to set the mode.

You can have as many values within a pattern as you want. Named Arguments cannot have whitespace within their patterns though.

Let's do a quick test as usual:

```bash
$> ./mytool 60 -m normal
Program exited with status code 1

# And here's the help text
$> ./mytool --help
temp.exe DEFAULT number [--mode|-m]

Description:
    The default command.

Positional Arguments:
    number                 The number to check.

Named Arguments:
    --mode|-m              Which mode to use.
```

## Named Commands

Named commands are commands that... have a name. For example `git commit`; `git remote add`; `dub init`, etc. are all named commands.

It's really easy to make a named command. Let's change our default command into a named command:

```d
// Renamed from DefaultCommand
@Command("assert|a|is even", "Asserts that a number is even.")
struct AssertCommand
{
    // ...
}
```

Basically, we change `@CommandDefault` to `@Command`, then we just pass a pattern (yes, commands can have multiple names!) as the first parameter for the `@Command` UDA, and move the description into the second parameter.

Command patterns can have spaces in them, to allow for a multi-word, fluent interface for your tool.

As a bit of a difference, let's test the code first:

```bash
# We have to specify a name now. JCLI will offer suggestions!
$> ./mytool 60
temp.exe: Unknown command
Did you mean:
    assert                 Asserts that a number is even.

# Passing cases (all producing the same output)
$> ./mytool assert 60
$> ./mytool a 60
$> ./mytool is even 60
Program exited with status code 1
```

JCLI has "smart" help text when it comes to displaying named commands. Observe here that JCLI is careful to only display one of the possible
names for commands that may have multiple names:

```bash
# JCLI will always display the first name of each commands' pattern.
$> ./mytool --help
Available commands:
    assert                 Asserts that a number is even.
```

The other feature of this help text is that JCLI has support for partial command matches:

```bash
# So let's first start with a tool that has two commands.
$> ./mytool --help
Available commands:
    assert                       - Asserts that a number is even.
    do a                         - Does A

# If we have a partial match to a command, then JCLI will filter the results down.
$> ./mytool do
mytool.exe: Unknown command 'do'.
Did you mean:
    do a                         - Does A

# If the command has multiple names, then JCLI is careful to use the correct name for the partial match.
# Remember that "assert" is also "is even".
$> ./mytool is --help
Available commands:
    assert                       - Asserts that a number is even.
```

## User Defined argument binding

JCLI has support for users specifying their own functions for converting an argument's string value into the final value passed into the command instance.

In fact, all of JCLI's built in arg binders use this system, they're just implicitly included by JCLI.

While I won't go over them directly, [here's](https://github.com/BradleyChatha/jcli/blob/master/source/jaster/cli/binder.d#L37) the documentation for lookup rules regarding binders, for those of you who are interested.

Let's recreate the `cat` command, which takes a filepath and then outputs the contents of that file.

Instead of asking JCLI for just a string though, let's create an arg binder that will construct a `File` (from [std.stdio](https://dlang.org/library/std/stdio/file.html)) from the string, so our command doesn't have to do any file loading by itself.

First, we need to create the arg binder:

```d
// app.d still
import std.stdio : File;
import jcli      : Result;

// You can optionally attach an exit code to a result.
enum FileErrorCodes
{
    notFound = 200;
}

@Binder
ResultOf!File fileBinder(string arg)
{
    import std.file : exists;
    
    return (arg.exists)
    ? ok(File(arg, "r"))
    : fail!File("File does not exist: "~arg, FileErrorCodes.notFound); // Second arg is optional
}
```

First of all we import `File` from the `std.stdio` module and `Result` from `jcli`.

Second, we create a function, decorated with `@Binder`, that follow a specific convention for its signature:

```d
@Binder
ResultOf!<OutputType> <anyNameItDoesntMatter>(string arg);
```

The return type is a `ResultOf`, whose `<OutputType>` is the type of the value that the binder sets the argument to, which is a `File` in our case.

The `arg` parameter is the raw string provided by the user, for whichever argument we're binding from.

Finally, we check if the file exists, and if it does we return a `ok!File` with a `File` opened in read-only mode. If it doesn't exist then we
return a `fail!File` alongside a user-friendly error message.

Arg binders need to be marked with the `@Binder` UDA so that the `CommandLineInterface` class can discover them. Talking about `CommandLineInterface`, it'll automatically discover any arg binder from the modules you tell it about, just like it does with commands.

Let's now create our new command:

```d
@Command("cat", "Displays the contents of a file.")
struct CatCommand
{
    @ArgPositional("filePath", "The path to the file to display.")
    File file;

    void onExecute()
    {
        import std.stdio : writeln;

        foreach(lineInFile; this.file.byLine())
            writeln(lineInFile);
    }
}
```

The most important thing of note here is, notice how the `file` variable has the type `File`, and recall that our arg binder's return type also has the type `ResultOf!File`? This allows the arg binder to know that it has a function to convert the user's provided string into a `File` for us.

Our `onExecute` function is nothing overly special, it just displays the file line by line.

Test time. Let's make it show the contents of our `dub.json` file, which is within the root of our project:

```bash
$> ./mytool cat ./dub.json
{
    "authors": [
            "Sealab"
    ],
    "copyright": "Copyright ┬® 2020, Sealab",
    "dependencies": {
            "jcli": "~>0.10.0"
    },
    "description": "A minimal D application.",
    "license": "proprietary",
    "name": "mytool"
}
Program exited with status code 0

# And just for good measure, let's see what happens if the file doesn't exist
$> ./mytool cat non-existing-file
temp.exe: File does not exist: non-existing-file
```

Very simple. Very useful.

## User Defined argument validation

It's cool and all being able to very easily create arg binders, but sometimes commands will need validation logic involved.

For example, some commands might only want files with a `.json` extention, while others may not care about extentions. So putting this logic into the arg binder itself isn't overly wise.

Some arguments may need validation on the pre-arg-binded string, whereas others may need validation on the post-arg-binded value. Some may need both!

JCLI handles all of this via argument validators.

Let's start off with the first example, making sure the user only passes in files with a `.json` extention, and apply it to our `cat` command. Code first, explanation after:

```d
@PreValidator
struct HasExtention
{
    string wantedExtention;

    ResultOf!void preValidate(string arg)
    {
        import std.algorithm : endsWith;

        return arg.endsWith(this.wantedExtention)
            ? ok()
            : fail!void("Expected file to have extention of "~this.wantedExtention);
    }
}

@Command("cat", "Displays the contents of a file.")
struct CatCommand
{
    @ArgPositional("filePath", "The path to the file to display.")
    @HasExtention(".json")
    File file;

    // omitted...
}
```

To start, we create a struct called `HasExtention`, we decorate it with `@PreValidator`, and we give it a field member called `string wantedExtention;`.

Before I continue, I want to explicitly state that this validator wants to perform validation on the raw string that the user provides (pre-arg-binded) and *not* on the final value (post-arg-binded). This is referred to as "Pre Validation". So on that note...

Next, and most importantly, we define a function that specifically called `preValidate` that follows the following convention:

```d
ResultOf!void preValidate(string arg);
```

This is the function that performs the actual validation (in this case, "Pre" validation).

It returns `ok()` if there are no validation errors, otherwise it returns `fail!void()` and optionally provides an error string as a user-friendly error (one is automatically generated otherwise).

The return type is a `ResultOf!void`, so a result that doesn't contain a value, but still states whether there was a fail or a ok.

The first parameter to our function is the raw string that the user has provided us.

So for our `HasExtention` validator, all we do is check if the user's file path ends with `this.wantedExtention`, which we set the value of later.

Now, inside `CatCommand` all we've done is attach our `HasExtention` struct as a UDA (and if you're not familiar with D, congrats, you just made your first UDA!). JCLI will automatically detect that `@HasExtention` is a pre-bind validator because it is decorated with `@PreValidator`.

Because D is wonderful, it will automatically generate a constructor for us where the first parameter sets the `wantedExtention` member. So `@HasExtention(".json")` will set the extention we want to `".json"`.

And that's literally all there is to it, let's test:

```bash
# Passing
$> ./mytool cat ./dub.json
[contents of dub.json since validation was a ok]
Program exited with status code 0

# Failing
$> ./mytool cat ./.gitignore
temp.exe: Expected file to have extention of .json
Program exited with status code -1
```

The other type of validation is post-arg-binded validation, which performs validation on the final value provided by an arg binder.

Let's make a validator that ensures that the file is under a certain size:

```d
@PostValidator
struct MaxSize
{
    ulong maxSize;

    ResultOf!void postValidate(File file)
    {
        return file.size() <= this.maxSize
            ? ok()
            : fail!void("File is too large.");
    }
}

@Command("cat", "Displays the contents of a file.")
struct CatCommand
{
    @ArgPositional("filePath", "The path to the file to display.")
    @HasExtention(".json")
    @MaxSize(2)
    File file;

    // omitted...
}
```

The convention for post-arg-binded validation is almost exactly the same as pre-arg-binded validation, it also functions in exactly the same way:

```d
ResultOf!void postValidate(<TYPE_OF_VALUE_TO_VALIDATE> value);
```

The only difference is that the first parameter isn't a `string`, but instead the type of value that this validator will work with.

You must also mark the struct with `@PostValidator` instead of `@PreValidator`.

Validators can have different overloads of this function if required. You can even make it a template. JCLI is fine with any of that.

We've set the max size to something really small, so we can easily test that it works:

```bash
$> ./mytool cat ./dub.json
temp.exe: File is too large.
Program exited with status code -1
```

Excellent. We have an issue however where this is all a bit... cumbersome, right?

**Currently not implemented in v0.20.0** 

Well, for small one-off validation tasks like this, we can use the two built-in validators `@PreValidate` and `@PostValidate`.

The functions you use in these two validators can return: `ResultOf!void`, `bool`, or `string`. So let's use `string` which signals
an error if we return non-null, and also `bool` which signals an error if we return `false`.

This is what the above example would look like using these two validators:

```d
@Command("cat", "Displays the contents of a file.")
struct CatCommand
{
    @ArgPositional("filePath", "The path to the file to display.")
    @PreValidate!(str => !str.endsWith(".json") ? "Expected file to end with .json." : null)
    @PostValidate!(file => file.size() <= 2)
    File file;

    // omitted...
}
```

So now we've moved the logic of `HasExtention` into a lamba inside `@PreValidate` using the `string` return variant,
and the logic of `MaxSize` into `PostValidate` using the `bool` return variant.

You can of course also pass already-made functions instead of lambdas, if that's more your thing.

The results are exactly the same as before, so they will be omitted.

## Per-argument binding

There is seemingly a fatal flaw with the arg binding system.

Imagine we had a `copy` command that copies the contents of a file into another file:

```d
@Command("copy", "Copies a file")
struct CopyCommand
{
    @ArgPositional("source", "The source file.")
    File source;

    @ArgPositional("destination", "The destination file.")
    File destination;

    void onExecute()
    {
        foreach(line; source.byLine)
            destination.writeln(line);
    }
}
```

The issue here is that `source` needs to be opened in read-only mode(`r`), however `destination` needs be written in truncate/write mode(`w`).

If we were to create a normal `@Binder`, we wouldn't be able to tell it the difference between the two files since we're limited in the amount
of information that is passed to an arg binder.

What we need is a way to specify the binding behavior on a per-argument basis.

While you *could* do a hackish thing such as creating two separate file types (`ReadOnlyFile` and `WriteFile`) then making arg binders for them, there's actually
a much easier solution - `@BindWith`:

```d
import std.stdio : File;

ResultOf!File openReadOnly(string arg)
{
    import std.file : exists;

    return (arg.exists)
    ? ok!File(File(arg, "r"))
    : fail!File("The file doesn't exist: "~arg);
}

@Command("copy", "Copies a file")
struct CopyCommand
{
    @ArgPositional("source", "The source file.")
    @BindWith!openReadOnly
    File source;

    @ArgPositional("destination", "The destination file.")
    @BindWith!(arg => ok!File(File(arg, "w")))
    File destination;

    void onExecute()
    {
        foreach(line; source.byLine)
            destination.writeln(line);
    }
}
```

To start off, we create the fairly self-explanatory `openReadOnly` function which looks exactly like an `@Binder`, except it doesn't have the UDA attached to it.

Next, we attach `@BindWith!openReadOnly` onto our `source` argument. This tells JCLI to use our `openReadOnly` function as this argument's binder.

Finally, we attach `@BindWith!(/*lambda*/)` onto our `destination` argument, for the same reasons as above. A lambda is used here for demonstration purposes.

And just like that we have now solved overcome our initial issue of "how to I customise binding for arguments of the same type?" in a simple, sane manner.

I'd like to mention that this feature works alongside the usual arg binding behavior. In other words, you can define an `@Binder` for a type which will
serve as the default method for binding, but then for those awkward, one-off cases you can use `@BindWith` to specify a different binding behavior on a per-argument
basis.

## Unparsed Raw Arg List

In some cases you might want to stop parsing arguments and just get them as raw strings. JCLI supports this use case by allowing raw arguments to appear after a long double-dash (`--`) parameter in the command line: `./mytool args to parse -- args to pass as is`.

Commands can access the raw arg list like so:

```d
@Command("echo", "Echos the raw arg list.")
struct EchoCommand
{
    @ArgRaw
    ArgParser rawArgs;

    void onExecute()
    {
        import std.stdio, std.algorithm;
        foreach(arg; this.rawArgs.map!(arg => arg.fullSlice))
            writeln(arg);
    }
}
```

Simply make a field of type `ArgParser`, then mark it with `@ArgRaw`, and then voila:

```bash
$> ./mytool echo -- Hello world, please be kind.
Hello
world,
please
be
kind.
Program exited with status code 0
```

## Inheritance

**As of v0.12.0 inheritance is currently in a broken state, please see issue [#44](https://github.com/BradleyChatha/jcli/issues/44) for a description**
**of the issue, as well as a mitigation suggestion.**

JCLI supports command inheritance.

The only rules with inheritance are:

* Only concrete classes can be marked with `@Command`.

* Concrete classes must have `onExecute` defined, either by a base class or directly.

Other than that, go wild. Every argument marked with `@ArgNamed` and `@ArgPositional` will be discovered within the inheritance tree for a command,
and they will all be populated as expected:

```d
abstract class CommandBase
{
    @ArgNamed("verbose|v", "Show verbose information.")
    Nullable!bool verbose;

    // This isn't recognised my JCLI, it's just a function all our
    // child classes should call as an arbitrary design choice.
    final void onPreExecute()
    {
        import std.stdio;

        if(this.verbose.get(false))
            writeln("Running in verbose mode!");
    }

    // Force our child classes to implement the function JCLI recognises.
    abstract void onExecute();
}

@Command("verbose say hello", "Says hello!... but only when you define the verbose flag.")
final class MyCommand : CommandBase
{
    override void onExecute()
    {
        import std.stdio;
        super.onPreExecute();

        if(super.verbose.get(false))
            writeln("Hello!");
    }
}
```

Nothing here is overly new, and it should make sense to you if you've gotten this far down:

```bash
# Without flag
$> ./mytool verbose say hello
Program exited with status code 0

# With flag
$> ./mytool verbose say hello --verbose
Running in verbose mode!
Hello!
Program exited with status code 0
```

To summarize, JCLI supports inheritance within commands, and it should for the most part function as you expect. The rest is down
to your own design.

## Argument groups

Some applications will find it useful to group their arguments together inside of their help text, for example:

```text
$> ./mytool command -h
temp.exe command arg1 arg2 output [--config|-c] [--log|-l] [--test-flag] [--verbose|-v]

Description:
    This is a command that is totally super complicated.

Positional Arguments:
    arg1                   This is a generic argument that isn't grouped anywhere
    arg2                   This is a generic argument that isn't grouped anywhere
    output                 Where to place the output.

Named Arguments:
    --test-flag            Test flag, please ignore.

I/O
    Arguments related to I/O.

    --config|-c            Specifies the config file to use.

Debug
    Arguments related to debugging.

    --log|-l               Specifies a log file to direct output to.
    --verbose|-v           Enables verbose logging.
```

This can be achieved by using the `@ArgGroup` UDA - this is how to produce the above help text:

```d
@Command("command", "This is a command that is totally super complicated.")
struct ComplexCommand
{
    @ArgPositional("arg1", "This is a generic argument that isn't grouped anywhere")
    int a;
    @ArgPositional("arg2", "This is a generic argument that isn't grouped anywhere")
    int b;

    @ArgNamed("test-flag", "Test flag, please ignore.")
    bool flag;

    @ArgGroup("Debug", "Arguments related to debugging.")
    {
        @ArgNamed("verbose|v", "Enables verbose logging.")
        Nullable!bool verbose;

        @ArgNamed("log|l", "Specifies a log file to direct output to.")
        Nullable!string log;
    }

    @ArgGroup("I/O", "Arguments related to I/O.")
    {
        // Notice that positional args DON'T get moved. This is to avoid unneeded confusion
        // since positional args are always required, and thus should be next to eachother in help text.
        @ArgPositional("output", "Where to place the output.")
        string output;

        @ArgNamed("config|c", "Specifies the config file to use.")
        Nullable!string config;
    }

    void onExecute(){}
}
```

## Bash Completion

JCLI provides automatic autocomplete for commands (currently only for command arguments, not commands themselves) via the `jcli.autocomplete` package.

yada yada, do this up eventually once this is up and running again (it's almost ready though!).

## Argument parsing actions

There are specific cases where arguments may need to be parsed in a different manner. You can customise parsing behavior on a per-argument basis by attaching any enum value from the `ArgAction` enum.

### ArgAction.count

By attaching `@(ArgAction.count)` onto a named argument, the argument's behavior will change in the following ways:

* Every time the argument is defined within the command's parameters, the value of the argument is incremented.

* The argument becomes optional by default. (No need for `Nullable`).

* No explicit value can be given to the argument.

* Arg binding and arg validation are not performed.

* Special syntax `-aaaa` (where 'a' is the name of the arg) is supported. (Increments 4 times).

Here's an example command:

```d
@CommandDefault("Outputs the value of '-a'.")
struct SumCommand
{
    @ArgNamed("a")
    @(ArgAction.count)
    int arg;

    void onExecute()
    {
        writeln(this.arg);
    }
}
```

With an example usage:

```bash
$> ./myTool -a -a
2

$> ./myTool -aaaaa
5

$> ./myTool
0
```

## Command Introspection

In certain cases there may be a need for being able to gather and inspect the data of a command and its arguments, ideally in the same way
JCLI is able to.

JCLI exposes this via the `jcli.introspect` package, which gathers all the JCLI-relevant details about a command and all of its recognised arguments.

This information is available at compile-time, allowing for the usual meta-programming shenanigans that D allows. This is useful for those that want to build
their own functionality on top of the several parts JCLI provides.

Our example will simply be an empty command with a few arguments we'd like to get information of:

**TODO Update this for v0.20.0 since this is outdated**

```d
import std, jcli;

@Command("name", "description")
struct MyCommand
{
    @ArgNamed("v|verbose", "Toggle verbose output.")
    Nullable!bool verbose;

    @ArgNamed("l", "Verbose level counter.")
    @(ArgAction.count)
    uint lCount;

    @ArgPositional("arg1", "The first argument to do stuff with.")
    string arg1;

    // No definition of 'onExecute' is required for this use-case.
}

// Via the `getCommandInfoFor` template, we can gather all the JCLI-relevant information we want.
// We do also have to pass in an instantiation of `ArgBinder`, but it's an unfortunate yet minor design limitation.
enum Info = getCommandInfoFor!(MyCommand, ArgBinder!());

void main()
{
    writeln("[Command Info]");
    writeln("Pattern     = ", Info.pattern);
    writeln("Description = ", Info.description);
    writeln();

    void displayArg(ArgInfoT)(ArgInfoT argInfo)
    {
        writefln("[Argument Info - %s]", ArgInfoT.stringof);
        writeln("Identifier  = ", argInfo.identifier);
        writeln("UDA         = ", argInfo.uda);
        writeln("Action      = ", argInfo.action);
        writeln("Group       = ", argInfo.group);
        writeln("Existence   = ", argInfo.existence);
        writeln("ParseScheme = ", argInfo.parseScheme);
        writeln();
    }

    foreach(arg; Info.namedArgs) displayArg(arg);
    foreach(arg; Info.positionalArgs) displayArg(arg);

    if(Info.rawListArg.isNull)
        writeln("[No Raw Arg List]\n");
    else
        displayArg(Info.rawListArg.get);

    // If needed, you can still get access to the argument's symbol.
    alias Symbol = __traits(getMember, MyCommand, Info.namedArgs[0].identifier);
    writeln("Arg0Nullable = ", isInstanceOf!(Nullable, typeof(Symbol)));
}
```

With the output of:

```bash
[Command Info]
Pattern     = Pattern("name")
Description = description

[Argument Info - ArgumentInfo!(ArgNamed, MyCommand)]
Identifier  = verbose
UDA         = ArgNamed(Pattern("v|verbose"), "Toggle verbose output.")
Action      = default_
Group       = ArgGroup("", "")
Existence   = optional
ParseScheme = bool_

[Argument Info - ArgumentInfo!(ArgNamed, MyCommand)]
Identifier  = lCount
UDA         = ArgNamed(Pattern("l"), "Verbose level counter.")
Action      = count
Group       = ArgGroup("", "")
Existence   = cast(CommandArgExistence)3 # NOTE: 3 = multiple | optional, result of the `count` action
ParseScheme = allowRepeatedName          # Result of the `count` action

[Argument Info - ArgumentInfo!(ArgPositional, MyCommand)]
Identifier  = arg1
UDA         = ArgPositional("arg1", "The first argument to do stuff with.")
Action      = default_
Group       = ArgGroup("", "")
Existence   = default_
ParseScheme = default_

[No Raw Arg List]

Arg0Nullable = true
```

I'll also note that every `ArgumentInfo` also contains an `actionFunc` variable which will be one of the functions inside of
`jcli.introspect.actions`. This function will perform the binding action (e.g. default_ goes through the `ArgBinder`, count increments, etc.).

## Light-weight command parsing

Some users may find `CommandLineInterface` too *forceful* and heavy in how it works. Some users may prefer that JCLI only handle
argument parsing and value binding, and then these users will handle the execution/logic themselves.

To do this, you can use the `CommandParser` struct, which is responsible for only parsing data into a command instance.

Here's an example:

```d
import std, jcli;
enum CalculateOperation
{
    add,
    sub
}

@CommandDefault // CommandParser doesn't really care about this UDA, it just wants it to exist (or @Command)
struct CalculateCommand
{
    @ArgPositional("a", "The first value.")
    int a;

    @ArgPositional("b", "The second value.")
    int b;

    @ArgNamed("o|op", "The operation to perform.")
    CalculateOperation op;
}

int main(string[] args)
{
    // If you don't specify an `ArgBinder`, then `CommandParser` will use the default one.
    CommandParser!(CalculateCommand, ArgBinder!()) parser; // Same as: CommandParser!CalculateCommand

    ResultOf!CalculateCommand result = parser.parse(args[1..$]); // args[0] is the program name, so we need to skip it.

    // Normally CommandLineInterface handles everything for us, but now we have to do this ourselves.
    if(!result.isOk)
    {
        writeln("calculate: ", result.error);
        return -1;
    }

    auto instance = result.value;

    // We also have to call/handle command logic ourself.
    final switch(instance.op) with(CalculateOperation)
    {
        case add: writeln(instance.a + instance.b); break;
        case sub: writeln(instance.a - instance.b); break;
    }

    return 0;
}
```

If you're this far down you won't need any example output of the above, so I've not bothered with it.

This usage of JCLI supports all forms of argument parsing and value binding (validators, custom binders, etc.) but does not support:
    * Help text generation (see: [Light-weight command help text](#light-weight-command-help-text))
    * Automatic support for multiple commands (you'll have to build that yourself on top of `CommandParser`)
    * Bash Completion (planned to become an independent component though)
    * Basically anything other than parsing arguments.

## Light-weight command help text

In situations where you'd rather use light-weight command parsing instead of `CommandLineInterface`, chances are that you'd also like easy access
to JCLI's per-command help text generation.

This can be achieved using the `CommandHelpText` struct which can be used to either generate a `HelpTextBuilderSimple`, or just a plain `string`
in the exact same format that you'd normally get by using `CommandLineInterface`:

```d
module app;
import std, jcli;

@Command("command", "This is a command that is totally super complicated.")
struct ComplexCommand
{
    @ArgPositional("arg1", "This is a generic argument that isn't grouped anywhere")
    int a;
    @ArgPositional("arg2", "This is a generic argument that isn't grouped anywhere")
    int b;

    @ArgNamed("test-flag", "Test flag, please ignore.")
    bool flag;

    @ArgGroup("Debug", "Arguments related to debugging.")
    {
        @ArgNamed("verbose|v", "Enables verbose logging.")
        Nullable!bool verbose;

        @ArgNamed("log|l", "Specifies a log file to direct output to.")
        Nullable!string log;
    }

    @ArgGroup("I/O", "Arguments related to I/O.")
    {
        @ArgPositional("output", "Where to place the output.")
        string output;

        @ArgNamed("config|c", "Specifies the config file to use.")
        Nullable!string config;
    }

    void onExecute(){}
}

void main(string[] args)
{
    CommandHelpText!ComplexCommand helpText;
    writeln(helpText.generate());
}
```

This is almost exactly the same as the [argument groups](#argument-groups) example, except that instead of going through `CommandLineInterface` we use `CommandHelpText`
to directly access the help text for our `ComplexCommand`.

The output is exactly the same as shown in the [argument groups](#argument-groups) example, so I won't be duplicating it here.

## Argument configuration

You can attach any values from the `ArgConfig` enum directly onto an argument, to configure certain behaviour about it.

As a reminder, to attach enum values onto something as a UDA, you must use the form `@(ArgConfig.xxx)`.


The information below is useful for seeing which combinations of features are supported.
Flags that must be accompanied by one of the other flags:

- `optionalBit` — none;
- `multipleBit` — one of `countBit`, `canRedefineBit` or `aggregateBit`;
- `parseAsFlagBit` — `optionalBit`;
- `countBit` — either `mutipleBit`, `repeatableNameBit`, or both;
- `caseInsensitiveBit` — none;
- `canRedefineBit` — `multipleBit`;
- `repeatableNameBit` — `countBit`.

Supported orthogonal higher level flag combinatons (encouraged to use).
"implied" written in a cell means the flag combination from the header implies the flag combination from the left:

|                | canRedefine | optional | caseInsesitive | accumulate | aggregate | repeatableName | parseAsFlag |
|----------------|-------------|----------|----------------|------------|-----------|----------------|-------------|
| canRedefine    | o           | +        | +              | -          | -         | - (not yet)    | +           |
| optional       | + implied   | o        | +              | +          | +         | +              | + implied   |
| caseInsesitive | +           | +        | o              | +          | +         | +              | +           |
| accumulate     | -           | +        | +              | o          | -         | + implied      | -           |
| aggregate      | -           | +        | +              | -          | o         | -              | -           |
| repeatableName | - (not yet) | +        | +              | +          | -         | o              | -           |


### ArgConfig.caseInsensitive

By default, named arguments are case-sensitive, meaning `abc` is not the same as `abC`.

By attaching `@(ArgConfig.caseInsensitive)` onto a named argument, it will allow things like `abc` to match `abc`, `aBc`, `ABC`, etc.

### ArgConfig.canRedefine

By default, named arguments can only be defined once, meaning `--abc 2 --abc 1` produces an error.

By attaching `@(ArgConfig.canRedefine)` onto a named argument, the right-most definition will be used (so, `--abc 1` in this case).

# Using JCLI without Dub

It's possible to use JCLI without dub, especially because it has no external dependencies (other than JANSI, which is actually bundled instead of added as a proper
dub dependency).

In fact, this library is developed under [Meson](https://mesonbuild.com) as the build tool, which means that you can easily integrated this library into your own Meson projects.

# Contributing

I'm perfectly accepting of anyone wanting to contribute to this library, just note that it might take me a while to respond.

And please, if you have an issue, *create a Github issue for me*. I can't fix or prioritise issues that I don't know exist.
I tend to not care about issues when **I** run across them, but when **someone else** runs into them, then it becomes a much higher priority for me to address it.

Finally, if you use JCLI in anyway feel free to request for me to add your project into the `Examples` section. I'd really love to see how others are using my code :)
