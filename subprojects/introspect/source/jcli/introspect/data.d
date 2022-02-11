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

struct PositionalArgumentInfo
{
    ArgPositional uda;
    ArgumentCommonInfo argument;

    mixin ArgumentGetters;
}

struct ArgIntrospect(BaseInfoType, alias fieldSymbol, string[] _fieldPathParts)
{
    BaseInfoType info;
    alias info this;

    immutable string[] fieldPathParts = _fieldPathParts;
    alias CommandType = __traits(parent, fieldSymbol);
    alias FieldType = typeof(fieldSymbol);

    static assert(fieldPathParts.length > 0);
}

/// command.assignValueToArgument!argInfo(value)

template assignValueToArgument(alias TArgIntrospect)
{
    void assignValueToArgument(
        ref TArgIntrospect.TCommand command,
        auto ref TArgIntrospect.FieldType value)
    {
        import core.lifetime: forward;
        assign!(TArgIntrospect.fieldPathParts)(command, forward!value);
    }
}

private template assign(string[] fieldPathParts)
{
    void assign(T, V)(ref T target, auto ref V value)
    {
        import core.lifetime: forward;

        static if (fieldPathParts.length == 0)
        {
            target = forward!value;
        }
        else
        {
            .assign!(fieldPathParts[1 .. $])(
                __traits(getMember, target, fieldPathParts[0]),
                forward!value
            );
        }
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

    /// Includes the simple string usage, which gets converted to an ArgNamed uda.
    alias /* NamedArgumentInfo[] */      named      = getNamedArgumentInfosOf!TCommand;
    alias /* PositionalArgumentInfo[] */ positional = [ argumentInfosOf!PositionalArgumentInfo ];
    
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
