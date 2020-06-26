module commands;

import jaster.cli;
import config;

/++
 + EXAMPLE USAGE:
 +  $> test.exe set name "Bradley"
 +  $> test.exe greet
 +      > Hello Bradley!
 +  $> test.exe set verbose true
 +  $> test.exe set name "Sealab"
 +      > Operation was a Success!
 +  $> test.exe force exception
 +      > [A whole lotta text]
 + ++/

@Command("set name", "Sets your name")
struct SetNameCommand
{
    private IConfig!MyConfig _config;

    @CommandPositionalArg(0, "name", "Your name")
    string name;

    this(IConfig!MyConfig config)
    {
        this._config = config;
    }

    void onExecute()
    {
        this._config.editAndSave((scope ref value)
        {
            value.name = this.name;
        });
        
        UserIO.configure().useVerboseLogging(this._config.value.verbose); // Ideally this is done in a base class or something, but trying to keep things simple.
        UserIO.verboseInfof("Operation was a %s", "Success!".ansi.fg(Ansi4BitColour.green));
    }
}

@Command("set verbose", "Sets verbose logging")
struct SetVerboseCommand
{
    private IConfig!MyConfig _config;

    @CommandPositionalArg(0, "value", "The verbose value")
    bool verbose;

    this(IConfig!MyConfig config)
    {
        this._config = config;
    }

    void onExecute()
    {
        this._config.editAndSave((scope ref value)
        {
            value.verbose = this.verbose;
        });
    }
}

@Command("greet", "I'll give you a greeting :)")
struct GreetCommand
{
    private IConfig!MyConfig _config;

    this(IConfig!MyConfig config)
    {
        this._config = config;
    }

    void onExecute()
    {
        UserIO.logInfof("Hello %s!", this._config.value.name);
    }
}

@Command("force exception", "Forces an exception to be thrown inside of IConfig.edit")
struct ForceExceptionCommand
{
    private IConfig!MyConfig _config;

    this(IConfig!MyConfig config)
    {
        this._config = config;
    }

    void onExecute()
    {
        UserIO.configure().useVerboseLogging(this._config.value.verbose);
        this._config.edit((scope ref value)
        { 
            throw new Exception("Exceptions are only printed in verbose logging mode."); 
        });
    }
}