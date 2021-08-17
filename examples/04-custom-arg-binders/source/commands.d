module commands;

import std.stdio : writeln, File;
import jcli;

@CommandDefault("Displays the contents of a file.")
struct CatCommand
{
    // Because this is of type `File`, JCLI will use our custom arg binder (in binders.d) to perform the conversion.
    //
    // NOTE: Ensure you've checked out app.d for this example, as it has changed slightly.
    @ArgPositional("file", "The file to display the contents of.")
    public File file;

    void onExecute()
    {
        foreach(line; this.file.byLine)
            writeln(line);
    }
}