import jaster.cli;
import jaster.ioc;
import commands, services;

/++
 + Ensure you've added jioc into your dub.sdl/dub.json
 +
 + Please refer to jioc's documentation for a proper in-depth explanation of how things work.
 + ++/
int main(string[] args)
{
    // Create a new service provider with our services.
    //
    // NOTE: `addCommandLineInterfaceService` is a free-standing function provided by JCLI, which is
    //       used to add the ICommandLineInterface.
    //
    //      `ICommandLineInterface` allows commands to execute other JCLI commands more easily than with `Shell.execute`.
    auto provider = new ServiceProvider(
    [
        addCommandLineInterfaceService(),
        ServiceInfo.asSingleton!(IPasswordManager, PasswordManager)
    ]);

    // Make sure to pass the provider into CommandLineInterface.
    //
    // Now, all command instaces are created using constructor injection (see JIOC's docs, or any docs about dependency injection really).
    auto cli = new CommandLineInterface!(commands)(provider);
    return cli.parseAndExecute(args);
}