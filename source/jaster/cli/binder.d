module jaster.cli.binder;

private
{
    import std.traits : isNumeric;
    import jaster.cli.udas : ArgBinderFunc; // Compiler can't see this for some reason when the import is nested.
}

struct ArgBinder(Modules...)
{
    import std.conv   : to;
    import std.traits : getSymbolsByUDA, Parameters, isFunction, fullyQualifiedName;
    import std.meta   : AliasSeq;
    import jaster.cli.udas, jaster.cli.internal;
    
    alias AllModules = AliasSeq!(Modules, jaster.cli.binder);

    /+ PUBLIC INTERFACE +/
    public
    {
        void bind(T)(string arg, ref T value)
        {
            bool handled = false;

            static foreach(mod; AllModules)
            {
                foreach(binder; getSymbolsByUDA!(mod, ArgBinderFunc))
                {
                    static if(__traits(compiles, binder!T))
                    {
                        alias Binder = binder!T;
                        const BinderFQN = fullyQualifiedName!mod~"."~fullyQualifiedName!Binder~"!("~T.stringof~")";
                    }
                    else
                    {
                        alias Binder = binder;
                        const BinderFQN = fullyQualifiedName!Binder;
                    }

                    static if(isFunction!Binder)
                    {
                        alias Params = Parameters!Binder;
                        static assert(Params.length == 2,
                            "The arg binder `"~BinderFQN~"` must only have `2` parameters, not `"~Params.length.to!string~"` parameters."
                        );
                        static assert(is(Params[0] == string),
                            "The arg binder `"~BinderFQN~"` must have a `string` as their first parameter, not a(n) `"~Params[0].stringof~"`."
                        );

                        static if(is(Params[1] == T)
                            || __traits(compiles, Binder("", T.init))) // Template support.
                        {
                            debugPragma!("Using arg binder `"~BinderFQN~"` for type `"~T.stringof~"`.");
                            Binder(arg, value);
                            handled = true;
                            break; // Break out of foreach
                        }
                    }
                    else
                    {
                        debugPragma!(
                            "Skipping arg binder `"~BinderFQN~"` for type `"~T.stringof~"` because `isFunction` is returning false."
                           ~"\nIf the binder is a template function, then this error is occuring because the function's contract fails, or it's code doesn't compile for the given type."
                        );
                    }
                }
            }

            if(!handled)
                assert(false, "No arg binder could be found for type `"~T.stringof~"`");
        }
    }
}
///
unittest
{
    auto binder = ArgBinder!(jaster.cli.binder)();

    int value;
    string strValue;
    binder.bind("200", value);
    binder.bind("200", strValue);

    assert(value == 200);
    assert(strValue == "200");
}

/+ BUILT-IN BINDERS +/
@ArgBinderFunc
void stringBinder(string arg, ref string value)
{
    value = arg;
}

@ArgBinderFunc
void numericBinder(T)(string arg, ref T value)
if(isNumeric!T)
{
    import std.conv : to;
    value = arg.to!T;
}