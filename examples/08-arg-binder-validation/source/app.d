import jcli;
import commands;

int main(string[] args)
{
    auto cli = new CommandLineInterface!(commands)();
    return cli.parseAndExecute(args);
}