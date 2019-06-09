module jaster.cli.internal;

void debugPragma(string Message)()
{
    debug pragma(msg, "[JCLI]<DEBUG> "~Message);
}