module jaster.cli.internal;

void debugPragma(string Message)()
{
    debug pragma(msg, "[JCLI]<DEBUG> "~Message);
}

template stringToMember(alias Symbol, string Member)
{
    alias stringToMember = __traits(getMember, Symbol, Member);
}