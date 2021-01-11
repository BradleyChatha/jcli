/// Contains a type to generate help text for a command.
module jaster.cli.commandhelptext;

import std.array;
import jaster.cli.infogen, jaster.cli.result, jaster.cli.helptext;

struct CommandHelpText(alias CommandT, alias ArgBinderInstance = ArgBinder!())
{
    enum Info = getCommandInfoFor!(CommandT, ArgBinderInstance);

    HelpTextBuilderSimple toBuilder(string appName) const
    {
        auto builder = new HelpTextBuilderSimple();

        void handleGroup(CommandArgGroup uda)
        {
            if(uda.isNull)
                return;

            builder.setGroupDescription(uda.name, uda.description);
        }

        foreach(arg; Info.namedArgs)
        {
            builder.addNamedArg(
                (arg.group.isNull) ? null : arg.group.name,
                arg.uda.pattern.byEach.array,
                arg.uda.description,
                cast(ArgIsOptional)((arg.existence & CommandArgExistence.optional) > 0)
            );
            handleGroup(arg.group);
        }

        foreach(arg; Info.positionalArgs)
        {
            builder.addPositionalArg(
                (arg.group.isNull) ? null : arg.group.name,
                arg.uda.position,
                arg.uda.description,
                cast(ArgIsOptional)((arg.existence & CommandArgExistence.optional) > 0),
                arg.uda.name
            );
            handleGroup(arg.group);
        }

        builder.commandName = appName ~ " " ~ Info.pattern.defaultPattern;
        builder.description = Info.description;

        return builder;
    }

    string toString(string appName) const
    {
        return this.toBuilder(appName).toString();
    }
}

// To get around a limiation of not being able to use Nullable in ArgumentInfo
private bool isNull(CommandArgGroup group)
{
    return group == CommandArgGroup.init;
}