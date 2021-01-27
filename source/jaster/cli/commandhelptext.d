/// Contains a type to generate help text for a command.
module jaster.cli.commandhelptext;

import std.array;
import jaster.cli.infogen, jaster.cli.result, jaster.cli.helptext, jaster.cli.binder;

/++
 + A helper struct that will generate help text for a given command.
 +
 + Description:
 +  This struct will construct a `HelpTextBuilderSimple` (via `toBuilder`, or a string via `toString`)
 +  that is populated via the information provided by the arguments found within `CommandT`, and also the information
 +  attached to `CommandT` itself.
 +
 +  Here is an example of a fully-featured piece of help text generated by this struct:
 +
 +  ```
 +  Usage: mytool MyCommand <InputFile> <OutputFile> <CompressionLevel> [-v|--verbose] [--encoding]
 +
 +  Description:
 +      This is a command that transforms the InputFile into an OutputFile
 +
 +  Positional Args:
 +      InputFile                    - The input file.
 +      OutputFile                   - The output file.
 +
 +  Named Args:
 +      -v,--verbose                 - Verbose output
 +
 +  Utility:
 +      Utility arguments used to modify the output.
 +
 +      CompressionLevel             - How much to compress the file.
 +      --encoding                   - Sets the encoding to use.
 +  ```
 +
 + The following UDAs are taken into account when generating the help text:
 +
 +  * `Command`
 +
 +  * `CommandNamedArg`
 +
 +  * `CommandPositionalArg`
 +
 +  * `CommandArgGroup`
 +
 + Furthermore, certain aspects such as whether an argument is nullable or not are reflected within the help text output.
 +
 + Params:
 +  CommandT          = The command to create the help text for.
 +  ArgBinderInstance = An instance of `ArgBinder`. Currently this is unused, but in the future this may be useful.
 + ++/
struct CommandHelpText(alias CommandT, alias ArgBinderInstance = ArgBinder!())
{
    /// The `CommandInfo` for the `CommandT`, `ArgBinderInstance` combo.
    enum Info = getCommandInfoFor!(CommandT, ArgBinderInstance);

    /++
     + Creates a `HelpTextBuilderSimple` which is populated with all the information available from `CommandT`.
     +
     + Params:
     +  appName = The name of your application, this is displayed within the help text's "usage" string.
     +
     + Returns:
     +  A `HelpTextBuilderSimple` which you can then either further customise, or call `.toString` on.
     + ++/
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

    /// Returns: The result of `toBuilder(appName).toString()`.
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