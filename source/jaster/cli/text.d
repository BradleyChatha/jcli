/// Contains various utilities for displaying and formatting text.
module jaster.cli.text;

/// Contains options for the `lineWrap` function.
struct LineWrapOptions
{
    /++
     + How many characters per line, in total, are allowed.
     +
     + Do note that the `linePrefix`, as well as leading new line characters are subtracted from this limit,
     + to find the acutal total amount of characters that can be shown on each line.
     + ++/
    size_t lineCharLimit;

    /++
     + A string to prefix each line with, helpful for automatic tabulation of each newly made line.
     + ++/
    string linePrefix;
}

/++
 + Wraps a piece of text into seperate lines, based on the given options.
 +
 + Throws:
 +  `Exception` if the char limit is too small to show any text.
 +
 + Notes:
 +  Currently, this performs character-wrapping instead of word-wrapping, so words
 +  can be split between multiple lines. There is no technical reason for this outside of I'm lazy.
 +
 +  For every line created from the given `text`, the starting and ending spaces (not whitespace, just spaces)
 +  are stripped off. This is so the user doesn't have to worry about random leading/trailling spaces, making it
 +  easier to format for the general case (though specific cases might find this undesirable, I'm sorry).
 +
 +  For every line created from the given `text`, the line prefix defined in the `options` is prefixed onto every newly made line.
 +
 + Peformance:
 +  This function calculates, and reserves all required memory using a single allocation (barring bugs ;3), so it shouldn't
 +  be overly bad to use.
 + ++/
string lineWrap(const(char)[] text, const LineWrapOptions options = LineWrapOptions(120, null))
{
    import std.exception : assumeUnique, enforce;

    char[] actualText;
    const charsPerLine = options.lineCharLimit - (options.linePrefix.length + 1); // '+ 1' is for the new line char.
    size_t offset      = 0;
    
    enforce(charsPerLine > 0, "The lineCharLimit is too low. There's not enough space for any text (after factoring the prefix and ending new line characters).");
    actualText.reserve(text.length + (options.linePrefix.length * (text.length / charsPerLine)));
    
    while(offset < text.length)
    {
        size_t end = (offset + charsPerLine);
        if(end > text.length)
            end = text.length;
        
        // Strip off whitespace, so things format properly.
        while(offset < text.length && text[offset] == ' ')
        {
            offset++;
            if(end < text.length)
                end++;
        }
        
        actualText ~= options.linePrefix;
        actualText ~= text[offset..(end >= text.length) ? text.length : end];
        actualText ~= "\n";

        offset += charsPerLine;
    }

    // Don't keep the new line for the last line.
    if(actualText.length > 0 && actualText[$-1] == '\n')
        actualText = actualText[0..$-1];

    return actualText.assumeUnique;
}
///
unittest
{
    const options = LineWrapOptions(7, "\t");
    const text    = "Hello world".lineWrap(options);
    assert(text == "\tHello\n\tworld", cast(char[])text);
}

// issue #2
unittest
{
    const options = LineWrapOptions(4, "");
    const text    = lineWrap("abcdefgh", options);

    assert(text[$-1] != '\n', "lineWrap is inserting a new line at the end again.");
    assert(text == "abc\ndef\ngh", text);
}