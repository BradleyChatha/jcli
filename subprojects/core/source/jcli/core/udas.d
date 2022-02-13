module jcli.core.udas;

import jcli.core.pattern;

package(jcli) mixin template BeingNamed()
{
    Pattern pattern;
    string description;

    string name() const @nogc nothrow pure @safe { return pattern[0]; }
}

// NOTE: 
// The constructors seem to not work when mixed in with the template above,
// which is why I mix in the string.
private enum string constructorsMixinString = 
q{
    this(string stringPattern, string description = "") pure
    {
        this.pattern = Pattern.parse(stringPattern);
        this.description = description;
    }
    
    this(Pattern pattern, string description = "") pure nothrow @nogc
    {
        this.pattern = pattern;
        this.description = description;
    }

    this(string[] pattern, string description = "") pure
    {
        this.pattern = Pattern(pattern);
        this.description = description;
    }
};

struct Command
{
    mixin BeingNamed;
    mixin(constructorsMixinString);
}

struct CommandDefault
{
    string description;
}

struct ArgPositional
{
    string name;
    string description = "";
}

struct ArgNamed
{
    mixin BeingNamed;
    mixin(constructorsMixinString);
}

struct ArgGroup
{
    string name;
    string description = "";
}

enum ArgOverflow;
enum ArgRaw;