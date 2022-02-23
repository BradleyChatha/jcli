import jcli;

int main(string[] args)
{
    static import commands;
    return matchAndExecuteAcrossModules!(commands)(args[1 .. $]);
}
