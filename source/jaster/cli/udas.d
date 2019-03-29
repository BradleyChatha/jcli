module jaster.cli.udas;

struct Command
{
}

struct CommandGroup
{
    string group;
    
    this(string group)
    {
        import std.algorithm : canFind;
        assert(!group.canFind(' ') && !group.canFind('\t'), "Nested command groups aren't supported yet, so please don't use whitespace in @CommandGroup.");

        this.group = group;
    }
}

struct CommandName
{
    string name;
}

struct CommandDescription
{
    string description;
}

struct Argument
{
}

struct ArgumentIndex
{
    size_t index;
}

struct ArgumentRequired
{
}

struct ArgumentDescription
{
    string description;
}

struct ArgumentOption
{
    string option;

    bool isValidOption(string toTest)
    {
        import std.algorithm : splitter, any;
        return this.option.splitter("|").any!(str => str == toTest);
    }
}