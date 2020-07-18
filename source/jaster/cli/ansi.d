/// Utilities to create ANSI coloured text.
module jaster.cli.ansi;

import std.traits : EnumMembers, isSomeChar;
import std.typecons : Flag;

alias IsBgColour = Flag!"isBackgroundAnsi";

/++
 + Defines what type of colour an `AnsiColour` stores.
 + ++/
enum AnsiColourType
{
    /// Default, failsafe.
    none,

    /// 4-bit colours.
    fourBit,

    /// 8-bit colours.
    eightBit,

    /// 24-bit colours.
    rgb
}

/++
 + An enumeration of standard 4-bit colours.
 +
 + These colours will have the widest support between platforms.
 + ++/
enum Ansi4BitColour
{
    // To get Background code, just add 10
    black           = 30,
    red             = 31,
    green           = 32,
    /// On Powershell, this is displayed as a very white colour.
    yellow          = 33,
    blue            = 34,
    magenta         = 35,
    cyan            = 36,
    /// More gray than true white, use `BrightWhite` for true white.
    white           = 37,
    /// Grayer than `White`.
    brightBlack     = 90,
    brightRed       = 91,
    brightGreen     = 92,
    brightYellow    = 93,
    brightBlue      = 94,
    brightMagenta   = 95,
    brightCyan      = 96,
    brightWhite     = 97
}

private union AnsiColourUnion
{
    Ansi4BitColour fourBit;
    ubyte          eightBit;
    AnsiRgbColour  rgb;
}

/// A very simple RGB struct, used to store an RGB value.
struct AnsiRgbColour
{
    /// The red component.
    ubyte r;
    
    /// The green component.
    ubyte g;

    /// The blue component.
    ubyte b;
}

/++
 + Contains either a 4-bit, 8-bit, or 24-bit colour, which can then be turned into
 + an its ANSI form (not a valid command, just the actual values needed to form the final command).
 + ++/
@safe
struct AnsiColour
{
    private 
    {
        AnsiColourUnion _value;
        AnsiColourType  _type;
        IsBgColour      _isBg;

        this(IsBgColour isBg)
        {
            this._isBg = isBg;
        }
    }

    /// A variant of `.init` that is used for background colours.
    static immutable bgInit = AnsiColour(IsBgColour.yes);

    /// Ctor for an `AnsiColourType.fourBit`.
    @nogc
    this(Ansi4BitColour fourBit, IsBgColour isBg = IsBgColour.no) nothrow pure
    {
        this._value.fourBit = fourBit;
        this._type          = AnsiColourType.fourBit;
        this._isBg          = isBg;
    }

    /// Ctor for an `AnsiColourType.eightBit`
    @nogc
    this(ubyte eightBit, IsBgColour isBg = IsBgColour.no) nothrow pure
    {
        this._value.eightBit = eightBit;
        this._type           = AnsiColourType.eightBit;
        this._isBg           = isBg;
    }

    /// Ctor for an `AnsiColourType.rgb`.
    @nogc
    this(ubyte r, ubyte g, ubyte b, IsBgColour isBg = IsBgColour.no) nothrow pure
    {        
        this._value.rgb = AnsiRgbColour(r, g, b);
        this._type      = AnsiColourType.rgb;
        this._isBg      = isBg;
    }

    /// ditto
    @nogc
    this(AnsiRgbColour rgb, IsBgColour isBg = IsBgColour.no) nothrow pure
    {
        this(rgb.r, rgb.g, rgb.b, isBg);
    }

    /++
     + Notes:
     +  To create a valid ANSI command from these values, prefix it with "\033[" and suffix it with "m", then place your text after it.
     +
     + Returns:
     +  This `AnsiColour` as an incomplete ANSI command.
     + ++/
    string toString() const pure
    {
        import std.format : format;

        final switch(this._type) with(AnsiColourType)
        {
            case none: return null;
            case fourBit:
                auto value = cast(int)this._value.fourBit;
                return "%s".format(this._isBg ? value + 10 : value);

            case eightBit:
                auto marker = (this._isBg) ? "48" : "38";
                auto value  = this._value.eightBit;
                return "%s;5;%s".format(marker, value);

            case rgb:
                auto marker = (this._isBg) ? "48" : "38";
                auto value  = this._value.rgb;
                return "%s;2;%s;%s;%s".format(marker, value.r, value.g, value.b);
        }
    }

