module commands;

import std.stdio : writeln, File;
import jaster.cli;
import services;

@CommandDefault("Determines if your password is correct.")
class PasswordCommand
{
    private IPasswordManager _passwords;
    
    @CommandPositionalArg(0, "password", "The password to check.")
    string password;

    // JIOC uses constructor injection primarily, so here we're asking it to inject our `IPasswordManager` service.
    this(IPasswordManager passwords)
    {
        this._passwords = passwords;
    }

    int onExecute()
    {
        return (this._passwords.isValidPassword(this.password))
        ? 0
        : 128;
    }
}