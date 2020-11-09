module jaster.cli.result;

import std.format : format;
import std.meta   : AliasSeq;

/++
 + A basic result object use by various parts of JCLI.
 +
 + Params:
 +  T = The type that is returned by this result object.
 + ++/
struct Result(T)
{
    // Can't use Algebraic as it's not nothrow, @nogc, and @safe.
    // Not using a proper union as to simplify attribute stuff.
    // Using an enum instead of `TypeInfo` as Object.opEquals has no attributes.
    // All functions are templated to allow them to infer certain annoying attributes (e.g. for types that have a postblit).
    static struct Success { static if(!is(T == void)) T value; }
    static struct Failure { string error; }

    private enum Type
    {
        ERROR,
        Success,
        Failure
    }
    private enum TypeToEnum(alias ResultType) = mixin("Type.%s".format(__traits(identifier, ResultType)));
    private enum TypeToUnionAccess(alias ResultType) = "this._value.%s_".format(__traits(identifier, ResultType));

    private static struct ResultUnion
    {
        Success Success_;
        Failure Failure_;
    }

    private Type _type;
    private ResultUnion _value;

    static foreach(ResultType; AliasSeq!(Success, Failure))
    {
        ///
        this()(ResultType value)
        {
            this._type = TypeToEnum!ResultType;
            mixin(TypeToUnionAccess!ResultType ~ " = value;");
        }

        mixin("alias is%s = isType!(%s);".format(__traits(identifier, ResultType), __traits(identifier, ResultType)));
        mixin("alias as%s = asType!(%s);".format(__traits(identifier, ResultType), __traits(identifier, ResultType)));
    }
    
    ///
    bool isType(ResultType)()
    {
        return this._type == TypeToEnum!ResultType;
    }

    ///
    ResultType asType(ResultType)()
    {
        return mixin(TypeToUnionAccess!ResultType);
    }

    /// Constructs a successful result, returning the given value.
    static Result!T success()(T value){ return typeof(this)(Success(value)); }

    /// Constructs a failure result, returning the given error.
    static Result!T failure()(string error){ return typeof(this)(Failure(error)); }
}