    @safe @nogc nothrow pure:
    
    /// Returns: The `AnsiColourType` of this `AnsiColour`.
    @property
    AnsiColourType type() const
    {
        return this._type;
    }

    /// Returns: Whether this `AnsiColour` is for a background or not (it affects the output!).
    @property
    IsBgColour isBg() const
    {
        return this._isBg;
    }

    /// ditto
    @property
    void isBg(IsBgColour bg)
    {
        this._isBg = bg;
    }

    /// ditto
    @property
    void isBg(bool bg)
    {
        this._isBg = cast(IsBgColour)bg;
    }

    /++
     + Assertions:
     +  This colour's type must be `AnsiColourType.fourBit`
     +
     + Returns:
     +  This `AnsiColour` as an `Ansi4BitColour`.
     + ++/
    @property
    Ansi4BitColour asFourBit()
    {
        assert(this.type == AnsiColourType.fourBit);
        return this._value.fourBit;
    }

    /++
     + Assertions:
     +  This colour's type must be `AnsiColourType.eightBit`
     +
     + Returns:
     +  This `AnsiColour` as a `ubyte`.
     + ++/
    @property
    ubyte asEightBit()
    {
        assert(this.type == AnsiColourType.eightBit);
        return this._value.eightBit;
    }

    /++
     + Assertions:
     +  This colour's type must be `AnsiColourType.rgb`
     +
     + Returns:
     +  This `AnsiColour` as an `AnsiRgbColour`.
     + ++/
    @property
    AnsiRgbColour asRgb()
    {
        assert(this.type == AnsiColourType.rgb);
        return this._value.rgb;
    }
}

enum AnsiTextFlags
{
    none      = 0,
    bold      = 1 << 0,
    dim       = 1 << 1,
    italic    = 1 << 2,
    underline = 1 << 3,
    slowBlink = 1 << 4,
    fastBlink = 1 << 5,
    invert    = 1 << 6,
    strike    = 1 << 7
}

private immutable FLAG_COUNT = EnumMembers!AnsiTextFlags.length - 1; // - 1 to ignore the `none` option
private immutable FLAG_AS_ANSI_CODE_MAP = 
[
    // Index correlates to the flag's position in the bitmap.
    // So bold would be index 0.
    // Strike would be index 7, etc.
    
    "1", // 0
    "2", // 1
    "3", // 2
    "4", // 3
    "5", // 4
    "6", // 5
    "7", // 6
    "9"  // 7
];
static assert(FLAG_AS_ANSI_CODE_MAP.length == FLAG_COUNT);

/// An alias for a string[] containing exactly enough elements for the following ANSI strings:
///
/// * [0]    = Foreground ANSI code.
/// * [1]    = Background ANSI code.
/// * [2..n] = The code for any `AnsiTextFlags` that are set.
alias AnsiComponents = string[2 + FLAG_COUNT]; // fg + bg + all supported flags.

/++
 + Populates an `AnsiComponents` with all the strings required to construct a full ANSI command string.
 +
 + Params:
 +  components = The `AnsiComponents` to populate. $(B All values will be set to null before hand).
 +  fg         = The `AnsiColour` representing the foreground.
 +  bg         = The `AnsiColour` representing the background.
 +  flags      = The `AnsiTextFlags` to apply.
 +
 + Returns:
 +  How many components in total are active.
 +
 + See_Also:
 +  `createAnsiCommandString` to create an ANSI command string from an `AnsiComponents`.
 + ++/
@safe
size_t populateActiveAnsiComponents(ref scope AnsiComponents components, AnsiColour fg, AnsiColour bg, AnsiTextFlags flags) pure
{
    size_t componentIndex;
    components[] = null;

    if(fg.type != AnsiColourType.none)
        components[componentIndex++] = fg.toString();

    if(bg.type != AnsiColourType.none)
        components[componentIndex++] = bg.toString();

    foreach(i; 0..FLAG_COUNT)
    {
        if((flags & (1 << i)) > 0)
            components[componentIndex++] = FLAG_AS_ANSI_CODE_MAP[i];
    }

    return componentIndex;
}

