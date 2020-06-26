/// Contains various utilities for displaying and formatting text.
module jaster.cli.text;

/// Contains options for the `lineWrap` function.
struct LineWrapOptions
{
    /++
     + How many characters per line, in total, are allowed.
     +
     + Do note that the `linePrefix`, `lineSuffix`, as well as leading new line characters are subtracted from this limit,
     + to find the acutal total amount of characters that can be shown on each line.
     + ++/
    size_t lineCharLimit;

    /++
     + A string to prefix each line with, helpful for automatic tabulation of each newly made line.
     + ++/
    string linePrefix;

    /++
     + Same as `linePrefix`, except it's a suffix.
     + ++/
    string lineSuffix;
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
 +  $(B This does not apply to prefixes and suffixes).
 +
 +  For every line created from the given `text`, the line prefix defined in the `options` is prefixed onto every newly made line.
 +
 + Peformance:
 +  This function calculates, and reserves all required memory using a single allocation (barring bugs ;3), so it shouldn't
 +  be overly bad to use.
 + ++/
string lineWrap(const(char)[] text, const LineWrapOptions options = LineWrapOptions(120))
{
    import std.exception : assumeUnique, enforce;

    char[] actualText;
    const charsPerLine = options.lineCharLimit - (options.linePrefix.length + + options.lineSuffix.length + 1); // '+ 1' is for the new line char.
    size_t offset      = 0;
    
    enforce(charsPerLine > 0, "The lineCharLimit is too low. There's not enough space for any text (after factoring the prefix, suffix, and ending new line characters).");

    const estimatedLines = (text.length / charsPerLine);
    actualText.reserve(text.length + (options.linePrefix.length * estimatedLines) + (options.lineSuffix.length * estimatedLines));
    
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
        actualText ~= options.lineSuffix;
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
    const options = LineWrapOptions(8, "\t", "-");
    const text    = "Hello world".lineWrap(options);
    assert(text == "\tHello-\n\tworld-", cast(char[])text);
}

// issue #2
unittest
{
    const options = LineWrapOptions(4, "");
    const text    = lineWrap("abcdefgh", options);

    assert(text[$-1] != '\n', "lineWrap is inserting a new line at the end again.");
    assert(text == "abc\ndef\ngh", text);
}

struct TextBufferChar
{
    import jaster.cli.ansi : AnsiColour, AnsiTextFlags;

    /// foreground
    AnsiColour    fg;
    /// background
    AnsiColour    bg;
    /// flags
    AnsiTextFlags flags;
    /// character
    char          value;

    /++
     + Returns:
     +  Whether this character needs an ANSI control code or not.
     + ++/
    @property
    bool usesAnsi() const
    {
        return this.fg    != AnsiColour.init
            || this.bg    != AnsiColour.init
            || this.flags != AnsiTextFlags.none;
    }
}

/++
 + A basic rectangle struct, used to specify the bounds of a `TextBufferWriter`.
 + ++/
struct TextBufferBounds
{
    /// x offset
    size_t left;
    /// y offset
    size_t top;
    /// width
    size_t width;
    /// height
    size_t height;

    /// 2D point to 1D array index.
    private size_t pointToIndex(size_t x, size_t y)
    {
        return (x + this.left) + ((this.width + this.left) * y);
    }
    ///
    unittest
    {
        import std.format : format;
        auto b = TextBufferBounds(0, 0, 5, 5);
        assert(b.pointToIndex(0, 0) == 0);
        assert(b.pointToIndex(4, 4) == 24);

        b = TextBufferBounds(1, 1, 2, 2);
        assert(b.pointToIndex(0, 0) == 1);
        assert(b.pointToIndex(1, 0) == 2);
        assert(b.pointToIndex(0, 1) == 4);
        assert(b.pointToIndex(1, 1) == 5);
    }

