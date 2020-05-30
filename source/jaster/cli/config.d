/// Contains services that are used to easily load, modify, and store the program's configuration.
module jaster.cli.config;

private
{
    import std.typecons : Flag;
    import std.traits   : isCopyable;
    import jaster.ioc;
}

alias WasExceptionThrown  = Flag!"wasAnExceptionThrown?";
alias SaveOnSuccess       = Flag!"configSaveOnSuccess";
alias RollbackOnFailure   = Flag!"configRollbackOnError";

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
        /// Loads the configuration. This should overwrite any unsaved changes.
        void load();

        /// Saves the configuration.
        void save();

        /// Returns: The current value for this configuration.
        @property
        T value();

        /// Sets the configuration's value.
        @property
        void value(T value);
    }

    public final
    {
        /++
         + Edit the value of this configuration using the provided `editFunc`, optionally
         + saving if no exceptions are thrown, and optionally rolling back any changes in the case an exception $(B is) thrown.
         +
         + Notes:
         +  Exceptions can be caught during either `editFunc`, or a call to `save`.
         +
         +  Functionally, "rolling back on success" simply means the configuration's `value[set]` property is never used.
         +
         +  This has a consequence - if your `editFunc` modifies the internal state of the value in a way that takes immediate effect on
         +  the original value (e.g. the value is a class type, so all changes will affect the origina value), then "rolling back" won't
         +  be able to prevent any data changes.
         +
         +  Therefor, its best to use structs for your configuration types if you're wanting to make use of "rolling back".
         +
         +  If an error occurs, then `UserIO.verboseException` is used to display the exception.
         +
         +  $(Ensure your lambda parameter is marked `scope ref`, otherwise you'll get a compiler error.)
         +
         + Params:
         +  editFunc = The function that will edit the configuration's value.
         +  rollback = If `RollbackOnFailure.yes`, then should an error occur, the configuration's value will be left unchanged.
         +  save     = If `SaveOnSuccess.yes`, then if no errors occur, a call to `save` will be made.
         +
         + Returns:
         +  `WasExceptionThrown` to denote whether an error occured or not.
         + ++/
        WasExceptionThrown edit(
            void delegate(scope ref T value) editFunc,
            RollbackOnFailure rollback = RollbackOnFailure.yes,
            SaveOnSuccess save = SaveOnSuccess.no
        )
        {
            auto uneditedValue = this.value;
            auto value         = uneditedValue; // So we can update the value in the event of `rollback.no`.
            try
            {
                editFunc(value); // Pass a temporary, so in the event of an error, changes shouldn't be half-committed.

                this.value = value;                
                if(save)
                    this.save();

                return WasExceptionThrown.no;
            }
            catch(Exception ex)
            {
                this.value = (rollback) ? uneditedValue : value;
                return WasExceptionThrown.yes;
            }
        }

        /// Exactly the same as `edit`, except with the `save` parameter set to `yes`.
        void editAndSave(void delegate(scope ref T value) editFunc)
        {
            this.edit(editFunc, RollbackOnFailure.yes, SaveOnSuccess.yes);
        }

        /// Exactly the same as `edit`, except with the `save` parameter set to `yes`, and `rollback` set to `no`.
        void editAndSaveNoRollback(void delegate(scope ref T value) editFunc)
        {
            this.edit(editFunc, RollbackOnFailure.no, SaveOnSuccess.yes);
        }

        /// Exactly the same as `edit`, except with the `rollback` paramter set to `no`.
        void editNoRollback(void delegate(scope ref T value) editFunc)
        {
            this.edit(editFunc, RollbackOnFailure.no, SaveOnSuccess.no);
        }
    }
}
///
unittest
{
    // This is mostly a unittest for testing, not as an example, but may as well show it as an example anyway.
    static struct Conf
    {
        string str;
        int num;
    }

    auto config = new InMemoryConfig!Conf();

    // Default: Rollback on failure, don't save on success.
    // First `edit` fails, so no data should be commited.
    // Second `edit` passes, so data is edited.
    // Test to ensure only the second `edit` committed changes.
    assert(config.edit((scope ref v) { v.str = "Hello"; v.num = 420; throw new Exception(""); }) == WasExceptionThrown.yes);
    assert(config.edit((scope ref v) { v.num = 21; })                                            == WasExceptionThrown.no);
    assert(config.value == Conf(null, 21));

    // Reset value, check that we didn't actually call `save` yet.
    config.load();
    assert(config.value == Conf.init);

    // Test editAndSave. Save on success, rollback on failure.
    // No longer need to test rollback's pass case, as that's now proven to work.
    config.editAndSave((scope ref v) { v.str = "Lalafell"; });
    config.value = Conf.init;
    config.load();
    assert(config.value.str == "Lalafell");

    // Reset value
    config.value = Conf.init;
    config.save();

    // Test editNoRollback, and then we'll have tested the pass & fail cases for saving and rollbacks.
    config.editNoRollback((scope ref v) { v.str = "Grubby"; throw new Exception(""); });
    assert(config.value.str == "Grubby", config.value.str);
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

/// A very simple `IConfig` that simply stores the value in memory. This is mostly only useful for testing.
final class InMemoryConfig(For) : IConfig!For
if(isCopyable!For)
{
    private For _savedValue;
    private For _value;

    public override
    {
        void save()
        {
            this._savedValue = this._value;
        }

        void load()
        {
            this._value = this._savedValue;
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
    }
}

/++
 + Returns:
 +  A Singleton `ServiceInfo` describing an `InMemoryConfig` that stores the `For` type.
 + ++/
ServiceInfo addInMemoryConfig(For)()
{
    return ServiceInfo.asSingleton!(IConfig!For, InMemoryConfig!For);
}

/// ditto.
ServiceInfo[] addInMemoryConfig(For)()
{
    services ~= addInMemoryConfig!For();
    return services;
}

/++
 + An `IConfig` with adapter support that uses the filesystem to store/retrieve its configuration value.
 +
 + Notes:
 +  This class will ensure the directory for the file exists.
 +
 +  This class will always create a backup ".bak" before every write attempt. It however does not
 +  attempt to restore this file in the event of an error.
 +
 +  If this class' config file doesn't exist, then `load` is no-op, leaving the `value` as `For.init`
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
     + Throws:
     +  `Exception` if the given `path` is invalid, after being converted into an absolute path.
     +
     + Params:
     +  path = The file path to store the configuration file at. This can be relative or absolute.
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