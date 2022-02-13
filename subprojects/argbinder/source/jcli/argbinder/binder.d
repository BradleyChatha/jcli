module jcli.argbinder.binder;

import jcli.introspect, jcli.core;

import std.algorithm;
import std.meta;
import std.traits;

enum Binder;
template UseConverter(alias _convertionFunction)
{ 
    alias convertionFunction = _convertionFunction;
}
template PreValidate(_validationFunctions...)
{
    alias validationFunctions = _validationFunction;
}
template PostValidate(_validationFunctions...)
{
    alias validationFunctions = _validationFunction;
}

template bindArgument(Binders...)
{
    Result bindArgument
    (
        alias /* Common or Named or Positional info */ argumentInfo,
        TCommand
    )
    (
        string stringValue,
        ref TCommand command
    )
    {
        alias BinderInfo = GetArgumentBinderInfo!(argumentInfo, TCommand, Binders);

        static foreach (v; BinderInfo.preValidators)
        {{
            const result = v(stringValue);
            if (!result.isOk)
                return fail!void(result.error, result.errorCode);
        }}

        auto result = BinderInfo.convertionFunction(stringValue);
        if (!result.isOk)
            return fail!void(result.error, result.errorCode);

        static foreach (v; BinderInfo.postValidators)
        {{
            const result = v(result.value);
            if (!result.isOk)
                return fail!void(result.error, result.errorCode);
        }}

        static if (argumentInfo.flags.has(ArgFlags._aggregateBit))
            command.getArgumentFieldRef!argumentInfo ~= result.value;
        else
            command.getArgumentFieldRef!argumentInfo = result.value;

        return ok();
    }
}

template bindArgumentAcrossModules(Modules...)
{
    alias ToBinder(alias M)         = getSymbolsByUDA!(M, Binder);
    alias Binders                   = staticMap!(ToBinder, Modules);
    alias bindArgumentAcrossModules = bindArgument!(Binders);
}

template GetArgumentBinderInfo(
    alias /* Common or Named or Positional info */ argumentInfo,
    TCommand,
    Binders...)
{
    alias argumentFieldSymbol = getArgumentFieldSymbol!(TCommand, argumentInfo);
    alias preValidators       = getValidators!(argumentFieldSymbol, PreValidate);
    alias postValidators      = getValidators!(argumentFieldSymbol, PostValidate);
    alias convertionFunction  = getConversionFunction!(argumentFieldSymbol, Binders);
}

// This function should be used to convert the string 
// to the given value when all other options have failed.
import std.conv : to, ConvException;
ResultOf!T universalFallbackConverter(T)(string value)
    if (__traits(compiles, to!T))
{
    try 
        return ok(to!T(value));
    catch (ConvException exc)
        return fail!T(exc.msg); 
}

private:

template getValidators(alias ArgSymbol, alias ValidatorUDAType)
{
    alias result = AliasSeq!();
    static foreach (alias ValidatorUDA; getUDAs!(ArgSymbol, ValidatorUDAType))
        result = AliasSeq!(result, ValidatorUDA.validationFunctions);
    alias getValidators = result;
}

/// Binders must be functions returning ResultOf
template getConversionFunction(alias argumentFieldSymbol, Binders...)
{
    import std.traits;
    alias ArgumentType = typeof(argumentFieldSymbol);
    alias FoundExplicitConverters = getUDAs!(argumentFieldSymbol, UseConverter);

    static assert(FoundExplicitConverters.length <= 1, "Only one @UseConverter may exist.");
    static if(FoundExplicitConverters.length == 0)
    {
        // There is no such thing as a to!(Nullable!int), for example,
        // but a Nullable!int can be created implicitly from an int.
        //
        // The whole point is, we need to convert into the underlying type 
        // and not into the outer Nullable type, because then to!ThatType will fail,
        // but the Nullable!T construction from a T won't.
        // 
        // So here we extract the inner type in case it is a Nullable.
        //
        // Note:
        // Nullable-like user types can be handled in user code via the use of Binders.
        // User-defined binders will match before the universal fallback converter (aka to!T).
        // 
        static if (is(ArgumentType : Nullable!T, T))
            alias ConvertionType = T;
        else
            alias ConvertionType = ArgumentType;

        enum isValidConversionFunction(alias f) = 
            __traits(compiles, { ArgumentType a = f!(ConvertionType)("").value; })
            || __traits(compiles, { ArgumentType a = f("").value; });
        alias validConversionFunctions = Filter!(isValidConversionFunction, Binders);

        static if (validConversionFunctions.length == 0)
            alias getConversionFunction = universalFallbackConverter!ConvertionType;
        else static if(__traits(compiles, Instantiate!(validConversionFunctions[0], ConvertionType)))
            alias getConversionFunction = Instantiate!(validConversionFunctions[0], ConvertionType);
        else
            alias getConversionFunction = validConversionFunctions[0];
    }
    else
    {
        alias getConversionFunction = FoundExplicitConverters[0].converterFunction;
    }
}