/++
 + Creates an ANSI command string using the given active `components`.
 +
 + Params:
 +  components = An `AnsiComponents` that has been populated with flags, ideally from `populateActiveAnsiComponents`.
 +
 + Returns:
 +  All of the component strings inside of `components`, formatted as a valid ANSI command string.
 + ++/
@safe
string createAnsiCommandString(ref scope AnsiComponents components) pure
{
    import std.algorithm : joiner, filter;
    import std.format    : format;

    return "\033[%sm".format(components[].filter!(s => s !is null).joiner(";")); 
}

/// Contains a single character, with ANSI styling.
@safe
struct AnsiChar 
{
    import jaster.cli.ansi : AnsiColour, AnsiTextFlags, IsBgColour;

    /// foreground
    AnsiColour    fg;
    /// background by reference
    AnsiColour    bgRef;
    /// flags
    AnsiTextFlags flags;
    /// character
    char          value;

    @nogc nothrow pure:

    /++
     + Returns:
     +  Whether this character needs an ANSI control code or not.
     + ++/
    @property
    bool usesAnsi() const
    {
        return this.fg    != AnsiColour.init
            || (this.bg   != AnsiColour.init && this.bg != AnsiColour.bgInit)
            || this.flags != AnsiTextFlags.none;
    }

    /// Set the background (automatically sets `value.isBg` to `yes`)
    @property
    void bg(AnsiColour value)
    {
        value.isBg = IsBgColour.yes;
        this.bgRef = value;
    }

    /// Get the background.
    @property
    AnsiColour bg() const { return this.bgRef; }
}

/++
 + A struct used to compose together a piece of ANSI text.
 +
 + Notes:
 +  A reset command (`\033[0m`) is automatically appended, so you don't have to worry about that.
 +
 +  This struct is simply a wrapper around `AnsiColour`, `AnsiTextFlags` types, and the `populateActiveAnsiComponents` and
 +  `createAnsiCommandString` functions.
 +
 + Usage:
 +  This struct uses the Fluent Builder pattern, so you can easily string together its
 +  various functions when creating your text.
 +
 +  Set the background colour with `AnsiText.bg`
 +
 +  Set the foreground/text colour with `AnsiText.fg`
 +
 +  AnsiText uses `toString` to provide the final output, making it easily used with the likes of `writeln` and `format`.
 + ++/
@safe
struct AnsiText
{
    import std.format : format;

    /// The ANSI command to reset all styling.
    public static const RESET_COMMAND = "\033[0m";

    @nogc
    private nothrow pure
    {
        string        _cachedText;
        const(char)[] _text;
        AnsiColour    _fg;
        AnsiColour    _bg;
        AnsiTextFlags _flags;

        ref AnsiText setColour(T)(ref AnsiColour colour, T value, IsBgColour isBg) return
        {
            colour = AnsiColour(value, isBg);
            this._cachedText = null;
            return this;
        }

        ref AnsiText setColour4(ref AnsiColour colour, Ansi4BitColour value, IsBgColour isBg) return
        {
            return this.setColour(colour, Ansi4BitColour(value), isBg);
        }

        ref AnsiText setColour8(ref AnsiColour colour, ubyte value, IsBgColour isBg) return
        {
            return this.setColour(colour, value, isBg);
        }

        ref AnsiText setColourRgb(ref AnsiColour colour, ubyte r, ubyte g, ubyte b, IsBgColour isBg) return
        {
            return this.setColour(colour, AnsiRgbColour(r, g, b), isBg);
        }

        ref AnsiText setFlag(AnsiTextFlags flag, bool isSet) return
        {
            if(isSet)
                this._flags |= flag;
            else
                this._flags &= ~flag;

            this._cachedText = null;
            return this;
        }
    }

    ///
    @safe @nogc
    this(const(char)[] text) nothrow pure
    {
        this._text = text;
        this._bg.isBg = true;
    }

