module jcli.introspect.data;

import jcli.core;


private
{
    /// Shows which other flags a feature is incompatible with.
    /// The flags should only declare this regarding the flags after them. 
    struct IncompatibleWithAnyOf
    {
        ArgFlags value;
    }

    /// Shows which other flags a feature is requred to be accompanied with.
    struct RequiresOneOrMoreOf
    {
        ArgFlags value;
    }

    /// Shows which flags a feature requres exactly one of.
    struct RequiresExactlyOneOf
    {
        ArgFlags value;
    }

    /// Shows which other flags a feature is requres with.
    struct RequiresAllOf
    {
        ArgFlags value;
    }
}

enum ArgFlags
{
    ///
    none,

    ///
    _optionalBit = 1 << 0,

    /// An argument with the same name may appear multiple times.
    @RequiresExactlyOneOf(countBit | canRedefineBit | aggregateBit)
    _multipleBit = 1 << 1,

    ///
    @IncompatibleWithAnyOf(_multipleBit)
    @RequiresAllOf(_optionalBit)
    _parseAsFlagBit = 1 << 2,

    /// Implies that the field should get the number of occurences of the argument.
    @RequiresOneOrMoreOf(_mutipleBit | _repeatableNameBit)
    _countBit = 1 << 3,

    /// The name of the argument is case insensitive.
    /// Aka "--STUFF" will work in place of "--stuff".
    _caseInsensitiveBit = 1 << 4,

    /// If the argument appears multiple times, 
    /// the last value provided will take effect.
    @IncompatibleWithAnyOf(_countBit)
    @RequiresAllOf(_multipleBit)
    _canRedefineBit = 1 << 5,

    /// When an argument name is specified multiple times, count how many there are.
    /// Example: `-vvv` gives the count of 3.
    @IncompatibleWithAnyOf(_parseAsFlagBit | _canRedefineBit)
    @RequiresAllOf(_countBit)
    _repeatableNameBit = 1 << 6,

    /// Put all matched values in an array. 
    @IncompatibleWithAnyOf(_parseAsFlagBit | _countBit | _canRedefineBit)
    _aggregateBit = 1 << 7,
}

private
{
    enum argFlagCount =
    (){
        size_t counter = 0;
        static foreach (field; __traits(allMembers, ArgFlags))
        {
            if (__traits(getMember, ArgFlags, field) > 0)
            {
                counter++;
            }
        }
        return counter;
    }();


    ArgFlags[argFlagCount] getFlagsInfo(TUDA)()
    {
        ArgFlags[argFlagCount] result;

        import std.bitmanip : bitsSet; 
        static foreach (field; __traits(allMembers, ArgFlags))
        {{
            size_t index = __traits(getMember, ArgFlags, field).bitsSet.front;
            static foreach (uda; __traits(getAttributes, field))
            {
                static if (is(typeof(uda) == TUDA))
                {
                    result[index] = uda.value;
                }
            }
        }}

        return result;
    }

    template _ArgFlagsInfo()
    {
        immutable ArgFlags[argFlagCount] incompatible        = getFlagsInfo!IncompatibleWithAnyOf;
        immutable ArgFlags[argFlagCount] requiresAll         = getFlagsInfo!RequiresAllOf;
        immutable ArgFlags[argFlagCount] requiresExactlyOne  = getFlagsInfo!RequiresExactlyOneOf;
        immutable ArgFlags[argFlagCount] requiresOneOrMore   = getFlagsInfo!RequiresOneOrMoreOf;
    }
    alias ArgFlagsInfo = _ArgFlagsInfo!();


    string getArgumentFlagsValidationMessage(ArgFlags flags)
    {
        import std.bitmanip : bitsSet;        
        import std.conv : to;

        foreach (size_t index; bitsSet(flags))
        {
            const currentFlag = 2 ^^ index;
            {
                const f = ArgFlagsInfo.incompatible[index];
                if (flags.hasEither(f))
                {
                    return "The flag " ~ currentFlag.to!string ~ " is incompatible with " ~ f.to!string;
                }
            }
            {
                const f = ArgFlagsInfo.requiresAll[index];
                if (flags.doesNotHave(f))
                {
                    return "The flag " ~ currentFlag.to!string ~ " requires all of " ~ f.to!string;
                }
            }
            {
                const f = ArgFlagsInfo.requiresOneOrMore[index];
                if (f != 0 && flags.doesNotHaveEither(f))
                {
                    return "The flag " ~ currentFlag.to!string ~ " requires one or more of " ~ f.to!string;
                }
            }
            {
                const f = ArgFlagsInfo.requiresExactlyOne[index];
                if (f != 0)
                {
                    auto matches = currentFlag & f;

                    import std.range : walkLength;
                    auto numMatches = bitsSet(matches).walkLength;

                    if (numMatches != 1)
                    {
                        return "The flag " ~ currentFlag.to!string ~ " requires exactly one of " ~ f.to!string
                            ~ ". Were matched all of the following: " ~ matches.to!string;
                    }
                }
            }
        }

        return null;
    }
}

