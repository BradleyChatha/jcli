module jcli.argbinder.binder;

import jcli.introspect, jcli.core;

import std.algorithm;
import std.meta;
import std.conv : to;
import std.traits;

enum Binder;
template UseConverter(alias _ConverterFunction)
{ 
    alias ConverterFunction = _ConverterFunction;
}
template PreValidate(_ValidationFunctions...)
{
    alias ValidationFunctions = _ValidationFunction;
}
template PostValidate(_ValidationFunctions...)
{
    alias ValidationFunctions = _ValidationFunction;
}

template bindArgument(Binders...)
{
    Result bindArgument(ArgumentCommonInfo argumentInfo, TCommand)(string stringValue, ref TCommand command)
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
    alias Binders                   = staticMap!(ToBinder, AliasSeq!(Modules, jcli.argbinder.binder));
    alias bindArgumentAcrossModules = bindArgument!(Binders);
}

template GetArgumentBinderInfo(ArgumentCommonInfo argumentCommonInfo, TCommand, Binders...)
{
    alias argumentFieldSymbol = getArgumentFieldSymbol!argumentCommonInfo;
    alias preValidators       = getValidators!(ArgumentFieldSymbol, PreValidator);
    alias postValidators      = getValidators!(ArgumentFieldSymbol, PostValidator);
    alias convertionFunction  = getConversionFunction!(ArgumentFieldSymbol, Binders);
}

// This function should be used to convert the string 
// to the given value when all other options have failed.
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
        result = AliasSeq!(result, ValidatorUDA.ValidationFunctions);
    alias getValidators = result;
}

/// Binders must be functions returning ResultOf
template getConversionFunction(alias ArgSymbol, Binders...)
{
    import std.traits;
    alias ArgumentType = typeof(ArgSymbol);
    alias FoundExplicitConverters = getUDAs!(ArgSymbol, UseConverter);

    static assert(FoundExplicitBinders.length <= 1, "Only one @UseConverter may exist.");
    static if(FoundExplicitBinders.length == 0)
    {
        alias ConverterFunction = FoundExplicitConverters[0].ConverterFunction;

        enum isValidConversionFunction(alias f) = 
            __traits(compiles, { ArgumentType a = f!(ArgT)("").value; })
            || __traits(compiles, { ArgumentType a = f("").value; });
        alias ValidConversionFunctions = Filter!(isValidConversionFunction, Binders);

        static if (ValidConversionFunctions.length == 0)
            alias getConversionFunction = universalFallbackConverter!ArgT;
        else static if(__traits(compiles, Instantiate!(ValidConversionFunctions[0], ArgT)))
            alias getConversionFunction = Instantiate!(ValidConversionFunctions[0], ArgT);
        else
            alias getConversionFunction = ValidConversionFunctions[0];
    }
    else
        alias getConversionFunction = FoundExplicitBinders[0].Func;
}