    /++
     + Notes:
     +  If no ANSI escape codes are used, then this function will simply return a `.idup` of the
     +  text provided to this struct's constructor.
     +
     + Returns:
     +  The ANSI escape-coded text.
     + ++/
    @safe
    string toString() pure
    {
        if(this._bg.type == AnsiColourType.none 
        && this._fg.type == AnsiColourType.none
        && this._flags   == AnsiTextFlags.none)
            this._cachedText = this._text.idup;

        if(this._cachedText !is null)
            return this._cachedText;

        // Find all 'components' that have been enabled
        AnsiComponents components;
        components.populateActiveAnsiComponents(this._fg, this._bg, this._flags);

        // Then join them together.
        this._cachedText = "%s%s%s".format(
            components.createAnsiCommandString(), 
            this._text,
            AnsiText.RESET_COMMAND
        ); 
        return this._cachedText;
    }

    @safe @nogc nothrow pure:

    /// Sets the foreground/background as a 4-bit colour. Widest supported option.
    ref AnsiText fg(Ansi4BitColour fourBit) return    { return this.setColour4  (this._fg, fourBit, IsBgColour.no);   }
    /// ditto
    ref AnsiText bg(Ansi4BitColour fourBit) return    { return this.setColour4  (this._bg, fourBit, IsBgColour.yes);  }

    /// Sets the foreground/background as an 8-bit colour. Please see this image for reference: https://i.stack.imgur.com/KTSQa.png
    ref AnsiText fg(ubyte eightBit) return            { return this.setColour8  (this._fg, eightBit, IsBgColour.no);  }
    /// ditto
    ref AnsiText bg(ubyte eightBit) return            { return this.setColour8  (this._bg, eightBit, IsBgColour.yes); }

    /// Sets the forground/background as an RGB colour.
    ref AnsiText fg(ubyte r, ubyte g, ubyte b) return { return this.setColourRgb(this._fg, r, g, b, IsBgColour.no);   }
    /// ditto
    ref AnsiText bg(ubyte r, ubyte g, ubyte b) return { return this.setColourRgb(this._bg, r, g, b, IsBgColour.yes);  }

    /// Sets whether the text is bold.
    ref AnsiText bold     (bool isSet = true) return { return this.setFlag(AnsiTextFlags.bold,      isSet); }
    /// Sets whether the text is dimmed (opposite of bold).
    ref AnsiText dim      (bool isSet = true) return { return this.setFlag(AnsiTextFlags.dim,       isSet); }
    /// Sets whether the text should be displayed in italics.
    ref AnsiText italic   (bool isSet = true) return { return this.setFlag(AnsiTextFlags.italic,    isSet); }
    /// Sets whether the text has an underline.
    ref AnsiText underline(bool isSet = true) return { return this.setFlag(AnsiTextFlags.underline, isSet); }
    /// Sets whether the text should blink slowly.
    ref AnsiText slowBlink(bool isSet = true) return { return this.setFlag(AnsiTextFlags.slowBlink, isSet); }
    /// Sets whether the text should blink rapidly.
    ref AnsiText fastBlink(bool isSet = true) return { return this.setFlag(AnsiTextFlags.fastBlink, isSet); }
    /// Sets whether the text should have its fg and bg colours inverted.
    ref AnsiText invert   (bool isSet = true) return { return this.setFlag(AnsiTextFlags.invert,    isSet); }
    /// Sets whether the text should have a strike through it.
    ref AnsiText strike   (bool isSet = true) return { return this.setFlag(AnsiTextFlags.strike,    isSet); }

    /// Sets the `AnsiTextFlags` for this piece of text.
    ref AnsiText setFlags(AnsiTextFlags flags) return 
    { 
        this._flags = flags; 
        return this; 
    }

    /// Gets the `AnsiTextFlags` for this piece of text.
    @property
    AnsiTextFlags flags() const
    {
        return this._flags;
    }

    /// Gets the `AnsiColour` used as the foreground (text colour).
    //@property
    AnsiColour fg() const
    {
        return this._fg;
    }

    /// Gets the `AnsiColour` used as the background.
    //@property
    AnsiColour bg() const
    {
        return this._bg;
    }

    /// Returns: The raw text of this `AnsiText`.
    @property
    const(char[]) rawText() const
    {
        return this._text;
    }
}

