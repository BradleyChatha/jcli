/// Utility for binding a string into arbitrary types, using user-defined functions.
module jaster.cli.binder;

private
{
    import std.traits : isNumeric, hasUDA;
    import jaster.cli.result, jaster.cli.internal;
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

// Kind of wanted to reuse `ArgBinderFunc`, but making it templated makes it a bit jank to use with functions,
// which don't need to provide any template values for it. So we have this UDA instead.
/++
 + Attach this onto an argument/provide it directly to `ArgBinder.bind`, to specify a specific function to use
 + when binding the argument, instead of relying on ArgBinder's default behaviour.
 +
 + Notes:
 +  The `Func` should match the following signature:
 +
 +  ```
 +  Result!T Func(string arg);
 +  ```
 +
 + Where `T` will be the type of the argument being bound to.
 +
 + Params:
 +  Func = The function to use to perform the binding.
 +
 + See_Also:
 +  `jaster.cli.binder.ArgBinder` and `jaster.cli.binder.ArgBinder.bind` for more details.
 + ++/
struct ArgBindWith(alias Func)
{
    Result!T bind(T)(string arg)
    {
        return Func(arg);
    }
}

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
 + Specific_Binders:
 +  Instead of using the lookup rules above, you can make use of the `ArgBindWith` UDA to provide a specific function to perform the binding
 +  of an argument.
 +
 + Validation_:
 +  Validation structs can be passed via the `UDAs` template parameter present for the `ArgBinder.bind` function.
 +
 +  If you are using `CommandLineInterface` (JCLI's default core), then a field's UDAs are passed through automatically as validator structs.
 +
 +  A validator is simply a struct marked with `@ArgValidator` that defines either, or both of these function signatures (or compatible signatures):
 +
 +  ```
 +      Result!void onPreValidate(string arg);
 +      Result!void onValidate(VALUE_TYPE value); // Can be templated of course.
 +  ```
 +
 +  A validator containing the `onPreValidate` function can be used to validate the argument prior to it being ran through
 +  an `@ArgBinderFunc`.
 +
 +  A validator containing the `onValidate` function can be used to validate the argument after it has been bound by an `@ArgBinderFunc`.
 +
 +  If validation fails, the vaildator can set the error message with `Result!void.failure()`. If this is left as `null`, then one will be automatically
 +  generated for you.
 +
 +  By specifying the "JCLI_Verbose" version, the `ArgBinder` will detail what validators are being used for what types, and for which stages of binding.
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
    import std.format : format;
    import jaster.cli.udas, jaster.cli.internal;
    
    version(Amalgamation)
        alias AllModules = AliasSeq!(Modules, jcli);
    else
        alias AllModules = AliasSeq!(Modules, jaster.cli.binder);

    /+ PUBLIC INTERFACE +/
    public static
    {
        /++
         + Binds the given `arg` to the `value`, using the `@ArgBinderFunc` found by using the 'Lookup Rules' documented in the
         + document comment for `ArgBinder`.
         +
         + Validators_:
         +  The `UDAs` template parameter is used to pass in different UDA structs, including validator structs (see ArgBinder's documentation comment).
         +
         +  Anything inside of this template parameter that isn't a struct, and doesn't have the `ArgValidator` UDA
         +  will be completely ignored, so it is safe to simply pass the results of
         +  `__traits(getAttributes, someField)` without having to worry about filtering.
         +
         + Specific_Binders:
         +  The `UDAs` template paramter is used to pass in different UDA structs, including the `ArgBindWith` UDA.
         +
         +  If the `ArgBindWith` UDA exists within the given parameter, arg binding will be performed using the function
         +  provided by `ArgBindWith`, instead of using the default lookup rules defined by `ArgBinder`.
         +
         +  For example, say you have a several `File` arguments that need different binding behaviour (some are read-only, some truncate, etc.)
         +  In a case like this, you could have some of those arguments marked with `@ArgBindWith!openFileReadOnly` and others with
         +  a function for truncating, etc.
         +
         + Throws:
         +  `Exception` if any validator fails.
         +
         + Assertions:
         +  When an `@ArgBinderFunc` is found, it must have only 1 parameter.
         + 
         +  The first parameter of an `@ArgBinderFunc` must be a `string`.
         +
         +  It must return an instance of the `Result` struct. It is recommended to use `Result!void` as the result's `Success.value` is ignored.
         +
         +  If no appropriate binder func was found, then an assert(false) is used.
         +
         +  If `@ArgBindWith` exists, then exactly 1 must exist, any more than 1 is an error.
         +
         + Params:
         +  arg   = The argument to bind.
         +  value = The value to put the result in.
         +  UDAs  = A tuple of UDA structs to use.
         + ++/
        Result!T bind(T, UDAs...)(string arg)
        {
            import std.conv   : to;
            import std.traits : getSymbolsByUDA, isInstanceOf;

            auto preValidateResult = onPreValidate!(T, UDAs)(arg);
            if(preValidateResult.isFailure)
                return Result!T.failure(preValidateResult.asFailure.error);

            alias ArgBindWithInstance = TryGetArgBindWith!UDAs;
            
            static if(is(ArgBindWithInstance == void))
            {
                enum Binder = ArgBinderFor!(T, AllModules);
                auto result = Binder.Binder(arg);
            }
            else
                auto result = ArgBindWithInstance.init.bind!T(arg); // Looks weird, but trust me. Keep in mind it's an `alias` not an `enum`.

            if(result.isSuccess)
            {
                auto postValidateResult = onValidate!(T, UDAs)(arg, result.asSuccess.value);
                if(postValidateResult.isFailure)
                    return Result!T.failure(postValidateResult.asFailure.error);
            }

            return result;
        }

        private Result!void onPreValidate(T, UDAs...)(string arg)
        {
            static foreach(Validator; ValidatorsFrom!UDAs)
            {{
                static if(isPreValidator!(Validator))
                {
                    debugPragma!("Using PRE VALIDATION validator %s for type %s".format(Validator, T.stringof));

                    Result!void result = Validator.onPreValidate(arg);
                    if(!result.isSuccess)
                    {
                        return result.failure(createValidatorError(
                            "Pre validation",
                            "%s".format(Validator),
                            T.stringof,
                            arg,
                            "[N/A]",
                            result.asFailure.error
                        ));
                    }
                }
            }}

            return Result!void.success();
        }

        private Result!void onValidate(T, UDAs...)(string arg, T value)
        {
            static foreach(Validator; ValidatorsFrom!UDAs)
            {{
                static if(isPostValidator!(Validator))
                {
                    debugPragma!("Using VALUE VALIDATION validator %s for type %s".format(Validator, T.stringof));

                    Result!void result = Validator.onValidate(value);
                    if(!result.isSuccess)
                    {
                        return result.failure(createValidatorError(
                            "Value validation",
                            "%s".format(Validator),
                            T.stringof,
                            arg,
                            "%s".format(value),
                            result.asFailure.error
                        ));
                    }
                }
            }}

            return Result!void.success();
        }
    }
}
///
@safe @("ArgBinder unittest")
unittest
{
    alias Binder = ArgBinder!(jaster.cli.binder);

    // Non-validated bindings.
    auto value    = Binder.bind!int("200");
    auto strValue = Binder.bind!string("200");

    assert(value.asSuccess.value == 200);
    assert(strValue.asSuccess.value == "200");

    // Validated bindings
    @ArgValidator
    static struct GreaterThan
    {
        import std.traits : isNumeric;
        ulong value;

        Result!void onValidate(T)(T value)
        if(isNumeric!T)
        {
            import std.format : format;

            return value > this.value
            ? Result!void.success()
            : Result!void.failure("Value %s is NOT greater than %s".format(value, this.value));
        }
    }

    value = Binder.bind!(int, GreaterThan(68))("69");
    assert(value.asSuccess.value == 69);

    // Failed validation
    assert(Binder.bind!(int, GreaterThan(70))("69").isFailure);
}

@("Test that ArgBinder correctly discards non-validators")
unittest
{
    alias Binder = ArgBinder!(jaster.cli.binder);

    Binder.bind!(int, "string", null, 2020)("2");
}

@("Test that __traits(getAttributes) works with ArgBinder")
unittest
{
    @ArgValidator
    static struct Dummy
    {
        Result!void onPreValidate(string arg)
        {
            return Result!void.failure(null);
        }
    }

    alias Binder = ArgBinder!(jaster.cli.binder);

    static struct S
    {
        @Dummy
        int value;
    }

    assert(Binder.bind!(int, __traits(getAttributes, S.value))("200").isFailure);
}

@("Test that ArgBindWith works")
unittest
{
    static struct S
    {
        @ArgBindWith!(str => Result!string.success(str ~ " lalafells"))
        string arg;
    }

    alias Binder = ArgBinder!(jaster.cli.binder);

    auto result = Binder.bind!(string, __traits(getAttributes, S.arg))("Destroy all");
    assert(result.isSuccess);
    assert(result.asSuccess.value == "Destroy all lalafells");
}

/+ HELPERS +/
@safe
private string createValidatorError(
    string stageName,
    string validatorName,
    string typeName,
    string argValue,
    string valueAsString,
    string validatorError
)
{
    import std.format : format;
    return (validatorError !is null)
           ? validatorError
           : "%s failed for type %s. Validator = %s; Arg = '%s'; Value = %s"
             .format(stageName, typeName, validatorName, argValue, valueAsString);
}

private enum isValidator(alias V)     = is(typeof(V) == struct) && hasUDA!(typeof(V), ArgValidator);
private enum isPreValidator(alias V)  = isValidator!V && __traits(hasMember, typeof(V), "onPreValidate");
private enum isPostValidator(alias V) = isValidator!V && __traits(hasMember, typeof(V), "onValidate");

private template ValidatorsFrom(UDAs...)
{
    import std.meta        : staticMap, Filter;
    import jaster.cli.udas : ctorUdaIfNeeded;

    alias Validators     = staticMap!(ctorUdaIfNeeded, UDAs);
    alias ValidatorsFrom = Filter!(isValidator, Validators);
}

private struct BinderInfo(alias T, alias Symbol)
{
    import std.traits : fullyQualifiedName, isFunction, Parameters, ReturnType;

    // For templated binder funcs, we need a slightly different set of values.
    static if(__traits(compiles, Symbol!T))
    {
        alias Binder      = Symbol!T;
        const FQN         = fullyQualifiedName!Binder~"!("~T.stringof~")";
        const IsTemplated = true;
    }
    else
    {
        alias Binder      = Symbol;
        const FQN         = fullyQualifiedName!Binder;
        const IsTemplated = false;
    }

    const IsFunction  = isFunction!Binder;

    static if(IsFunction)
    {
        alias Params  = Parameters!Binder;
        alias RetType = ReturnType!Binder;
    }
}

private template ArgBinderMapper(T, alias Binder)
{
    import std.traits : isInstanceOf;

    enum Info = BinderInfo!(T, Binder)();

    // When the debugPragma isn't used inside a function, we have to make aliases to each call in order for it to work.
    // Ugly, but whatever.

    static if(!Info.IsFunction)
    {
        alias a = debugPragma!("Skipping arg binder `"~Info.FQN~"` for type `"~T.stringof~"` because `isFunction` is returning false.");
        static if(Info.IsTemplated)
            alias b = debugPragma!("This binder is templated, so it is likely that the binder's contract failed, or its code doesn't compile for this given type.");

        alias ArgBinderMapper = void;
    }
    else static if(!__traits(compiles, { Result!T r = Info.Binder(""); }))
    {
        alias c = debugPragma!("Skipping arg binder `"~Info.FQN~"` for type `"~T.stringof~"` because it does not compile for the given type.");

        alias ArgBinderMapper = void;
    }
    else
    {
        alias d = debugPragma!("Considering arg binder `"~Info.FQN~"` for type `"~T.stringof~"`.");

        static assert(Info.Params.length == 1,
            "The arg binder `"~Info.FQN~"` must only have `1` parameter, not `"~Info.Params.length.to!string~"` parameters."
        );
        static assert(is(Info.Params[0] == string),
            "The arg binder `"~Info.FQN~"` must have a `string` as their first parameter, not a(n) `"~Info.Params[0].stringof~"`."
        );
        static assert(isInstanceOf!(Result, Info.RetType),
            "The arg binder `"~Info.FQN~"` must return a `Result`, not `"~Info.RetType.stringof~"`"
        );
        
        enum ArgBinderMapper = Info;
    }
}

private template ArgBinderFor(alias T, Modules...)
{
    import std.meta        : staticMap, Filter;
    import jaster.cli.udas : getSymbolsByUDAInModules;

    enum isNotVoid(alias T) = !is(T == void);
    alias Mapper(alias BinderT) = ArgBinderMapper!(T, BinderT);

    alias Binders         = getSymbolsByUDAInModules!(ArgBinderFunc, Modules);
    alias BindersForT     = staticMap!(Mapper, Binders);
    alias BindersFiltered = Filter!(isNotVoid, BindersForT);

    // Have to use static if here because the compiler's order of operations makes it so a single `static assert` wouldn't be evaluated at the right time,
    // and so it wouldn't produce our error message, but instead an index out of bounds one.
    static if(BindersFiltered.length > 0)
    {
        enum ArgBinderFor = BindersFiltered[0];
        alias a = debugPragma!("Using arg binder `"~ArgBinderFor.FQN~"` for type `"~T.stringof~"`");
    }
    else
        static assert(false, "No arg binder found for type `"~T.stringof~"`");    
}

private template TryGetArgBindWith(UDAs...)
{
    import std.traits : isInstanceOf;
    import std.meta   : Filter;

    enum FilterFunc(alias T) = isInstanceOf!(ArgBindWith, T);
    alias Filtered = Filter!(FilterFunc, UDAs);

    static if(Filtered.length == 0)
        alias TryGetArgBindWith = void;
    else static if(Filtered.length > 1)
        static assert(false, "Multiple `ArgBindWith` instances were found, only one can be used.");
    else
        alias TryGetArgBindWith = Filtered[0];
}

private template SortedEnumValueNamesFor(E)
if(is(E == enum))
{
    private string names()
    {
        import std.array : array, join;
        import std.algorithm : sort;

        string[] names;
        static foreach(member; __traits(allMembers, E))
            names ~= member;

        names.sort();
        return names.join(", ");
    }

    const SortedEnumValueNamesFor = names();
}

/+ BUILT-IN BINDERS +/

/// arg -> string. The result is the contents of `arg` as-is.
@ArgBinderFunc @safe @nogc
Result!string stringBinder(string arg) nothrow pure
{
    return Result!string.success(arg);
}

/// arg -> enum.
@ArgBinderFunc @trusted // assumeUnique is @system
Result!T enumBinder(T)(string arg) pure
if(is(T == enum))
{
    import std.algorithm : joiner;
    import std.array     : Appender;
    import std.conv      : to, ConvException;
    import std.exception : assumeUnique;
    import jaster.cli.text : asLineWrapped, LineWrapOptions;

    try return Result!T.success(arg.to!T);
    catch(ConvException ex)
    {
        Appender!(char[]) msg;
        const options = LineWrapOptions(80, "\t", "");

        msg.put("Unknown option '");
        msg.put(arg);
        msg.put("' for type ");
        msg.put(__traits(identifier, T));
        msg.put('\n');

        msg.put("Allowed: [\n");
        msg.put(asLineWrapped(SortedEnumValueNamesFor!T, options));
        msg.put("\n]");

        return Result!T.failure(msg.data.assumeUnique);
    }
}

/// arg -> numeric | bool. The result is `arg` converted to `T`.
@ArgBinderFunc @safe
Result!T convBinder(T)(string arg) pure
if(isNumeric!T || is(T == bool))
{
    import std.conv : to, ConvException;
    
    try return Result!T.success(arg.to!T);
    catch(ConvException ex)
        return Result!T.failure(ex.msg);
}

/+ BUILT-IN VALIDATORS +/

/++
 + An `@ArgValidator` that runs the given `Func` during post-binding validation.
 +
 + Notes:
 +  This validator is loosely typed, so if your validator function doesn't compile or doesn't work with whatever
 +  type you attach this validator to, you might get some long-winded errors.
 +
 + Params:
 +  Func = The function that provides validation on a value.
 + ++/
@ArgValidator
struct PostValidate(alias Func)
{
    // We don't do any static checking of the parameter type, as we can utilise a very interesting use case of anonymous lambdas here
    // by allowing the compiler to perform the checks for us.
    //
    // However that does mean we can't provide our own error message, but the scope is so small that a compiler generated one should suffice.
    Result!void onValidate(ParamT)(ParamT arg)
    {
        return Func(arg);
    }
}

// I didn't *want* this to be templated, but when it's not templated and asks directly for a
// `Result!void function(string)`, I get a very very odd error message: "expression __lambda2 is not a valid template value argument"
/++
 + An `@ArgValidator` that runs the given `Func` during pre-binding validation.
 +
 + Params:
 +  Func = The function that provides validation on an argument.
 + ++/
@ArgValidator
struct PreValidate(alias Func)
{
    Result!void onPreValidate(string arg)
    {
        return Func(arg);
    }
}
///
@("PostValidate and PreValidate")
unittest
{
    static struct S
    {
        @PreValidate!(str => Result!void.failureIf(str.length != 3, "Number must be 3 digits long."))
        @PostValidate!(i => Result!void.failureIf(i <= 200, "Number must be larger than 200."))   
        int arg;
    }
    
    alias Binder = ArgBinder!(jaster.cli.binder);
    alias UDAs   = __traits(getAttributes, S.arg);

    assert(Binder.bind!(int, UDAs)("20").isFailure);
    assert(Binder.bind!(int, UDAs)("199").isFailure);
    assert(Binder.bind!(int, UDAs)("300").asSuccess.value == 300);
}