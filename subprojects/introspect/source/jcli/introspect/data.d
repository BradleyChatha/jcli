module jcli.introspect.data;

import jcli.introspect.flags;
import jcli.core;

struct CommandGeneralInfo
{
    Command uda;
    string identifier;
    bool isDefault;
}

struct ArgumentCommonInfo
{
    // TODO: Support nested structs. For now, no such thing.
    // This is currently the name of the field, used to get a reference to that field.
    string identifier;
    ArgFlags flags;
    ArgGroup group;
}

/// Reason: accessing with multiple dots is annoying and prevents easy refactoring.
mixin template ArgumentGetters()
{
    @safe nothrow @nogc pure const
    {
        string description() { return uda.description; }
        string name() { return uda.name; }
        string identifier() { return argument.identifier; }
        ArgFlags flags() { return argument.flags; }
        ArgGroup group() { return argument.group; }
    }
}

struct NamedArgumentInfo
{
    ArgNamed uda;
    ArgumentCommonInfo argument;

    mixin ArgumentGetters;
    inout(Pattern) pattern() @safe nothrow @nogc inout { return uda.pattern; }
}

// It's a good idea to encapsulate this logic here.
// It can be easily modified later when we add nested structs.
template isNameMatch(NamedArgumentInfo namedArgumentInfo)
{
    import std.algorithm;
    /// Takes a name, like the `aa` part of `-aa`.
    /// Tries to match the pattern specified as the template argument.
    bool isNameMatch(string value)
    {
        enum caseInsensitive = flags.has(ArgFlags._caseInsensitiveBit);
        {
            bool noMatches = namedArgumentInfo
                .pattern
                .matches!caseInsensitive(value)
                .empty;
            if (!noMatches)
                return true;
        }
        static if (namedArgumentInfo.flags.has(ArgFlags._repeatableNameBit))
        {
            bool allSame = value.all(value[0]);
            if (!allSame)
                return false;
            bool noMatches = namedArgumentInfo
                .pattern
                .matches!caseInsensitive(value[0])
                .empty;
            return !noMatches;
        }
        else
        {
            return false;
        }
    }
}

struct PositionalArgumentInfo
{
    ArgPositional uda;
    ArgumentCommonInfo argument;

    mixin ArgumentGetters;
}

// private template FieldType(TCommand, string fieldPath)
// {
//     mixin("alias FieldType = typeof(TCommand." ~ fieldPath ~ ");");
// }

/// command.getArgumentFieldRef!argInfo
template getArgumentFieldRef(alias commonArgumentInfoOrFieldPath)
{
    import core.lifetime: forward;
    import std.string : join;

    static if (is(typeof(commonArgumentInfoOrFieldPath) == ArgumentCommonInfo)) 
        enum string fieldPath = info.identifier;
    else
        enum string fieldPath = commonArgumentInfoOrFieldPath;
    
    ref auto getArgumentFieldRef(TCommand)(ref TCommand command)
    {
        import core.lifetime: forward;
        return mixin("command." ~ fieldPath ~ ";");
    }
}

template CommandInfo(TCommand)
{
    alias CommandT = TCommand;
    immutable CommandInfo general = getGeneralCommandInfoOf!TCommand;
    alias Arguments = CommandArgumentsInfo!TCommand;
}

template CommandArgumentsInfo(TCommand)
{
    static foreach (field; TCommand.tupleof)
        static assert(countUDAsOf!(field, ArgNamed, ArgPositional, ArgOverflow, ArgRaw).length <= 1);

    // TODO: 
    // We should have another member here, with the members that are nested structs.
    //
    // Probably say positional arguments are not allowed for nested structs, 
    // because it would be extremely confusing to implement and nobody will probably ever use them.
    //
    // The nested struct can be either named (aka -name.field to give a value to the flag `field`
    // inside that nested struct argument), or flattened (allow to simply do -field).
    //
    // We should create another member which would point to the arguments with the nested types perhaps?
    // We could get the names of the types by accessing the field identifiers?
    // ```
    // immutable NamedArgumentInfo[] nested;
    // ```
    // Then make a helper template that would flatten these for the linear iteration, 
    // for use in the command parser. It really does not need to know about this nesting,
    // since it would always read the arguments linearly, only matching actual qualified names,
    // it does not care where in the struct that field is.
    //
    // But we still do need all the info for e.g. reading arguments from typical config format,
    // where nesting is allowed. Like json or xml. There, the user would write out a nested object
    // instead of assigning the fields individually, which would be kinda hard to implement without
    // the nesting info (you'd have to reget that info from the stored dots in the idetifiers.

    // TODO: 
    // A similar mechanism can be used to get pointers to data received from other commands.
    // This will be useful when nested commands partially match the given arguments.
    // Currently not implemented whatsoever.

    // TODO: These seem to be used only as a compile-time info thing, so these should perhaps be alias seqs.

    /// Includes the simple string usage, which gets converted to an ArgNamed uda.
    immutable NamedArgumentInfo[]      named      = getNamedArgumentInfosOf!TCommand;
    immutable PositionalArgumentInfo[] positional = [ argumentInfosOf!PositionalArgumentInfo ];
    
    import std.algorithm : count;
    immutable size_t numRequiredPositionalArguments = positional.count!(
        p => p.flags.has(ArgFlags._requiredBit));

    enum takesOverflow = is(typeof(fieldWithUDAOf!ArgOverflow));
    static if (takesOverflow)
        immutable ArgumentCommonInfo overflow = getCommonArgumentInfo!(fieldWithUDAOf!ArgOverflow);

    enum takesRaw = is(typeof(fieldWithUDAOf!ArgRaw));
    static if (takesRaw)
        immutable ArgumentCommonInfo raw = getCommonArgumentInfo!(fieldWithUDAOf!ArgRaw);
}