/++
 + A helper UFCS function used to fluently convert any piece of text into an `AnsiText`.
 + ++/
@safe @nogc
AnsiText ansi(const char[] text) nothrow pure
{
    return AnsiText(text);
}
///
@safe
unittest
{
    assert("Hello".ansi.toString() == "Hello");
    assert("Hello".ansi.fg(Ansi4BitColour.black).toString() == "\033[30mHello\033[0m");
    assert("Hello".ansi.bold.strike.bold(false).italic.toString() == "\033[3;9mHello\033[0m");
}

/// Describes whether an `AnsiSectionBase` contains a piece of text, or an ANSI escape sequence.
enum AnsiSectionType
{
    /// Default/Failsafe value
    ERROR,
    text,
    escapeSequence
}

/++
 + Contains an section of text, with an additional field to specify whether the
 + section contains plain text, or an ANSI escape sequence.
 +
 + Params:
 +  Char = What character type is used.
 +
 + See_Also:
 +  `AnsiSection` alias for ease-of-use.
 + ++/
@safe
struct AnsiSectionBase(Char)
if(isSomeChar!Char)
{
    /// The type of data stored in this section.
    AnsiSectionType type;

    /++
     + The value of this section.
     +
     + Notes:
     +  For sections that contain an ANSI sequence (`AnsiSectionType.escapeSequence`), the starting characters (`\033[`) and
     +  ending character ('m') are stripped from this value.
     + ++/
    const(Char)[] value;

    // Making comparisons with enums can be a bit too clunky, so these helper functions should hopefully
    // clean things up.

    @safe @nogc nothrow pure const:

    /// Returns: Whether this section contains plain text.
    bool isTextSection()
    {
        return this.type == AnsiSectionType.text;
    }

    /// Returns: Whether this section contains an ANSI escape sequence.
    bool isSequenceSection()
    {
        return this.type == AnsiSectionType.escapeSequence;
    }
}

/// An `AnsiSectionBase` that uses `char` as the character type, a.k.a what's going to be used 99% of the time.
alias AnsiSection = AnsiSectionBase!char;

/++
 + An InputRange that turns an array of `Char`s into a range of `AnsiSection`s.
 +
 + This isn't overly useful on its own, and is mostly so other ranges can be built on top of this.
 +
 + Notes:
 +  Please see `AnsiSectionBase.value`'s documentation comment, as it explains that certain characters of an ANSI sequence are
 +  omitted from the final output (the starting `"\033["` and the ending `'m'` specifically).
 +
 + Limitations:
 +  To prevent the need for allocations or possibly buggy behaviour regarding a reusable buffer, this range can only work directly
 +  on arrays, and not any generic char range.
 + ++/
@safe
struct AnsiSectionRange(Char)
if(isSomeChar!Char)
{
    private
    {
        const(Char)[]        _input;
        size_t               _index;
        AnsiSectionBase!Char _current;
    }

    @nogc pure nothrow:

    /// Creates an `AnsiSectionRange` from the given `input`.
    this(const Char[] input)
    {
        this._input = input;
        this.popFront();
    }

    /// Returns: The latest-parsed `AnsiSection`.
    AnsiSectionBase!Char front()
    {
        return this._current;
    }

    /// Returns: Whether there's no more text to parse.
    bool empty()
    {
        return this._current == AnsiSectionBase!Char.init;
    }

    /// Parses the next section.
    void popFront()
    {
        if(this._index >= this._input.length)
        {
            this._current = AnsiSectionBase!Char.init; // .empty condition.
            return;
        }
        
        const isNextSectionASequence = this._index <= this._input.length - 2
                                    && this._input[this._index..this._index + 2] == "\033[";

        // Read until end, or until an 'm'.
        if(isNextSectionASequence)
        {
            // Skip the start codes
            this._index += 2;

            bool foundM  = false;
            size_t start = this._index;
            for(; this._index < this._input.length; this._index++)
            {
                if(this._input[this._index] == 'm')
                {
                    foundM = true;
                    break;
                }
            }

            // I don't know 100% what to do here, but, if we don't find an 'm' then we'll treat the sequence as text, since it's technically malformed.
            this._current.value = this._input[start..this._index];
            if(foundM)
            {
                this._current.type = AnsiSectionType.escapeSequence;
                this._index++; // Skip over the 'm'
            }
            else
                this._current.type = AnsiSectionType.text;

            return;
        }

        // Otherwise, read until end, or an ansi start sequence.
        size_t start              = this._index;
        bool   foundEscape        = false;
        bool   foundStartSequence = false;

        for(; this._index < this._input.length; this._index++)
        {
            const ch = this._input[this._index];

            if(ch == '[' && foundEscape)
            {
                foundStartSequence = true;
                this._index -= 1; // To leave the start code for the next call to popFront.
                break;
            }

            foundEscape = (ch == '\033');
        }

        this._current.value = this._input[start..this._index];
        this._current.type  = AnsiSectionType.text;
    }
}

