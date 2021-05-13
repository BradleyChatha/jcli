/// Templates for generating information about commands.
module jaster.cli.infogen.gen;

import std.traits, std.meta, std.typecons;
import jaster.cli.infogen, jaster.cli.udas, jaster.cli.binder;

/++
 + Generates a `CommandInfo!CommandT` populated with all the information about the command and its arguments.
 +
 + Description:
 +  This template can be useful to gather information about a command and its argument, without having any extra baggage attached.
 +
 +  This allows you to introspect information about the command in the same way as JCLI does.
 +
 + Params:
 +  CommandT = The Command to generate the information for.
 +  ArgBinderInstance = The `ArgBinder` to use when generating argument setter functions.
 + ++/
template getCommandInfoFor(alias CommandT, alias ArgBinderInstance)
{
    static assert(isSomeCommand!CommandT, "Type "~CommandT.stringof~" is not marked with @Command or @CommandDefault.");

    static if(hasUDA!(CommandT, Command))
    {
        enum CommandPattern = getSingleUDA!(CommandT, Command).pattern;
        enum CommandDescription = getSingleUDA!(CommandT, Command).description;

        static assert(CommandPattern.pattern !is null, "Null pattern names are deprecated, use `@CommandDefault` instead.");
    }
    else
    {
        enum CommandPattern = Pattern.init;
        enum CommandDescription = getSingleUDA!(CommandT, CommandDefault).description;
    }

    enum ArgInfoTuple = toArgInfoArray!(CommandT, ArgBinderInstance);

    enum getCommandInfoFor = CommandInfo!CommandT(
        CommandPattern,
        CommandDescription,
        ArgInfoTuple[0],
        ArgInfoTuple[1],
        ArgInfoTuple[2]
    );

    enum _dummy = assertGroupDescriptionConsistency!CommandT(getCommandInfoFor);
}
///
unittest
{
    import std.typecons : Nullable;

    @Command("test", "doe")
    static struct C
    {
        @CommandNamedArg("abc", "123") string arg;
        @CommandPositionalArg(20, "ray", "me") @CommandArgGroup("nam") Nullable!bool pos;
        @CommandNamedArg @(CommandArgAction.count) int b;
    }

    enum info = getCommandInfoFor!(C, ArgBinder!());
    static assert(info.pattern.matchSpaceless("test"));
    static assert(info.description == "doe");
    static assert(info.namedArgs.length == 2);
    static assert(info.positionalArgs.length == 1);

    static assert(info.namedArgs[0].identifier == "arg");
    static assert(info.namedArgs[0].uda.pattern.matchSpaceless("abc"));
    static assert(info.namedArgs[0].action == CommandArgAction.default_);
    static assert(info.namedArgs[0].group == CommandArgGroup.init);
    static assert(info.namedArgs[0].existence == CommandArgExistence.default_);
    static assert(info.namedArgs[0].parseScheme == CommandArgParseScheme.default_);

    static assert(info.positionalArgs[0].identifier == "pos");
    static assert(info.positionalArgs[0].uda.position == 20);
    static assert(info.positionalArgs[0].action == CommandArgAction.default_);
    static assert(info.positionalArgs[0].group.name == "nam");
    static assert(info.positionalArgs[0].existence == CommandArgExistence.optional);
    static assert(info.positionalArgs[0].parseScheme == CommandArgParseScheme.bool_);

    static assert(info.namedArgs[1].action == CommandArgAction.count);
}

private auto toArgInfoArray(alias CommandT, alias ArgBinderInstance)()
{
    import std.typecons : tuple;

    alias NamedArgs = getNamedArguments!CommandT;
    alias PositionalArgs = getPositionalArguments!CommandT;

    auto namedArgs = new NamedArgumentInfo!CommandT[NamedArgs.length];
    auto positionalArgs = new PositionalArgumentInfo!CommandT[PositionalArgs.length];
    typeof(CommandInfo!CommandT.rawListArg) rawListArg;

    static foreach(i, ArgT; NamedArgs)
        namedArgs[i] = getArgInfoFor!(CommandT, ArgT, ArgBinderInstance);
    static foreach(i, ArgT; PositionalArgs)
        positionalArgs[i] = getArgInfoFor!(CommandT, ArgT, ArgBinderInstance);

    alias RawListArgSymbols = getSymbolsByUDA!(CommandT, CommandRawListArg);
    static if(RawListArgSymbols.length > 0)
    {
        static assert(RawListArgSymbols.length == 1, "Only one argument can be marked with @CommandRawListArg");
        static assert(!isSomeArgument!(RawListArgSymbols[0]), "@CommandRawListArg is mutually exclusive to the other command UDAs.");
        rawListArg = getArgInfoFor!(CommandT, RawListArgSymbols[0], ArgBinderInstance);
    }

    return tuple(namedArgs, positionalArgs, rawListArg);
}

