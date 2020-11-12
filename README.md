<p align="center">
    <img src="https://i.imgur.com/nbQPhO9.png"/>
</p>

# Overview

![Tests](https://github.com/BradleyChatha/jcli/workflows/Test%20LDC%20x64/badge.svg)
![Examples](https://github.com/BradleyChatha/jcli/workflows/Test%20Examples/badge.svg)

JCLI is a library to aid in the creation of command line tooling, with an aim of being easy to use, while also allowing
the individual parts of the library to be used on their own, aiding more dedicated users in creation of their own CLI core.

As a firm believer of good documentation, JCLI is completely documented with in-depth explanations where needed. In-browser documentation can be found [here](https://jcli.dpldocs.info/jaster.cli.html).

Tested on Windows and Ubuntu 18.04.

1. [Overview](#overview)
1. [Features](#features)
1. ["Quick" Start/HOWTO](#quick-start)
    * Basic usage:
        1. [Creating a default command](#creating-a-default-command)
        1. [Positional arguments](#positional-arguments)
        1. [Registering commands](#registering-commands)
        1. [Running the program](#running-the-program)
        1. [Named arguments](#named-arguments)
        1. [Optional arguments](#optional-arguments)
        1. [Arguments with multiple names](#arguments-with-multiple-names)
        1. [Named commands](#named-commands)
        1. [Unparsed Raw Arg List](#unparsed-raw-arg-list)

    * Advanced usage:
        1. [User Defined argument binding](#user-defined-argument-binding)
        1. [User Defined argument validation](#user-defined-argument-validation)
        1. [Per-Argument binding][#per-argument-binding]
        1. [Dependency Injection](#dependency-injection)
        1. [Calling a command from another command](#calling-a-command-from-another-command)
        1. [Configuration](#configuration)
        1. [Inheritance](#inheritance)
        1. [Argument groups](#argument-groups)
1. [Using JCLI without Dub](#using-jcli-without-dub)
1. [Versions](#versions)
1. [Contributing](#contributing)

# Features

* Argument parsing:

    * Named and positional arguments.

    * Boolean arguments (flags).

    * Optional arguments using the standard `Nullable` type.

    * User-Defined argument binding (string -> any_type_you_want) - blanket and per-argument.

    * User-Defined argument validation (via UDAs that follow a convention).

    * Pass through unparsed arguments (`./mytool parsed args -- these are unparsed args`).

    * Automatic error messages for missing and malformed arguments.

* Commands:

    * Standard command line format (`./mytool command args --flag=value ...`).

    * Automatic command dispatch.

    * Defined using UDAs, and are automatically discovered.

    * Supports a default command.

    * Supports named commands that allow for multiple words and per-command argument parsing.

    * Opt-in dependency injection via constructor injection.

    * Support for command inheritance.

    * Both `struct` and `class` are allowed.

* Help text:

    * Automatically generated with slight ability for customisation.

    * Works for the default command.

    * Works for exact matches for named commands.

    * Works for partial matches for named commands.

    * Arguments can be displayed in organised groups.

* Utilities:

    * Opt-in bash completion support.

    * Coloured, configurable logging.

    * User Input that integrates with User-Defined argument binding and validation.

    * Decent support for writing and parsing ANSI text.

    * Basic but flexible Configuration Providers, used alongside Dependency Injection.

    * An ANSI-enabled text buffer, for easier and efficient control over coloured, non-uniform text output.

    * Shell utilities such as `pushLocation` and `popLocation`, synonymous with Powershell's `Push-Location` and `Pop-Location`.

* Customisable design:

    * All individual parts of this library are intended to be reusable. Allowing you to build your own CLI core using these already-made components, if desired.

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
    @CommandPositionalArg(0, "number", "The number to check.")
    int number;

    int onExecute()
    {
        return number % 2 == 0 ? 1 : 0;
    }
}
```

We create the field member `int number;` and decorate it with the `@CommandPositionalArg` UDA to specify it as a positional argument.

The first parameter is the position this argument should be at, which we define as the 0th position.

The second parameter is an optional name we can give the parameter, which is shown in the command's help text, but serves no other function.

The last parameter is simply a description.

An example of the help text is shown in the [Running your program](#running-your-program) section, which demonstrates why
you should provide a name to positional arguments.

## Registering commands

To use our new command, we just need to register it first:

```d
import jcli

// This is still in app.d
int main(string[] args)
{
    auto executor = new CommandLineInterface!(app);
    const statusCode = executor.parseAndExecute(args);

    UserIO.logInfof("Program exited with status code %s", statusCode);

    return statusCode;
}
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
Usage: mytool.exe DEFAULT <number>

Description:
    The default command.

Positional Args:
    number                       - The number to check.
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
mytool.exe: Missing required arguments <number>
Program exited with status code -1

# Too many numbers
$> ./mytool 1 2
mytool.exe: too many arguments starting at '2'
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
    @CommandPositionalArg(0, "number", "The number to check.")
    int number;

    @CommandNamedArg("mode", "Which mode to use.")
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

Inside `DefaultCommand` we create a member field called `mode` that is decorated with the `@CommandNamedArg` UDA and has enum type. JCLI knows how to convert an argument value into an enum value.

The first parameter is the name of the argument, which is actually important this time as this determines what name the user needs to use.

The second parameter is just the description.

Then inside of `onExecute` we just check what `mode` was set to and do stuff based off of its value.

Let's have a quick look at the help text first, to see the changes being reflected:

```bash
$> ./mytool --help
Usage: mytool.exe DEFAULT <number> --mode

Description:
    The default command.

Positional Args:
    number                       - The number to check.

Named Args:
    --mode                       - Which mode to use.
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
mytool.exe: For named argument mode: Mode does not have a member named 'non_existing_mode'
Program exited with status code -1

# Can safely assume Odd behaves properly.

# Now, we haven't marked --mode as optional, so...
$> mytool 60
mytool.exe: Missing required arguments --mode
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
    @CommandPositionalArg(0, "number", "The number to check.")
    int number;

    @CommandNamedArg("mode", "Which mode to use.")
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
Usage: mytool.exe DEFAULT <number> [--mode]

Description:
    The default command.

Positional Args:
    number                       - The number to check.

Named Args:
    --mode                       - Which mode to use.
```

Notice the "Usage:" line. `--mode` has now become `[--mode]` to indicate it is optional.

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
    @CommandNamedArg("mode|m", "Which mode to use.")
    Nullable!Mode mode;

    // omitted as it's unchanged...
}
```

All we've done is changed `@CommandNamedArg`'s name from `"mode"` to `"mode|m"`, which basically means that we can use *either* `--mode` or `-m` to set the mode.

You can have as many values within a pattern as you want. Named Arguments cannot have whitespace within their patterns though.

Let's do a quick test as usual:

```bash
$> ./mytool 60 -m normal
Program exited with status code 1

# JCLI even supports this weird syntax shorthand arguments sometimes use.
$> ./mytool 60 -mreversed
Program exited with status code 0

# And here's the help text
$> ./mytool --help
Usage: mytool.exe DEFAULT <number> [--mode|-m]

Description:
    The default command.

Positional Args:
    number                       - The number to check.

Named Args:
    --mode,-m                    - Which mode to use.
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
mytool.exe: Unknown command '60'.
Did you mean:
    assert                       - Asserts that a number is even.

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
    assert                       - Asserts that a number is even.
```

The other feature of this help text is that JCLI has support for partial command matches:

**FUTURE ME I NEED TO FIX THIS BELOW EXAMPLE** - It should display "is even" instead of "assert" for the last set of help text.
I find it funny that the bash completion code knows how to do this, but the help text generator doesn't.

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

@ArgBinderFunc
Result!File fileBinder(string arg)
{
    import std.file : exists;

    // Alternatively: Result!File.failureIf(!arg.exists, File(arg, "r"), "File does not exist: "~arg)
    return (arg.exists)
    ? Result!File.success(File(arg, "r"))
    : Result!File.failure("File does not exist: "~arg);
}
```

First of all we import `File` from the `std.stdio` module and `Result` from `jcli`.

Second, we create a function, decorated with `@ArgBinderFunc`, that follow a specific convention for its signature:

```d
@ArgBinderFunc
Result!<OutputType> <anyNameItDoesntMatter>(string arg);
```

The return type is a `Result`, whose `<OutputType>` is the type of the value that the binder sets the argument to, which is a `File` in our case.

The `arg` parameter is the raw string provided by the user, for whichever argument we're binding from.

Finally, we check if the file exists, and if it does we return a `Result!File.success` with a `File` opened in read-only mode. If it doesn't exist then we
return a `Result!File.failure` alongside a user-friendly error message.

Arg binders need to be marked with the `@ArgBinderFunc` UDA so that the `CommandLineInterface` class can discover them. Talking about `CommandLineInterface`, it'll automatically discover any arg binder from the modules you tell it about, just like it does with commands.

Let's now create our new command:

```d
@Command("cat", "Displays the contents of a file.")
struct CatCommand
{
    @CommandPositionalArg(0, "filePath", "The path to the file to display.")
    File file;

    void onExecute()
    {
        import std.stdio : writeln;

        foreach(lineInFile; this.file.byLine())
            writeln(lineInFile);
    }
}
```

The most important thing of note here is, notice how the `file` variable has the type `File`, and recall that our arg binder's return type also has the type `Result!File`? This allows the arg binder to know that it has a function to convert the user's provided string into a `File` for us.

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
mytool.exe: For positional arg 0(filePath): File does not exist: non-existing-file
```

Very simple. Very useful.

## User Defined argument validation

It's cool and all being able to very easily create arg binders, but sometimes commands will need validation logic involved.

For example, some commands might only want files with a `.json` extention, while others may not care about extentions. So putting this logic into the arg binder itself isn't overly wise.

Some arguments may need validation on the pre-arg-binded string, whereas others may need validation on the post-arg-binded value. Some may need both!

JCLI handles all of this via argument validators.

Let's start off with the first example, making sure the user only passes in files with a `.json` extention, and apply it to our `cat` command. Code first, explanation after:

```d
@ArgValidator
struct HasExtention
{
    string wantedExtention;

    Result!void onPreValidate(string arg)
    {
        import std.algorithm : endsWith;

        // If the condition is true, return a failure result with a message, otherwise return a success result.
        return Result!void.failureIf(
            !arg.endsWith(this.wantedExtention), 
            "Expected file to have extention of "~this.wantedExtention
        );
    }
}

@Command("cat", "Displays the contents of a file.")
struct CatCommand
{
    @CommandPositionalArg(0, "filePath", "The path to the file to display.")
    @HasExtention(".json")
    File file;

    // omitted...
}
```

To start, we create a struct called `HasExtention`, we decorate it with `@ArgValidator`, and we give it a field member called `string wantedExtention;`.

Before I continue, I want to explicitly state that this validator wants to perform validation on the raw string that the user provides (pre-arg-binded) and *not* on the final value (post-arg-binded). This is referred to as "Pre Validation". So on that note...

Next, and most importantly, we define a function that specifically called `onPreValidate` that follows the following convention:

```d
Result!void onPreValidate(string arg);
```

This is the function that performs the actual validation (in this case, "Pre" validation).

It returns `Result!void.success()` if there are no validation errors, otherwise it returns `Result!void.failure()` and optionally provides an error string as a user-friendly error (one is automatically generated otherwise).

The return type is a `Result!void`, so a result that doesn't contain a value, but still states whether there was a failure or a success.

The first parameter to our function is the raw string that the user has provided us.

So for our `HasExtention` validator, all we do is check if the user's file path ends with `this.wantedExtention`, which we set the value of later.

Now, inside `CatCommand` all we've done is attach our `HasExtention` struct as a UDA (and if you're not familiar with D, congrats, you just made your first UDA!). JCLI will automatically detect that `@HasExtention` is a validator because it is decorated with `@ArgValidator`.

Because D is wonderful, it will automatically generate a constructor for us where the first parameter sets the `wantedExtention` member. So `@HasExtention(".json")` will set the extention we want to `".json"`.

And that's literally all there is to it, let's test:

```bash
# Passing
$> ./mytool cat ./dub.json
[contents of dub.json since validation was a success]
Program exited with status code 0

# Failing
$> ./mytool cat ./.gitignore
mytool.exe: For positional arg 0(filePath): Expected file to have extention of .json
Program exited with status code -1
```

The other type of validation is post-arg-binded validation, which performs validation on the final value provided by an arg binder.

Let's make a validator that ensures that the file is under a certain size:

```d
@ArgValidator
struct MaxSize
{
    ulong maxSize;

    Result!void onValidate(File file)
    {
        return Result!void.failureIf(
            file.size() > this.maxSize,
            "File is too large."
        );
    }
}

@Command("cat", "Displays the contents of a file.")
struct CatCommand
{
    @CommandPositionalArg(0, "filePath", "The path to the file to display.")
    @HasExtention(".json")
    @MaxSize(2)
    File file;

    // omitted...
}
```

The convention for post-arg-binded validation is almost exactly the same as pre-arg-binded validation, it also functions in exactly the same way:

```d
Result!void onValidate(<TYPE_OF_VALUE_TO_VALIDATE> value);
```

The only difference is that the first parameter isn't a `string`, but instead the type of value that this validator will work with.

Validators can have different overloads of this function if required. You can even make it a template. JCLI is fine with any of that.

We've set the max size to something really small, so we can easily test that it works:

```bash
$> ./mytool cat ./dub.json
mytool.exe: For positional arg 0(filePath): File is too large.
Program exited with status code -1
```

Excellent. We have an issue however where this is all a bit... cumbersome, right?

Well, for small one-off validation tasks like this, we can use the two built-in validators `@PreValidate` and `@PostValidate`.

This is what the above example would look like using these two validators:

```d
@Command("cat", "Displays the contents of a file.")
struct CatCommand
{
    @CommandPositionalArg(0, "filePath", "The path to the file to display.")
    @PreValidate!(str => Result!void.failureIf(!str.endsWith(".json"), "Expected file to end with .json."))
    @PostValidate!(file => Result!void.failureIf(file.size() > 2, "File is larger than 2 bytes."))
    File file;

    // omitted...
}
```

So now we've moved the logic of `HasExtention` into a lamba inside `@PreValidate`, and the logic of `MaxSize` into `PostValidate`.

You can of course also pass already-made functions instead of lambdas, if that's more your thing.

The results are exactly the same as before, so they will be omitted.

## Per-argument binding

There is seemingly a fatal flaw with the arg binding system.

Imagine we had a `copy` command that copies the contents of a file into another file:

```d
@Command("copy", "Copies a file")
struct CopyCommand
{
    @CommandPositionalArg(0, "source", "The source file.")
    File source;

    @CommandPositionalArg(1, "destination", "The destination file.")
    File destination;

    void onExecute()
    {
        foreach(line; source.byLine)
            destination.writeln(line);
    }
}
```

The issue here is that `source` needs to be opened in read-only mode(`r`), however `destination` needs be written in truncate/write mode(`w`).

If we were to create a normal `@ArgBinderFunc`, we wouldn't be able to tell it the difference between the two files since we're limited in the amount
of information that is passed to an arg binder.

What we need is a way to specify the binding behavior on a per-argument basis.

While you *could* do a hackish thing such as creating two separate file types (`ReadOnlyFile` and `WriteFile`) then making arg binders for them, there's actually
a much easier solution - `@ArgBindWith`:

```d
import std.stdio : File;

Result!File openReadOnly(string arg)
{
    import std.file : exists;

    return (arg.exists)
    ? Result!File.success(File(arg, "r"))
    : Result!File.failure("The file doesn't exist: "~arg);
}

@Command("copy", "Copies a file")
struct CopyCommand
{
    @CommandPositionalArg(0, "source", "The source file.")
    @ArgBindWith!openReadOnly
    File source;

    @CommandPositionalArg(1, "destination", "The destination file.")
    @ArgBindWith!(arg => Result!File.success(File(arg, "w")))
    File destination;

    void onExecute()
    {
        foreach(line; source.byLine)
            destination.writeln(line);
    }
}
```

To start off, we create the fairly self-explanatory `openReadOnly` function which looks exactly like an `@ArgBinderFunc`, except it doesn't have the UDA attached to it.

Next, we attach `@ArgBindWith!openReadOnly` onto our `source` argument. This tells JCLI to use our `openReadOnly` function as this argument's binder.

Finally, we attach `@ArgBindWith!(/*lambda*/)` onto our `destination` argument, for the same reasons as above. A lambda is used here for demonstration purposes.

And just like that we have now solved overcome our initial issue of "how to I customise binding for arguments of the same type?" in a simple, sane manner.

I'd like to mention that this feature works alongside the usual arg binding behavior. In other words, you can define an `@ArgBinderFunc` for a type which will
serve as the default method for binding, but then for those awkward, one-off cases you can use `@ArgBindWith` to specify a different binding behavior on a per-argument
basis.

## Unparsed Raw Arg List

In some cases you might want to stop parsing arguments and just get them as raw strings. JCLI supports this use case by allowing raw arguments to appear after a long double-dash (`--`) parameter in the command line: `./mytool args to parse -- args to pass as is`.

Commands can access the raw arg list like so:

```d
@Command("echo", "Echos the raw arg list.")
struct EchoCommand
{
    @CommandRawArg
    string[] rawArgs;

    void onExecute()
    {
        import std.stdio;
        foreach(arg; this.rawArgs)
            writeln(arg);
    }
}
```

Simply make a field of type `string[]`, then mark it with `@CommandRawArg`, and then voila:

```bash
$> ./mytool echo -- Hello world, please be kind.
Hello
world,
please
be
kind.
Program exited with status code 0
```

## Dependency Injection

Commands in JCLI actually live inside an IOC container (henceforth 'Service Provider'), provided by my other library called [jioc](https://github.com/BradleyChatha/jioc).

By default, JCLI will construct the Service Provider on its own and register some internal services to it.

However JCLI will also allow you to provide it with an already-made Service Provider so that you can inject your own services into your commands via
constructor injection.

To start off, you'll need to run `dub add jioc`, as well as `import jaster.ioc`:

```d
import jaster.ioc;

int main(string[] args)
{
    ServiceInfo[] services;
    // We'll leave the array empty for now, as different sections will go over some specifics.

    auto provider = new ServiceProvider(services);
    auto executor = new CommandLineInterface!(app)(provider);
    // same as before from here...
}
```

To start off, build up an array of `ServiceInfo`. If you want to learn about making your own services, for now you'll need
to take a look at the [example](https://github.com/BradleyChatha/jcli/tree/master/examples/05-dependency-injection/source) code, and maybe also some of JIOC's 
[code](https://github.com/BradleyChatha/jioc). I'll get around to better docs *eventually*.

Anyway, that's basically it to start off with. Any services you provide a `ServiceInfo` for can now be obtained via constructor injection. The section below will
show off an example.

## Calling a command from another command

It can be useful to call different commands from within another command, so JCLI sort of has you covered here.

JCLI, via dependency injection, provides the `ICommandLineInterface` service which exposes the `parseAndExecute` function that you already know and love.

So, following on from the code in the [Dependency Injection](#dependency-injection) section, we'll inject an `ICommandLineInterface` into a new command, whose
purpose is to call the `echo` command (from the [Raw Arg List](#unparsed-raw-arg-list) section) with a predefined set of arguments:

```d
int main(string[] args)
{
    ServiceInfo[] services;
    services.addCommandLineInterfaceService();

    // omitted...
}

@Command("say hello", "Says hello!")
struct SayHelloCommand
{
    private ICommandLineInterface _cli;

    this(ICommandLineInterface cli)
    {
        assert(cli !is null);
        this._cli = cli;
    }

    int onExecute()
    {
        return this._cli.parseAndExecute(["echo", "--", "Hello!"], IgnoreFirstArg.no);
    }
}
```

Within the main function we first call `services.addCommandLineInterfaceService`, which is provided by JCLI to create the `ServiceInfo` that describes
`ICommandLineInterface`. i.e. This tells the `ServiceProvider` on how to create a solid instance of `ICommandLineInterface` when we need one.

Inside of our new command, with have our constructor (`this(ICommandLineInterface)`) that is asking for an `ICommandLineInterface`.

So, when JCLI is constructing a command instance it does so via JIOC's `Injector.construct` function.

The way `Injector.construct` works is: it looks at every parameter of the command's constructor (if it has one); any type that is a class or interface, it'll
attempt to retrieve via a `ServiceProvider`; if it was successful, and instance of that class or interface is passed as that constructor parameter, otherwise `null`
is passed through.

In other words, by asking for an `ICommandLineInterface` within our constructor, we're just telling JCLI to fetch that service from the Service Provider and pass it
through via our constructor, which from there we'll store the reference. We do a null check assert just in case our service doesn't exist within the Service Provider.

After that, when we're executing our new command we essentially generate a call similar to `./mytool echo -- Hello!`, except programmatically, making sure we
forward the status code.

A note about `parseAndExecute`'s second parameter - the `args` from the main function will usually have the program's name as the 0th element, which we generally
don't care about so `parseAndExecute` will skip it by default.

However, when we want to manually pass in arguments we *don't* want it to skip over the first element, which is what the second parameter is telling it to do.

## Configuration

Many tools require persistent configuration, which is an easy yet tedious task to setup, so JCLI provides a rather basic yet useable configuration interface.

The configuration provided by JCLI isn't meant to be overly advanced, it's more just a "get me a working config file ASAP" useful for smaller applications/prototypes,
who don't really need something too fancy.

Configuration is provided via Dependency Injection, using the `IConfig` interface.

There are two implementations of `IConfig` provided by JCLI currently: an in-memory config, and a file config. Both of these implementations are `Adaptable` - as in their
serialisation logic is provided by an external library, bridged into JCLI via an adapter.

JCLI currently only has one built-in adapter which is for [asdf](https://github.com/libmir/asdf), a fast and relatively robust JSON serialisation library.

Writing adapters is very easy to the point where, after all this talk about certain things following a "convention", you should be able to pick it up pretty quickly
by looking at the [asdf adapter](https://github.com/BradleyChatha/jcli/blob/master/source/jaster/cli/adapters/config/asdf.d) itself.

So to put it all together, if you want a file config that uses asdf for serialisation (which means you also get to use all the UDAs and other idiosyncrasies of
whichever library you use), then you can go with an `AdaptableFileConfig` paired with the `AsdfConfigAdapter`.

So, after all that mumbo jumbo, let's see how to use actually use it inside of a program. Before you being, you must run `dub add asdf` otherwise the asdf adapter
won't be available:

```d
struct Config
{
    string file;
    int counter;
    bool destroyComputerOnError;
}

int main(string[] args)
{
    ServiceInfo[] services;
    services.addFileConfig!(Config, AsdfConfigAdapter)("./config.json");

    /// omitted.
}

@Command("seed config", "Seeds the config file with some odd data.")
struct SeedConfigCommand
{
    IConfig!Config _config;

    this(IConfig!Config config)
    {
        assert(config !is null);
        this._config = config;
    }

    void onExecute()
    {
        // A shortcut for this is `editAndSave`
        WasExceptionThrown yesOrNo = this._config.edit(
            // Don't forget the `scope ref`
            (scope ref config)
            {
                config.file = "Andy's dirty secret.txt";
                config.counter = 200;
                config.destroyComputerOnError = true;
            },
            RollbackOnFailure.yes,
            SaveOnSuccess.yes
        );
        assert(yesOrNo == WasExceptionThrown.no);
    }
}

@Command("print config", "Prints the config to the screen.")
struct PrintConfigCommand
{
    IConfig!Config _config;

    this(IConfig!Config config)
    {
        assert(config !is null);
        this._config = config;
    }

    void onExecute()
    {
        import std.stdio;
        writeln(this._config.value);
    }
}
```

Quite a big chunk of code this time, but when broken down it's pretty simple.

We first define our `Config` struct, which is just your average POD struct with some data we want to persist.

Then we use the `services.addFileConfig` function to create a `ServiceInfo` that describes an `AdaptableFileConfig`.

The first template parameter is the user-defined type to store into the file, so `Config` in this case.

The second template parameter is the adapter to use, which is the `AsdfConfigAdapter`.

The first runtime parameter is the path to where the file should be stored.

So we are using asdf to store/retrieve our `Config` from the file `"./config.json"`, in essence.

We can access this service from our commands by requesting an `IConfig!Config`.

Over inside of the `SeedConfigCommand` struct, we have an instance of `IConfig!Config` injected, and then inside of `onExecute` we do something
a bit more peculiar.

The `IConfig.edit` function is used here, as I want to demonstrate the handful of capabilities that `IConfig` supports. As the comment says, there's
a shortcut function for this particular usage called `editAndSave`.

The first parameter is a delegate (lambda) that is given a shallow copy of the configuration's value by reference. All this delegate needs to do is
populate the configuration value with whatever it wants to set it to, by whatever means to get the data.

The second parameter is a flag called `RollbackOnFailure`. As the name implies, if the delegate in the first parameter throws an exception then the
`IConfig` will attempt to rollback any changes. Please see [this comment](https://jcli.dpldocs.info/jaster.cli.config.IConfig.edit.html) on it works exactly.

The third and final parameter is a flag called `SaveOnSuccess`, which literally does at it says on the tin. If the delegate was successful, then call
`IConfig.save` to save any changes.

Finally with this `onExecute`, we just make sure that the return value was `WasExceptionThrown.no`, which explains itself.

Alternatively you can just set `IConfig.value` to something, and then call `IConfig.save`. The `IConfig.edit` function was just supposed to be a helper
around things.

We're now onto the final part of this code which is the `PrintConfigCommand`.

Literally all it does it ask for the config to be injected, retrieves its value via `IConfig.value`, and then prints it to the screen
(D's `writeln` automatically pretty prints structs).

As I said, JCLI's built-in configuration isn't terribly fancy, and offloads the majority of the work onto third party code. But it gets the job
done when you just want something up quick and easy.

## Inheritance

JCLI supports command inheritance.

The only rules with inheritance are:

* Only concrete classes can be marked with `@Command`.

* Concrete classes must have `onExecute` defined, either by a base class or directly.

Other than that, go wild. Every argument marked with `@CommandNamedArg` and `@CommandPostionalArg` will be discovered within the inheritance tree for a command,
and they will all be populated as expected:

```d
abstract class CommandBase
{
    @CommandNamedArg("verbose|v", "Show verbose information.")
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

```bash
$> ./mytool command -h
Usage: mytool.exe command <arg1> <arg2> <output> --test-flag [--verbose|-v] [--log|-l] [--config|-c]

Description:
    This is a command that is totally super complicated.

Positional Args:
    arg1                         - This is a generic argument that isn't grouped anywhere
    arg2                         - This is a generic argument that isn't grouped anywhere

Named Args:
    --test-flag                  - Test flag, please ignore.

Debug:
    Arguments related to debugging.

    --verbose,-v                 - Enables verbose logging.
    --log,-l                     - Specifies a log file to direct output to.

I/O:
    Arguments related to I/O.

    output                       - Where to place the output.
    --config,-c                  - Specifies the config file to use.
```

This can be achieved by using the `@CommandArgGroup` UDA - this is how to produce the above help text:

```d
@Command("command", "This is a command that is totally super complicated.")
struct ComplexCommand
{
    @CommandPositionalArg(0, "arg1", "This is a generic argument that isn't grouped anywhere")
    int a;
    @CommandPositionalArg(1, "arg2", "This is a generic argument that isn't grouped anywhere")
    int b;

    @CommandNamedArg("test-flag", "Test flag, please ignore.")
    bool flag;

    @CommandArgGroup("Debug", "Arguments related to debugging.")
    {
        @CommandNamedArg("verbose|v", "Enables verbose logging.")
        Nullable!bool verbose;

        @CommandNamedArg("log|l", "Specifies a log file to direct output to.")
        Nullable!string log;
    }

    @CommandArgGroup("I/O", "Arguments related to I/O.")
    {
        @CommandPositionalArg(2, "output", "Where to place the output.")
        string output;

        @CommandNamedArg("config|c", "Specifies the config file to use.")
        Nullable!string config;
    }

    void onExecute(){}
}
```

Currently, the order of groups is based on their order in the source code.

# Using JCLI without Dub

It is entirely possible to use JCLI without needing to use dub, there are just two things to keep in mind.

1. JCLI has a hard dependency on [JIOC](https://github.com/BradleyChatha/jioc) however, I am the maintainer of this library, and it is a single-file library, so it is both
safe to assume it'll stay up-to-date, and it is easy to add into your project.

2. For optional dependencies that JCLI supports, such as asdf, these are locked behind different [versions](#versions) so you only need to include them if you're using
them in the first place.

Other than that, if you're not using dub/dub-compatible build system, then I assume you already understand how you would go about adding third party code into your builds.

# Versions

JCLI makes use of the `version` statement in various areas. Here is a list of all versions that JCLI utilises.

Any versions prefixed with `Have_` are automatically created by dub for each dependency in your project. For example, `Have_asdf` will be automatically
defined by dub if you have `asdf` as a dependency of your project. If you do not use dub then you'll have to manually specify these versions when relevant.

| Version                   | Description                                                                                                                    |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| JCLI_Verbose              | When defined, enables certain verbose compile-time logging, such as how `ArgBinder` is deciding which `@ArgBinderFunc` to use. |
| Have_asdf                 | Enables the `AsdfConfigAdapter`, which uses the `asdf` library to serialise the configuration value.                           |

# Contributing

I'm perfectly accepting of anyone wanting to contribute to this library, just note that it might take me a while to respond.

And please, if you have an issue, *create a Github issue for me*. I can't fix or prioritise issues that I don't know exist.
I tend to not care about issues when **I** run across them, but when **someone else** runs into them, then it becomes a much higher priority for me to address it.

Finally, if you use JCLI in anyway feel free to request for me to add your project into the `Examples` section. I'd really love to see how others are using my code :)