/// Returns: A new `AnsiSectionRange` using the given `input`.
@safe @nogc
AnsiSectionRange!Char asAnsiSections(Char)(const Char[] input) nothrow pure
if(isSomeChar!Char)
{
    return AnsiSectionRange!Char(input);
}

@("Test AnsiSectionRange for only text, only ansi, and a mixed string.")
@safe
unittest
{
    import std.array : array;

    const onlyText = "Hello, World!";
    const onlyAnsi = "\033[30m\033[0m";
    const mixed    = "\033[30mHello, \033[0mWorld!";

    void test(string input, AnsiSection[] expectedSections)
    {
        import std.algorithm : equal;
        import std.format    : format;

        auto range = input.asAnsiSections();
        assert(range.equal(expectedSections), "Expected:\n%s\nGot:\n%s".format(expectedSections, range));
    }

    test(onlyText, [AnsiSection(AnsiSectionType.text, "Hello, World!")]);
    test(onlyAnsi, [AnsiSection(AnsiSectionType.escapeSequence, "30"), AnsiSection(AnsiSectionType.escapeSequence, "0")]);
    test(mixed,
    [
        AnsiSection(AnsiSectionType.escapeSequence, "30"),
        AnsiSection(AnsiSectionType.text,           "Hello, "),
        AnsiSection(AnsiSectionType.escapeSequence, "0"),
        AnsiSection(AnsiSectionType.text,           "World!")
    ]);

    assert(mixed.asAnsiSections.array.length == 4);
}

private enum MAX_SGR_ARGS         = 4;     // 2;r;g;b being max... I think
private immutable DEFAULT_SGR_ARG = ['0']; // Missing params are treated as 0

@trusted @nogc
private void executeSgrCommand(ubyte command, ubyte[MAX_SGR_ARGS] args, ref AnsiColour foreground, ref AnsiColour background, ref AnsiTextFlags flags) nothrow pure
{
    // Pre-testing me: I hope to god this works first time.
    // During-testing me: It didn't
    switch(command)
    {
        case 0:
            foreground = AnsiColour.init;
            background = AnsiColour.init;
            flags      = AnsiTextFlags.init;
            break;

        case 1: flags |= AnsiTextFlags.bold;        break;
        case 2: flags |= AnsiTextFlags.dim;         break;
        case 3: flags |= AnsiTextFlags.italic;      break;
        case 4: flags |= AnsiTextFlags.underline;   break;
        case 5: flags |= AnsiTextFlags.slowBlink;   break;
        case 6: flags |= AnsiTextFlags.fastBlink;   break;
        case 7: flags |= AnsiTextFlags.invert;      break;
        case 9: flags |= AnsiTextFlags.strike;      break;

        case 22: flags &= ~(AnsiTextFlags.bold | AnsiTextFlags.dim);            break;
        case 23: flags &= ~AnsiTextFlags.italic;                                break;
        case 24: flags &= ~AnsiTextFlags.underline;                             break;
        case 25: flags &= ~(AnsiTextFlags.slowBlink | AnsiTextFlags.fastBlink); break;
        case 27: flags &= ~AnsiTextFlags.invert;                                break;
        case 29: flags &= ~AnsiTextFlags.strike;                                break;

        //   FG      +FG       BG       +BG
        case 30: case 90: case 40: case 100:
        case 31: case 91: case 41: case 101:
        case 32: case 92: case 42: case 102:
        case 33: case 93: case 43: case 103:
        case 34: case 94: case 44: case 104:
        case 35: case 95: case 45: case 105:
        case 36: case 96: case 46: case 106:
        case 37: case 97: case 47: case 107:
            scope colour = (command >= 30 && command <= 37) || (command >= 90 && command <= 97)
                           ? &foreground
                           : &background;
            *colour = AnsiColour(cast(Ansi4BitColour)command);
            break;

        case 38: case 48:
            const isFg   = (command == 38);
            scope colour = (isFg) ? &foreground : &background;
                 *colour = (args[0] == 5) // 5 = Pallette, 2 = RGB.
                           ? AnsiColour(args[1])
                           : (args[0] == 2)
                             ? AnsiColour(args[1], args[2], args[3])
                             : AnsiColour.init;
                colour.isBg = cast(IsBgColour)!isFg;
            break;

        default: break; // Ignore anything we don't support or care about.
    }
}

