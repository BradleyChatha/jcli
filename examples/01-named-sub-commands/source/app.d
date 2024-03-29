import jcli;
import commands;

/++
 + Most simple example:
 +  - Create a `CommandLineInterface`.
 +      - Pass it every module containing your commands via its template parameter, and it'll auto-detect every command.
 +  - Call `.parseAndExecute` with the args passed to the main function.
 +  - ???
 +  - Profit?
 + ++/
int main(string[] args)
{
    auto cli = new CommandLineInterface!(commands)();
    return cli.parseAndExecute(args);
}