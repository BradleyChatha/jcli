module jcli.core.udas;

import jcli.core.pattern;

package(jcli) mixin template BeingNamed()
{
    Pattern pattern;
    string description;

    @safe pure const:
    string name() nothrow @nogc { return pattern[0]; }
}

// NOTE: 
// The constructors seem to not work when mixed in with the template above,
// which is why I mix in the string.
private enum string ConstructorsMixinString = 
q{
    this(string stringPattern, string description = "")
    {
        this.pattern = Pattern.parse(stringPattern);
        this.description = description;
    }
    
    this(Pattern pattern, string description = "") nothrow @nogc
    {
        this.pattern = pattern;
        this.description = description;
    }

    this(string[] pattern, string description = "")
    {
        this.pattern = Pattern(pattern);
        this.description = description;
    }
};

struct Command
{
    mixin BeingNamed;
    mixin(ConstructorsMixinString);
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
    mixin BeingNamed;
    mixin(ConstructorsMixinString);
}

struct ArgGroup
{
    string name;
    string description;
}

enum ArgOverflow;
enum ArgRaw;