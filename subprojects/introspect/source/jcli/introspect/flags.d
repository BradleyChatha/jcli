module jcli.introspect.flags;

enum ArgConfig : ArgFlags
{
    ///
    none,

    /// If the argument appears multiple times, the last value provided will take effect.
    canRedefine = ArgFlags._canRedefineBit | ArgFlags._multipleBit,

    /// If not given a value, will have its default value and not trigger an error.
    /// Missing (even named) arguments trigger an error by default.
    optional = ArgFlags._optionalBit,

    /// The opposite of optional.
    required = ArgFlags._requiredBit,

    /// The name of the argument is case insensitive.
    /// Aka "--STUFF" will work in place of "--stuff".
    caseInsesitive = ArgFlags._caseInsensitiveBit,

    /// Example: `-a -a` gives 2.
    accumulate = ArgFlags._multipleBit | ArgFlags._countBit,

    /// The type of the field must be an array of some sort.
    /// Example: `-a b -a c` gives an the array ["b", "c"]
    aggregate = ArgFlags._multipleBit | ArgFlags._aggregateBit,

    /// When an argument name is specified multiple times, count how many there are.
    /// Example: `-vvv` gives the count of 3.
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

package(jcli):

enum ArgFlags
{
    ///
    none,

    /// If not given a value, will have its default value and not trigger an error.
    _optionalBit = 1 << 0,

    /// An argument with the same name may appear multiple times.
    @RequiresExactlyOneOf(countBit | canRedefineBit | aggregateBit)
    _multipleBit = 1 << 1,

    /// Allow an argument name to appear without a value.
    @IncompatibleWithAnyOf(_multipleBit)
    @RequiresAllOf(_optionalBit)
    _parseAsFlagBit = 1 << 2,

    /// Implies that the field should get the number of occurences of the argument.
    @RequiresOneOrMoreOf(_mutipleBit | _repeatableNameBit)
    _countBit = 1 << 3,

    /// The name of the argument is case insensitive.
    /// Aka "--STUFF" will work in place of "--stuff".
    _caseInsensitiveBit = 1 << 4,

    /// If the argument appears multiple times, the last value provided will take effect.
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

    /// The opposite of optional. Can usually be inferred.
    @IncompatibleWithAnyOf(_optionalBit | _parseAsFlagBit)
    _requiredBit = 1 << 8,

    /// Whether the required bit or optional bit was given explicitly by the user
    /// or inferred by the system.
    _inferedOptionalityBit = 1 << 9,

    /// Meets the requirements of having their optionality being changed.
    /// This bit is kind of pointless so I will probably remove it.
    @RequiresAllOf(_inferedOptionalityBit)
    _mayChangeOptionalityWithoutBreakingThingsBit = 1 << 10,

    /// Whether is positional. 
    /// On the user side, it is usually provided via UDAs.
    @IncompatibleWithAnyOf(
        _multipleBit
        | _parseAsFlagBit
        | _countBit
        | _canRedefineBit
        | _repeatableNameBit
        | _aggregateBit)
    _positionalArgumentBit = 1 << 11,

    /// Whether is positional. 
    /// On the user side, it is usually provided via UDAs.
    @IncompatibleWithAnyOf(_positionalBit)
    _namedArgumentBit = 1 << 12,

    /// Whether a field is of struct type, containing subfields, which are also arguments.
    /// This means all fields of that nested struct are to be considered arguments, if marked as such.
    /// I could force the user to 
    // _nestedStructBit = 1 << 13,
}

bool areArgumentFlagsValid(ArgFlags flags)
{
    // for not just call into get message, but this can be optimized a little bit later.
    return getArgumentFlagsValidationMessage(flags) is null;
}

string getArgumentFlagsValidationMessage(ArgFlags flags)
{
    import std.bitmanip : bitsSet;        
    import std.conv : to;

    alias ArgFlagsInfo = _ArgFlagsInfo!();
    
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

private template _ArgFlagsInfo()
{
    immutable ArgFlags[argFlagCount] incompatible        = getFlagsInfo!IncompatibleWithAnyOf;
    immutable ArgFlags[argFlagCount] requiresAll         = getFlagsInfo!RequiresAllOf;
    immutable ArgFlags[argFlagCount] requiresExactlyOne  = getFlagsInfo!RequiresExactlyOneOf;
    immutable ArgFlags[argFlagCount] requiresOneOrMore   = getFlagsInfo!RequiresOneOrMoreOf;

    enum argFlagCount = 
    (){
        import std.bitmanip : bitsSet;
        import std.algorithm;
        import std.range;
        return ArgFlags.max.bitsSet.array[$ - 1] + 1;
    }();

    ArgFlags[argFlagCount] getFlagsInfo(TUDA)()
    {
        ArgFlags[argFlagCount] result;

        import std.bitmanip : bitsSet; 
        static foreach (enumMember; __traits(allMembers, ArgFlags))
        {{
            size_t index = __traits(getMember, ArgFlags, enumMember).bitsSet.front;
            static foreach (uda; __traits(getAttributes, enumMember))
            {
                static if (is(typeof(uda) == TUDA))
                {
                    result[index] = uda.value;
                }
            }
        }}

        return result;
    }
}
