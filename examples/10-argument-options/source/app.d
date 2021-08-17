import jcli;
import commands;

// Nothing new here.
int main(string[] args)
{
    auto cli = new CommandLineInterface!(commands)();
    return cli.parseAndExecute(args);
}