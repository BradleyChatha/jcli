module commands;

import std.stdio : writeln, File;
import jaster.cli;

@Command(null, "Displays the contents of a file.")
class CatCommand
{
    // Because this is of type `File`, JCLI will use our custom arg binder (in binders.d) to perform the conversion.
    //
    // NOTE: Ensure you've checked out app.d for this example, as it has changed slightly.
    @CommandPositionalArg(0, "The file to display the contents of.")
    public File file;

    void onExecute()
    {
        foreach(line; this.file.byLine)
            writeln(line);
    }
}