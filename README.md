<p align="center">
    <img src="https://i.imgur.com/nbQPhO9.png"/>
</p>

# Overview

![Tests](https://github.com/BradleyChatha/jcli/workflows/Test%20LDC%20x64/badge.svg)
![Examples](https://github.com/BradleyChatha/jcli/workflows/Test%20Examples/badge.svg)

JCLI is a library to aid in the creation of command line tooling, with an aim of being easy to use, while also allowing
the individual parts of the library to be used on their own, aiding more dedicated users in creation their own CLI core.

As a firm believer of good documentation, JCLI is completely documented with in-depth explanations where needed. In-browser documentation can be found [here](https://jcli.dpldocs.info/jaster.cli.html).

Tested on Windows and Ubuntu 18.04.

1. [Overview](#overview)
1. [Features](#features)
1. ["Quick" Start/HOWTO](#quick-start)
    1. [Creating a default command](#creating-a-default-command)
    1. [Positional arguments](#positional-arguments)
    1. [Registering commands](#registering-commands)
    1. [Running the program](#running-the-program)
    1. [Named arguments](#named-arguments)
    1. [Optional arguments](#optional-arguments)
    1. [Arguments with multiple names](#arguments-with-multiple-names)
    1. [Named commands](#named-commands)
    1. [User Defined argument binding](#user-defined-argument-binding)
    1. [User Defined argument validation](#user-defined-argument-validation)
    1. [Unparsed Raw Arg List](#unparsed-raw-arg-list)
    1. [Dependency Injection](#dependency-injection)
    1. [Calling a command from another command](#calling-a-command-from-another-command)
    1. [Configuration](#configuration)
    1. [Inheritance](#inheritance)
1. [Versions](#versions)
1. [Contributing](#contributing)

# Features

* Argument parsing:

    * Named and positional arguments.
    
    * Boolean arguments (flags).

    * Optional arguments using the standard `Nullable` type.

    * User-Defined argument binding (string -> any_type_you_want).

    * User-Defined argument validation (via UDAs that follow a convention).

    * Pass through unparsed arguments. (`./mytool parsed args -- these are unparsed args`)

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

* Utilities:

    * Bash completion support.

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

All commands must define an `onExecute` function, which either returns `void`, or an `int` that will be used as the program's exit/status code.

As a side note, an initial dub project does not include the intial `module app;` shown in the example above. I've added it as we'll need the directly reference the module in a later section.

## Positional Arguments

To start off, let's make our default command take a number as a positional arg. If this number is even then return `1`, otherwise return `0`.

Positional arguments are expected to exist in a specific position within the arguments passed to your program.

For example the command `mytool 60 yoyo true` would have `60` in the 0th position, `yoyo` in the 1st position, and `true` in the 2nd position:

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

We create the field member `int number;` and decorate it with the `@CommandPositionalArg` UDA to specify it as a positional argument.

The first parameter is the position this argument should be at, which we define as the 0th position.

The second parameter is an optional name we can give the parameter, which is shown in the command's help text, but serves no other function.

The last parameter is simply a description.

An example of the help text is shown in the [Running your program](#running-your-program) section, which demonstrates why
you should be provide a name to positional arguments.

## Registering commands

To use our new command, we just need to register it first:

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

First, we create `executor` which is a `CommandLineInterface` instance. To discover commands, it must know which modules to look in. Remember at the start I told you to write `module app;` at the start of the file? So what we're doing here is passing our module called `app` into `CommandLineInterface`, so that it can find all our commands there.

For future reference, you can pass any amount of modules into `CommandLineInterface`, not just a single one.

Second, we call `executor.parseAndExecute(args)`, which returns a status code that we store into the variable `statusCode`. This `parseAndExecute` function will parse the arguments given to it; figure out which command to call; create an instance of that command; fill out the command's argument members, and then finally call the command's `onExecute` function. The rest is pretty self explanatory.

Your app.d file should look something like [this](https://pastebin.com/PhRFtW9G).

## Running the program

First, let's have a look at the help text for our default command:

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
    reversed // Even returns 0. Odd returns 1.
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

Let's have a quick look at the help text first, to see the changes being reflected:

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

Anyway, all we want to do is make our `mode` argument a `Nullable`, so JCLI knows it's optional:

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

The other change we made is that inside of `onExecute` we now use `this.mode.get(Mode.normal)`.

The `Nullable.get` function will either return us the value stored in the `Nullable`, or if the `Nullable` is null it will return to us the value we pass to it.

So by doing `get(Mode.normal)` we're saying "Give us the value the user passed in. Or, if the user didn't pass in a value, default to `Mode.normal`".

First, let's look at the help text, as it very slightly changes for nullable arguments:

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

So now let's test that the argument is now in fact optional:

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

Let's do a quick test as usual:

```bash
$> ./mytool 60 -m normal
Program exited with status code 1

# JCLI even supports this weird syntax shorthand arguments sometimes use.
$> ./mytool 60 -mreversed
Program exited with status code 0
```

## Named Commands

Named commands are commands that... have a name. For example `git commit`; `dub build`; `dub init`, etc. are all named commands.

It's really easy to make a named command. Let's change our default command into a named command:

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

As a bit of a difference, let's test the code first:

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

First, we need to create the arg binder:

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

The most important thing of note here is, notice how the `file` variable has the type `File`, and recall that our arg binder's `output` parameter also has the type `File`? This tells the arg binder that it has a function to convert the user's provided string into a `File` for us.

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
std.exception.ErrnoException@std\stdio.d(428): Cannot open file `non-existing-file' in mode `r' (No such file or directory)
```

Very simple. Very useful.

## User Defined argument validation

It's cool and all being able to very easily create arg binders, but sometimes commands will need validation logic involved.

For example, some commands might only want files with a `.json` extention, while others may not care about extentions. So putting this logic into the arg binder itself isn't overly wise.

Some arguments may need validation on the pre-arg-binded string, whereas others may need validation on the post-arg-binded value. Some may need both!

JCLI handles all of this via argument validators.

Let's start off with the first example, making sure the user only passes in files with a `.json` extention, and apply it to our `cat` command. Code first, explanation after:

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

And that's literally all there is to it, let's test:

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

Let's make a validator that ensures that the file is under a certain size:

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

We've set the max size to something really small, so we can easily test that it works:

```bash
$> ./mytool cat ./dub.json
ERROR: For positional arg 0(filePath): File is too large.
Program exited with status code -1
```

Excellent.

**Word of warning**: Due to various reasons I won't get into, JCLI will silently skip over validators that have incorrect interfaces, so if something isn't working it's likely because JCLI has found an issue with it. Specify the version `JCLI_BinderCompilerErrors` inside of your dub.json/dub.sdl in order to try and attempt to debug why.

## Unparsed Raw Arg List

So far whenever we've been testing our program, I've told you to do `dub build` into a `./mytools ...` command.

What if I told you we can just use a single dub command to do both at the same time?

`dub run` will both build and run the program, while also allowing us to pass arguments to our own program.

For example, instead of `./mytool cat dub.json` we can just do `dub run -- cat dub.json`, all the args after the double dash are passed
unmodified to our own program. JCLI refers to this as the "raw arg list".

So naturally, JCLI provides this feature as well using the exact same syntax:

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
