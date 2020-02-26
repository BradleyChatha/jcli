module jaster.cli.internal;

void debugPragma(string Message)()
{
    version(JCLI_Verbose)
        debug pragma(msg, "[JCLI]<DEBUG> "~Message);
}