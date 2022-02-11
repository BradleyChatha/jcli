module jcli.helptext.helptext;

import jcli.core, jcli.text, jcli.introspect;

struct CommandHelpText(alias CommandT_)
{
    alias CommandT          = CommandT_;
    alias CommandInfo       = commandInfoFor!CommandT;

    private string _cached;

    string generate(string appName = null, uint width = 180)
    {
        import std.range;
        import std.algorithm;

        if(this._cached)
            return this._cached;

        HelpText help = HelpText.make(width);

        if(appName is null)
        {
            import std.file : thisExePath;
            import std.path : baseName;
            appName = thisExePath().baseName;
        }

        static struct Arg
        {
            string name;
            string description;
            ArgGroup group;
            bool optional;
        }

        string patternToNamedArgList(Pattern pattern)
        {
            return pattern.patterns
                          .map!(p => p.length == 1 ? "-"~p : "--"~p)
                          .fold!((a,b) => a.length ? a~"|"~b : b)("");
        }

        Arg[] positionals;
        Arg[] named;

        static foreach(i, pos; CommandInfo.positionalArgs)
            positionals ~= Arg(pos.uda.name, pos.uda.description);
        static foreach(i, nam; CommandInfo.namedArgs)
        {
            named ~= Arg(
                patternToNamedArgList(nam.uda.pattern),
                nam.uda.description,
                nam.group,
                !!(nam.existence & ArgExistence.optional)
            );
        }

        named.multiSort!("a.optional != b.optional", "a.name < b.name");
        
        import std.format : format;
        help.addLineWithPrefix("Usage: ", "%s %s%s%s".format(
            appName,
            CommandInfo.pattern.patterns.walkLength ? CommandInfo.pattern.patterns.front : "DEFAULT",
            positionals.map!(p => "<"~p.name~">").fold!((a,b) => a~" "~b)(""),
            named.map!(p => p.optional ? "["~p.name~"]" : p.name).fold!((a,b) => a~" "~b)("")
        ), AnsiStyleSet.init.style(AnsiStyle.init.bold));

        if(CommandInfo.description)
            help.addHeaderWithText("Description:", CommandInfo.description);

        if(positionals.length)
        {
            help.addHeader("Positional Arguments:");
            foreach(pos; positionals)
            {
                help.addArgument(
                    pos.name,
                    [HelpTextDescription(0, pos.description)]
                );
            }
        }

        Arg[][ArgGroup] argsByGroup;
        foreach(nam; named)
        {
            scope ptr = (nam.group in argsByGroup);
            if(!ptr)
            {
                argsByGroup[nam.group] = Arg[].init;
                ptr = (nam.group in argsByGroup);
            }

            (*ptr) ~= nam;
        }

        foreach(group, args; argsByGroup)
        {
            help.addLine(null);

            if(group == ArgGroup.init)
                help.addHeader("Named Arguments:");
            else if(group.description == null)
                help.addHeader(group.name);
            else
                help.addHeaderWithText(group.name, group.description);

            foreach(arg; args)
            {
                auto descs = [HelpTextDescription(0, arg.description)];

                help.addArgument(
                    arg.name,
                    descs
                );
            }
        }

        this._cached = help.finish();
        return this._cached;
    }
}

unittest
{
    @Command("command", "This is a command that is totally super complicated.")
    static struct ComplexCommand
    {
        @ArgPositional("arg1", "This is a generic argument that isn't grouped anywhere")
        int a;
        @ArgPositional("arg2", "This is a generic argument that isn't grouped anywhere")
        int b;
        @ArgPositional("output", "Where to place the output.")
        string output;

        @ArgNamed("test-flag", "Test flag, please ignore.")
        @(ArgConfig.parseAsFlag)
        bool flag;

        @ArgGroup("Debug", "Arguments related to debugging.")
        {
            @ArgNamed("verbose|v", "Enables verbose logging.")
            Nullable!bool verbose;

            @ArgNamed("log|l", "Specifies a log file to direct output to.")
            Nullable!string log;
        }

        @ArgGroup("I/O", "Arguments related to I/O.")
        @ArgNamed("config|c", "Specifies the config file to use.")
        Nullable!string config;

        void onExecute(){}
    }

    auto c = CommandHelpText!ComplexCommand();
    // I've learned its next to pointless to fully unittest help text, since it can change so subtly and so often
    // that manual validation is good enough.
    //assert(false, c.generate());
}