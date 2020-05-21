/// An adapter for the asdf library.
module jaster.cli.adapters.config.asdf;

version(Have_asdf)
{
    import asdf;
    import jaster.cli.config : isConfigAdapterFor;

    struct AsdfConfigAdapter
    {
        static
        {
            const(ubyte[]) serialise(For)(For value)
            {
                return cast(const ubyte[])value.serializeToJsonPretty();
            }

            For deserialise(For)(const ubyte[] data)
            {
                import std.utf : validate;

                auto dataAsText = cast(const char[])data;
                dataAsText.validate();

                return dataAsText.deserialize!For();
            }
        }
    }

    private struct ExampleStruct
    {
        string s;
    }
    static assert(isConfigAdapterFor!(AsdfConfigAdapter, ExampleStruct));
}