private template getArgInfoFor(alias CommandT, alias ArgT, alias ArgBinderInstance)
{
    // Determine argument info type.
    static if(isNamedArgument!ArgT)
        alias ArgInfoT = NamedArgumentInfo!CommandT;
    else static if(isPositionalArgument!ArgT)
        alias ArgInfoT = PositionalArgumentInfo!CommandT;
    else static if(isRawListArgument!ArgT)
        alias ArgInfoT = RawListArgumentInfo!CommandT;
    else
        static assert(false, "Type "~ArgT~" cannot be recognised as an argument.");

    // Find what action to use.
    enum isActionUDA(alias UDA) = is(typeof(UDA) == CommandArgAction);
    enum ActionUDAs = Filter!(isActionUDA, __traits(getAttributes, ArgT));
    static if(ActionUDAs.length == 0)
        enum Action = CommandArgAction.default_;
    else static if(ActionUDAs.length == 1)
        enum Action = ActionUDAs[0];
    else
        static assert(false, "Multiple `CommandArgAction` UDAs detected for argument "~ArgT.stringof);
    alias ActionFunc = actionFuncFromAction!(Action, CommandT, ArgT, ArgBinderInstance);
    
    // Get the arg group if one is assigned.
    static if(hasUDA!(ArgT, CommandArgGroup))
        enum Group = getSingleUDA!(ArgT, CommandArgGroup);
    else
        enum Group = CommandArgGroup.init;

    // Determine existence and parse scheme traits.
    enum Existence = determineExistence!(CommandT, typeof(ArgT), Action);
    enum Scheme    = determineParseScheme!(CommandT, ArgT, Action);
    enum Config    = determineConfig!(CommandT, ArgT, Action);

    enum getArgInfoFor = ArgInfoT(
        __traits(identifier, ArgT),
        getSingleUDA!(ArgT, typeof(ArgInfoT.uda)),
        Action,
        Group,
        Existence,
        Scheme,
        Config,
        &ActionFunc
    );
}

private template actionFuncFromAction(CommandArgAction Action, alias CommandT, alias ArgT, alias ArgBinderInstance)
{
    import std.conv;

    static if(isRawListArgument!ArgT)
        alias actionFuncFromAction = dummyAction!CommandT;
    else static if(Action == CommandArgAction.default_)
        alias actionFuncFromAction = actionValueBind!(CommandT, ArgT, ArgBinderInstance);
    else static if(Action == CommandArgAction.count)
        alias actionFuncFromAction = actionCount!(CommandT, ArgT, ArgBinderInstance);
    else
    {
        pragma(msg, Action.to!string);
        pragma(msg, CommandT);
        pragma(msg, __traits(identifier, ArgT));
        pragma(msg, ArgBinderInstance);
        static assert(false, "No suitable action found.");
    }
}

private CommandArgExistence determineExistence(alias CommandT, alias ArgTType, CommandArgAction Action)()
{
    import std.typecons : Nullable;

    CommandArgExistence value;

    static if(isInstanceOf!(Nullable, ArgTType))
        value |= CommandArgExistence.optional;
    static if(Action == CommandArgAction.count)
    {
        value |= CommandArgExistence.multiple;
        value |= CommandArgExistence.optional;
    }

    return value;
}

private template determineParseScheme(alias CommandT, alias ArgT, CommandArgAction Action)
{
    import std.typecons : Nullable;

    static if(is(typeof(ArgT) == bool) || is(typeof(ArgT) == Nullable!bool))
        enum determineParseScheme = CommandArgParseScheme.bool_;
    else static if(Action == CommandArgAction.count)
        enum determineParseScheme = CommandArgParseScheme.allowRepeatedName;
    else
        enum determineParseScheme = CommandArgParseScheme.default_;
}

private template determineConfig(alias CommandT, alias ArgT, CommandArgAction Action)
{
    enum UDAs = getUDAs!(ArgT, CommandArgConfig);
    static if(UDAs.length > 0)
    {
        static CommandArgConfig createMask()
        {
            CommandArgConfig value;
            foreach(uda; UDAs)
                value |= uda;
            return value;
        }
        enum determineConfig = createMask();
    }
    else
        enum determineConfig = CommandArgConfig.none;
}

private bool assertGroupDescriptionConsistency(alias CommandT)(CommandInfo!CommandT info)
{
    import std.algorithm : map, filter, all, uniq, joiner;
    import std.range     : chain;
    import std.conv      : to;

    auto groups = info.namedArgs
                      .map!(a => a.group).chain(
                          info.positionalArgs
                              .map!(a => a.group)
                      );
    auto uniqueGroupNames = groups.map!(g => g.name).uniq;

    foreach(name; uniqueGroupNames)
    {
        auto descriptionsForGroupName = groups.filter!(g => g.name == name).map!(g => g.description);
        auto firstNonNullDescription = descriptionsForGroupName.filter!(d => d !is null);
        if(firstNonNullDescription.empty)
            continue;

        const canonDescription = firstNonNullDescription.front;
        assert(
            descriptionsForGroupName.all!(d => d is null || d == canonDescription),
            "Group '"~name~"' has multiple conflicting descriptions. Canon description is '"~canonDescription~"' but the following conflicts were found: "
           ~"["
           ~descriptionsForGroupName.filter!(d => d !is null && d != canonDescription).map!(d => `"`~d~`"`).joiner(" <-> ").to!string
           ~"]"
        );
    }

    return true; // Dummy value, just so I can do enum assignment
}