    private void assertPointInBounds(size_t x, size_t y, size_t bufferSize)
    {
        assert(x < this.width,  "X is larger than width.");
        assert(y < this.height, "Y is larger than height.");

        const maxIndex   = this.pointToIndex(this.width - 1, this.height - 1);
        const pointIndex = this.pointToIndex(x, y);
        assert(pointIndex <= maxIndex,  "Index is outside alloted bounds.");
        assert(pointIndex < bufferSize, "Index is outside of the TextBuffer's bounds.");
    }
}

/++
 + The main way to modify and read data into/from a `TextBuffer`.
 + ++/
struct TextBufferWriter
{
    import jaster.cli.ansi : AnsiColour, AnsiTextFlags;

    private
    {
        TextBuffer       _buffer;
        TextBufferBounds _bounds;
        AnsiColour       _fg;
        AnsiColour       _bg;
        AnsiTextFlags    _flags;

        this(TextBuffer buffer, TextBufferBounds bounds)
        {
            this._buffer = buffer;
            this._bounds = bounds;
        }
    }

    /++
     + Sets a character at a specific point.
     +
     + Params:
     +  x  = The x position of the point.
     +  y  = The y position of the point.
     +  ch = The character to place.
     + ++/
    void set(size_t x, size_t y, char ch)
    {
        const index = this._bounds.pointToIndex(x, y);
        this._bounds.assertPointInBounds(x, y, this._buffer._chars.length);

        scope value = &this._buffer._chars[index];
        value.value = ch;
        value.fg    = this._fg;
        value.bg    = this._bg;
        value.flags = this._flags;

        this._buffer.makeDirty();
    }

    /// The bounds that this `TextWriter` is constrained to.
    @property
    TextBufferBounds bounds() const
    {
        return this._bounds;
    }
    
    /// Set the foreground for any newly-written characters.
    @property
    void fg(AnsiColour fg) { this._fg = fg; }
    /// Set the background for any newly-written characters.
    @property
    void bg(AnsiColour bg) { this._bg = bg; }
    /// Set the flags for any newly-written characters.
    @property
    void flags(AnsiTextFlags flags) { this._flags = flags; }

