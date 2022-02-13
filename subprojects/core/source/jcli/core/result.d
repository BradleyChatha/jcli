module jcli.core.result;


struct ResultOf(alias T)
{
    import std.typecons : Nullable;

    enum IsVoid = is(T == void);
    alias This = typeof(this);

    private
    {
        string _error = "I've not been initialised.";
        int _errorCode;
        static if(!IsVoid)
            T _value;
    }

    static if(IsVoid)
    {
        static This ok()()
        {
            This t;
            t._error = null;
            return t;
        }
    }
    else
    {
        static This ok()(T value)
        {
            This t;
            t._error = null;
            t._value = value;
            return t;
        }
    }

    static This fail()(string error, int errorCode = -1)
    {
        This t;
        t._error = error;
        t._errorCode = errorCode;
        return t;
    }

    static if(!is(T == void) && is(T : Nullable!DataT, DataT))
    void opAssign(inout ResultOf!DataT notNullResult)
    {
        this._error = notNullResult._error;
        this._errorCode = notNullResult._errorCode;
        this._value = notNullResult._value;
    }

    inout:

    bool isOk()()
    {
        return this._error is null;
    }

    bool isError()()
    {
        return this._error !is null;
    }

    string error()()
    {
        assert(!this.isOk, "Cannot call .error on an ok result. Please use .isOk to check.");
        return this._error;
    }

    int errorCode()()
    {
        assert(!this.isOk, "Cannot call .errorCode on an ok result.");
        return this._errorCode;
    }

    static if(!IsVoid)
    inout(T) value()() inout
    {
        assert(this.isOk, "Cannot call .value on a failed result. Please use .isOk to check.");
        return this._value;
    }

    void enforceOk()()
    {
        if(!this.isOk)
            throw new ResultException(this.error, this.errorCode);
    }
}
///
unittest
{
    auto ok     = ResultOf!int.ok(1);
    auto fail   = ResultOf!int.fail("Bad", 200);
    auto init   = ResultOf!int.init;
    auto void_  = Result.ok();

    assert(ok.isOk);
    assert(ok.value == 1);

    assert(!fail.isOk);
    assert(fail.error == "Bad");
    assert(fail.errorCode == 200);

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

auto fail(T)(string error, int errorCode = -1)
{
    return ResultOf!T.fail(error, errorCode);
}

class ResultException : Exception
{
    const(int) errorCode;

    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        this.errorCode = -1;
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, int errorCode, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        this.errorCode = errorCode;
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        this.errorCode = -1;
        super(msg, file, line, nextInChain);
    }
}