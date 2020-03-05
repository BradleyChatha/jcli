module jaster.cli.binder;

private
{
    import std.traits : isNumeric;
    import jaster.cli.udas : ArgBinderFunc; // Compiler can't see this for some reason when the import is nested.
}

/++
 + A static struct providing functionality for binding a string (the argument) to a value.
 +
 + Description:
 +  The ArgBinder itself does not directly contain functions to bind arguments (e.g arg -> int, arg -> enum, etc.).
 +
 +  Instead, arg binders are user-provided, free-standing functions that are automatically detected from the specified `Modules`.
 +
 +  For each module passed in the `Modules` template parameter, the arg binder will search for any free-standing function marked with
 +  the `@ArgBinderFunc` UDA. These functions must follow a specific signature `@ArgBinderFunc void myBinder(string arg, ref TYPE value)`.
 +
 +  The second parameter (marked 'TYPE') can be *any* type that is desired. The type of this second parameter defines which type it will
 +  bind/convert the given argument into. The second parameter may also be a template type, if needed, to allow for more generic binders.
 +
 +  For example, the following binder `@ArgBinderFunc void argToInt(string arg, ref int value);` will be called anytime the arg binder
 +  needs to bind the argument into an `int` value.
 +
 + Lookup_Rules:
 +  The arg binder functions off of a simple 'First come first served' ruleset.
 +
 +  When looking for a suitable `@ArgBinderFunc` for the given value type, the following process is taken:
 +     * Foreach module in the `Modules` type parameter (from first to last).
 +         * Foreach free-standing function inside of the current module (usually in lexical order).
 +             * Do a compile-time check to see if this function can be called with a string as the first parameter, and the value type as the second.
 +                 * If the check passes, use this function.
 +                 * Otherwise, continue onto the next function.
 +
 +  This means there is significant meaning in the order that the modules are passed. Because of this, the built-in binders (contained in the 
 +  same module as this struct) will always be put at the very end of the list, meaning the user has the oppertunity to essentially 'override' any
 +  of the built-in binders.
 +
 +  One may ask "Won't that be confusing? How do I know which binder is being used?". My answer, while not perfect, is in non-release builds, 
 +  the binder will output a `debug pragma` to give detailed information on which binders are used for which types, and which ones are skipped over (and why they were skipped).
 +
 +  Note that you must also add "JCLI_Verbose" as a version (either in your dub file, or cli, or whatever) for these messages to show up.
 +
 +  While not perfect, this does go over the entire process the arg binder is doing to select which `@ArgBinderFunc` it will use.
 +
 + Notes:
 +  While other parts of this library have special support for `Nullable` types. This struct doesn't directly have any special
 +  behaviour for them, and instead must be built on top of this struct (a templated `@ArgBinderFunc` just for nullables is totally possible!).
 +
 + Params:
 +  Modules = The modules to look over. Please read the 'Description' and 'Lookup Rules' sections of this documentation comment.
 + +/
static struct ArgBinder(Modules...)
{
    import std.conv   : to;
    import std.traits : getSymbolsByUDA, Parameters, isFunction, fullyQualifiedName;
    import std.meta   : AliasSeq;
    import jaster.cli.udas, jaster.cli.internal;
    
    alias AllModules = AliasSeq!(Modules, jaster.cli.binder);

    /+ PUBLIC INTERFACE +/
    public static
    {
        /++
         + Binds the given `arg` to the `value`, using the `@ArgBinderFunc` found by using the 'Lookup Rules' documented in the
         + document comment for `ArgBinder`.
         +
         + Assertions:
         +  When an `@ArgBinderFunc` is found, it must have only 2 parameters.
         + 
         +  The first parameter of an `@ArgBinderFunc` must be a `string`.
         +
         +  If no appropriate binder func was found, then an assert(false) is used.
         +
         + Params:
         +  arg     = The argument to bind.
         +  value   = The value to put the result in.
         + ++/
        void bind(T)(string arg, ref T value)
        {
            bool handled = false;

            static foreach(mod; AllModules)
            {
                foreach(binder; getSymbolsByUDA!(mod, ArgBinderFunc))
                {
                    static if(__traits(compiles, binder!T))
                    {
                        alias Binder = binder!T;
                        const BinderFQN = fullyQualifiedName!mod~"."~fullyQualifiedName!Binder~"!("~T.stringof~")";
                    }
                    else
                    {
                        alias Binder = binder;
                        const BinderFQN = fullyQualifiedName!Binder;
                    }

                    static if(isFunction!Binder)
                    {
                        alias Params = Parameters!Binder;
                        static assert(Params.length == 2,
                            "The arg binder `"~BinderFQN~"` must only have `2` parameters, not `"~Params.length.to!string~"` parameters."
                        );
                        static assert(is(Params[0] == string),
                            "The arg binder `"~BinderFQN~"` must have a `string` as their first parameter, not a(n) `"~Params[0].stringof~"`."
                        );

                        static if(is(Params[1] == T)
                               || __traits(compiles, Binder("", value))) // Template support.
                        {
                            debugPragma!("Using arg binder `"~BinderFQN~"` for type `"~T.stringof~"`.");
                            Binder(arg, value);
                            handled = true;
                            break; // Break out of foreach
                        }
                    }
                    else
                    {
                        debugPragma!(
                            "Skipping arg binder `"~BinderFQN~"` for type `"~T.stringof~"` because `isFunction` is returning false."
                           ~"\nIf the binder is a template function, then this error is occuring because the function's contract fails, or it's code doesn't compile for the given type."
                        );
                    }
                }
            }

            if(!handled)
                assert(false, "No arg binder could be found for type `"~T.stringof~"`");
        }
    }
}
///
unittest
{
    alias Binder = ArgBinder!(jaster.cli.binder);

    int value;
    string strValue;
    Binder.bind("200", value);
    Binder.bind("200", strValue);

    assert(value == 200);
    assert(strValue == "200");
}

/+ BUILT-IN BINDERS +/

/// arg -> string. The result is the contents of `arg` as-is.
@ArgBinderFunc
void stringBinder(string arg, ref string value)
{
    value = arg;
}

/// arg -> numeric. The result is `arg` converted to `T`.
@ArgBinderFunc
void numericBinder(T)(string arg, ref T value)
if(isNumeric!T)
{
    import std.conv : to;
    value = arg.to!T;
}

/// arg -> enum. The `arg` must be the name of one of the values in the `T` enum.
@ArgBinderFunc
void enumBinder(T)(string arg, ref T value)
if(is(T == enum))
{
    import std.conv : to;
    value = arg.to!T;
}

/// arg -> bool.
@ArgBinderFunc
void boolBinder(string arg, ref bool value)
{
    import std.conv : to;
    value = arg.to!bool;
}