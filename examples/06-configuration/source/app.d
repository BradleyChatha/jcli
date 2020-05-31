import jaster.cli;
import jaster.ioc;
import commands, config;

// See example 5 if you haven't already, if you get confused about the dependency injection.
int main(string[] args)
{
    // JCLI provides the `addFileConfig` helper function to easily create an `AdaptableFileConfig`.
    //
    // This example has the `asdf` library as a dependency, as this activates JCLI's built-in asdf adapater.
    auto provider = new ServiceProvider(
    [
        addFileConfig!(MyConfig, AsdfConfigAdapter)("config.json")
    ]);

    auto cli = new CommandLineInterface!(commands)(provider);
    return cli.parseAndExecute(args);
}