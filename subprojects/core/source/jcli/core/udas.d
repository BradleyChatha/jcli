module jcli.core.udas;

import jcli.core.pattern;

package(jcli) mixin template BeingNamed()
{
    Pattern pattern;
    string description;
    string name() @safe nothrow @nogc pure const { return pattern[0]; }

    this(string stringPattern, string description = "")
    {
        this.pattern = Pattern.parse(stringPattern);
        this.description = description;
    }
    
    this(Pattern pattern, string description = "")
    {
        this.pattern = pattern;
        this.description = description;
    }

    this(string[] pattern, string description = "")
    {
        this.pattern = Pattern(pattern);
        this.description = description;
    }
}

struct Command
{
    mixin BeingNamed;
}

struct CommandDefault()
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
    mixin BeingNamed;
}

struct ArgGroup
{
    string name;
    string description;
}

enum ArgOverflow;
enum ArgRaw;