module commands;

import jaster.cli;

// NOTE: This example is just something quickly thrown together to show a very manual kind of style for using `TextBuffer.
//
//       Most positions and sizes were manually calculated to keep the code small, but in the real world you'd likely have these
//       things calculated within the code itself.
//
//       I *am* planning on adding a proper table component into JCLI at some point, so don't think that this will be the only
//       way that JCLI helps you make tables (in the future!). It will likely be built off of `TextBuffer` though, as it provides
//       a very convenient, and decently performing interface for Ansi-enabled text elements to be built on top of.

@Command("fixed", "Shows a table made using TextBuffer in a fixed size style.")
struct FixedTableCommand
{
    void onExecute()
    {
        auto options = TextBufferOptions(TextBufferLineMode.addNewLine); // Add a new line character between each line.
        auto buffer  = new TextBuffer(80, 7, options);

        const ALL    = TextBuffer.USE_REMAINING_SPACE; // Easier to read.
        alias Colour = AnsiColour; // To get around some weird behaviour that the `with` statement is causing.
        alias Flags  = AnsiTextFlags; // ditto
        with(buffer) with(Flags)
        {
            // Create all the borders in green.
            // Using a "with" statement is one way to make working with a writer easy to use.
            // The other code below shows another way - using the fluent interface pattern.
            with(createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE))
            {
                fg = Colour(Ansi4BitColour.green);
                fill(0,     0,      ALL,    ALL,    ' '); // Every character defaults to space
                fill(0,     0,      ALL,    1,      '#'); // Top horizontal border
                fill(0,     2,      ALL,    1,      '='); // Horizontal border under column names
                fill(0,     4,      ALL,    1,      '-'); // Horizontal border under values
                fill(0,     1,      1,      ALL,    '|'); // Left-most vertical border
                fill(79,    1,      1,      ALL,    '|'); // Right-most vertical border
                fill(21,    1,      1,      ALL,    '|'); // Vertical border after Name column
                fill(36,    1,      1,      ALL,    '|'); // Vertical border after Age column
                fill(0,     6,      ALL,    1,      '#'); // Bottom horizontal border
            }

            // Create seperate writers (very cheap) to easily confine and calculate the space we work with.
            // The fluent interface makes this less cumbersome than it'd otherwise be.
            createWriter(2, 1, 20, 5)
                .write(7, 0, "Name")
                .write(1, 2, "Bradley".ansi.fg(Ansi4BitColour.red))
                .write(1, 4, "Andy".ansi.fg(Ansi4BitColour.blue));
            createWriter(23, 1, 13, 5)
                .write(5, 0, "Age")
                .fg(Colour(Ansi4BitColour.brightBlue))
                .flags(underline | bold) // Because of the AnsiTextFlags `with` statement.
                .write(1, 2, "21")
                .write(1, 4, "200");
            createWriter(38, 1, 51, 5)
                .write(14, 0, "Description")
                .fg(Colour(Ansi4BitColour.magenta))
                .write(1,  2, "Hates being alive.")
                .write(1,  4, "Andy + clones = rule world");
        }

        UserIO.logInfof(buffer.toString());
    }
}

@Command("dynamic", "Shows a table made using TextBuffer in a dynamically sized style.")
struct DynamicTableCommand
{
    void onExecute()
    {
        auto options = TextBufferOptions(TextBufferLineMode.addNewLine); // Add a new line character between each line.
        auto buffer  = new TextBuffer(80, 0, options);

        const ALL = TextBuffer.USE_REMAINING_SPACE; // Easier to read.

        // Create top-border; column names, and border under column names.
        buffer.height = 3;
        buffer.createWriter(0, 0, ALL, ALL)
              .fill(0, 0, ALL, ALL, ' ')                    // Default every character to a space
              .write(9,  1, "Name")                         // Write the column names first, as we'll switch foreground later
              .write(27, 1, "Age")                          //
              .write(52, 1, "Description")                  //
              .fg(AnsiColour(Ansi4BitColour.green))         // Borders will be in green
              .fill(0,      0,      ALL,    1,      '#')    // Top border
              .fill(0,      1,      1,      ALL,    '|')    // Left hand vertical border
              .fill(21,     1,      1,      ALL,    '|')    // Vertical border after Name column
              .fill(36,     1,      1,      ALL,    '|')    // Vertical border after Age column
              .fill(79,     1,      1,      ALL,    '|')    // Vertical border after Description column
              .fill(1,      2,      20,     1,      '=')    // Horizontal border under column names
              .fill(22,     2,      14,     1,      '=')    //
              .fill(37,     2,      42,     1,      '=');   //

        // Function that can add a new row for us.
        void addRow(string name, string age, string description)
        {
            const LINES_PER_ROW = 2; // One for the data, one of the underside border.
            const startHeight   = buffer.height;
            buffer.height       = startHeight + LINES_PER_ROW;

            // Default the new lines as spaces
            buffer.createWriter(0, startHeight, ALL, ALL)
                  .fill(0, 0, ALL, ALL, ' ');
            
            // One writer per column, to keep things constrained.
            buffer.createWriter(0, startHeight, 22, 1)
                  .fg(AnsiColour(Ansi4BitColour.red))
                  .write(2, 0, name);

            buffer.createWriter(22, startHeight, 15, 1)
                  .fg(AnsiColour(Ansi4BitColour.brightBlue))
                  .flags(AnsiTextFlags.underline | AnsiTextFlags.bold)
                  .write(1, 0, age);

            buffer.createWriter(37, startHeight, 43, 1)
                  .fg(AnsiColour(Ansi4BitColour.magenta))
                  .write(1, 0, description);

            // Add in the borders
            // NOTE: An alternative way to lay out things is to do the borders for the entire table at the very end.
            buffer.createWriter(0, startHeight, ALL, 2)
                  .fg(AnsiColour(Ansi4BitColour.green))
                  .fill(0,  1,  ALL, 1,   '=')
                  .fill(0,  0,  1,   ALL, '|')
                  .fill(21, 0,  1,   ALL, '|')
                  .fill(36, 0,  1,   ALL, '|')
                  .fill(79, 0,  1,   ALL, '|');
        }

        addRow("Bradley", "21",   "Spent way too much effort on TextBuffer.");
        addRow("Andy",    "4000", "Dreaming about his next 3 polytunnels.");

        UserIO.logInfof(buffer.toString());
    }
}