/++
 + An InputRange that converts a range of `AnsiSection`s into a range of `AnsiChar`s.
 +
 + TLDR; If you have a piece of ANSI-encoded text, and you want to easily step through character by character, keeping the ANSI info, then
 +       this range is for you.
 +
 + Notes:
 +  This struct is @nogc, except for when it throws exceptions.
 +
 + Behaviour:
 +  This range will only return characters that are not part of an ANSI sequence, which should hopefully end up only being visible ones.
 +
 +  For example, a string containing nothing but ANSI sequences won't produce any values.
 +
 + Params:
 +  R = The range of `AnsiSection`s.
 +
 + See_Also:
 +  `asAnsiChars` for easy creation of this struct.
 + ++/
struct AsAnsiCharRange(R)
{
    import std.range : ElementType;
    static assert(
        is(ElementType!R == AnsiSection), 
        "Range "~R.stringof~" must be a range of AnsiSections, not "~ElementType!R.stringof
    );

    private
    {
        R           _sections;
        AnsiChar    _front;
        AnsiSection _currentSection;
        size_t      _indexIntoSection;
    }

    @safe pure:

    /// Creates a new instance of this struct, using `range` as the range of sections.
    this(R range)
    {
        this._sections = range;
        this.popFront();
    }

    /// Returns: Last parsed character.
    AnsiChar front()
    {
        return this._front;
    }

    /// Returns: Whether there's no more characters left to parse.
    bool empty()
    {
        return this._front == AnsiChar.init;
    }

    /++
     + Parses the next sections.
     +
     + Optimisation:
     +  Pretty sure this is O(n)
     + ++/
    void popFront()
    {
        if(this._sections.empty && this._currentSection == AnsiSection.init)
        {
            this._front = AnsiChar.init;
            return;
        }

        // Check if we need to fetch the next section.
        if(this._indexIntoSection >= this._currentSection.value.length)
            this.nextSection();

        // For text sections, just return the next character. For sequences, set the new settings.
        if(this._currentSection.isTextSection)
        {
            this._front.value = this._currentSection.value[this._indexIntoSection++];
            
            // If we've reached the end of the final section, make the next call to this function set .empty to true.
            if(this._sections.empty && this._indexIntoSection >= this._currentSection.value.length)
                this._currentSection = AnsiSection.init;

            return;
        }

        ubyte[MAX_SGR_ARGS] args;
        while(this._indexIntoSection < this._currentSection.value.length)
        {
            import std.conv : to;
            const param = this.readNextAnsiParam().to!ubyte;

            // Again, since this code might become a function later, I'm doing things a bit weirdly as pre-prep
            switch(param)
            {
                // Set fg or bg.
                case 38:
                case 48:
                    args[] = 0;
                    args[0] = this.readNextAnsiParam().to!ubyte; // 5 = Pallette, 2 = RGB

                    if(args[0] == 5)
                        args[1] = this.readNextAnsiParam().to!ubyte;
                    else if(args[0] == 2)
                    {
                        foreach(i; 0..3)
                            args[1 + i] = this.readNextAnsiParam().to!ubyte;
                    }
                    break;
                
                default: break;
            }

            executeSgrCommand(param, args, this._front.fg, this._front.bgRef, this._front.flags);
        }

        // If this was the last section, then we need to set .empty to true since we have no more text to give back anyway.
        if(this._sections.empty())
        {
            import std.stdio : writeln;

            this._front = AnsiChar.init;
            this._currentSection = AnsiSection.init;
        }
        else // Otherwise, get the next char!
            this.popFront();
    }

