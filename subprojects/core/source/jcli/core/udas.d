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

    // I want this constructor to exit, but its kind of weird to do rn.
    // this(string description) pure nothrow @nogc
    // {
    //     this.pattern = Pattern.init;
    //     this.description = description;
    // }
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
    string description;

    @nogc nothrow pure @safe:
    
    this(string description)
    {
        this.description = description;
        this.name = "";
    }
    
    this(string name, string description)
    {
        this.description = description;
        this.name = name;
    }
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

/// Mark the member pointers of the command context struct 
/// to the parent command context struct with this.
/// That will make it join the command group.
/// The `onExecute` method will be called after the `onExecute` of that parent executes.
/// 
/// For now, when multiple such fields exist, the command  will be a child of both, 
/// and when the command is resolved, only the context pointer of 
/// the parent command that it was resolved through will be not-null.
enum ParentCommand;
