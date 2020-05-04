/// Internal utilities.
module jaster.cli.internal;

/// pragma(msg) only used in debug mode, if version JCLI_Verbose is specified.
void debugPragma(string Message)()
{
    version(JCLI_Verbose)
        debug pragma(msg, "[JCLI]<DEBUG> "~Message);
}