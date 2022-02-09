module jcli.introspect.data;

import jcli.core;

enum ArgExistence
{
    mandatory   = 0,
    optional    = 1 << 0,
    multiple    = 1 << 1
}

enum ArgParseScheme
{
    normal,
    bool_,
    repeatableName
}

enum ArgAction
{
    normal,
    count
}

enum ArgConfig
{
    none,
    canRedefine = 1 << 0,
    caseInsensitive = 1 << 1
}

struct CommandInfo(alias CommandT_)
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

struct ArgIntrospect(alias UDA_, alias CommandT_)
{
    alias UDA = UDA_;
    alias CommandT = CommandT_;

    string identifier;
    UDA uda;
    ArgExistence existence;
    ArgParseScheme scheme;
    ArgAction action;
    ArgConfig config;
    ArgGroup group;
}

template getArgSymbol(alias ArgIntrospectT)
{
    mixin("alias getArgSymbol = ArgIntrospectT.CommandT."~ArgIntrospectT.identifier~";");
}

ref auto getArg(alias ArgIntrospectT)(ref return ArgIntrospectT.CommandT command)
{
    mixin("return command."~ArgIntrospectT.identifier~";");
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