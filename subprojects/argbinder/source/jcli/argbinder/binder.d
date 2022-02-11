module jcli.argbinder.binder;

import jcli.introspect, jcli.core;

import std.algorithm;
import std.meta;
import std.traits;

struct Binder {}
struct BindWith(alias Func_){ alias Func = Func_; }
struct PreValidator {}
struct PostValidator {}

template ArgBinder(Modules...)
{
    alias ToBinder(alias M) = getSymbolsByUDA!(M, Binder);
    alias Binders           = staticMap!(ToBinder, AliasSeq!(Modules, jcli.argbinder.binder));

    Result bind(alias ArgIntrospectT)(string str, ref ArgIntrospectT.CommandT command)
    {
        alias ArgSymbol         = getArgSymbol!ArgIntrospectT;
        alias PreValidators     = getValidators!(ArgSymbol, PreValidator);
        alias PostValidators    = getValidators!(ArgSymbol, PostValidator);
        alias BindWith          = getBindWith!(ArgSymbol, Binders);

        static foreach(v; PreValidators)
        {{
            const result = v.preValidate(str);
            if(!result.isOk)
                return fail!void(result.error, result.errorCode);
        }}

        auto result = BindWith(str);
        if(!result.isOk)
            return fail!void(result.error, result.errorCode);
        getArg!ArgIntrospectT(command) = result.value;

        static foreach(v; PostValidators)
        {{
            const res = v.postValidate(getArg!ArgIntrospectT(command));
            if(!res.isOk)
                return fail!void(res.error, res.errorCode);
        }}

        return ok();
    }
}

@Binder
ResultOf!string binderString(string value)
{
    return ok(value);
}
///
unittest
{
    @CommandDefault
    static struct S
    {
        @ArgPositional
        string str;
    }

    alias Info = commandInfoFor!S;
    enum Param = Info.positionalArgs[0];
    S s;
    assert(ArgBinder!().bind!Param("hello", s).isOk);
    assert(s.str == "hello");
}

@Binder
ResultOf!T binderTo(T)(string value)
if(__traits(compiles, to!T(value)))
{
    try return ok(value.to!T);
    catch(ConvException msg) return fail!T(msg.msg);
}
///
unittest
{
    @CommandDefault
    static struct S
    {
        @ArgPositional
        int num;
    }

    alias Info = commandInfoFor!S;
    enum Param = Info.positionalArgs[0];
    S s;
    assert(ArgBinder!().bind!Param("256", s).isOk);
    assert(s.num == 256);
    assert(ArgBinder!().bind!Param("two five six", s).isError);
}

// It's not clear what they are, these validators
private template getValidators(alias ArgSymbol, alias Validator)
{
    alias Udas                  = __traits(getAttributes, ArgSymbol);
    enum isValidator(alias Uda) = __traits(compiles, typeof(Uda)) && hasUDA!(typeof(Uda), Validator);
    alias getValidators         = Filter!(isValidator, Udas);
}

/// Binders must be functions returning ResultOf
private template getBindWith(alias ArgSymbol, Binders...)
{
    alias Udas                  = __traits(getAttributes, ArgSymbol);
    enum isBindWith(alias Uda)  = isInstanceOf!(BindWith, Uda);
    alias Found                 = Filter!(isBindWith, Udas);

    static if(isInstanceOf!(Nullable, typeof(ArgSymbol)))
        alias ArgT = typeof(ArgSymbol.get());
    else
        alias ArgT = typeof(ArgSymbol);

    static assert(Found.length <= 1, "Only one @BindWith may exist.");
    static if(Found.length == 0)
    {
        enum isValidBinder(alias Binder) = 
            __traits(compiles, { ArgT a = Binder!(ArgT)("").value; })
            || __traits(compiles, { ArgT a = Binder("").value; });
        alias ValidBinders = Filter!(isValidBinder, Binders);

        static if(ValidBinders.length)
        {
            static if(__traits(compiles, Instantiate!(ValidBinders[0], ArgT)))
                alias getBindWith = Instantiate!(ValidBinders[0], ArgT);
            else
                alias getBindWith = ValidBinders[0];
        }
        else
            static assert(false, "No binders available for symbol "~__traits(identifier, ArgSymbol)~" of type "~ArgT.stringof);
    }
    else
        alias getBindWith = Found[0].Func;
}