<p align="center">
    <img src="https://i.imgur.com/nbQPhO9.png"/>
</p>

# Overview

![Tests](https://github.com/BradleyChatha/jcli/workflows/Test%20LDC%20x64/badge.svg)
![Examples](https://github.com/BradleyChatha/jcli/workflows/Test%20Examples/badge.svg)

JCLI is a library to aid in the creation of command line tooling, with an aim of being easy to use, while also allowing
the individual parts of the library to be used on their own, allowing more dedicated users some tools to create their own
customised core.

As a firm believer of good documentation, JCLI is completely documented with in-depth explanations where needed. In-browser documentation can be found [here](https://jcli.dpldocs.info/jaster.cli.html).

1. [Overview](#overview)
2. [Features](#features)
3. ["Quick" Start/HOWTO](#quick-start)
    1. [Creating your project](#creating-your-project)
    2. [Creating a default command](#creating-a-default-command)
    3. [Positional arguments](#positional-arguments)
    4. [Registering commands](#registering-commands)
    5. [Compiling and running your program (and help text)](#compiling-and-running-our-program-also-show-help-text)
    6. [Named arguments](#named-arguments)
    7. [Optional arguments](#optional-arguments)
    8. [Arguments with multiple names](#arguments-with-multiple-names)
    9. [Named commands/subcommands](#named-commands)
    10. [User Defined argument binding](#user-defined-argument-binding)
    11. [User Defined argument validation](#user-defined-argument-validation)
4. [Versions](#versions)
5. [Contributing](#contributing)

# Features

* Parsing arguments. Named and Positional arguments are supported.

* Dispatching to the appropriate commands.

* Commands are defined using UDAs, and are automatically discovered.

* Supports a default command, as well as any number of named/sub-commands.

* Commands are provided with automatic constructor Dependency Injection.

* User-Defined argument binding (string -> any_type_you_want).

* User-Defined argument validation (via UDAs that follow a convention).

* Special support for boolean arguments.

* Support for allowing the user to pass through unparsed arguments. (`mytool command -- these are unparsed args`)

* Automatic support and generation for help text via `--help` on: default commands, exact matches for named/sub-commands, and partial matches for named/sub-commands.

* Bash Completion support.

* Coloured, configurable logging.

* Utilities for getting input from the user. Integrates with User-Defined argument binding + validation.

* Fluently built ANSI (stylised) text, with Windows' ANSI support automatically turned on.

* Good support for parsing ANSI-encoding text, so not only can you create ANSI text, you can also read it properly.

* Basic but flexible Configuration Providers, used alongside Dependency Injection.

* An ANSI-enabled text buffer, for easier and efficient control over coloured, non-uniform text output.

* Shell utilities such as `pushLocation` and `popLocation`, synonymous with Powershell's `Push-Location` and `Pop-Location`.

* Tested on Windows, and Ubuntu 18.04.

* All individual parts of this library are intended to be reusable. Allowing you to build your own CLI core using these already-made components, if desired.

# Quick Start

*This is a brief overview, for slightly more in-depth examples please look at the fully-documented [examples](https://github.com/BradleyChatha/jcli/tree/master/examples) folder.*

## Creating your project

Install any D [compiler](https://dlang.org/download.html#dmd).

Open a command prompt and run `dub init mytool` and follow the on-screen prompts.

Run the command `dub add jcli` to add JCLI as a dependency.

Open `source/app.d`, **add the line** `module app;` at the top of the file, and we'll get started from there.

## Creating a default command

The default command is the command that is ran when you don't specify the name of a named command. e.g. `mytool 60 20 --some=args` would call the default command if it exists.

To start off with, we need to import jcli and create a minimal amount of code for our command to exist.

```d
import jaster.cli;

@Command(null, "The default command.")
struct DefaultCommand
{
    int onExecute()
    {
        return 0;
    }
}
```

The `@Command` is a UDA (User Defined Attribute) where the first parameter is the command's name (`null` for the default command), and the second parameter is the command's description.

All commands must define an `onExecute` function, which either returns `void`, or an `int` which will be used as the program's exit/status code.

Commands can either be a struct or a class, but for now we'll use structs as they're simpler.

## Positional Arguments

To start off, let's make this command a number as a positional arg. If this number is even then return `1`, otherwise return `0`.

Positional arguments don't have a name, and are expected to exist in a specific position within the arguments passed to your program.

For example the command `mytool 60 yoyo true` would have `60` in the 0th position, `yoyo` in the 1st position, and `true` in the 2nd position.

```d
@Command(null, "The default command.")
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

We create the field member `int number;` and decorate with the `@CommandPositionalArg` UDA to specify it as a positional argument.

The first parameter is the position this argument should be at, which we define as the 0th position.

The second parameter is an optional name we can give the parameter, which is shown in the command's help text, but serves no other function.

The last parameter is simply a description.

## Registering commands

We can almost use our new command, we just need to register it first. As usual I'll provide an explanation after the code.

```d
import jaster.cli;

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

First, we create `executor` which is a `CommandLineInterface` instance. If you are not familiar with D, the `!(app)` construct is how we pass template parameters in D, so this would be analogous to `<app>()` in C++.

For `CommandLineInterface` to discover commands, it must know which modules (in D, this is a code file) to look in. Remember at the start I told you to write `module app;` at the start of the file? So all `!(app)` is doing is passing the module called `app` into `CommandLineInterface`, so that it can find all our commands there.

For future reference, you can pass any amount of modules into `CommandLineInterface`, not just a single one.

Second, we call `executor.parseAndExecute(args)`, which returns a status code that we store into the variable `statusCode`. This `parseAndExecute` function will parse the arguments given to it; figure out which command to call; create an instance of that command; fill out the command's argument members, and then finally call the command's `onExecute` function.

Third, we simply log the status code to the console, so we can easily see what our program is doing.

Finally, we return the status code and let the OS/shell do whatever with it.

Your app.d file should look something like [this](https://pastebin.com/aeAGa0gY).

## Compiling and running our program (Also show help text)

Open a command prompt inside the root of your project's folder, and run the command `dub build`.

If everything went well then an executable file called `mytool` (or whatever you named your project) should've been created inside of your project's root.

First, let's have a look at the help text for our default command.

```bash
$> ./mytool --help
Usage: DEFAULT {0/number}

Description:
    The default command.

Positional Args:
    0,number                     - The number to check.
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

# No number (Error message doesn't look great yet)
$> ./mytool
ERROR: The following required positional arguments were not provided: ["[0] number"]
Program exited with status code -1

# Too many numbers
$> ./mytool 1 2
ERROR: Stray positional arg found: '2'
Program exited with status code -1
```

Excellent, we can see that with little to no work, our command performs as expected while rejecting invalid use cases.

## Named arguments

Right, so what if the user decides that they want us to return `0` instead of `1`, and `1` instead of `0`. In other words, reverse the output?

Well, let's make them pass in a named argument called `--mode`, which maps directly to an `enum` inside of our D code, to select what behavior we want. Did I forget to mention JCLI can do that?

```d
enum Mode
{
    normal,  // Even returns 1. Odd returns 0.
    reversed // Even returns 0. Odd return 1.
}

@Command(null, "The default command.")
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

To start off, we create an `enum` called `Mode`, and give the members `normal` and `reversed`. JCLI knows how to map strings into enums.

Next, inside of `DefaultCommand` we create a member field called `Mode mode;` that is decorated with the `CommandNamedArg` UDA.

The first parameter is the name of the argument, which is actually important this time as this determines what name the user has to use.

The second parameter is just the description.

Then inside of `onExecute` we just check what `mode` was set to and do stuff based off of its value.

Time to test! Remember to run `dub build` first.

Let's have a quick look at the help text first, to see the changes being reflected.

```bash
$> ./mytool --help
Usage: DEFAULT {0/number} [mode]

Description:
    The default command.

Positional Args:
    0,number                     - The number to check.

Named Args:
    --mode                       - Which mode to use.
```

And now let's test our functionality.

```bash
# JCLI supports most common argument styles.

# Even (Normal)
$> mytool 60 --mode normal
Program exited with status code 1

# Even (Reversed)
$> mytool 60 --mode=reversed
Program exited with status code 0

# Bad value for mode
$> mytool 60 --mode lol
std.conv.ConvException@\src\phobos\std\conv.d(2817): Mode does not have a member named 'reverse'

# Can safely assume Odd behaves properly.

# Now, we haven't marked --mode as optional, so...
$> mytool 60
ERROR: The following required named arguments were not provided: ["mode"]
Program exited with status code -1
```

We can see that `--mode` is working as expected, however notice that in the last case, the user isn't allowed to leave out `--mode` since it's not marked as optional.

## Optional Arguments

Optional arguments, as the name implies, are optional. Only Named arguments can be optional (technically, Positional arguments can be optional in certain use cases, but JCLI doesn't support that... yet).

Inside of D's standard library - Phobos - is the module [std.typecons](https://dlang.org/phobos/std_typecons.html) which contains a type called [Nullable](https://dlang.org/phobos/std_typecons.html#Nullable).

JCLI has special support for this type, as it is used to mark an argument as optional. This type is publicly imported by JCLI, so you don't have to import anything extra.

Anyway, all we want to do is make our `mode` argument a `Nullable`, so the user knows it's optional.

```d
@Command(null, "The default command.")
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

The first change is that `Mode mode;` has now become `Nullable!Mode mode`, to make it, quite literally, a `Mode` that is `Nullable`.

The other change we made is that, inside of `onExecute` we now use `this.mode.get(Mode.normal)`.

The `Nullable.get` function will either return us the value stored in the `Nullable`, or if the `Nullable` is null it will return to us the value we pass to it.

So by doing `get(Mode.normal)` we're saying "Give us the value the user passed in. Or, if the user didn't pass in a value, default to `Mode.normal`".

First, let's look at the help text, as it very slightly changes for nullable arguments.

```bash
$> ./mytool --help
Usage: DEFAULT {0/number} <[mode]>

Description:
    The default command.

Positional Args:
    0,number                     - The number to check.

Named Args:
    --mode                       - Which mode to use.
```

Notice the "Usage:" line. The `[mode]` has now become `<[mode]>` to indicate it is optional.

So now let's test that the argument is now in fact optional.

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

Here is where the very simple concept of "patterns" comes into play. At the moment, and honestly for the foreseeable future, patterns are just strings with a pipe ('|') between each different value.

```d
@Command(null, "The default command.")
struct DefaultCommand
{
    @CommandNamedArg("mode|m", "Which mode to use.")
    Nullable!Mode mode;

    // omitted as it's unchanged...
}
```

All we've done is changed `@CommandNamedArg`'s name from `"mode"` to `"mode|m"`, which basically means that we can use *either* `--mode` or `-m` to set the mode.

You can have as many values within a pattern as you want. Named Arguments cannot have whitespace within their patterns though.

Let's do a quick test as usual.

```bash
$> ./mytool 60 -m normal
Program exited with status code 1

# JCLI even supports this weird syntax shorthand arguments sometimes use.
$> ./mytool 60 -mreversed
Program exited with status code 0
```

## Named Commands

Named commands are commands that... have a name. For example `git commit`; `dub build`; `dub init`, etc. are all named commands.

It's really easy to make a named command. Let's change our default command into a named command.

```d
// Renamed from DefaultCommand
@Command("assert|a|is even", "Asserts that a number is even.")
struct AssertCommand
{
    // ...
}
```

Basically, we just pass a pattern (yes, commands can have multiple names!) as the first parameter for the `@Command` UDA, instead of leaving it as null.

Command patterns can have spaces in them, to allow a multi-word, fluent interface for your tool.

As a bit of a difference, let's test the code first.

```bash
# We have to specify a name now. JCLI will offer suggestions!
$> ./mytool 60
ERROR: Unknown command '60'.

Did you mean:
    assert                       - Asserts that a number is even.

# Passing cases (all producing the same output)
$> ./mytool assert 60
$> ./mytool a 60
$> ./mytool is even 60
Program exited with status code 1
```

TODO: I need to fix the help text (why is it always broken) before showing smart help text suggestions here.

## User Defined argument binding

JCLI has support for users specifying their own functions for converting an argument's string value into the final value passed into the command instance.

In fact, all of JCLI's built in arg binders use this system, they're just implicitly included by JCLI.

While I won't go over them directly, [here's](https://github.com/BradleyChatha/jcli/blob/master/source/jaster/cli/binder.d#L37) the documentation for lookup rules regarding binders, for those of you who are interested.

Let's recreate the `cat` command, which takes a filepath and then outputs the contents of that file.

Instead of asking JCLI for just a string though, let's create an arg binder that will construct a `File` (from [std.stdio](https://dlang.org/library/std/stdio/file.html)) from the string, so our command doesn't have to do any file loading by itself.

First, we need to create the arg binder.

```d
// app.d still
import std.stdio : File;

@ArgBinderFunc
void fileBinder(string arg, ref File output)
{
    output = File(arg, "r");
}
```

First of all we import `File` from the `std.stdio` module.

Second, we create a function, decorated with `@ArgBinderFunc`, that follow a specific convention for its signature:

```d
@ArgBinderFunc
void <anyNameItDoesntMatter>(string arg, ref <YourOutputTypeHere> output);
```

The `arg` parameter is the raw string provided by the user, for whichever argument we're binding from.

The `output` parameter is passed by reference, and the arg binder is expected to set it to the final value that'll be passed into the command instance.

Finally, all our binder does is set the `output` parameter to a `File` that opens a file using the exact `arg` given to use by the user, and opens it in read-only mode ('r').

Arg binders need to be marked with the `@ArgBinderFunc` UDA so that the `CommandLineInterface` class can discover them. Talking about `CommandLineInterface`, it'll automatically discover any arg binder from the modules you tell it about, just like it does with commands.

Let's now create our new command.

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

The most important thing of note here is, notice how the `file` variable has the type `File`, and recall that our arg binder's `output` parameter also has the type `File`? This tells the arg binder that it has a function to convert the user's provided string into a `File` for us.

Our `onExecute` function is nothing overly special, it just displays the file line by line.

Test time. Let's make it show the contents of our `dub.json` file, which is within the root of our project.

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
std.exception.ErrnoException@std\stdio.d(428): Cannot open file `non-existing-file' in mode `r' (No such file or directory)
```

Very simple. Very useful.

## User Defined argument validation

It's cool and all being able to very easily create arg binders, but sometimes commands will need validation logic involved.

For example, some commands might only want files with a `.json` extention, while others may not care about extentions. So putting this logic into the arg binder itself isn't overly wise.

Some arguments may need validation on the pre-arg-binded string, whereas others may need validation on the post-arg-binded value. Some may need both!

JCLI handles all of this via argument validators.

Let's start off with the first example, making sure the user only passes in files with a `.json` extention, and apply it to our `cat` command. Code first, explanation after.

```d
struct HasExtention
{
    string wantedExtention;

    bool onPreValidate(string arg, ref string errorIfFalse)
    {
        import std.algorithm : endsWith;

        // Errors only display if we return false.
        errorIfFalse = "Expected file to have extention of "~this.wantedExtention;

        return arg.endsWith(this.wantedExtention);
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

To start, we create a struct called `HasExtention` and we give it a field member called `string wantedExtention;`.

Before I continue, I want to explicitly state that this validator wants to perform validation on the raw string that the user provides (pre-arg-binded) and *not* on the final value (post-arg-binded). This is referred to as "Pre Validation". So on that note...

Next, and most importantly, we define a function that specifically called `onPreValidate` that follows the following convention:

```d
bool onPreValidate(string arg, ref string error);
```

This is the function that performs the actual validation (in this case, "Pre" validation).

It returns `true` if there are no validation errors, otherwise it returns `false` and optionally sets the `error` string to a user-friendly error (one is automatically generated otherwise).

The first parameter is the raw string that the user has provided us, and I just explained the second parameter.

So for our `HasExtention` validator, all we do is check if the user's file path ends with `this.wantedExtention`, which we set the value of later.

Now, inside `CatCommand` all we've done is attach our `HasExtention` struct as a UDA (and if you're not familiar with D, congrats, you just made your first UDA!). JCLI will automatically detect that `@HasExtention` is a validator because it follows that convention mentioned just above.

Because D is wonderful, it will automatically generate a constructor for us where the first parameter sets the `wantedExtention` member. So `@HasExtention(".json")` will set the extention we want to `".json"`.

And that's literally all there is to it, let's test.

```bash
# Passing
$> ./mytool cat ./dub.json
[contents of dub.json since validation was a success]
Program exited with status code 0

# Failing
$> ./mytool cat ./.gitignore
ERROR: For positional arg 0(filePath): Expected file to have extention of .json
Program exited with status code -1
```

The other type of validation is post-arg-binded validation, which performs validation on the final value provided by an arg binder.

Let's make a validator that ensures that the file is under a certain size.

```d
struct MaxSize
{
    ulong maxSize;

    bool onValidate(File file, ref string error)
    {
        error = "File is too large.";
        return file.size() <= this.maxSize;
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
bool onValidate(<TYPE_OF_VALUE_TO_VALIDATE> value, ref string error);
```

The only difference is that the first parameter isn't a `string`, but instead the type of value that this validator will work with.

Validators can have different overloads of this function if required. You can even make it a template. JCLI is fine with any of that.

We've set the max size to something really small, so we can easily test that it works.

```bash
$> ./mytool cat ./dub.json
ERROR: For positional arg 0(filePath): File is too large.
Program exited with status code -1
```

Excellent.

**Word of warning**: Due to various reasons I won't get into, JCLI will silently skip over validators that have incorrect interfaces, so if something isn't working it's likely because JCLI has found an issue with it. Specify the version `JCLI_BinderCompilerErrors` inside of your dub.json/dub.sdl in order to try and attempt to debug why.

# Versions

JCLI makes use of the `version` statement in various areas. Here is a list of all versions that JCLI utilises.

Any versions prefixed with `Have_` are automatically created by dub for each dependency in your project. For example, `Have_asdf` will be automatically
defined by dub if you have `asdf` as a dependency of your project. If you do not use dub then you'll have to manually specify these versions when relevant.

| Version                   | Description                                                                                                                    |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| JCLI_Verbose              | When defined, enables certain verbose compile-time logging, such as how `ArgBinder` is deciding which `@ArgBinderFunc` to use. |
| JCLI_BinderCompilerErrors | Tells `ArgBinder` to intentionally cause compiler errors, allowing an attempt to figure out instantiation issues.              |
| Have_asdf                 | Enables the `AsdfConfigAdapter`, which uses the `asdf` library to serialise the configuration value.                           |

# Contributing

I'm perfectly accepting of anyone wanting to contribute to this library, just note that it might take me a while to respond.

And please, if you have an issue, *create a Github issue for me*. I can't fix or prioritise issues that I don't know exist.
I tend to not care about issues when **I** run across them, but when **someone else** runs into them, then it becomes a much higher priority for me to address it.

Finally, if you use JCLI in anyway feel free to request for me to add your project into the `Examples` section. I'd really love to see how others are using my code :)