    /// Get the foreground.
    @property
    AnsiColour fg() { return this._fg; }
    /// Get the foreground.
    @property
    AnsiColour bg() { return this._bg; }
    /// Get the foreground.
    @property
    AnsiTextFlags flags() { return this._flags; }
}

// Testing that basic operations work
unittest
{
    import std.format : format;

    auto buffer = new TextBuffer(3, 3);
    auto writer = buffer.createWriter(1, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

    foreach(ref ch; buffer._chars)
        ch.value = '0';

    writer.set(0, 0, 'A');
    writer.set(1, 0, 'B');
    writer.set(0, 1, 'C');
    writer.set(1, 1, 'D');
    writer.set(1, 2, 'E');

    assert(buffer.toStringNoDupe() == 
         "0AB"
        ~"0CD"
        ~"00E"
    , "%s".format(buffer.toStringNoDupe()));
}

// Testing that ANSI works (but only when the entire thing is a single ANSI command)
unittest
{
    import std.format : format;
    import jaster.cli.ansi : AnsiText, Ansi4BitColour, AnsiColour;

    auto buffer = new TextBuffer(3, 1);
    auto writer = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

    writer.fg = AnsiColour(Ansi4BitColour.green);
    writer.set(0, 0, 'A');
    writer.set(1, 0, 'B');
    writer.set(2, 0, 'C');

    assert(buffer.toStringNoDupe() == 
         "\033[%smABC%s".format(cast(int)Ansi4BitColour.green, AnsiText.RESET_COMMAND)
    , "%s".format(buffer.toStringNoDupe()));
}

// Testing that a mix of ANSI and plain text works.
unittest
{
    import std.format : format;
    import jaster.cli.ansi : AnsiText, Ansi4BitColour, AnsiColour;

    auto buffer = new TextBuffer(3, 3);
    auto writer = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

    writer.fg = AnsiColour(Ansi4BitColour.green);
    writer.set(0, 0, 'A');
    writer.set(1, 0, 'B');
    writer.set(2, 0, 'C');
    
    writer.fg = AnsiColour.init;
    writer.set(0, 1, 'D');
    writer.set(1, 1, 'E');
    writer.set(2, 1, 'F');

    writer.fg = AnsiColour(Ansi4BitColour.green);
    writer.set(0, 2, 'G');
    writer.set(1, 2, 'H');
    writer.set(2, 2, 'I');

    assert(buffer.toStringNoDupe() == 
         "\033[%smABC%s".format(cast(int)Ansi4BitColour.green, AnsiText.RESET_COMMAND)
        ~"DEF"
        ~"\033[%smGHI%s".format(cast(int)Ansi4BitColour.green, AnsiText.RESET_COMMAND)
    , "%s".format(buffer.toStringNoDupe()));
}

// I want reference semantics.

/++
 + An ANSI-enabled class used to easily manipulate a text buffer of a fixed width and height.
 +
 + Description:
 +  This class was inspired by the GPU component for the OpenComputers Minecraft mod.
 +
 +  I thought having something like this, where you can easily manipulate a 2D grid of characters (including colour and the like)
 +  would be quite valuable.
 +
 +  For example, the existance of this class can be the stepping stone into various other things such as: a basic (and I mean basic) console-based UI functionality;
 +  other ANSI-enabled components such as tables, which can otherwise be a pain due to the non-uniform length of ANSI text (e.g. ANSI codes being invisible characters),
 +  and so on.
 +
 + Limitations:
 +  Currently the buffer must be given a fixed size, but I'm hoping to fix this (at the very least for the y-axis) in the future.
 +  It's probably pretty easy, I just haven't looked into doing it yet.
 +
 +  Creating the final string output (via `toString`) is unoptimised. It performs pretty well for a 180x180 buffer with a sparing amount of colours,
 +  but don't expect it to perform too well right now.
 +  One big issue is that *any* change will cause the entire output to be reconstructed, which I'm sure can be changed to be a bit more optimal.
 + ++/
final class TextBuffer
{
    /// Used to specify that a writer's width or height should use all the space it can.
    enum USE_REMAINING_SPACE = size_t.max;

    private
    {
        TextBufferChar[] _chars;
        size_t           _width;
        size_t           _height;

        char[] _output;
        char[] _cachedOutput;

        void makeDirty()
        {
            this._cachedOutput = null;
        }
    }

    /++
     + Creates a new `TextBuffer` with the specified width and height.
     +
     + Params:
     +  width  = How many characters each line can contain.
     +  height = How many lines in total there are.
     + ++/
    this(size_t width, size_t height)
    {
        this._width        = width;
        this._height       = height;
        this._chars.length = width * height;
    }
    
    /++
     + Creates a new `TextBufferWriter` bound to this `TextBuffer`.
     +
     + Description:
     +  The only way to read and write to certain sections of a `TextBuffer` is via the `TextBufferWriter`.
     +
     +  Writers are constrained to the given `bounds`, allowing careful control of where certain parts of your code are allowed to modify.
     +
     + Params:
     +  bounds = The bounds to constrain the writer to.
     +           You can use `TextBuffer.USE_REMAINING_SPACE` as the width and height to specify that the writer's width/height will use
     +           all the space that they have available.
     +
     + Returns:
     +  A `TextBufferWriter`, constrained to the given `bounds`, which is also bounded to this specific `TextBuffer`.
     + ++/
    TextBufferWriter createWriter(TextBufferBounds bounds)
    {
        if(bounds.width == USE_REMAINING_SPACE)
            bounds.width = this._width - bounds.left;

        if(bounds.height == USE_REMAINING_SPACE)
            bounds.height = this._height - bounds.top;

        return TextBufferWriter(this, bounds);
    }

    /// ditto.
    TextBufferWriter createWriter(size_t left, size_t top, size_t width, size_t height)
    {
        return this.createWriter(TextBufferBounds(left, top, width, height));
    }

    // This is a very slow (well, I assume, tired code is usually slow code), very naive function, but as long as it works for now, then it can be rewritten later.
    /++
     + Converts this `TextBuffer` into a string.
     +
     + Description:
     +  The value returned by this function is a slice into an internal buffer. This buffer gets
     +  reused between every call to this function.
     +
     +  So basically, if you don't need the guarentees of `immutable` (which `toString` will provide), and are aware
     +  that the value from this function can and will change, then it is faster to use this function as otherwise, with `toString`,
     +  a call to `.idup` is made.
     +
     + Optimisation:
     +  This function isn't terribly well optimised in all honesty, but that isn't really too bad of an issue because, at least on
     +  my computer, it only takes around 2ms to create the output for a 180x180 grid, in the worst case scenario - where every character
     +  requires a different ANSI code.
     +
     +  Worst case is O(3n), best case is O(2n), backtracking only occurs whenever a character is found that cannot be written with the same ANSI codes
     +  as the previous one(s), so the worst case only occurs if every single character requires a new ANSI code.
     +
     +  Small test output - `[WORST CASE | SHARED] ran 1000 times -> 1 sec, 817 ms, 409 us, and 5 hnsecs -> AVERAGING -> 1 ms, 817 us, and 4 hnsecs`
     +
     +  While I haven't tested memory usage, by default all of the initial allocations will be `(width * height) * 2`, which is then reused between runs.
     +
     +  This function will initially set the internal buffer to `width * height * 2` in an attempt to overallocate more than it needs.
     +
     +  This function caches its output (using the same buffer), and will reuse the cached output as long as there hasn't been any changes.
     +
     +  If there *have* been changes, then the internal buffer is simply reused without clearing or reallocation.
     +
     +  Finally, this function will automatically group together ranges of characters that can be used with the same ANSI codes, as an
     +  attempt to minimise the amount of characters actually required. So the more characters in a row there are that are the same colour and style,
     +  the faster this function performs.
     +
     + Returns:
     +  An (internally mutable) slice to this class' output buffer.
     + ++/
    const(char[]) toStringNoDupe()
    {
        import std.algorithm   : joiner;
        import std.utf         : byChar;
        import jaster.cli.ansi : AnsiComponents, populateActiveAnsiComponents, AnsiText;

        if(this._output is null)
            this._output = new char[this._chars.length * 2]; // Optimistic overallocation, to lower amount of resizes

        if(this._cachedOutput !is null)
            return this._cachedOutput;

        size_t outputCursor;
        size_t ansiCharCursor;

        // Auto-increments outputCursor while auto-resizing the output buffer.
        void putChar(char c)
        {
            if(outputCursor >= this._output.length)
                this._output.length *= 2;

            this._output[outputCursor++] = c;
        }
        
        // Finds the next sequence of characters that have the same foreground, background, and flags.
        // e.g. the next sequence of characters that can be used with the same ANSI command.
        // Returns `null` once we reach the end.
        TextBufferChar[] getNextAnsiRange()
        {
            if(ansiCharCursor >= this._chars.length)
                return null;

            const startCursor = ansiCharCursor;
            const start       = this._chars[ansiCharCursor++];
            while(ansiCharCursor < this._chars.length)
            {
                auto current  = this._chars[ansiCharCursor++];
                current.value = start.value; // cheeky way to test equality.
                if(start != current)
                {
                    ansiCharCursor--;
                    break;
                }
            }

            return this._chars[startCursor..ansiCharCursor];
        }

        auto sequence = getNextAnsiRange();
        while(sequence.length > 0)
        {
            const first = sequence[0]; // Get the first character so we can get the ANSI settings for the entire sequence.
            if(first.usesAnsi)
            {
                AnsiComponents components;
                const activeCount = components.populateActiveAnsiComponents(first.fg, first.bg, first.flags);

                putChar('\033');
                putChar('[');
                foreach(ch; components[0..activeCount].joiner(";").byChar)
                    putChar(ch);
                putChar('m');
            }

            foreach(ansiChar; sequence)
                putChar(ansiChar.value);

            if(first.usesAnsi)
            {
                foreach(ch; AnsiText.RESET_COMMAND)
                    putChar(ch);
            }

            sequence = getNextAnsiRange();
        }

        this._cachedOutput = this._output[0..outputCursor];
        return this._cachedOutput;
    }

    /// Returns: `toStringNoDupe`, but then `.idup`s the result.
    override string toString()
    {
        return this.toStringNoDupe().idup;
    }
}