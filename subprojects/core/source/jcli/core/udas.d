module jcli.core.udas;

import jcli.core.pattern;

struct Command
{
    Pattern pattern;
    string description;

    this(string pattern, string description = "")
    {
        this.pattern = Pattern(pattern);
        this.description = description;
    }
}

struct CommandDefault
{
    string description;
}

struct ArgPositional
{
    string name;
    string description;
}

struct ArgNamed
{
    Pattern pattern;
    string description;

    this(string pattern, string description = "")
    {
        this.pattern = Pattern(pattern);
        this.description = description;
    }
}

struct ArgGroup
{
    string name;
    string description;
}

struct ArgOverflow{}
struct ArgRaw{}