module jcli.core.flags;

enum ArgConfig : ArgFlags
{
    ///
    none,

    /// If the argument appears multiple times, the last value provided will take effect.
    canRedefine = ArgFlags._canRedefineBit | ArgFlags._multipleBit | ArgFlags._namedArgumentBit,

    /// If not given a value, will have its default value and not trigger an error.
    /// Missing (even named) arguments trigger an error by default.
    optional = ArgFlags._optionalBit,

    /// The opposite of optional.
    required = ArgFlags._requiredBit,

    /// The name of the argument is case insensitive.
    /// Aka "--STUFF" will work in place of "--stuff".
    caseInsensitive = ArgFlags._caseInsensitiveBit,

    /// Example: `-a -a` gives 2.
    accumulate = ArgFlags._multipleBit | ArgFlags._countBit | ArgFlags._namedArgumentBit,

    /// The type of the field must be an array of some sort.
    /// Example: `-a b -a c` gives an the array ["b", "c"]
    aggregate = ArgFlags._multipleBit | ArgFlags._aggregateBit | ArgFlags._namedArgumentBit,

    /// When an argument name is specified multiple times, count how many there are.
    /// Example: `-vvv` gives the count of 3.
    repeatableName = ArgFlags._repeatableNameBit | ArgFlags._countBit | ArgFlags._namedArgumentBit,

    /// Allow an argument name to appear without a value.
    /// Example: `--flag` would parse as `true`.
    parseAsFlag = ArgFlags._parseAsFlagBit | ArgFlags._optionalBit | ArgFlags._namedArgumentBit,

    /// Can be used instead of ArgPositional UDA.
    positional = ArgFlags._positionalArgumentBit,

    /// Can be used instead of ArgNamed UDA.
    named = ArgFlags._namedArgumentBit,
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
        int value;
    }

    /// Shows which other flags a feature is requred to be accompanied with.
    struct RequiresOneOrMoreOf
    {
        int value;
    }

    /// Shows which flags a feature requres exactly one of.
    struct RequiresExactlyOneOf
    {
        int value;
    }

    /// Shows which other flags a feature is requres with.
    struct RequiresAllOf
    {
        int value;
    }
}

package(jcli):

// HACK: DMD-FE v2.102.2 has introduced/fixed a circular dependency bug, and we're being hit by it.
//       So to compensate we store the values of `ArgFlags` in untyped enum members.
enum : int
{
    _optionalBit_Hack = 1 << 0,
    _multipleBit_Hack = 1 << 1,
    _parseAsFlagBit_Hack = 1 << 2,
    _countBit_Hack = 1 << 3,
    _caseInsensitiveBit_Hack = 1 << 4,
    _canRedefineBit_Hack = 1 << 5,
    _repeatableNameBit_Hack = 1 << 6,
    _aggregateBit_Hack = 1 << 7,
    _requiredBit_Hack = 1 << 8,
    _inferedOptionalityBit_Hack = 1 << 9,
    _mayChangeOptionalityWithoutBreakingThingsBit_Hack = 1 << 10,
    _positionalArgumentBit_Hack = 1 << 11,
    _namedArgumentBit_Hack = 1 << 12,
}

enum ArgFlags
{
    ///
    none,

    /// If not given a value, will have its default value and not trigger an error.
    _optionalBit = _optionalBit_Hack,

    /// An argument with the same name may appear multiple times.
    @RequiresExactlyOneOf(_countBit_Hack | _canRedefineBit_Hack | _aggregateBit_Hack)
    _multipleBit = _multipleBit_Hack,

    /// Allow an argument name to appear without a value.
    @IncompatibleWithAnyOf(_multipleBit_Hack)
    @RequiresAllOf(_optionalBit_Hack)
    _parseAsFlagBit = _parseAsFlagBit_Hack,

    /// Implies that the field should get the number of occurences of the argument.
    @RequiresOneOrMoreOf(_multipleBit_Hack | _repeatableNameBit_Hack)
    _countBit = _countBit_Hack,

