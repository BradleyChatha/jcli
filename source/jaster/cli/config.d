/// Contains services that are used to easily load, modify, and store the program's configuration.
module jaster.cli.config;

private
{
    import std.traits : isCopyable;
    import jaster.ioc;
}

/++
 + The simplest interface for configuration.
 +
 + This doesn't care about how data is loaded, stored, or saved. It simply provides
 + a bare-bones interface to accessing data, without needing to worry about the nitty-gritty stuff.
 + ++/
interface IConfig(T)
if(is(T == struct) || is(T == class))
{
    public
    {
        /// Saves the configuration. Location, format, etc. all completely depends on the implementation.
        void save();

        /// Loads the configuration.
        void load();
        
        /++
         + Returns:
         +  The configuration's value.
         + ++/
        @property
        T value();

        /++
         + Sets the configuration's value.
         + ++/
        @property
        void value(T newValue);

        /++
         + Returns:
         +  A reference to the configuration's value.
         + ++/
        @property
        ref T valueRef();
    }
}

/++
 + A template that evaluates to a bool which determines whether the given `Adapter` can successfully
 + compile all the code needed to serialise and deserialise the `For` type.
 +
 + Adapters:
 +  Certain `IConfig` implementations may provide a level of flexibliity in the sense that they will offload the responsiblity
 +  of serialising/deserialising the configuration onto something called an `Adapter`.
 +
 +  For the most part, these `Adapters` are likely to simply be that: an adapter for an already existing serialisation library.
 +
 +  Adapters require two static functions, with the following or compatible signatures:
 +
 +  ```
 +  const(ubyte[]) serialise(For)(For value);
 +
 +  For deserialise(For)(const(ubyte[]) value);
 +  ```
 +
 + Builtin Adapters:
 +  Please note that any adapter that uses a third party library will only be compiled if your own project includes aforementioned library.
 +
 +  For example, `AsdfConfigAdapter` requires the asdf library, so will only be available if your dub project includes asdf (or specify the `Have_asdf` version).
 +
 +  e.g. if you want to use `AsdfConfigAdapter`, use a simple `dub add asdf` in your own project and then you're good to go.
 +
 +  JCLI provides the following adapters by default:
 +
 +  * `AsdfConfigAdapter` - An adapter for the asdf serialisation library. asdf is marked as an optional package.
 +
 + Notes:
 +  If for whatever reason the given `Adapter` cannot compile when being used with the `For` type, this template
 +  will attempt to instigate an error message from the compiler as to why.
 +
 +  If this template is being used inside a `static assert`, and fails, then the above attempt to provide an error message as to
 +  why the compliation failed will not be shown, as the `static assert is false` error is thrown before the compile has a chance to collect any other error message.
 +
 +  In such a case, please temporarily rewrite the `static assert` into storing the result of this template into an `enum`, as that should then allow
 +  the compiler to generate the error message.
 + ++/
template isConfigAdapterFor(Adapter, For)
{
    static if(isConfigAdapterForImpl!(Adapter, For))
        enum isConfigAdapterFor = true;
    else
    {
        alias _ErrorfulInstansiation = showAdapterCompilerErrors!(Adapter, For);
        enum isConfigAdapterFor = false;
    }
}

private enum isConfigAdapterForImpl(Adapter, For) = 
    __traits(compiles, { const ubyte[] data = Adapter.serialise!For(For.init); })
 && __traits(compiles, { const ubyte[] data; For value = Adapter.deserialise!For(data); });

private void showAdapterCompilerErrors(Adapter, For)()
{
    const ubyte[] data = Adapter.serialise!For(For.init);
    For value = Adapter.deserialise!For(data);
}

/++
 + An `IConfig` with adapter support that uses the filesystem to store/retrieve its configuration value.
 +
 + See_Also:
 +  The docs for `isConfigAdapterFor`.
 +
 +  `addFileConfig`
 + ++/
final class AdaptableFileConfig(For, Adapter) : IConfig!For
if(isConfigAdapterFor!(Adapter, For) && isCopyable!For)
{
    private For _value;
    private string _path;

    /++
     + Params:
     +  path = The file path to store the configuration file at.
     + ++/
    this(string path)
    {
        import std.exception : enforce;
        import std.path : absolutePath, isValidPath;

        this._path = path.absolutePath();
        enforce(isValidPath(this._path), "The path '"~this._path~"' is invalid");
    }

    public override
    {
        void save()
        {
            import std.file      : write, exists, mkdirRecurse, copy;
            import std.path      : dirName, extension, setExtension;

            const pathDir = this._path.dirName;
            if(!exists(pathDir))
                mkdirRecurse(pathDir);

            const backupExt = this._path.extension ~ ".bak";
            const backupPath = this._path.setExtension(backupExt);
            if(exists(this._path))
                copy(this._path, backupPath);

            const ubyte[] data = Adapter.serialise!For(this._value);
            write(this._path, data);
        }

        void load()
        {
            import std.file : exists, read;

            if(!this._path.exists)
                return;

            this._value = Adapter.deserialise!For(cast(const ubyte[])read(this._path));
        }

        @property
        For value()
        {
            return this._value;
        }

        @property
        void value(For newValue)
        {
            this._value = newValue;
        }

        @property
        ref For valueRef()
        {
            return this._value;
        }
    }
}

/++
 + Note:
 +  The base type of the resulting service is `IConfig!For`, so ensure that your dependency injected code asks for
 +  `IConfig!For` instead of `AdapatableFileConfig!(For, Adapter)`.
 +
 + Returns:
 +  A Singleton `ServiceInfo` describing an `AdapatableFileConfig` that serialises the given `For` type, into a file
 +  using the provided `Adapter` type.
 + ++/
ServiceInfo addFileConfig(For, Adapter)(string fileName)
{
    return ServiceInfo.asSingleton!(
        IConfig!For, 
        AdaptableFileConfig!(For, Adapter)
    )(
        (ref _)
        { 
            auto config = new AdaptableFileConfig!(For, Adapter)(fileName);
            config.load();

            return config;
        }
    );
}

/// ditto.
ServiceInfo[] addFileConfig(For, Adapter)(ref ServiceInfo[] services, string fileName)
{
    services ~= addFileConfig!(For, Adapter)();
    return services;
}