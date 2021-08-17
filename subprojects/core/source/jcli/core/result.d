module jcli.core.result;

struct ResultOf(alias T)
{
    enum IsVoid = is(T == void);
    alias This = typeof(this);

    private
    {
        string _error = "I've not been initialised.";
        static if(!IsVoid)
            T _value;
    }

    static if(IsVoid)
    {
        @safe @nogc
        static This ok() nothrow pure
        {
            This t;
            t._error = null;
            return t;
        }
    }
    else
    {
        @safe @nogc
        static This ok(T value) nothrow pure
        {
            This t;
            t._error = null;
            t._value = value;
            return t;
        }
    }

    @safe @nogc
    static This fail(string error) nothrow pure
    {
        This t;
        t._error = error;
        return t;
    }

    @safe @nogc nothrow pure inout:

    bool isOk()
    {
        return this._error is null;
    }

    string error()
    {
        assert(!this.isOk, "Cannot call .error on an ok result. Please use .isOk to check.");
        return this._error;
    }

    static if(!IsVoid)
    inout(T) value() inout
    {
        assert(this.isOk, "Cannot call .value on a failed result. Please use .isOk to check.");
        return this._value;
    }
}
///
unittest
{
    auto ok     = ResultOf!int.ok(1);
    auto fail   = ResultOf!int.fail("Bad");
    auto init   = ResultOf!int.init;
    auto void_  = Result.ok();

    assert(ok.isOk);
    assert(ok.value == 1);

    assert(!fail.isOk);
    assert(fail.error == "Bad");

    assert(!init.isOk);
    assert(init.error);

    assert(void_.isOk);
}

alias Result = ResultOf!void;

auto ok(T)(T value)
{
    return ResultOf!T.ok(value);
}

auto ok()()
{
    return Result.ok();
}

auto fail(T)(string error)
{
    return ResultOf!T.fail(error);
}