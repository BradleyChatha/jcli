module jaster.cli.infogen.actions;

import std.format, std.traits, std.typecons : Nullable;
import jaster.cli.infogen, jaster.cli.binder, jaster.cli.result;

// ArgBinder knows how to safely discard UDAs it doesn't care about.
private alias getBinderUDAs(alias ArgT) = __traits(getAttributes, ArgT);

// Now you may think: "But Bradley, this is module-level, why does this need to be marked static?"
//
// Well now little Timmy, what you don't seem to notice is that D, for some reason, is embedding a "this" pointer (as a consequence of `ArgT` referencing a member field),
// however because this is still technically a `function` I can call it *without* providing a context pointer, which has led to some very
// interesting errors.
static Result!void actionValueBind(alias CommandT, alias ArgT, alias ArgBinderInstance)(string value, ref CommandT commandInstance)
{
    alias SymbolType = typeof(ArgT);

    static if(isInstanceOf!(Nullable, SymbolType))
    {
        // The Unqual removes the `inout` that `get` uses.
        alias ResultT = Unqual!(ReturnType!(SymbolType.get));
    }
    else
        alias ResultT = SymbolType;

    auto result = ArgBinderInstance.bind!(ResultT, getBinderUDAs!ArgT)(value);
    if(!result.isSuccess)
        return Result!void.failure(result.asFailure.error);

    mixin("commandInstance.%s = result.asSuccess.value;".format(__traits(identifier, ArgT)));
    return Result!void.success();
}

static Result!void actionCount(alias CommandT, alias ArgT, alias ArgBinderInstance)(string value, ref CommandT commandInstance)
{
    static assert(__traits(compiles, {typeof(ArgT) a; a++;}), "Type "~typeof(ArgT).stringof~" does not implement the '++' operator.");

    // If parser passes null then the user's input was: -v or -vsome_value
    // If parser passes value then the user's input was: -vv or -vvv(n+1)
    const amount = (value is null) ? 1 : value.length;

    // Simplify implementation for user-defined types by only using ++.
    foreach(i; 0..amount)
        mixin("commandInstance.%s++;".format(__traits(identifier, ArgT)));

    return Result!void.success();
}

static Result!void dummyAction(alias CommandT)(string value, ref CommandT commandInstance)
{
    assert(false, "This action doesn't do anything.");
}