/// Utility for binding a string into arbitrary types, using user-defined functions.
module jaster.cli.binder;

private
{
    import std.traits : isNumeric;
}

/++
 + Attach this to any free-standing function to mark it as an argument binder.
 +
 + See_Also:
 +  `jaster.cli.binder.ArgBinder` for more details.
 + ++/
struct ArgBinderFunc {}

/++
 + Attach this to any struct to specify that it can be used as an arg validator.
 +
 + See_Also:
 +  `jaster.cli.binder.ArgBinder` for more details.
 + ++/
struct ArgValidator {}

/++
 + A static struct providing functionality for binding a string (the argument) to a value, as well as optionally validating it.
 +
 + Description:
 +  The ArgBinder itself does not directly contain functions to bind or validate arguments (e.g arg -> int, arg -> enum, etc.).
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
 +  When binding a value, you can optionally pass in a set of Validators, which are (typically) struct UDAs that provide a certain
 +  interface for validation.
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
 + Validation_:
 +  Validation structs can be passed via the `Validators` template parameter present for the `ArgBinder.bind` function.
 +
 +  If you are using `CommandLineInterface` (JCLI's default core), then a field's UDAs are passed through automatically as validator structs.
 +
 +  A validator is simply a struct marked with `@ArgValidator` that defines either, or both of these function signatures (or compatible signatures):
 +
 +  ```
 +      bool onPreValidate(string arg, ref string errorMessage);
 +      bool onValidate(VALUE_TYPE value, ref string errorMessage); // Can be templated of course.
 +  ```
 +
 +  A validator containing the `onPreValidate` function can be used to validate the argument prior to it being ran through
 +  an `@ArgBinderFunc`.
 +
 +  A validator containing the `onValidate` function can be used to validate the argument after it has been bound by an `@ArgBinderFunc`.
 +
 +  If validation fails, the vaildator can set a user-friendly `errorMessage` to display. If this is left as `null`, then one will be automatically
 +  generated for you.
 +
 +  By specifying the "JCLI_Verbose" version, the `ArgBinder` will detail what validators are being used for what types, and for which stages of binding.
 +
 +  If a type does not pass any of the previously mentioned interfaces, then it is silently ignored. You can specify the `JCLI_BinderCompilerErrors` version
 +  to make `ArgBinder` display some compiler errors, which may help you pinpoint why your validator struct is failing to be used.
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
         + Validators:
         +  The `UDAs` template parameter is used to pass in different UDA structs, including validator structs (see ArgBinder's documentation comment).
         +
         +  Anything inside of this template parameter that isn't a struct, and doesn't define any valid
         +  validator interface, will be completely ignored, so it is safe to simply pass the results of
         +  `__traits(getAttributes, someField)` without having to worry about filtering.
         +
         + Throws:
         +  `Exception` if any validator fails.
         +
         + Assertions:
         +  When an `@ArgBinderFunc` is found, it must have only 2 parameters.
         + 
         +  The first parameter of an `@ArgBinderFunc` must be a `string`.
         +
         +  If no appropriate binder func was found, then an assert(false) is used.
         +
         + Params:
         +  arg   = The argument to bind.
         +  value = The value to put the result in.
         +  UDAs  = A tuple of UDA structs to use.
         + ++/
        void bind(T, UDAs...)(string arg, ref T value)
        {
            import std.traits    : isType, hasUDA;
            import std.format    : format; // Only for exceptions/compile time logging.
            import std.exception : enforce;
            import std.meta      : staticMap;

            // Get all the validators we need.
            enum isValidator(alias V)    = is(typeof(V) == struct) && hasUDA!(typeof(V), ArgValidator);
            enum canPreValidate(alias V) = isValidator!V && __traits(hasMember, V, "onPreValidate");
            enum canValidate(alias V)    = isValidator!V && __traits(hasMember, V, "onValidate");

            // The user might specify `@Struct` instead of `@Struct()`, so this is just to handle that.
            template ctorValidatorIfNeeded(alias V)
            {
                static if(isType!V)
                    enum ctorValidatorIfNeeded = V.init;
                else
                    alias ctorValidatorIfNeeded = V;
            }
            alias ValidatorsMapped = staticMap!(ctorValidatorIfNeeded, UDAs);

            // Runtime variables
            bool handled = false;
            string validatorError;

            // Pre validate the argument text.
            static foreach(Validator; ValidatorsMapped)
            static if(canPreValidate!Validator)
            {
                debugPragma!("Using PRE VALIDATION validator %s for type %s".format(Validator, T.stringof));
                enforce(
                    Validator.onPreValidate(arg, validatorError),
                    new ArgBinderValidationException(
                        "Pre validation",
                        "%s".format(Validator),
                        T.stringof,
                        arg,
                        "[N/A]",
                        validatorError
                    )
                );
            }

            static foreach(mod; AllModules)
            {
                // Bind the text to the value, using the right binder.
                foreach(binder; getSymbolsByUDA!(mod, ArgBinderFunc))
                {

                    // For templated binder funcs, we need a slightly different set of values.
                    static if(__traits(compiles, binder!T))
                    {
                        alias Binder      = binder!T;
                        const BinderFQN   = fullyQualifiedName!mod~"."~fullyQualifiedName!Binder~"!("~T.stringof~")";
                        const IsTemplated = true;
                    }
                    else
                    {
                        alias Binder      = binder;
                        const BinderFQN   = fullyQualifiedName!Binder;
                        const IsTemplated = false;
                    }
                    
                    // Perform the binding, asserting that its interface is correct.
                    static if(isFunction!Binder)
                    {
                        alias Params = Parameters!Binder;
                        static assert(Params.length == 2,
                            "The arg binder `"~BinderFQN~"` must only have `2` parameters, not `"~Params.length.to!string~"` parameters."
                        );
                        static assert(is(Params[0] == string),
                            "The arg binder `"~BinderFQN~"` must have a `string` as their first parameter, not a(n) `"~Params[0].stringof~"`."
                        );

                        static if(__traits(compiles, Binder("", value)))
                        {
                            debugPragma!("Using arg binder `"~BinderFQN~"` for type `"~T.stringof~"`.");
                            Binder(arg, value);
                            handled = true;
                            break; // Break out of foreach
                        }
                    }
                    else
                    {
                        debugPragma!("Skipping arg binder `"~BinderFQN~"` for type `"~T.stringof~"` because `isFunction` is returning false.");
                        static if(IsTemplated)
                            debugPragma!("This binder is templated, so it is likely that the binder's contract fails, or its code doesn't compile for this given type.");
                    }
                }
            }

            if(!handled)
                assert(false, "No arg binder could be found for type `"~T.stringof~"`");

            // Value validation.
            static foreach(Validator; ValidatorsMapped)
            static if(canValidate!Validator)
            {
                debugPragma!("Using VALUE VALIDATION validator %s for type %s".format(Validator, T.stringof));
                enforce(
                    Validator.onValidate(value, validatorError),
                    new ArgBinderValidationException(
                        "Value validation",
                        "%s".format(Validator),
                        T.stringof,
                        arg,
                        "%s".format(value),
                        validatorError
                    )
                );
            }
        }
    }
}
///
@safe
unittest
{
    import std.exception : assertThrown;

    alias Binder = ArgBinder!(jaster.cli.binder);

    // Non-validated bindings.
    int value;
    string strValue;
    Binder.bind("200", value);
    Binder.bind("200", strValue);

    assert(value == 200);
    assert(strValue == "200");

    // Validated bindings
    @ArgValidator
    static struct GreaterThan
    {
        import std.traits : isNumeric;
        ulong value;

        bool onValidate(T)(T value, ref string error)
        if(isNumeric!T)
        {
            import std.format : format;

            // This is only shown on error, so it's safe to set on truthy paths as well
            error = "Value %s is NOT greater than %s".format(value, this.value);

            return value > this.value;
        }
    }

    Binder.bind!(int, GreaterThan(68))("69", value);
    assert(value == 69);

    assertThrown(Binder.bind!(int, GreaterThan(70))("69", value)); // Failed validation causes an exception to be thrown.
}