    /// The name of the argument is case insensitive.
    /// Aka "--STUFF" will work in place of "--stuff".
    _caseInsensitiveBit = _caseInsensitiveBit_Hack,

    /// If the argument appears multiple times, the last value provided will take effect.
    @IncompatibleWithAnyOf(_countBit_Hack)
    @RequiresAllOf(_multipleBit_Hack)
    _canRedefineBit = _canRedefineBit_Hack,

    /// When an argument name is specified multiple times, count how many there are.
    /// Example: `-vvv` gives the count of 3.
    @IncompatibleWithAnyOf(_parseAsFlagBit_Hack | _canRedefineBit_Hack)
    @RequiresAllOf(_countBit_Hack)
    _repeatableNameBit = _repeatableNameBit_Hack,

    /// Put all matched values in an array. 
    @IncompatibleWithAnyOf(_parseAsFlagBit_Hack | _countBit_Hack | _canRedefineBit_Hack)
    _aggregateBit = _aggregateBit_Hack,

    /// The opposite of optional. Can usually be inferred.
    @IncompatibleWithAnyOf(_optionalBit_Hack | _parseAsFlagBit_Hack)
    _requiredBit = _requiredBit_Hack,

    /// Whether the required bit or optional bit was given explicitly by the user
    /// or inferred by the system.
    _inferedOptionalityBit = _inferedOptionalityBit_Hack,

    /// Meets the requirements of having their optionality being changed.
    /// This bit is kind of pointless so I will probably remove it.
    @RequiresAllOf(_inferedOptionalityBit_Hack)
    _mayChangeOptionalityWithoutBreakingThingsBit = _mayChangeOptionalityWithoutBreakingThingsBit_Hack,

    /// Whether is positional. 
    /// On the user side, it is usually provided via UDAs.
    @IncompatibleWithAnyOf(
        _multipleBit_Hack
        | _parseAsFlagBit_Hack
        | _countBit_Hack
        | _canRedefineBit_Hack
        | _repeatableNameBit_Hack
        | _aggregateBit_Hack)
    _positionalArgumentBit = _positionalArgumentBit_Hack,

    /// Whether is positional. 
    /// On the user side, it is usually provided via UDAs.
    @IncompatibleWithAnyOf(_positionalArgumentBit_Hack)
    _namedArgumentBit = _namedArgumentBit_Hack,

    /// Whether a field is of struct type, containing subfields, which are also arguments.
    /// This means all fields of that nested struct are to be considered arguments, if marked as such.
    /// I could force the user to 
    // _nestedStructBit = 1 << 13,
}

bool areArgumentFlagsValid(ArgFlags flags) pure @safe
{
    // for not just call into get message, but this can be optimized a little bit later.
    return getArgumentFlagsValidationMessage(flags) is null;
}

// string toFlagsString(ArgFlags flags) pure @safe
// {
//     return jcli.core.utils.toFlagsString(flags);
// }

alias ArgFlagsInfo = _ArgFlagsInfo!(ArgFlags);

import jcli.core.utils : toFlagsString;
import std.bitmanip : bitsSet;        
import std.conv : to;

string getArgumentFlagsValidationMessage(ArgFlags flags) pure @safe
{
    foreach (size_t index; bitsSet(flags))
    {
        const currentFlag = cast(ArgFlags)(1 << index);
        {
            const f = ArgFlagsInfo.incompatible[index];
            if (flags.hasEither(f))
            {
                return "The flag " ~ currentFlag.toFlagsString ~ " is incompatible with " ~ f.toFlagsString;
            }
        }
        {
            const f = ArgFlagsInfo.requiresAll[index];
            if (flags.doesNotHave(f))
            {
                return "The flag " ~ currentFlag.toFlagsString ~ " requires all of " ~ f.toFlagsString;
            }
        }
        {
            const f = ArgFlagsInfo.requiresOneOrMore[index];
            if (f != 0 && flags.doesNotHaveEither(f))
            {
                return "The flag " ~ currentFlag.toFlagsString ~ " requires one or more of " ~ f.toFlagsString;
            }
        }
        {
            const f = ArgFlagsInfo.requiresExactlyOne[index];
            if (f != 0)
            {
                auto matches = flags & f;

                import std.range : walkLength;
                auto numMatches = bitsSet(matches).walkLength;

                if (numMatches != 1)
                {
                    return "The flag " ~ currentFlag.toFlagsString ~ " requires exactly one of " ~ f.toFlagsString
                        ~ ". Were matched all of the following: " ~ matches.toFlagsString;
                }
            }
        }
    }

    return null;
}

