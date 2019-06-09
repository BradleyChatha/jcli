module jaster.cli.binder;

import jaster.cli.udas : ArgBinderFunc; // Compiler can't see this for some reason when the import is nested.

struct ArgBinder(Modules...)
{
    import std.conv   : to;
    import std.traits : getSymbolsByUDA, Parameters, isFunction, fullyQualifiedName;
    import jaster.cli.udas, jaster.cli.internal;
    
    /+ PUBLIC INTERFACE +/
    public
    {
        void bind(T)(string arg, ref T value)
        {
            static foreach(mod; Modules)
            {
                static foreach(binder; getSymbolsByUDA!(mod, ArgBinderFunc))
                {{
                    // Template support.
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

                    static assert(isFunction!Binder,
                        "The arg binder `"~BinderFQN~"` isn't a function. (hint: `function`, not `delegate`)"
                    );

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
                        return; // To avoid the assert at the end.
                    }
                }}
            }

            assert(false, "No arg binder could be found for type `"~T.stringof~"`");
        }
    }
}

@ArgBinderFunc
private void testBinder(T)(string arg, ref T value)
{
    import std.conv : to;

    value = arg.to!T;
}

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