@("Test that ArgBinder correctly discards non-validators")
unittest
{
    alias Binder = ArgBinder!(jaster.cli.binder);

    int value;
    Binder.bind!(int, "string", null, 2020)("2", value);
}

@("Test that __traits(getAttributes) works with ArgBinder")
unittest
{
    import std.exception : assertThrown;

    @ArgValidator
    static struct Dummy
    {
        bool onPreValidate(string arg, ref string error)
        {
            return false;
        }
    }

    alias Binder = ArgBinder!(jaster.cli.binder);

    static struct S
    {
        @Dummy
        int value;
    }

    S value;
    Binder.bind!(int, __traits(getAttributes, S.value))("200", value.value).assertThrown;
}

class ArgBinderValidationException : Exception
{
    const string stageName;
    const string validatorName;
    const string typeName;
    const string argValue;
    const string valueAsString;
    const string validatorError;

    pure @safe this(
        string stageName,
        string validatorName,
        string typeName,
        string argValue,
        string valueAsString,
        string validatorError,
        string file = __FILE__, 
        size_t line = __LINE__, 
        Throwable next = null)
    {
        this.stageName      = stageName;
        this.validatorName  = validatorName;
        this.typeName       = typeName;
        this.argValue       = argValue;
        this.valueAsString  = valueAsString;
        this.validatorError = validatorError;
        import std.format : format;
        auto error = (this.validatorError !is null)
                     ? this.validatorError
                     : "%s failed for type %s. Validator = %s; Arg = '%s'; Value = %s"
                       .format(stageName, typeName, validatorName, argValue, valueAsString);

        super(error, file, line, next);
    }
}

/+ BUILT-IN BINDERS +/

/// arg -> string. The result is the contents of `arg` as-is.
@ArgBinderFunc @safe @nogc
void stringBinder(string arg, ref scope string value) nothrow pure
{
    value = arg;
}

/// arg -> numeric. The result is `arg` converted to `T`.
@ArgBinderFunc @safe
void numericBinder(T)(string arg, ref scope T value) pure
if(isNumeric!T)
{
    import std.conv : to;
    value = arg.to!T;
}

/// arg -> enum. The `arg` must be the name of one of the values in the `T` enum.
@ArgBinderFunc @safe
void enumBinder(T)(string arg, ref scope T value) pure
if(is(T == enum))
{
    import std.conv : to;
    value = arg.to!T;
}

/// arg -> bool.
@ArgBinderFunc @safe
void boolBinder(string arg, ref scope bool value) pure
{
    import std.conv : to;
    value = arg.to!bool;
}