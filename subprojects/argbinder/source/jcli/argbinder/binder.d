module jcli.argbinder.binder;

import jcli.introspect, jcli.core, std;

struct Binder {}
struct BindWith(alias Func_){ alias Func = Func_; }
struct PreValidator {}
struct PostValidator {}

abstract class ArgBinder(Modules...)
{
    alias ToBinder(alias M) = getSymbolsByUDA!(M, Binder);
    alias Binders           = staticMap!(ToBinder, AliasSeq!(Modules, jcli.argbinder.binder));

    static Result bind(alias ArgIntrospectT)(string str, ref ArgIntrospectT.CommandT command)
    {
        alias ArgSymbol         = getArgSymbol!ArgIntrospectT;
        alias PreValidators     = getValidators!(ArgSymbol, PreValidator);
        alias PostValidators    = getValidators!(ArgSymbol, PostValidator);
        alias BindWith          = getBindWith!(ArgSymbol, Binders);

        static foreach(v; PreValidators)
        {{
            const result = v.preValidate(str);
            if(!result.isOk)
                return fail!void(result.error);
        }}

        auto result = BindWith(str);
        if(!result.isOk)
            return fail!void(result.error);
        getArg!ArgIntrospectT(command) = result.value;

        static foreach(v; PostValidators)
        {{
            const res = v.postValidate(getArg!ArgIntrospectT(command));
            if(!res.isOk)
                return fail!void(res.error);
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
ResultOf!T binderNumber(T)(string value)
if(isNumeric!T)
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
    assert(!ArgBinder!().bind!Param("two five six", s).isOk);
}

@Binder
ResultOf!bool binderBool(string value)
{
    try return ok(value.to!bool);
    catch(ConvException msg) return fail!bool(msg.msg);
}

private template getValidators(alias ArgSymbol, alias Validator)
{
    alias Udas                  = __traits(getAttributes, ArgSymbol);
    enum isValidator(alias Uda) = __traits(compiles, typeof(Uda)) && hasUDA!(typeof(Uda), Validator);
    alias getValidators         = Filter!(isValidator, Udas);
}

private template getBindWith(alias ArgSymbol, Binders...)
{
    alias Udas                  = __traits(getAttributes, ArgSymbol);
    enum isBindWith(alias Uda)  = isInstanceOf!(BindWith, Uda);
    alias Found                 = Filter!(isBindWith, Udas);

    static assert(Found.length <= 1, "Only one @BindWith may exist.");
    static if(Found.length == 0)
    {
        enum isValidBinder(alias Binder) = 
            __traits(compiles, { typeof(ArgSymbol) a = Binder!(typeof(ArgSymbol))("").value; })
            || __traits(compiles, { typeof(ArgSymbol) a = Binder("").value; });
        alias ValidBinders = Filter!(isValidBinder, Binders);

        static if(ValidBinders.length)
        {
            static if(__traits(compiles, Instantiate!(ValidBinders[0], typeof(ArgSymbol))))
                alias getBindWith = Instantiate!(ValidBinders[0], typeof(ArgSymbol));
            else
                alias getBindWith = ValidBinders[0];
        }
        else
            static assert(false, "No binders available for symbol "~__traits(identifier, ArgSymbol)~" of type "~typeof(ArgSymbol).stringof);
    }
    else
        alias getBindWith = Found[0].Func;
}