enum ArgConfig : ArgFlags
{
    ///
    none,

    ///
    canRedefine = ArgFlags._canRedefineBit | ArgFlags._multipleBit,

    /// If not given a value, will have its default value and not trigger an error.
    /// Missing (even named) arguments trigger an error by default.
    optional = ArgFlags._optionalBit,

    ///
    caseInsesitive = ArgFlags._caseInsensitiveBit,

    /// Example: `-a -a` gives 2.
    accumulate = ArgFlags._multipleBit | ArgFlags._countBit,

    /// The type of the field must be an array of some sort.
    /// Example: `-a b -a c` gives an the array ["b", "c"]
    aggregate = ArgFlags._multipleBit | ArgFlags._aggregateBit,

    ///
    repeatableName = ArgFlags._repeatableNameBit | ArgFlags._countBit,

    /// Allow an argument name to appear without a value.
    /// Example: `--flag` would parse as `true`.
    parseAsFlag = ArgFlags._parseAsFlagBit | ArgFlags._optionalBit,
}
unittest
{
    static foreach (name; __traits(allMembers, ArgConfig))
    {{
        ArgConfig flags = __traits(getMember, ArgConfig, name);
        string validation = getArgumentFlagsValidationMessage(flags);
        assert(validation is null);
    }}
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
    bool doesNotHaveEither(ArgFlags a, ArgFlags b)
    {
        return (a & b) == 0;
    }
}

unittest
{
    with (ArgFlags)
    {
        ArgFlags a = _aggregateBit | _caseInsensitiveBit;
        ArgFlags b = _canRedefineBit;
        assert(doesNotHave(a, b));  
        assert(doesNotHave(a, b | _caseInsensitiveBit));  
        assert(has(a, _caseInsensitiveBit));  
        assert(hasEither(a, b | _caseInsensitiveBit));
        assert(hasEither(a, _caseInsensitiveBit)); 
        assert(doesNotHaveEither(a, b));
    }
}

struct CommandGeneralInfo
{
    Command uda;
    string identifier;
    bool isDefault;
}

struct ArgumentCommonInfo
{
    string identifier;
    ArgFlags flags;
    ArgGroup group;
}

struct NamedArgumentInfo
{
    ArgNamed uda;
    ArgumentCommonInfo argument;
}

struct PositionalArgumentInfo
{
    ArgPositional uda;
    ArgumentCommonInfo argument;
}

template CommandInfo(TCommand)
{
    alias CommandT = TCommand;
    immutable CommandInfo general = getCommandGeneralInfoOf!TCommand;
    alias arguments = CommandArgumentsInfo!TCommand;
}

template CommandArgumentsInfo(TCommand)
{
    static foreach (field; TCommand.tupleof)
        static assert(countUDAsOf!(field, ArgNamed, ArgPositional, ArgOverflow, ArgRaw).length <= 1);

    immutable NamedArgumentInfo[]      named      = [ argumentInfosOf!ArgNamed ];
    immutable PositionalArgumentInfo[] positional = [ argumentInfosOf!PositionalArgumentInfo ];

    enum takesOverflow = is(typeof(fieldWithUDAOf!ArgOverflow));
    static if (takesOverflow)
        immutable ArgumentCommonInfo overflow = getCommonArgumentInfo!(fieldWithUDAOf!ArgOverflow);

    enum takesRaw = is(typeof(fieldWithUDAOf!ArgRaw));
    static if (takesRaw)
        immutable ArgumentCommonInfo raw = getCommonArgumentInfo!(fieldWithUDAOf!ArgRaw);
}


private:

ArgumentCommonInfo getCommonArgumentInfo(T, alias field)() pure
{
    import std.conv : to;
    ArgumentCommonInfo result;
    // ArgFlags[] recordedFlags = [];
    
    static foreach (uda; __traits(getAttributes, field))
    {
        static if (is(typeof(uda) == ArgFlags))
        {
            // recordedFlags ~= uda;
            result.flags |= uda;
        }
        else static if (is(typeof(uda) == ArgGroup))
        {
            static assert(!is(typeof(group)), "Only one Group attribute is allowed per field.");
            ArgGroup group = uda;
        }
    }

    {
        auto validationMessage = getArgumentFlagsValidationMessage(result.flags);
        assert(validationMessage is null, validationMessage);
    }

    import std.traits : hasUDA, getUDAs;
    static if (is(typeof(group)))
        result.group = group;
    result.identifier  = __traits(identifier, field);
    return result;
}

