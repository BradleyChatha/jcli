module jcli.introspect.data;

import jcli.core;

enum ArgFlags
{
    ///
    none,

    ///
    _optionalBit = 1 << 0,

    /// An argument with the same name may appear multiple times.
    _multipleBit = 1 << 1,

    ///
    _parseAsFlagBit = 1 << 2,

    /// Implies that the field should get the number of occurences of the argument.
    _countBit = 1 << 3,

    /// The name of the argument is case insensitive.
    /// Aka "--STUFF" will work in place of "--stuff".
    _caseInsensitiveBit = 1 << 4,
    
    /// If the argument appears multiple times, 
    /// the last value provided will take effect.
    _canRedefineBit = 1 << 5,

    /// When an argument name is specified multiple times, count how many there are.
    /// Example: `-vvv` gives the count of 3.
    _repeatableNameBit = 1 << 6,

    /// Put all matched values in an array. 
    _aggregateBit = 1 << 7,

    ///
    canRedefine = _canRedefineBit | _multipleBit,

    /// If not given a value, will have its default value and not trigger an error.
    /// Missing (even named) arguments trigger an error by default.
    optional = _optionalBit,

    ///
    caseInsesitive = _caseInsensitiveBit,

    /// Example: `-a -a` gives 2.
    accumulate = _multipleBit | _countBit,

    /// The type of the field must be an array of some sort.
    /// Example: `-a b -a c` gives an the array ["b", "c"]
    aggregate = _multipleBit | _aggregateBit,

    ///
    repeatableName = _repeatableNameBit | _countBit,

    /// Allow an argument name to appear without a value.
    /// Example: `--flag` would parse as `true`.
    parseAsFlag = _parseAsFlagBit | _optionalBit,
}

package (jcli)
{
    bool doesNotHave(ArgFlags a, ArgFlags b)
    {
        return (a & b) != b;
    }
    bool has(ArgFlags a, ArgFlags b)
    {
        return (a & b) == b;
    }
    bool hasEither(ArgFlags a, ArgFlags b)
    {
        return (a & b) != 0;
    }
}

struct CommandInfo(CommandT_)
{
    alias CommandT = CommandT_;

    Pattern pattern;
    string  description;
    bool    isDefault;

    ArgIntrospect!(ArgPositional, CommandT)[]   positionalArgs;
    ArgIntrospect!(ArgNamed, CommandT)[]        namedArgs;
    ArgIntrospect!(ArgRaw, CommandT)            rawArg;
    ArgIntrospect!(ArgOverflow, CommandT)       overflowArg;
}

struct ArgIntrospect(UDA_, CommandT_)
{
    alias UDA = UDA_;
    alias CommandT = CommandT_;

    string identifier;
    UDA uda;
    ArgConfig flags;
    ArgGroup group;
}

template getArgSymbol(alias ArgIntrospectT)
{
    mixin("alias getArgSymbol = ArgIntrospectT.CommandT."~ArgIntrospectT.identifier~";");
}

///
unittest
{
    import jcli.introspect.gather;

    @CommandDefault()
    static struct T
    {
        @ArgPositional
        int a;
    }

    T t = T(360);
    enum Info = commandInfoFor!T();
    assert(getArg!(Info.positionalArgs[0])(t) == 360);
    
    static assert(__traits(identifier, getArgSymbol!(Info.positionalArgs[0])) == "a");
}