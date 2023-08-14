module jcli.introspect.data;

import jcli.core;

import std.conv : to;
import std.traits;
import std.meta;

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
    string name() const nothrow @nogc pure @safe { return uda.name; }

    inout nothrow @nogc pure @safe
    {
        ref inout(string) description() return { return uda.description; }
        ref inout(string) identifier() return { return argument.identifier; }
        ref inout(ArgFlags) flags() return { return argument.flags; }
        ref inout(ArgGroup) group() return { return argument.group; }
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
        enum caseInsensitive = namedArgumentInfo.flags.has(ArgFlags._caseInsensitiveBit);
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
            bool allSame = value.all!(a => a == value[0]);
            if (!allSame)
                return false;
            bool noMatches = namedArgumentInfo
                .pattern
                .matches!caseInsensitive(value[0 .. 1])
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


private template fieldPathOf(alias argumentInfoOrFieldPath)
{
    static if (is(Unqual!(typeof(argumentInfoOrFieldPath)) == ArgumentCommonInfo)) 
        enum string fieldPathOf = argumentInfoOrFieldPath.identifier;
    else static if (is(Unqual!(typeof(argumentInfoOrFieldPath.argument)) == ArgumentCommonInfo)) 
        enum string fieldPathOf = argumentInfoOrFieldPath.argument.identifier;
    else static if (is(Unqual!(typeof(argumentInfoOrFieldPath)) == string))
        enum string fieldPathOf = argumentInfoOrFieldPath;
    else
        static assert(false, "Unsupported thing: " ~ Unqual!(typeof(argumentInfoOrFieldPath)).stringof);
}

/// command.getArgumentFieldRef!argInfo
template getArgumentFieldRef(alias argumentInfoOrFieldPath)
{
    ref auto getArgumentFieldRef(TCommand)(ref TCommand command)
    {
        mixin("return command." ~ fieldPathOf!argumentInfoOrFieldPath ~ ";");
    }
}
template getArgumentFieldSymbol(TCommand, alias argumentInfoOrFieldPath)
{
    mixin("alias getArgumentFieldSymbol = TCommand." ~ fieldPathOf!argumentInfoOrFieldPath ~ ";");
}

template getCommandUDAs(CommandType)
{
    alias commandUDAs = AliasSeq!(
        getUDAs!(CommandType, Command),
        getUDAs!(CommandType, CommandDefault));

    static if (commandUDAs.length > 0)
    {
        alias getCommandUDAs = commandUDAs;
    }
    else
    {
        enum isValue(alias stringUDA) = is(typeof(stringUDA) : string);
        alias stringUDAs = Filter!(isValue,
            getUDAs!(CommandType, string));

        static if (stringUDAs.length > 0)
            alias getCommandUDAs = AliasSeq!(stringUDAs[0]);
        else
            alias getCommandUDAs = AliasSeq!();
    }
}


// NOTE:
// It's not clear at all what a good design fot this is.
// I only feel esoteric OOP vibes when deciding whether this should be in a struct,
// template, whether it should be a getter, and enum, immutable, or an alias.
// It feels to me like it's only philosophical at this point.
// So I'm just going to do a single thing and call it a day.
// Whatever I do feels wrong tho.
template CommandInfo(TCommand)
{
    alias CommandType = TCommand;
    alias Arguments = CommandArgumentsInfo!TCommand;

    static assert(
        getCommandUDAs!TCommand.length <= 1,
        "Only one command UDA is allowed.");
    alias commandUDAs = getCommandUDAs!TCommand;

    static if (commandUDAs.length == 0)
    {
        enum flags = CommandFlags.noCommandAttribute;
    }
    else
    {
        alias rawCommandUDA = Alias!(commandUDAs[0]);

        static if (is(typeof(rawCommandUDA) : string))
        {
            enum flags = CommandFlags.stringAttribute | CommandFlags.givenValue;
            enum string udaValue = rawCommandUDA;
        }
        else static if (is(rawCommandUDA == Command))
        {
            enum flags = CommandFlags.commandAttribute;
            immutable udaValue = Command([__traits(identifier, TCommand)], "");
        }
        else static if (is(rawCommandUDA == CommandDefault))
        {
            enum flags = CommandFlags.commandAttribute | CommandFlags.explicitlyDefault;
            immutable udaValue = CommandDefault("");
        }
        else static if (is(typeof(rawCommandUDA) == Command))
        {
            enum flags = CommandFlags.commandAttribute | CommandFlags.givenValue;
            immutable udaValue = rawCommandUDA;
        }
        else static if (is(typeof(rawCommandUDA) == CommandDefault))
        {
            enum flags = CommandFlags.commandAttribute | CommandFlags.givenValue | CommandFlags.explicitlyDefault;
            immutable udaValue = rawCommandUDA;
        }
        else static assert(0);

        // this part is super meh
        static if (flags.has(CommandFlags.stringAttribute))
            enum string description = udaValue;
        else
            enum string description = udaValue.description;
    }
}

template CommandArgumentsInfo(TCommand)
{
    alias CommandType = TCommand;

    static foreach (field; TCommand.tupleof)
        static assert(countUDAsOf!(field, ArgNamed, ArgPositional, ArgOverflow, ArgRaw) <= 1);

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
    immutable PositionalArgumentInfo[] positional = getPositionalArgumentInfosOf!TCommand;

    import std.algorithm;
    enum size_t numRequiredPositionalArguments = positional
        .filter!((immutable p) => p.flags.has(ArgFlags._requiredBit))
        .count;

    private alias fieldsWithOverflow = fieldsWithUDAOf!(TCommand, ArgOverflow);
    static assert(fieldsWithOverflow.length <= 1, "No more than one overflow argument allowed");
    enum takesOverflow = fieldsWithOverflow.length == 1;
    static if (takesOverflow)
        immutable ArgumentCommonInfo overflow = getCommonArgumentInfo!(fieldsWithOverflow[0], ArgConfig.aggregate);

    
    private alias fieldsWithRaw = fieldsWithUDAOf!(TCommand, ArgRaw);
    static assert(fieldsWithRaw.length <= 1, "No more than one raw argument allowed");
    enum takesRaw = fieldsWithRaw.length == 1;
    static if (takesRaw)
        immutable ArgumentCommonInfo raw = getCommonArgumentInfo!(fieldsWithRaw[0], ArgConfig.aggregate);
    
    enum takesSomeArguments = named.length > 0 || positional.length > 0 || takesOverflow || takesRaw;
}

unittest
{
    {
        static struct S
        {
            @ArgNamed
            @ArgNamed
            string a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        static struct S
        {
            @ArgNamed
            @ArgPositional
            string a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        static struct S
        {
            @ArgPositional
            @ArgPositional
            string a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        static struct S
        {
            @ArgOverflow
            @ArgOverflow
            string[] a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        static struct S
        {
            @ArgOverflow
            @ArgRaw
            string[] a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        static struct S
        {
            @ArgOverflow
            string[] a;

            @ArgRaw
            string[] b;
        }
        alias Info = CommandArgumentsInfo!S;
        assert(Info.takesOverflow);
        assert(Info.overflow.identifier == "a");
        assert(Info.takesRaw);
        assert(Info.raw.identifier == "b");
        assert(Info.named.length == 0);
        assert(Info.positional.length == 0);
    }
    {
        static struct S
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
        static assert(positional.flags.has(ArgFlags._positionalArgumentBit));
    }
    {
        static struct S
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
        static assert(named.flags.has(ArgFlags._namedArgumentBit));
    }
    {
        static struct S
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
        static assert(named.flags.has(ArgFlags._namedArgumentBit));
    }
    {
        static struct S
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
        static assert(named.flags.has(ArgFlags._namedArgumentBit));

        // The description is not applied here, because 
        // ArgNamed takes precedence over the string.
        // static assert(named.uda.description == "b");
    }
    {
        static struct S
        {
            @("b")
            string a = "c";
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.named[0].flags.has(ArgFlags._optionalBit));
    }
    {
        static struct S
        {
            @ArgNamed
            string a = "c";
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.named[0].flags.has(ArgFlags._optionalBit));
    }
    {
        static struct S
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
        static struct S
        {
            @ArgPositional
            string a = "c";

            @ArgPositional
            string b;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.positional[0].flags.has(ArgFlags._requiredBit));
        static assert(Info.positional[1].flags.has(ArgFlags._requiredBit));
    }
    {
        static struct S
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
            enum b = Info.positional[1];
            static assert(b.identifier == "b");
            static assert(b.name == "b");
            static assert(b.flags.doesNotHave(ArgFlags._optionalBit));
        }
    }
    {
        static struct S
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
        static struct S
        {
            @ArgPositional
            @(ArgConfig.parseAsFlag)
            bool a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        static struct S
        {
            @ArgNamed
            @(ArgConfig.parseAsFlag)
            bool a;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.named[0].flags.has(ArgFlags._parseAsFlagBit));
    }
    {
        static struct S
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
        static struct S
        {
            @ArgNamed
            bool a;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.named[0].flags.doesNotHave(ArgFlags._parseAsFlagBit));
    }
    {
        static struct S
        {
            @ArgPositional
            bool a;
        }
        alias Info = CommandArgumentsInfo!S;
        static assert(Info.positional[0].flags.doesNotHave(ArgFlags._parseAsFlagBit));
    }
    {
        static struct S
        {
            @ArgNamed
            @(ArgConfig._optionalBit | ArgFlags._requiredBit)
            string a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        static struct S
        {
            @ArgNamed
            Nullable!string a;
        }
        alias Info = CommandArgumentsInfo!S;
        enum a = Info.named[0];
        static assert(a.flags.has(ArgFlags._optionalBit | ArgFlags._inferedOptionalityBit));
    }
    {
        static struct S
        {
            @ArgPositional
            Nullable!string a;
        }
        alias Info = CommandArgumentsInfo!S;
        enum a = Info.positional[0];
        static assert(a.flags.has(ArgFlags._optionalBit | ArgFlags._inferedOptionalityBit));
    }
    {
        static struct S
        {
            @ArgPositional
            @(ArgFlags._requiredBit)
            Nullable!string a;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        static struct S
        {
            @ArgPositional
            Nullable!string a;
            @ArgPositional
            string b;
        }
        static assert(!__traits(compiles, CommandArgumentsInfo!S));
    }
    {
        static struct S
        {
            @ArgPositional
            string a;
            @ArgPositional
            Nullable!string b;
        }
        alias Info = CommandArgumentsInfo!S;
        enum a = Info.positional[0];
        static assert(a.flags.has(ArgFlags._requiredBit | ArgFlags._inferedOptionalityBit));
        enum b = Info.positional[1];
        static assert(b.flags.has(ArgFlags._optionalBit | ArgFlags._inferedOptionalityBit));
    }
    {
        static struct S
        {
            @("Hello")
            @(ArgConfig.positional)
            string a;

            @("World")
            string b;
        }
        alias Info = CommandArgumentsInfo!S;

        enum a = Info.positional[0];
        static assert(a.flags.has(ArgFlags._requiredBit | ArgFlags._inferedOptionalityBit));
        static assert(a.description == "Hello");
        
        enum b = Info.named[0];
        static assert(b.flags.has(ArgFlags._requiredBit | ArgFlags._inferedOptionalityBit));
        static assert(b.description == "World");
    }
}

private:

import std.traits;
import std.meta;

// NOTE:
// Passing the udas as a sequence works, but trying to get them within the function does not.
// Apparently, it may work if we mark the function static, but afaik that's a compiler bug.
// Another NOTE:
// We still need the static here?? wtf?
static ArgFlags foldArgumentFlags(udas...)()
{
    ArgFlags result;
    ArgConfig[] highLevelFlags;

    static foreach (uda; udas)
    {
        static if (is(typeof(uda) == ArgConfig))
        {
            highLevelFlags ~= uda;
        }
        static if (is(typeof(uda) : ArgFlags))
        {
            static assert(uda.doesNotHaveEither(
                ArgFlags._inferedOptionalityBit | ArgFlags._mayChangeOptionalityWithoutBreakingThingsBit),
                "Specifying the `_inferedOptionalityBit` or `_mayChangeOptionalityWithoutBreakingThingsBit`"
                ~ " in user code is not allowed. The optionality will be inferred automatically by default, if possible.");
            result |= uda;
        }
    }

    // Validate only the high level flag combinations.
    {
        string validationMessage = getArgumentConfigFlagsIncompatibilityValidationMessage(highLevelFlags);
        assert(validationMessage is null, validationMessage);
    }

    return result;
}


// This is needed as a workaround for the function below.
// Basically, you cannot access `field.init` or get the attributes
// of a field symbol in a function context.
// template FieldInfo(alias field)
// {
//     alias FieldType = typeof(field);
//     enum FieldType initialValue = field.init;
// }

// This function is needed as a separate entity as a workaround the compiler quirk that makes
// us unable to query attributes of field symbols in templated functions.
// I would've inlined it below, but we're forced to use a template, or pass the arguments as an alias seq. 
ArgFlags inferOptionalityAndValidate(FieldType)(ArgFlags initialFlags, FieldType fieldDefaultValue)
{
    import std.conv : to;
    ArgFlags flags = initialFlags;

    // Validate all flags and try to infer optionality.
    with (ArgFlags)
    {
        auto validationMessage = getArgumentFlagsValidationMessage(flags);
        assert(validationMessage is null, validationMessage);

        string messageIfAddedOptional = getArgumentFlagsValidationMessage(flags | _optionalBit);

        static if (is(FieldType : Nullable!T, T))
        {
            assert(messageIfAddedOptional is null,
                "Nullable types must be optional.\n" ~ messageIfAddedOptional);

            if (flags.doesNotHave(_optionalBit))
                flags |= _optionalBit | _inferedOptionalityBit;
        }
        // Note: These two checks are common for both named arguments and positional arguments. 
        else if (flags.doesNotHaveEither(_optionalBit | _requiredBit)) // @suppress(dscanner.suspicious.static_if_else)
        {
            string messageIfAddedRequired = getArgumentFlagsValidationMessage(flags | _requiredBit);
            // TODO: 
            // This rudimentary check fails e.g. for the following: 
            // `struct A { int a = 0; }`
            // Aka when the value is given, but is also the default.
            // Guys from the D server say it's probably impossible to do currently.
            // NOTE: `is` does bitwise comparison. `!=` would fail for float.nan
            bool canInferOptional = FieldType.init !is fieldDefaultValue;

            if (messageIfAddedOptional is null && canInferOptional)
            {
                flags |= _optionalBit;
                if (messageIfAddedRequired is null)
                    flags |= _mayChangeOptionalityWithoutBreakingThingsBit;
            }
            else
            {
                assert(messageIfAddedRequired is null,
                    "The type can be neither optional nor required. This check should have never been hit.\n"
                    ~ "If we added required: " ~ messageIfAddedRequired ~ "\n"
                    ~ "If we added optional: " ~ messageIfAddedOptional);

                flags |= _requiredBit;
                if (messageIfAddedOptional is null)
                    flags |= _mayChangeOptionalityWithoutBreakingThingsBit;
            }
            flags |= _inferedOptionalityBit;
        }
    }

    return flags;
}

// NOTE: 
// We never pass alias to field even to CTFE functions as template parameters,
// because the compiler essetially prevents their use there.
// Passing to templates is ok, but trying to do anything with them in template functions
// makes the compiler complain.
enum defaultValueOf(alias field) = __traits(child, __traits(parent, field).init, field);

// Gives some basic information associated with the given argument field.
public template getCommonArgumentInfo(alias field, ArgFlags initialFlags = ArgFlags.none)
{
    enum flagsBeforeInference = initialFlags | foldArgumentFlags!(__traits(getAttributes, field));
    enum flagsAfterInference = inferOptionalityAndValidate!(typeof(field))(
        flagsBeforeInference, defaultValueOf!field);
    
    alias groups = getUDAs!(field, ArgGroup);
    static assert(groups.length <= 1, "Only one group attribute is allowed");
    static if (groups.length == 1)
        enum group = groups[0];
    else
        enum group = ArgGroup.init;

    enum identifier = __traits(identifier, field);
    enum getCommonArgumentInfo = ArgumentCommonInfo(identifier, flagsAfterInference, groups);
}

template getArgumentInfo(UDAType, alias field)
{
    static foreach (uda; __traits(getAttributes, field))
    {
        static if (is(uda == UDAType))
        {
            enum getArgumentInfo = UDAType.init;
        }
        else static if (is(typeof(uda) == UDAType))
        {
            enum getArgumentInfo = uda;
        }
    }
}


template fieldsWithUDAOf(T, UDAType)
{
    enum hasThatUDA(alias field) = hasUDA!(field, UDAType);
    alias fieldsWithUDAOf = Filter!(hasThatUDA, T.tupleof);
}
unittest
{
    enum Test;
    static struct S
    {
        @Test string a;
        @Test string b;
        string c;
    }
    alias fields = fieldsWithUDAOf!(S, Test);
    static assert(fields.length == 2);
    static assert(fields[0].stringof == "a");
    static assert(fields[1].stringof == "b");
}

template fieldWithUDAOf(T, UDAType)
{
    alias allFields = fieldsWithUDAOf!(T, UDAType);
    static assert(allFields.length > 0);
    alias fieldWithUDAOf = allFields[0];
}
unittest
{
    enum Test;
    {
        static struct S
        {
            @Test string a;
            string c;
        }
        alias field = fieldWithUDAOf!(S, Test);
        static assert(field.stringof == "a");
    }
    {
        static struct S
        {
            @Test string a;
            @Test string c;
        }
        alias field = fieldWithUDAOf!(S, Test);
        static assert(field.stringof == "a");
    }
    {
        static struct S
        {
            string a;
            string c;
        }
        static assert(!__traits(compiles, fieldWithUDAOf!(S, Test)));
    }
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
unittest
{
    struct Data { int a; }
    enum Enum;
    {
        @Data int b;

        alias Info = UDAInfo!(getUDAs!(b, Data));
        static assert(Info.hasDefaultValue);
        static assert(is(Info.Type == Data));
    }
    {
        @Data(1) int b;

        alias Info = UDAInfo!(getUDAs!(b, Data));
        static assert(!Info.hasDefaultValue);
        static assert(Info.value == Data(1));
        static assert(is(Info.Type == Data));
    }
    {
        @Enum int b;

        alias Info = UDAInfo!(getUDAs!(b, Enum));
        static assert(is(Info.Type == Enum));
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

PositionalArgumentInfo[] getPositionalArgumentInfosOf(TCommand)() pure
{
    import std.algorithm;
    import std.range;

    // Since this is a static foreach, it will be easy to include type info here.
    PositionalArgumentInfo[] result;

    static foreach (field; TCommand.tupleof)
    {{
        enum hasPositionalUDA = hasUDA!(field, ArgPositional);
        // Doing this one is tiny bit costly ...
        enum foldedArgFlags = foldArgumentFlags!(__traits(getAttributes, field));
        enum hasPositionalFlag = foldedArgFlags.has(ArgFlags._positionalArgumentBit);

        static if (hasPositionalUDA)
        {
            auto info = getArgumentInfo!(ArgPositional, field);
            if (info.name == "")
                info.name = __traits(identifier, field);
        }
        else static if (hasPositionalFlag)
        {
            alias stringAttributes = getUDAs!(field, string);

            // TODO: check for string type attribute.
            static if (stringAttributes.length > 0)
                auto info = ArgPositional(__traits(identifier, field), stringAttributes[0]);
            else
                auto info = ArgPositional(__traits(identifier, field), "");
        }

        static if (hasPositionalUDA || hasPositionalFlag)
        {
            result ~= PositionalArgumentInfo(
                info, getCommonArgumentInfo!(field, ArgFlags._positionalArgumentBit));
        }
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
        .each!((ref PositionalArgumentInfo p)
        {
            assert(p.flags.has(ArgFlags._mayChangeOptionalityWithoutBreakingThingsBit), 
                "The positional argument " ~ p.identifier 
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

ArgFlags inferArgumentFlagsSpecificToNamedArguments(FieldType)(ArgFlags flags, FieldType fieldDefaultValue) pure
{
    with (ArgFlags)
    {
        if (flags.has(_parseAsFlagBit))
        {
            static if (is(FieldType == bool) || is(FieldType : Nullable!bool))
            {
                static if (is(FieldType == bool))
                    assert(fieldDefaultValue == false, 
                        "Fields marked `parseAsFlag` must have the default value false.");
                else
                    assert(fieldDefaultValue.isNull,
                        "Nullable fields marked with `parseAsFlag` must have the default value of null.");

                string messageIfAddedOptional = getArgumentFlagsValidationMessage(flags | _optionalBit);

                // NOTE: This one should always be covered by the flags validation instead.
                assert(messageIfAddedOptional is null, "Should never be hit!!\n" ~ messageIfAddedOptional);
                
                if (flags.doesNotHave(_optionalBit))
                    flags |= _optionalBit | _inferedOptionalityBit;
            }
            else
            {
                // TODO: maybe allow flags in the future??
                assert(false, "Fields marked `parseAsFlag` must be boolean.");
            }
        }
    }
    return flags;
}

NamedArgumentInfo[] getNamedArgumentInfosOf(TCommand)() pure
{
    import std.traits : hasUDA;
    NamedArgumentInfo[] result;
    
    static foreach (field; TCommand.tupleof)
    {{
        enum hasNamed = hasUDA!(field, ArgNamed);
        enum foldedArgFlags = foldArgumentFlags!(__traits(getAttributes, field));
        enum hasPositionalFlag = foldedArgFlags.has(ArgFlags._positionalArgumentBit);
        enum hasNamedFlag = foldedArgFlags.has(ArgFlags._namedArgumentBit);

        // This check is getting quite complex, so time to refactor to be honest.
        enum isSimple = !hasNamed
            && !hasUDA!(field, ArgPositional)
            && !hasPositionalFlag
            && (hasUDA!(field, string) || hasNamedFlag);

        static if (hasNamed)
        {
            ArgNamed uda = getArgumentInfo!(ArgNamed, field);
            if (uda.pattern == Pattern.init)
                uda.pattern = Pattern([__traits(identifier, field)]);
        }
        else static if (isSimple)
        {
            alias stringAttributes = getUDAs!(field, string);
            static if (stringAttributes.length > 0)
                ArgNamed uda = ArgNamed(__traits(identifier, field), stringAttributes[0]);
            else
                ArgNamed uda = ArgNamed(__traits(identifier, field), "");
        }
        
        static if (hasNamed || isSimple)
        {
            auto argument  = getCommonArgumentInfo!(field, ArgFlags._namedArgumentBit);
            argument.flags = inferArgumentFlagsSpecificToNamedArguments!(typeof(field))(
                argument.flags, defaultValueOf!field);
            result ~= NamedArgumentInfo(uda, argument);
        }
    }}
    return result;
}