/// Returns the validation message that describes in what way
/// any pairs of flags were incompatible.
/// We only do compile-time assertions, which is why this function 
/// just concatenates strings to return the error message (basically, it shouldn't matter).
string getArgumentConfigFlagsIncompatibilityValidationMessage(ArgConfig[] flagsToTest)
{
    foreach (index, f1; flagsToTest)
    {
        foreach (f2; flagsToTest[index + 1 .. $])
        {
            if (f1 == f2)
                continue;

            foreach (bitIndex; bitsSet(f1))
            {
                auto incompatibleForThisBit = ArgFlagsInfo.incompatible[bitIndex];

                if (incompatibleForThisBit & f1)
                {
                    return "The high-level config flag " ~ f1.to!string
                        ~ " is invalid, the low level parts are incompatible. The bit "
                        ~ (cast(ArgFlags)(1 << bitIndex)).to!string
                        ~ " is incompatible with " ~ incompatibleForThisBit.toFlagsString;
                }

                auto problematicFlags = cast(ArgFlags) (incompatibleForThisBit & f2);
                if (problematicFlags)
                {
                    return "The high-level config flag " ~ f1.to!string
                        ~ " is incompatible with " ~ f2.to!string
                        ~ ". The problematic flags are " ~ problematicFlags.toFlagsString;
                }
            }
        }
    }
    return null;
}

enum CommandFlags
{
    none = 0,

    /// No command attribute was found.
    noCommandAttribute = 1 << 0,

    /// The command attribute was deduced from its simple form, aka @("description").
    stringAttribute = 1 << 1,

    /// The command was set from a Command or CommandDefault attribute
    commandAttribute = 1 << 2,

    /// e.g. @Command("ab", "cd") instead of @Command.
    givenValue = 1 << 3,

    ///
    explicitlyDefault = 1 << 4,
}

import jcli.core.utils : FlagsHelpers;
mixin FlagsHelpers!ArgFlags;
mixin FlagsHelpers!CommandFlags;

@safe nothrow @nogc pure const
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



private template _ArgFlagsInfo(Flags)
{
    immutable Flags[argFlagCount] incompatible        = getFlagsInfo!IncompatibleWithAnyOf;
    immutable Flags[argFlagCount] requiresAll         = getFlagsInfo!RequiresAllOf;
    immutable Flags[argFlagCount] requiresExactlyOne  = getFlagsInfo!RequiresExactlyOneOf;
    immutable Flags[argFlagCount] requiresOneOrMore   = getFlagsInfo!RequiresOneOrMoreOf;

    enum argFlagCount = 
    (){
        import std.algorithm;
        import std.range;
        return Flags.max.bitsSet.array[$ - 1] + 1;
    }();

    Flags[argFlagCount] getFlagsInfo(TUDA)()
    {
        Flags[argFlagCount] result;

        static foreach (memberName; __traits(allMembers, Flags))
        {{
            size_t index = __traits(getMember, Flags, memberName).bitsSet.front;
            static foreach (uda; __traits(getAttributes, __traits(getMember, Flags, memberName)))
            {
                static if (is(typeof(uda) == TUDA))
                {
                    result[index] = cast(Flags)uda.value;
                }
            }
        }}

        return result;
    }
}
