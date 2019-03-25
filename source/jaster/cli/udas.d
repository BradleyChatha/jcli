module jaster.cli.udas;

struct Command
{
}

struct CommandGroup
{
    string group;
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