unittest
{
    {
        struct S
        {
            @ArgNamed
            @ArgNamed
            string a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        struct S
        {
            @ArgNamed
            @ArgPositional
            string a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        struct S
        {
            @ArgPositional
            @ArgPositional
            string a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        struct S
        {
            @ArgOverflow
            @ArgOverflow
            string[] a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        struct S
        {
            @ArgOverflow
            @ArgRaw
            string[] a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        struct S
        {
            @ArgOverflow
            string[] a;

            @ArgRaw
            string[] b;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.takesOverflow);
        static assert(Info.overflow.identifier == "a");
        static assert(Info.takesRaw);
        static assert(Info.raw.identifier == "b");
        static assert(Info.named.length == 0);
        static assert(Info.positional.length == 0);
    }
    {
        struct S
        {
            @ArgPositional
            string a;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(!Info.takesOverflow);
        static assert(!Info.takesRaw);
        static assert(Info.positional.length == 1);
        enum positional = Info.positional[0];
        static assert(positional.identifier == "a");
        static assert(positional.name == "a");
    }
    {
        struct S
        {
            @ArgNamed
            string a;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(!Info.takesOverflow);
        static assert(!Info.takesRaw);
        static assert(Info.named.length == 1);
        enum named = Info.named[0];
        static assert(named.identifier == "a");
        static assert(named.name == "a");
    }
    {
        struct S
        {
            @("b")
            string a;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(!Info.takesOverflow);
        static assert(!Info.takesRaw);
        static assert(Info.named.length == 1);
        enum named = Info.named[0];
        static assert(named.identifier == "a");
        static assert(named.name == "a");
        static assert(named.description == "b");
    }
    {
        struct S
        {
            @("b")
            @ArgNamed
            string a;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.named.length == 1);
        enum named = Info.named[0];
        static assert(named.identifier == "a");
        static assert(named.name == "a");

        // The description is not applied here, because 
        // ArgNamed takes precedence over the string.
        // static assert(named.uda.description == "b");
    }
    {
        struct S
        {
            @("b")
            string a = "c";
        }
        alias Info = CommandArgumentsInfo!S;
        Info.named[0].argument.flags.has(ArgFlags._optionalBit);
    }
    {
        struct S
        {
            @ArgNamed
            string a = "c";
        }
        alias Info = CommandArgumentsInfo!S;
        Info.named[0].argument.flags.has(ArgFlags._optionalBit);
    }
    {
        struct S
        {
            @ArgPositional
            @(ArgConfig.optional)
            string a;

            @ArgPositional
            string b;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        struct S
        {
            @ArgPositional
            string a = "c";

            @ArgPositional
            string b;
        }
        // For now does not compile, but it should
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        struct S
        {
            @ArgPositional
            string a;

            @ArgPositional
            string b;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.positional.length == 2);
        {
            enum a = Info.positional[0];
            static assert(a.identifier == "a");
            static assert(a.name == "a");
            static assert(a.flags.doesNotHave(ArgFlags._optionalBit));
        }
        {
            enum b = Info.positional[0];
            static assert(b.identifier == "b");
            static assert(b.name == "b");
            static assert(b.flags.doesNotHave(ArgFlags._optionalBit));
        }
    }
    {
        struct S
        {
            @ArgPositional
            string a;

            @ArgPositional
            string b = "c";
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.positional.length == 2);
        {
            enum a = Info.positional[0];
            static assert(a.identifier == "a");
            static assert(a.name == "a");
            static assert(a.flags.doesNotHave(ArgFlags._optionalBit));
        }
        {
            enum b = Info.positional[1];
            static assert(b.identifier == "b");
            static assert(b.name == "b");
            static assert(b.flags.has(ArgFlags._optionalBit));
        }
    }
    {
        struct S
        {
            @ArgPositional
            @(ArgConfig.parseAsFlag)
            bool a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        struct S
        {
            @ArgNamed
            @(ArgConfig.parseAsFlag)
            bool a;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.named[0].flags.has(ArgFlags._parseAsFlagBit));
    }
    {
        struct S
        {
            @ArgNamed
            @(ArgConfig.parseAsFlag)
            bool a = true;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        // NOTE: 
        // The previous version inferred that flag.
        // I think, inferring it could lead to bugs so I say you should specify it explicitly.
        struct S
        {
            @ArgNamed
            bool a;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.named[0].flags.doesNotHave(ArgFlags._parseAsFlagBit));
    }
    {
        struct S
        {
            @ArgPositional
            bool a;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.named[0].flags.doesNotHave(ArgFlags._parseAsFlagBit));
    }
    {
        struct S
        {
            @ArgNamed
            @(ArgConfig._optionalBit | ArgFlags._requiredBit)
            string a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        struct S
        {
            @ArgNamed
            Nullable!string a;
        }
        alias Info = CommandArgumentsInfo!S;
        alias a = Info.named[0];
        static assert(a.flags.has(ArgFlags._optionalBit | ArgFlags._inferedOptionalityBit));
    }
    {
        struct S
        {
            @ArgPositional
            Nullable!string a;
        }
        alias Info = CommandArgumentsInfo!S;
        alias a = Info.named[0];
        static assert(a.flags.has(ArgFlags._optionalBit | ArgFlags._inferedOptionalityBit));
    }
    {
        struct S
        {
            @ArgPositional
            @(ArgFlags._requiredBit)
            Nullable!string a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        struct S
        {
            @ArgPositional
            Nullable!string a;
            @ArgPositional
            string b;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        struct S
        {
            @ArgPositional
            string a;
            @ArgPositional
            Nullable!string b;
        }
        alias Info = CommandArgumentsInfo!S;
        alias a = Info.named[0];
        static assert(a.flags.has(ArgFlags._requiredBit | ArgFlags._inferedOptionalityBit));
        alias b = Info.named[1];
        static assert(b.flags.has(ArgFlags._optionalBit | ArgFlags._inferedOptionalityBit));
    }
}

private:

ArgumentCommonInfo getCommonArgumentInfo(alias field)(ArgFlags initialFlags) pure
{
    import std.conv : to;
    ArgumentCommonInfo result;
    result.flags = initialFlags;
    // ArgFlags[] recordedFlags = [];
    
    static foreach (uda; __traits(getAttributes, field))
    {
        static if (is(typeof(uda) : ArgFlags))
        {
            // recordedFlags ~= uda;
            static assert(uda.doesNotHaveEither(
                ArgFlags._inferedOptionalityBit, ArgFlags._mayChangeOptionalityWithoutBreakingThingsBit),
                "Specifying the `_inferedOptionalityBit` or `_mayChangeOptionalityWithoutBreakingThingsBit`"
                ~ " in user code is not allowed. The optionality will be inferred automatically by default, if possible.");
            result.flags |= uda;
        }
        else static if (is(typeof(uda) == ArgGroup))
        {
            static assert(!is(typeof(group)), "Only one Group attribute is allowed per field.");
            ArgGroup group = uda;
        }
    }

    // Validate all flags and try to infer optionality.
    with (ArgFlags)
    {
        auto validationMessage = getArgumentFlagsValidationMessage(result.flags);
        assert(validationMessage is null, validationMessage);

        string messageIfAddedOptional = getArgumentFlagsValidationMessage(result.flags | _optionalBit);

        static if (is(typeof(field) : Nullable!T, T))
        {
            assert(messageIfAddedOptional is null,
                "Nullable types must be optional.\n" ~ messageIfAddedOptional);

            if (flags.doesNotHave(_optionalBit))
                flags |= _optionalBit | _inferedOptionalityBit;
        }
        // Note: These two checks are common for both named arguments and positional arguments. 
        else if (result.flag.doesNotHaveEither(_optionalBit | _requiredBit)) // @suppress(dscanner.suspicious.static_if_else)
        {
            string messageIfAddedRequired = getArgumentFlagsValidationMessage(result.flags | _requiredBit);

            if (messageIfAddedOptional is null
                // TODO: 
                // This rudimentary check fails e.g. for the following: 
                // `struct A { int a = 0; }`
                // Aka when the value is given, but is also the default.
                // Guys from the D server say it's probably impossible to do currently.
                && typeof(field).init != field.init)
            {
                result.flags |= _optionalBit;
                if (messageIfAddedRequired is null)
                    result.flags |= _mayChangeOptionalityWithoutBreakingThingsBit;
            }
            else
            {
                assert(messageIfAddedRequired is null,
                    "The type can be neither optional nor required. This check should have never been hit.\n"
                    ~ "If we added required: " ~ messageIfAddedRequired ~ "\n"
                    ~ "If we added optional: " ~ messageIfAddedOptional);

                result.flags |= _requiredBit;
                if (messageIfAddedOptional is null)
                    result.flags |= _mayChangeOptionalityWithoutBreakingThingsBit;
            }
            result.flags |= _inferedOptionalityBit;
        }
    }

    static if (is(typeof(group)))
        result.group = group;
    result.identifier = __traits(identifier, field);
    return result;
}

template getArgumentInfo(UDAType, alias field)
{
    static foreach (uda; __traits(getAttributes, field))
    {
        static if (is(uda == UDAType))
        {
            auto getArgumentInfo() { return UDAType(__traits(identifier, field), ""); }
        }
        else static if (is(typeof(uda) == UDAType))
        {
            auto getArgumentInfo() { return uda; }
        }
    }
}

ArgNamed getSimpleArgumentInfo(alias field)() pure
{
    ArgNamed result;
    result.argument = getCommonArgumentInfo!field(ArgFlags._namedArgumentBit);

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


PositionalArgumentInfo[] getPositionalArgumentInfosOf(TCommand)()
{
    import std.algorithm;
    import std.range;

    // Since this is a static foreach, it will be easy to include type info here.
    PositionalArgumentInfo[] result;
    static foreach (field; fieldsWithUDAOf!(TCommand, ArgPositional))
    {{
        auto t = PositionalArgumentInfo(
            getArgumentInfo!(ArgPositional, field),
            getCommonArgumentInfo!field(ArgFlags._positionalArgumentBit));
        result ~= t;
    }}

    alias isOptional = p => p.flags.has(ArgFlags._optionalBit);
    alias isRequired = p => p.flags.has(ArgFlags._requiredBit);

    // If there is an optional positional argument in between required ones,
    // we change it to positional, if possible. 
    
    int indexOfLastRequired = -1;
    foreach (index, ref p; result)
    {
        if (isRequired(p))
            indexOfLastRequired = cast(int) index;
    }
    if (indexOfLastRequired == -1)
        return result;

    result
        .take(indexOfLastRequired)
        .filter!(isOptional)
        .each!((ref p)
        {
            assert(p.has(ArgFlags._mayChangeOptionalityWithoutBreakingThingsBit), 
                "The positional argument " ~ p.identifer 
                ~ " cannot be optional, because it is in between two positionals.");
            p.flags &= ~ArgFlags._mayChangeOptionalityWithoutBreakingThingsBit;
            p.flags &= ~ArgFlags._optionalBit;
            p.flags |= ArgFlags._requiredBit;
        });

    return result;

    // const notOptionalAfterOptional = positional
    //     // after one that isn't optional,
    //     .find!(p => p.flags.has(ArgFlags._optionalBit))
    //     // there are no optionals.
    //     .find!(isNotOptional);

    // if (!notOptionalAfterOptional.empty)
    // {
    //     string message = "Found the following non-optional positional arguments after an optional argument: ";
        
    //     message ~= notOptionalAfterOptional
    //         .filter!isNotOptional
    //         .map!(p => p.argument.identifier)
    //         .join(", ");

    //     // TODO: Having a default value should imply optionality only after this check.
    //     message ~= ". They must either have a default value and or be marked with the optional attribute.";

    //     assert(false, message);
    // }
}

void inferArgumentFlagsSpecificToNamedArguments(alias field)(ref ArgFlags flags)
{
    with (ArgFlags)
    {
        if (flags.has(_parseAsFlagBit))
        {
            // TODO: maybe allow flags in the future??
            assert(is(typeof(field) == bool),
                "Fields marked `parseAsFlag` must be boolean.");
            assert(field.init == false, 
                "Fields marked `parseAsFlag` must have the default value false.");

            // NOTE: This one should always be covered by the flags validation instead.
            assert(messageIfAddedOptional is null, "Should never be hit!!");
            
            if (flags.doesNotHave(_optionalBit))
                flags |= _optionalBit | _inferedOptionalityBit;
        }
    }
}


NamedArgumentInfo[] getNamedArgumentInfosOf(TCommand)()
{
    import std.traits : hasUDA;
    NamedArgumentInfo[] result;
    static foreach (field; TCommand.tupleof)
    {{
        static if (hasUDA!(field, ArgNamed))
        {
            auto arg = getArgumentInfo!field(ArgFlags._namedArgumentBit);
            inferArgumentFlagsSpecificToNamedArguments!field(arg.flags);
            result ~= arg;
        }
        else static if (!hasUDA!(field, ArgPositional) && hasUDA!(field, string))
        {
            auto arg = getSimpleArgumentInfo!field(ArgFlags._namedArgumentBit);
            inferArgumentFlagsSpecificToNamedArguments!field(arg.flags);
            result ~= arg;
        }
    }}
    return result;
}
