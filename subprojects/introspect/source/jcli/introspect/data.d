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
    static foreach (field; TCommand.tupleof)
        static assert(countUDAsOf!(field, ArgNamed, ArgPositional, ArgOverflow, ArgRaw).length <= 1);

    alias CommandT = TCommand;

    immutable CommandGeneralInfo       general          = getCommandGeneralInfoOf!TCommand;
    immutable NamedArgumentInfo[]      namedArgs        = [ argumentInfosOf!ArgNamed ];
    immutable PositionalArgumentInfo[] positionalArgs   = [ argumentInfosOf!PositionalArgumentInfo ];

    enum takesOverflowArgs = is(typeof(fieldWithUDAOf!ArgOverflow));
    static if (takesOverflowArgs)
        immutable ArgumentCommonInfo overflowArg = getCommonArgumentInfo!(fieldWithUDAOf!ArgOverflow);

    enum takesRawArgs = is(typeof(fieldWithUDAOf!ArgRaw));
    static if (takesRawArgs)
        immutable ArgumentCommonInfo rawArg = getCommonArgumentInfo!(fieldWithUDAOf!ArgRaw);
}

/// TODO: maybe??
string getArgumentFlagsValidationMessage(ArgFlags flags)
{
    string[] ret;
    with (ArgFlags)
    {
        immutable leftAlwaysPairsWithRight = [
            [_parseAsFlagBit, _optionalBit],
            [_canRedefineBit, _multipleBit],
            [_repeatableNameBit, _countBit],
            [_aggregateBit, _multipleBit],
        ];

        // immutable cannotGoWithEither = [
        //     [_multipleBit, _parseAsFlagBit], // probably
        //     [_countBit, _aggregateBit, 
        //     _caseInsensitiveBit
        //     _canRedefineBit
        //     _repeatableNameBit
        //     _aggregateBit

        //     [_countBit, _parseAsFlagBit, _canRedefineBit, _aggregateBit],
        //     [_aggregateBit, _parseAsFlagBit, _repeatableNameBit],
        //     [_canRedefineBit, 
        // ];

        if (flags.has(aggregate) && flags.has(parseAsFlag))
        {
            ret ~= "`aggregate` cannot be used together with `parseAsFlag`";
        }
    }
    return null;
}

ArgumentCommonInfo getCommonArgumentInfo(T, alias field)() pure
{
    ArgumentCommonInfo result;
    ArgFlags[] recordedFlags = [];
    
    static foreach (uda; __traits(getAttributes, field))
    {
        static if (is(typeof(uda) == ArgFlags))
        {
            recordedFlags ~= uda;
        }
        else static if (is(typeof(uda) == ArgGroup))
        {
            static assert(!is(typeof(group)), "Only one Group attribute is allowed per field.");
            ArgGroup group = uda;
        }
    }

    // TODO: validate flags
    foreach (flag; flags)
        result.flags |= flag;

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
        static if (is(uda == UDAType) || is(typeof(uda) == UDAType))
        {
            static assert(!is(typeof(uda1)),
                "Only one `" ~ __traits(identifier, UDAType) ~ "` attribute is allowed per field.");

            static if (is(uda == UDAType))
            {
                auto uda1 = UDAType([__traits(identifier, field)], "");
            }
            else static if (is(typeof(uda) == UDAType))
            {
                auto uda1 = uda;
            }
        }
    }
    static assert(is(typeof(uda1)), "`" ~ UDAType.stringof ~ "` attribute not found.");
    result.uda = uda1;
    return result;
}

private template commandUDAOf(Type)
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
    alias result = AliasSeq!();
    static foreach (field; T.tupleof)
    {
        static foreach (uda; __traits(getAttributes, field))
        {
            static if (is(UDAInfo!uda.Type == UDAType))
            {
                result = AliasSeq!(result, field);
            }
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
    import std.meta : Alias;
    alias countUDAsOf = Alias!(0);
    static foreach (UDAType; UDATypes)
    {
        static foreach (uda; __traits(getAttributes, something))
        {
            static if (is(UDAInfo!uda.Type == UDAType))
                countUDAsOf = Alias!(countUDAsOf + 1);
        }
    }
}

template hasExactlyOneOfUDAs(alias something, UDATypes...)
{
    enum hasExactlyOneOfUDAs = countUDAsOf!(something, UDATypes) == 1;
}

private template staticMap(alias Template, things...)
{
    import std.traits : AliasSeq;
    alias staticMap = AliasSeq!();
    static foreach (thing; things)
        staticMap = AliasSeq!(staticMap, F!thing);
}

private template redirect(alias Template, Args...)
{
    template redirect(Args2...)
    {
        alias redirect = Template!(Args, Args2);
    }
}

private alias argumentInfosOf(TCommand, UDAType) = staticMap!(
    redirect!(getArgumentInfo, UDAType),
    fieldsWithUDAOf!(TCommand, UDAType));