UDAType getArgumentInfo(UDAType, alias field)() pure
{
    UDAType result;
    result.argument = getCommonArgumentInfo!(UDAType, field)();

    static foreach (uda; __traits(getAttributes, field))
    {
        static if (is(uda == UDAType))
        {
            auto uda1 = UDAType([__traits(identifier, field)], "");
        }
        else static if (is(typeof(uda) == UDAType))
        {
            auto uda1 = uda;
        }
    }
    result.uda = uda1;
    return result;
}

ArgNamed getSimpleArgumentInfo(alias field)() pure
{
    ArgNamed result;
    result.argument = getCommonArgumentInfo!(ArgNamed, field)();

    import std.traits : getUDAs;
    string description = getUDAs!(field, string)[0];

    result.uda = ArgNamed(__traits(identifier, field), description);
    return result;
}

template commandUDAOf(Type)
{
    static foreach (uda; __traits(getAttributes, Symbol))
    {
        static if (is(Command == UDAInfo!uda.Type))
        {
            enum commandUDAOf = UDAInfo!uda.value;
        }
        static if (is(CommandDefault == UDAInfo!uda.Type))
        {
            enum commandUDAOf = UDAInfo!uda.value;
        }
    }
}

CommandGeneralInfo getGeneralCommandInfoOf(TCommand)() pure
{
    CommandGeneralInfo result;
    static foreach (uda; __traits(getAttributes, field))
    {
        static if (is(typeof(commandUDAOf!TCommand)))
        {
            static assert(!is(typeof(uda1)),
                "Only one Command attribute is allowed per field.");

            static if (is(uda == Command))
            {
                auto uda1 = Command([__traits(identifier, field)], "");
            }
            else static if (is(typeof(uda) == Command))
            {
                auto uda1 = uda;
            }
            else static if (is(uda == CommandDefault))
            {
                auto uda1 = CommandDefault();
            }
            else
            {
                auto uda1 = uda;
            }
        }
    }
    static assert(is(typeof(uda1)), "Command attribute not found.");
    result.isDefault = is(typeof(uda1) == CommandDefault);
    result.uda = uda1;
    result.identifier = __traits(identifier, TCommand);
}

template fieldsWithUDAOf(T, UDAType)
{
    import std.traits : hasUDA;
    alias result = AliasSeq!();
    static foreach (field; T.tupleof)
    {
        static if (hasUDA!(field, UDAType))
        {
            result = AliasSeq!(result, field);
        }
    }
    alias fieldsWithUDAOf = result;
}

template fieldWithUDAOf(T, UDAType)
{
    alias allFields = fieldsWithUDAOf!(T, UDAType);
    static assert(allFields.length == 0);
    alias fieldWithUDAOf = allFields[0];
}

template UDAInfo(alias uda)
{
    static if (is(typeof(uda)))
    {
        alias Type = typeof(uda);
        enum hasDefaultValue = false;
        enum value = uda;
    }
    else static if (is(typeof(uda.init)))
    {
        alias Type = uda;
        enum hasDefaultValue = true;
        enum value = uda.init;
    }
    else
    {
        // Even though calling enums a type is technically wrong.
        alias Type = uda;
    }
}

template countUDAsOf(alias something, UDATypes...)
{
    enum countUDAsOf =
    (){
        size_t result = 0;
        static foreach (UDAType; UDATypes)
        {
            static foreach (uda; __traits(getAttributes, something))
            {
                static if (is(UDAInfo!uda.Type == UDAType))
                    result++;
            }
        }
        return result;
    }();
}

template hasExactlyOneOfUDAs(alias something, UDATypes...)
{
    enum hasExactlyOneOfUDAs = countUDAsOf!(something, UDATypes) == 1;
}

template staticMap(alias Template, things...)
{
    import std.traits : AliasSeq;
    alias staticMap = AliasSeq!();
    static foreach (thing; things)
        staticMap = AliasSeq!(staticMap, F!thing);
}

template redirect(alias Template, Args...)
{
    template redirect(Args2...)
    {
        alias redirect = Template!(Args, Args2);
    }
}

alias argumentInfosOf(TCommand, UDAType) = staticMap!(
    redirect!(getArgumentInfo, UDAType),
    fieldsWithUDAOf!(TCommand, UDAType));


NamedArgumentInfo[] getNamedArgumentInfosOf(TCommand)()
{
    import std.traits : hasUDA;
    NamedArgumentInfo[] result;
    static foreach (field; TCommand.tupleof)
    {
        static if (hasUDA!(field, ArgNamed))
        {
            result ~= getArgumentInfo!(ArgNamed, field);
        }
        else static if (!hasUDA!(field, ArgPositional) && hasUDA!(field, string))
        {
            result ~= getSimpleArgumentInfo!(field);
        }
    }
    return result;
}