    private void nextSection()
    {
        if(this._sections.empty)
            return;

        this._indexIntoSection = 0;
        this._currentSection   = this._sections.front;
        this._sections.popFront();
    }

    private const(char)[] readNextAnsiParam()
    {
        size_t start = this._indexIntoSection;
        const(char)[] slice;

        // Read until end or semi-colon. We're only expecting SGR codes because... it doesn't really make sense for us to handle the others.
        for(; this._indexIntoSection < this._currentSection.value.length; this._indexIntoSection++)
        {
            const ch = this._currentSection.value[this._indexIntoSection];
            switch(ch)
            {
                // I *swear* you could do something like `case '0'..'9'`, but I appear to be wrong here?
                case '0':
                case '1':
                case '2':
                case '3':
                case '4':
                case '5':
                case '6':
                case '7':
                case '8':
                case '9':
                    break;

                case ';':
                    slice = this._currentSection.value[start..this._indexIntoSection++]; // ++ to move past the semi-colon.
                    break;

                default:
                    throw new Exception("Unexpected character in ANSI escape sequence: '"~ch~"'");
            }

            if(slice !is null)
                break;
        }

        // In case the final delim is simply EOF
        if(slice is null && start < this._currentSection.value.length)
            slice = this._currentSection.value[start..$];

        return (slice.length == 0) ? DEFAULT_SGR_ARG : slice; // Empty params are counted as 0.
    }
}

/++
 + Notes:
 +  Reminder that `AnsiSection.value` shouldn't include the starting `"\033["` and ending `'m'` when it
 +  contains an ANSI sequence.
 +
 + Returns:
 +  An `AsAnsiCharRange` wrapped around `range`.
 + ++/
AsAnsiCharRange!R asAnsiChars(R)(R range)
{
    return typeof(return)(range);
}

/// Returns: An `AsAnsiCharRange` wrapped around an `AnsiSectionRange` wrapped around `input`.
@safe
AsAnsiCharRange!(AnsiSectionRange!char) asAnsiChars(const char[] input) pure
{
    return typeof(return)(input.asAnsiSections);
}

@("Test AsAnsiCharRange")
@safe
unittest
{
    import std.array  : array;
    import std.format : format;

    const input = "Hello".ansi.fg(Ansi4BitColour.green).bg(20).bold.toString()
                ~ "World".ansi.fg(255, 0, 255).italic.toString();

    const chars = input.asAnsiChars.array;
    assert(
        chars.length == "HelloWorld".length, 
        "Expected length of %s not %s\n%s".format("HelloWorld".length, chars.length, chars)
    );

    // Styling for both sections
    const style1 = AnsiChar(AnsiColour(Ansi4BitColour.green), AnsiColour(20, IsBgColour.yes), AnsiTextFlags.bold);
    const style2 = AnsiChar(AnsiColour(255, 0, 255), AnsiColour.init, AnsiTextFlags.italic);

    foreach(i, ch; chars)
    {
        AnsiChar style = (i < 5) ? style1 : style2;
        style.value    = ch.value;

        assert(ch == style, "Char #%s doesn't match.\nExpected: %s\nGot: %s".format(i, style, ch));
    }

    assert("".asAnsiChars.array.length == 0);
}

/// On windows - enable ANSI support.
version(Windows)
{
    static this()
    {
        import core.sys.windows.windows : HANDLE, DWORD, GetStdHandle, STD_OUTPUT_HANDLE, GetConsoleMode, SetConsoleMode, ENABLE_VIRTUAL_TERMINAL_PROCESSING;

        HANDLE stdOut = GetStdHandle(STD_OUTPUT_HANDLE);
        DWORD mode = 0;

        GetConsoleMode(stdOut, &mode);
        mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        SetConsoleMode(stdOut, mode);
    }
}