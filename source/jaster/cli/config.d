module jaster.cli.config;

private
{
    import std.traits : isCopyable;
    import jaster.ioc;
}

interface IConfig(T)
if(is(T == struct) || is(T == class))
{
    public
    {
        void save();
        void load();
        
        @property
        T value();

        @property
        void value(T newValue);

        @property
        ref T valueRef();
    }
}

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

enum isConfigAdapterForImpl(Adapter, For) = 
    __traits(compiles, { const ubyte[] data = Adapter.serialise!For(For.init); })
 && __traits(compiles, { const ubyte[] data; For value = Adapter.deserialise!For(data); });

void showAdapterCompilerErrors(Adapter, For)()
{
    const ubyte[] data = Adapter.serialise!For(For.init);
    For value = Adapter.deserialise!For(data);
}

final class AdaptableFileConfig(For, Adapter) : IConfig!For
if(isConfigAdapterFor!(Adapter, For) && isCopyable!For)
{
    private For _value;
    private string _path;

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