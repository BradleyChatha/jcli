/*dub.sdl:
    name "jcli"
*/
/*jcli:
Copyright © 2021 Bradley Chatha

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
/*jioc:
The MIT License (MIT)

Copyright (c) 2020 Bradley Chatha (SealabJaster)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/
/*
    WARNING:
        It should go without saying that slapping a bunch of files together and hackily patching it to compile is very likely
        to cause unusual compiler errors during its early stages of support (i.e. this file).

        Please open an issue on Github if you run into any compiler errors that occur when using this file as opposed to using the
        non-amalgamated dub package of JCLI, as these will 99% of the time be a bug that needs addressing and fixing.

        Second, just report *any* behavioural differences (whether at runtime or compile time) between the amalgamated and non-amalgamated version of JCLI.

        Finally, if there's any improvements you can think of to make support for amalgamation better and more stable, please let me know!

    DEBUG_NOTE:
        If you compile this file via 'dmd ./jcli.d -H', then DMD will create a './jcli.di' file which gives a much more structured overview
        of how this code is viewed by the compiler.

        So for example, if you're getting errors such as "so and so is not defined", make dmd generate the .di file, do a search for the thing it says
        doesn't exist, and you might just find that it's somehow ended up under a "version(unittest)" statement, for example.

        Again, file an issue if something like this occurs.
*/
module jcli;
version = Amalgamation;/// An adapter for the asdf library.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.adapters.config.asdf;

version(Have_asdf)
{
    import asdf;
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.config : isConfigAdapterFor;

    struct AsdfConfigAdapter
    {
        static
        {
            const(ubyte[]) serialise(For)(For value)
            {
                return cast(const ubyte[])value.serializeToJsonPretty();
            }

            For deserialise(For)(const ubyte[] data)
            {
                import std.utf : validate;

                auto dataAsText = cast(const char[])data;
                dataAsText.validate();

                return dataAsText.deserialize!For();
            }
        }
    }

    private struct ExampleStruct
    {
        string s;
    }
    static assert(isConfigAdapterFor!(AsdfConfigAdapter, ExampleStruct));
}
/// Utilities to create ANSI coloured text.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.ansi;

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
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.ansi : AnsiColour, AnsiTextFlags, IsBgColour;

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
            static if(is(T == AnsiColour))
            {
                colour      = value;
                colour.isBg = isBg;
            }
            else
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

    /// Sets the forground/background to an `AnsiColour`. Background colours will have their `isBg` flag set automatically.
    ref AnsiText fg(AnsiColour colour) return { return this.setColour(this._fg, colour, IsBgColour.no);   }
    /// ditto
    ref AnsiText bg(AnsiColour colour) return { return this.setColour(this._bg, colour, IsBgColour.yes);  }

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

    /// Sets the raw text used.
    @property
    void rawText(const char[] text)
    {
        this._text       = text;
        this._cachedText = null;
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
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    assert("Hello".ansi.toString() == "Hello");
    assert("Hello".ansi.fg(Ansi4BitColour.black).toString() == "\033[30mHello\033[0m");
    assert("Hello".ansi.bold.strike.bold(false).italic.toString() == "\033[3;9mHello\033[0m");
}
*/

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
///
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test AnsiSectionRange for only text, only ansi, and a mixed string.")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.array : array;

    const onlyText = "Hello, World!";
    const onlyAnsi = "\033[30m\033[0m";
    const mixed    = "\033[30;1;2mHello, \033[0mWorld!";

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
        AnsiSection(AnsiSectionType.escapeSequence, "30;1;2"),
        AnsiSection(AnsiSectionType.text,           "Hello, "),
        AnsiSection(AnsiSectionType.escapeSequence, "0"),
        AnsiSection(AnsiSectionType.text,           "World!")
    ]);

    assert(mixed.asAnsiSections.array.length == 4);
}
*/

/// Returns: A new `AnsiSectionRange` using the given `input`.
@safe @nogc
AnsiSectionRange!Char asAnsiSections(Char)(const Char[] input) nothrow pure
if(isSomeChar!Char)
{
    return AnsiSectionRange!Char(input);
}

/++
 + Provides an InputRange that iterates over all non-ANSI related parts of `input`.
 +
 + This can effectively be used to parse over text that is/might contain ANSI encoded text.
 +
 + Params:
 +  input = The input to strip.
 +
 + Returns:
 +  An InputRange that provides all ranges of characters from `input` that do not belong to an
 +  ANSI command sequence.
 +
 + See_Also:
 +  `asAnsiSections`
 + ++/
@safe @nogc
auto stripAnsi(const char[] input) nothrow pure
{
    import std.algorithm : filter, map;
    return input.asAnsiSections.filter!(s => s.isTextSection).map!(s => s.value);
}
///
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.array : array;

    auto ansiText = "ABC".ansi.fg(Ansi4BitColour.red).toString()
                  ~ "Doe Ray Me".ansi.bg(Ansi4BitColour.green).toString()
                  ~ "123";

    assert(ansiText.stripAnsi.array == ["ABC", "Doe Ray Me", "123"]);
}
*/

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

    if(background != AnsiColour.init)
        background.isBg = IsBgColour.yes;
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
                case '0': .. case '9':
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
///
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test AsAnsiCharRange")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
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
*/

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

/++
 + An InputRange that converts a range of `AnsiSection`s into a range of `AnsiText`s.
 +
 + Notes:
 +  This struct is @nogc, except for when it throws exceptions.
 +
 + Behaviour:
 +  This range will only return text that isn't part of an ANSI sequence, which should hopefully end up only being visible ones.
 +
 +  For example, a string containing nothing but ANSI sequences won't produce any values.
 +
 + Params:
 +  R = The range of `AnsiSection`s.
 +
 + See_Also:
 +  `asAnsiTexts` for easy creation of this struct.
 + ++/
struct AsAnsiTextRange(R)
{
    // TODO: DRY this struct, since it's just a copy-pasted modification of `AsAnsiCharRange`.

    import std.range : ElementType;
    static assert(
        is(ElementType!R == AnsiSection), 
        "Range "~R.stringof~" must be a range of AnsiSections, not "~ElementType!R.stringof
    );

    private
    {
        R           _sections;
        AnsiText    _front;
        AnsiChar    _settings; // Just to store styling settings.
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
    AnsiText front()
    {
        return this._front;
    }

    /// Returns: Whether there's no more text left to parse.
    bool empty()
    {
        return this._front == AnsiText.init;
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
            this._front = AnsiText.init;
            return;
        }

        // Check if we need to fetch the next section.
        if(this._indexIntoSection >= this._currentSection.value.length)
            this.nextSection();

        // For text sections, just return them. For sequences, set the new settings.
        if(this._currentSection.isTextSection)
        {
            this._front.fg         = this._settings.fg;
            this._front.bg         = this._settings.bg;
            this._front.setFlags   = this._settings.flags; // mmm, why is that setter prefixed with "set"?
            this._front.rawText    = this._currentSection.value;
            this._indexIntoSection = this._currentSection.value.length;
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

            executeSgrCommand(param, args, this._settings.fg, this._settings.bgRef, this._settings.flags);
        }

        // If this was the last section, then we need to set .empty to true since we have no more text to give back anyway.
        if(this._sections.empty())
        {
            import std.stdio : writeln;

            this._front = AnsiText.init;
            this._currentSection = AnsiSection.init;
        }
        else // Otherwise, get the next text!
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
                case '0': .. case '9':
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
///
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test AsAnsiTextRange")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    // Even this test is copy-pasted, I'm so lazy today T.T

    import std.array  : array;
    import std.format : format;

    const input = "Hello".ansi.fg(Ansi4BitColour.green).bg(20).bold.toString()
                ~ "World".ansi.fg(255, 0, 255).italic.toString();

    const text = input.asAnsiTexts.array;
    assert(
        text.length == 2, 
        "Expected length of %s not %s\n%s".format(2, text.length, text)
    );

    // Styling for both sections
    const style1 = AnsiChar(AnsiColour(Ansi4BitColour.green), AnsiColour(20, IsBgColour.yes), AnsiTextFlags.bold);
    auto  style2 = AnsiChar(AnsiColour(255, 0, 255), AnsiColour.init, AnsiTextFlags.italic);

    assert(text[0].fg      == style1.fg);
    assert(text[0].bg      == style1.bg);
    assert(text[0].flags   == style1.flags);
    assert(text[0].rawText == "Hello");
    
    style2.bgRef.isBg = IsBgColour.yes; // AnsiText is a bit better at keeping this value set to `yes` than `AnsiChar`.
    assert(text[1].fg      == style2.fg);
    assert(text[1].bg      == style2.bg);
    assert(text[1].flags   == style2.flags);
    assert(text[1].rawText == "World");

    assert("".asAnsiTexts.array.length == 0);
}
*/

/++
 + Notes:
 +  Reminder that `AnsiSection.value` shouldn't include the starting `"\033["` and ending `'m'` when it
 +  contains an ANSI sequence.
 +
 + Returns:
 +  An `AsAnsiTextRange` wrapped around `range`.
 + ++/
AsAnsiTextRange!R asAnsiTexts(R)(R range)
{
    return typeof(return)(range);
}

/// Returns: An `AsAnsiTextRange` wrapped around an `AnsiSectionRange` wrapped around `input`.
@safe
AsAnsiTextRange!(AnsiSectionRange!char) asAnsiTexts(const char[] input) pure
{
    return typeof(return)(input.asAnsiSections);
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
/// Utility for binding a string into arbitrary types, using user-defined functions.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.binder;

private
{
    import std.traits : isNumeric, hasUDA;
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.result, jaster.cli.internal;
}

/++
 + Attach this to any free-standing function to mark it as an argument binder.
 +
 + See_Also:
 +  `jaster.cli.binder.ArgBinder` for more details.
 + ++/
struct ArgBinderFunc {}

/++
 + Attach this to any struct to specify that it can be used as an arg validator.
 +
 + See_Also:
 +  `jaster.cli.binder.ArgBinder` for more details.
 + ++/
struct ArgValidator {}

// Kind of wanted to reuse `ArgBinderFunc`, but making it templated makes it a bit jank to use with functions,
// which don't need to provide any template values for it. So we have this UDA instead.
/++
 + Attach this onto an argument/provide it directly to `ArgBinder.bind`, to specify a specific function to use
 + when binding the argument, instead of relying on ArgBinder's default behaviour.
 +
 + Notes:
 +  The `Func` should match the following signature:
 +
 +  ```
 +  Result!T Func(string arg);
 +  ```
 +
 + Where `T` will be the type of the argument being bound to.
 +
 + Params:
 +  Func = The function to use to perform the binding.
 +
 + See_Also:
 +  `jaster.cli.binder.ArgBinder` and `jaster.cli.binder.ArgBinder.bind` for more details.
 + ++/
struct ArgBindWith(alias Func)
{
    Result!T bind(T)(string arg)
    {
        return Func(arg);
    }
}

/++
 + A static struct providing functionality for binding a string (the argument) to a value, as well as optionally validating it.
 +
 + Description:
 +  The ArgBinder itself does not directly contain functions to bind or validate arguments (e.g arg -> int, arg -> enum, etc.).
 +
 +  Instead, arg binders are user-provided, free-standing functions that are automatically detected from the specified `Modules`.
 +
 +  For each module passed in the `Modules` template parameter, the arg binder will search for any free-standing function marked with
 +  the `@ArgBinderFunc` UDA. These functions must follow a specific signature `@ArgBinderFunc void myBinder(string arg, ref TYPE value)`.
 +
 +  The second parameter (marked 'TYPE') can be *any* type that is desired. The type of this second parameter defines which type it will
 +  bind/convert the given argument into. The second parameter may also be a template type, if needed, to allow for more generic binders.
 +
 +  For example, the following binder `@ArgBinderFunc void argToInt(string arg, ref int value);` will be called anytime the arg binder
 +  needs to bind the argument into an `int` value.
 +
 +  When binding a value, you can optionally pass in a set of Validators, which are (typically) struct UDAs that provide a certain
 +  interface for validation.
 +
 + Lookup_Rules:
 +  The arg binder functions off of a simple 'First come first served' ruleset.
 +
 +  When looking for a suitable `@ArgBinderFunc` for the given value type, the following process is taken:
 +     * Foreach module in the `Modules` type parameter (from first to last).
 +         * Foreach free-standing function inside of the current module (usually in lexical order).
 +             * Do a compile-time check to see if this function can be called with a string as the first parameter, and the value type as the second.
 +                 * If the check passes, use this function.
 +                 * Otherwise, continue onto the next function.
 +
 +  This means there is significant meaning in the order that the modules are passed. Because of this, the built-in binders (contained in the 
 +  same module as this struct) will always be put at the very end of the list, meaning the user has the oppertunity to essentially 'override' any
 +  of the built-in binders.
 +
 +  One may ask "Won't that be confusing? How do I know which binder is being used?". My answer, while not perfect, is in non-release builds, 
 +  the binder will output a `debug pragma` to give detailed information on which binders are used for which types, and which ones are skipped over (and why they were skipped).
 +
 +  Note that you must also add "JCLI_Verbose" as a version (either in your dub file, or cli, or whatever) for these messages to show up.
 +
 +  While not perfect, this does go over the entire process the arg binder is doing to select which `@ArgBinderFunc` it will use.
 +
 + Specific_Binders:
 +  Instead of using the lookup rules above, you can make use of the `ArgBindWith` UDA to provide a specific function to perform the binding
 +  of an argument.
 +
 + Validation_:
 +  Validation structs can be passed via the `UDAs` template parameter present for the `ArgBinder.bind` function.
 +
 +  If you are using `CommandLineInterface` (JCLI's default core), then a field's UDAs are passed through automatically as validator structs.
 +
 +  A validator is simply a struct marked with `@ArgValidator` that defines either, or both of these function signatures (or compatible signatures):
 +
 +  ```
 +      Result!void onPreValidate(string arg);
 +      Result!void onValidate(VALUE_TYPE value); // Can be templated of course.
 +  ```
 +
 +  A validator containing the `onPreValidate` function can be used to validate the argument prior to it being ran through
 +  an `@ArgBinderFunc`.
 +
 +  A validator containing the `onValidate` function can be used to validate the argument after it has been bound by an `@ArgBinderFunc`.
 +
 +  If validation fails, the vaildator can set the error message with `Result!void.failure()`. If this is left as `null`, then one will be automatically
 +  generated for you.
 +
 +  By specifying the "JCLI_Verbose" version, the `ArgBinder` will detail what validators are being used for what types, and for which stages of binding.
 +
 + Notes:
 +  While other parts of this library have special support for `Nullable` types. This struct doesn't directly have any special
 +  behaviour for them, and instead must be built on top of this struct (a templated `@ArgBinderFunc` just for nullables is totally possible!).
 +
 + Params:
 +  Modules = The modules to look over. Please read the 'Description' and 'Lookup Rules' sections of this documentation comment.
 + +/
static struct ArgBinder(Modules...)
{
    import std.conv   : to;
    import std.traits : getSymbolsByUDA, Parameters, isFunction, fullyQualifiedName;
    import std.meta   : AliasSeq;
    import std.format : format;
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.udas, jaster.cli.internal;
    
    version(Amalgamation)
        alias AllModules = AliasSeq!(Modules, jcli);
    else
        alias AllModules = AliasSeq!(Modules, jaster.cli.binder);

    /+ PUBLIC INTERFACE +/
    public static
    {
        /++
         + Binds the given `arg` to the `value`, using the `@ArgBinderFunc` found by using the 'Lookup Rules' documented in the
         + document comment for `ArgBinder`.
         +
         + Validators_:
         +  The `UDAs` template parameter is used to pass in different UDA structs, including validator structs (see ArgBinder's documentation comment).
         +
         +  Anything inside of this template parameter that isn't a struct, and doesn't have the `ArgValidator` UDA
         +  will be completely ignored, so it is safe to simply pass the results of
         +  `__traits(getAttributes, someField)` without having to worry about filtering.
         +
         + Specific_Binders:
         +  The `UDAs` template paramter is used to pass in different UDA structs, including the `ArgBindWith` UDA.
         +
         +  If the `ArgBindWith` UDA exists within the given parameter, arg binding will be performed using the function
         +  provided by `ArgBindWith`, instead of using the default lookup rules defined by `ArgBinder`.
         +
         +  For example, say you have a several `File` arguments that need different binding behaviour (some are read-only, some truncate, etc.)
         +  In a case like this, you could have some of those arguments marked with `@ArgBindWith!openFileReadOnly` and others with
         +  a function for truncating, etc.
         +
         + Throws:
         +  `Exception` if any validator fails.
         +
         + Assertions:
         +  When an `@ArgBinderFunc` is found, it must have only 1 parameter.
         + 
         +  The first parameter of an `@ArgBinderFunc` must be a `string`.
         +
         +  It must return an instance of the `Result` struct. It is recommended to use `Result!void` as the result's `Success.value` is ignored.
         +
         +  If no appropriate binder func was found, then an assert(false) is used.
         +
         +  If `@ArgBindWith` exists, then exactly 1 must exist, any more than 1 is an error.
         +
         + Params:
         +  arg   = The argument to bind.
         +  value = The value to put the result in.
         +  UDAs  = A tuple of UDA structs to use.
         + ++/
        Result!T bind(T, UDAs...)(string arg)
        {
            import std.conv   : to;
            import std.traits : getSymbolsByUDA, isInstanceOf;

            auto preValidateResult = onPreValidate!(T, UDAs)(arg);
            if(preValidateResult.isFailure)
                return Result!T.failure(preValidateResult.asFailure.error);

            alias ArgBindWithInstance = TryGetArgBindWith!UDAs;
            
            static if(is(ArgBindWithInstance == void))
            {
                enum Binder = ArgBinderFor!(T, AllModules);
                auto result = Binder.Binder(arg);
            }
            else
                auto result = ArgBindWithInstance.init.bind!T(arg); // Looks weird, but trust me. Keep in mind it's an `alias` not an `enum`.

            if(result.isSuccess)
            {
                auto postValidateResult = onValidate!(T, UDAs)(arg, result.asSuccess.value);
                if(postValidateResult.isFailure)
                    return Result!T.failure(postValidateResult.asFailure.error);
            }

            return result;
        }

        private Result!void onPreValidate(T, UDAs...)(string arg)
        {
            static foreach(Validator; ValidatorsFrom!UDAs)
            {{
                static if(isPreValidator!(Validator))
                {
                    debugPragma!("Using PRE VALIDATION validator %s for type %s".format(Validator, T.stringof));

                    Result!void result = Validator.onPreValidate(arg);
                    if(!result.isSuccess)
                    {
                        return result.failure(createValidatorError(
                            "Pre validation",
                            "%s".format(Validator),
                            T.stringof,
                            arg,
                            "[N/A]",
                            result.asFailure.error
                        ));
                    }
                }
            }}

            return Result!void.success();
        }

        private Result!void onValidate(T, UDAs...)(string arg, T value)
        {
            static foreach(Validator; ValidatorsFrom!UDAs)
            {{
                static if(isPostValidator!(Validator))
                {
                    debugPragma!("Using VALUE VALIDATION validator %s for type %s".format(Validator, T.stringof));

                    Result!void result = Validator.onValidate(value);
                    if(!result.isSuccess)
                    {
                        return result.failure(createValidatorError(
                            "Value validation",
                            "%s".format(Validator),
                            T.stringof,
                            arg,
                            "%s".format(value),
                            result.asFailure.error
                        ));
                    }
                }
            }}

            return Result!void.success();
        }
    }
}
///
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@safe @("ArgBinder unittest")

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    alias Binder = ArgBinder!(jaster.cli.binder);

    // Non-validated bindings.
    auto value    = Binder.bind!int("200");
    auto strValue = Binder.bind!string("200");

    assert(value.asSuccess.value == 200);
    assert(strValue.asSuccess.value == "200");

    // Validated bindings
    @ArgValidator
    static struct GreaterThan
    {
        import std.traits : isNumeric;
        ulong value;

        Result!void onValidate(T)(T value)
        if(isNumeric!T)
        {
            import std.format : format;

            return value > this.value
            ? Result!void.success()
            : Result!void.failure("Value %s is NOT greater than %s".format(value, this.value));
        }
    }

    value = Binder.bind!(int, GreaterThan(68))("69");
    assert(value.asSuccess.value == 69);

    // Failed validation
    assert(Binder.bind!(int, GreaterThan(70))("69").isFailure);
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test that ArgBinder correctly discards non-validators")

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    alias Binder = ArgBinder!(jaster.cli.binder);

    Binder.bind!(int, "string", null, 2020)("2");
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test that __traits(getAttributes) works with ArgBinder")

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    @ArgValidator
    static struct Dummy
    {
        Result!void onPreValidate(string arg)
        {
            return Result!void.failure(null);
        }
    }

    alias Binder = ArgBinder!(jaster.cli.binder);

    static struct S
    {
        @Dummy
        int value;
    }

    assert(Binder.bind!(int, __traits(getAttributes, S.value))("200").isFailure);
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test that ArgBindWith works")

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    static struct S
    {
        @ArgBindWith!(str => Result!string.success(str ~ " lalafells"))
        string arg;
    }

    alias Binder = ArgBinder!(jaster.cli.binder);

    auto result = Binder.bind!(string, __traits(getAttributes, S.arg))("Destroy all");
    assert(result.isSuccess);
    assert(result.asSuccess.value == "Destroy all lalafells");
}
*/

/+ HELPERS +/
@safe
private string createValidatorError(
    string stageName,
    string validatorName,
    string typeName,
    string argValue,
    string valueAsString,
    string validatorError
)
{
    import std.format : format;
    return (validatorError !is null)
           ? validatorError
           : "%s failed for type %s. Validator = %s; Arg = '%s'; Value = %s"
             .format(stageName, typeName, validatorName, argValue, valueAsString);
}

private enum isValidator(alias V)     = is(typeof(V) == struct) && hasUDA!(typeof(V), ArgValidator);
private enum isPreValidator(alias V)  = isValidator!V && __traits(hasMember, typeof(V), "onPreValidate");
private enum isPostValidator(alias V) = isValidator!V && __traits(hasMember, typeof(V), "onValidate");

private template ValidatorsFrom(UDAs...)
{
    import std.meta        : staticMap, Filter;
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.udas : ctorUdaIfNeeded;

    alias Validators     = staticMap!(ctorUdaIfNeeded, UDAs);
    alias ValidatorsFrom = Filter!(isValidator, Validators);
}

private struct BinderInfo(alias T, alias Symbol)
{
    import std.traits : fullyQualifiedName, isFunction, Parameters, ReturnType;

    // For templated binder funcs, we need a slightly different set of values.
    static if(__traits(compiles, Symbol!T))
    {
        alias Binder      = Symbol!T;
        const FQN         = fullyQualifiedName!Binder~"!("~T.stringof~")";
        const IsTemplated = true;
    }
    else
    {
        alias Binder      = Symbol;
        const FQN         = fullyQualifiedName!Binder;
        const IsTemplated = false;
    }

    const IsFunction  = isFunction!Binder;

    static if(IsFunction)
    {
        alias Params  = Parameters!Binder;
        alias RetType = ReturnType!Binder;
    }
}

private template ArgBinderMapper(T, alias Binder)
{
    import std.traits : isInstanceOf;

    enum Info = BinderInfo!(T, Binder)();

    // When the debugPragma isn't used inside a function, we have to make aliases to each call in order for it to work.
    // Ugly, but whatever.

    static if(!Info.IsFunction)
    {
        alias a = debugPragma!("Skipping arg binder `"~Info.FQN~"` for type `"~T.stringof~"` because `isFunction` is returning false.");
        static if(Info.IsTemplated)
            alias b = debugPragma!("This binder is templated, so it is likely that the binder's contract failed, or its code doesn't compile for this given type.");

        alias ArgBinderMapper = void;
    }
    else static if(!__traits(compiles, { Result!T r = Info.Binder(""); }))
    {
        alias c = debugPragma!("Skipping arg binder `"~Info.FQN~"` for type `"~T.stringof~"` because it does not compile for the given type.");

        alias ArgBinderMapper = void;
    }
    else
    {
        alias d = debugPragma!("Considering arg binder `"~Info.FQN~"` for type `"~T.stringof~"`.");

        static assert(Info.Params.length == 1,
            "The arg binder `"~Info.FQN~"` must only have `1` parameter, not `"~Info.Params.length.to!string~"` parameters."
        );
        static assert(is(Info.Params[0] == string),
            "The arg binder `"~Info.FQN~"` must have a `string` as their first parameter, not a(n) `"~Info.Params[0].stringof~"`."
        );
        static assert(isInstanceOf!(Result, Info.RetType),
            "The arg binder `"~Info.FQN~"` must return a `Result`, not `"~Info.RetType.stringof~"`"
        );
        
        enum ArgBinderMapper = Info;
    }
}

private template ArgBinderFor(alias T, Modules...)
{
    import std.meta        : staticMap, Filter;
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.udas : getSymbolsByUDAInModules;

    enum isNotVoid(alias T) = !is(T == void);
    alias Mapper(alias BinderT) = ArgBinderMapper!(T, BinderT);

    alias Binders         = getSymbolsByUDAInModules!(ArgBinderFunc, Modules);
    alias BindersForT     = staticMap!(Mapper, Binders);
    alias BindersFiltered = Filter!(isNotVoid, BindersForT);

    // Have to use static if here because the compiler's order of operations makes it so a single `static assert` wouldn't be evaluated at the right time,
    // and so it wouldn't produce our error message, but instead an index out of bounds one.
    static if(BindersFiltered.length > 0)
    {
        enum ArgBinderFor = BindersFiltered[0];
        alias a = debugPragma!("Using arg binder `"~ArgBinderFor.FQN~"` for type `"~T.stringof~"`");
    }
    else
        static assert(false, "No arg binder found for type `"~T.stringof~"`");    
}

private template TryGetArgBindWith(UDAs...)
{
    import std.traits : isInstanceOf;
    import std.meta   : Filter;

    enum FilterFunc(alias T) = isInstanceOf!(ArgBindWith, T);
    alias Filtered = Filter!(FilterFunc, UDAs);

    static if(Filtered.length == 0)
        alias TryGetArgBindWith = void;
    else static if(Filtered.length > 1)
        static assert(false, "Multiple `ArgBindWith` instances were found, only one can be used.");
    else
        alias TryGetArgBindWith = Filtered[0];
}

/+ BUILT-IN BINDERS +/

/// arg -> string. The result is the contents of `arg` as-is.
@ArgBinderFunc @safe @nogc
Result!string stringBinder(string arg) nothrow pure
{
    return Result!string.success(arg);
}

/// arg -> numeric | enum | bool. The result is `arg` converted to `T`.
@ArgBinderFunc @safe
Result!T convBinder(T)(string arg) pure
if(isNumeric!T || is(T == bool) || is(T == enum))
{
    import std.conv : to, ConvException;
    
    try return Result!T.success(arg.to!T);
    catch(ConvException ex)
        return Result!T.failure(ex.msg);
}

/+ BUILT-IN VALIDATORS +/

/++
 + An `@ArgValidator` that runs the given `Func` during post-binding validation.
 +
 + Notes:
 +  This validator is loosely typed, so if your validator function doesn't compile or doesn't work with whatever
 +  type you attach this validator to, you might get some long-winded errors.
 +
 + Params:
 +  Func = The function that provides validation on a value.
 + ++/
@ArgValidator
struct PostValidate(alias Func)
{
    // We don't do any static checking of the parameter type, as we can utilise a very interesting use case of anonymous lambdas here
    // by allowing the compiler to perform the checks for us.
    //
    // However that does mean we can't provide our own error message, but the scope is so small that a compiler generated one should suffice.
    Result!void onValidate(ParamT)(ParamT arg)
    {
        return Func(arg);
    }
}

// I didn't *want* this to be templated, but when it's not templated and asks directly for a
// `Result!void function(string)`, I get a very very odd error message: "expression __lambda2 is not a valid template value argument"
/++
 + An `@ArgValidator` that runs the given `Func` during pre-binding validation.
 +
 + Params:
 +  Func = The function that provides validation on an argument.
 + ++/
@ArgValidator
struct PreValidate(alias Func)
{
    Result!void onPreValidate(string arg)
    {
        return Func(arg);
    }
}
///
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("PostValidate and PreValidate")

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    static struct S
    {
        @PreValidate!(str => Result!void.failureIf(str.length != 3, "Number must be 3 digits long."))
        @PostValidate!(i => Result!void.failureIf(i <= 200, "Number must be larger than 200."))   
        int arg;
    }
    
    alias Binder = ArgBinder!(jaster.cli.binder);
    alias UDAs   = __traits(getAttributes, S.arg);

    assert(Binder.bind!(int, UDAs)("20").isFailure);
    assert(Binder.bind!(int, UDAs)("199").isFailure);
    assert(Binder.bind!(int, UDAs)("300").asSuccess.value == 300);
}
*/
/// Contains a type to generate help text for a command.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.commandhelptext;

import std.array;
//[CONTAINS_BLACKLISTED_IMPORT]import jaster.cli.infogen, jaster.cli.result, jaster.cli.helptext, jaster.cli.binder;

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
/// Contains a type that can parse data into a command.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.commandparser;

import std.traits, std.algorithm, std.conv, std.format, std.typecons;
//[CONTAINS_BLACKLISTED_IMPORT]import jaster.cli.infogen, jaster.cli.binder, jaster.cli.result, jaster.cli.parser;

/++
 + A type that can parse an argument list into a command.
 +
 + Description:
 +  One may wonder, "what's the difference between `CommandParser` and `CommandLineInterface`?".
 +
 +  The answer is simple: `CommandParser` $(B only) performs argument parsing and value binding for a single command,
 +  whereas `CommandLineInterface` builds on top of `CommandParser` and several other components in order to support
 +  multiple commands via a complete CLI interface.
 +
 +  So in short, if all you want from JCLI is its command modeling and parsing abilties without all the extra faff
 +  provided by `CommandLineInterface`, and you're fine with performing execution by yourself, then you'll want to use
 +  this type.
 +
 + Commands_:
 +  Commands and arguments are defined in the same way as `CommandLineInterface` documents.
 +
 +  However, you don't need to define an `onExecute` function as this type has no concept of executing commands, only parsing them.
 +
 + Dependency_Injection:
 +  This is a feature provided by `CommandLineInterface`, not `CommandParser`.
 +
 +  Command instances must be constructed outside of `CommandParser`, as it has no knowledge on how to do this, it only knows how to parse data into it.
 +
 + Params:
 +  CommandT = The type of your command.
 +  ArgBinderInstance = The `ArgBinder` to use when binding arguments to the user provided values.
 + ++/
struct CommandParser(alias CommandT, alias ArgBinderInstance = ArgBinder!())
{
    /// The `CommandInfo` for the command being parsed. Special note is that this is compile-time viewable.
    enum Info = getCommandInfoFor!(CommandT, ArgBinderInstance);

    private static struct ArgRuntimeInfo(ArgInfoT)
    {
        ArgInfoT argInfo;
        bool wasFound;

        bool isNullable()
        {
            return (this.argInfo.existence & CommandArgExistence.optional) > 0;
        }
    }
    private auto argInfoOf(ArgInfoT)(ArgInfoT info) { return ArgRuntimeInfo!ArgInfoT(info); }

    /// Same as `parse` except it will automatically construct an `ArgPullParser` for you.
    Result!void parse(string[] args, ref CommandT commandInstance)
    {
        auto parser = ArgPullParser(args);
        return this.parse(parser, commandInstance);
    }

    /++
     + Parses the given arguments into your command instance.
     +
     + Description:
     +  This performs the full value parsing as described in `CommandLineInterface`.
     +
     + Notes:
     +  If the argument parsing fails, your command instance and parser $(B can be in a half-parsed state).
     +
     + Params:
     +  parser = The parser containing the argument tokens.
     +  commandInstance = The instance of your `CommandT` to populate.
     +
     + Returns:
     +  A successful result (`Result.isSuccess`) if argument parsing and binding succeeded, otherwise a failure result
     +  with an error (`Result.asFailure.error`) describing what happened. This error is user-friendly.
     +
     + See_Also:
     +  `jaster.cli.core.CommandLineInterface` as it goes over everything in detail.
     +
     +  This project's README also goes into detail about how commands are parsed.
     + ++/
    Result!void parse(ref ArgPullParser parser, ref CommandT commandInstance)
    {
        auto namedArgs = this.getNamedArgs();
        auto positionalArgs = this.getPositionalArgs();

        size_t positionalArgIndex = 0;
        bool breakOuterLoop = false;
        for(; !parser.empty && !breakOuterLoop; parser.popFront())
        {
            const token = parser.front();
            final switch(token.type) with(ArgTokenType)
            {
                case None: assert(false);
                case EOF: break;

                // Positional Argument
                case Text:
                    if(positionalArgIndex >= positionalArgs.length)
                    {
                        return typeof(return).failure(
                            "too many arguments starting at '%s'".format(token.value)
                        );
                    }

                    auto actionResult = positionalArgs[positionalArgIndex].argInfo.actionFunc(token.value, commandInstance);
                    positionalArgs[positionalArgIndex++].wasFound = true;

                    if(!actionResult.isSuccess)
                    {
                        return typeof(return).failure(
                            "positional argument %s ('%s'): %s"
                            .format(positionalArgIndex-1, positionalArgs[positionalArgIndex-1].argInfo.uda.name, actionResult.asFailure.error)
                        );
                    }
                    break;

                // Named Argument
                case LongHandArgument:
                    if(token.value == "-" || token.value == "") // --- || --
                    {
                        breakOuterLoop = true;                        
                        static if(!Info.rawListArg.isNull)
                            mixin("commandInstance.%s = parser.unparsedArgs;".format(Info.rawListArg.get.identifier));
                        break;
                    }
                    goto case;
                case ShortHandArgument:
                    const argIndex = namedArgs.countUntil!"a.argInfo.uda.pattern.matchSpaceless(b)"(token.value);
                    if(argIndex < 0)
                        return typeof(return).failure("unknown argument '%s'".format(token.value));

                    if(namedArgs[argIndex].wasFound && (namedArgs[argIndex].argInfo.existence & CommandArgExistence.multiple) == 0)
                        return typeof(return).failure("multiple definitions of argument '%s'".format(token.value));

                    namedArgs[argIndex].wasFound = true;
                    auto argParseResult = this.performParseScheme(parser, commandInstance, namedArgs[argIndex].argInfo);
                    if(!argParseResult.isSuccess)
                        return typeof(return).failure("named argument '%s': ".format(token.value)~argParseResult.asFailure.error);
                    break;
            }
        }

        auto validateResult = this.validateArgs(namedArgs, positionalArgs);
        return validateResult;
    }

    private Result!void performParseScheme(ref ArgPullParser parser, ref CommandT commandInstance, NamedArgumentInfo!CommandT argInfo)
    {
        final switch(argInfo.parseScheme) with(CommandArgParseScheme)
        {
            case default_: return this.parseDefault(parser, commandInstance, argInfo);
            case allowRepeatedName: return this.parseRepeatableName(parser, commandInstance, argInfo);
            case bool_: return this.parseBool(parser, commandInstance, argInfo);
        }
    }

    private Result!void parseBool(ref ArgPullParser parser, ref CommandT commandInstance, NamedArgumentInfo!CommandT argInfo)
    {
        // Bools have special support:
        //  If they are defined, they are assumed to be true, however:
        //      If the next token is Text, and its value is one of a predefined list, then it is then sent to the ArgBinder instead of defaulting to true.

        auto parserCopy = parser;
        parserCopy.popFront();

        if(parserCopy.empty
        || parserCopy.front.type != ArgTokenType.Text
        || !["true", "false"].canFind(parserCopy.front.value))
            return argInfo.actionFunc("true", /*ref*/ commandInstance);

        auto result = argInfo.actionFunc(parserCopy.front.value, /*ref*/ commandInstance);
        parser.popFront(); // Keep the main parser up to date.

        return result;
    }

    private Result!void parseDefault(ref ArgPullParser parser, ref CommandT commandInstance, NamedArgumentInfo!CommandT argInfo)
    {
        parser.popFront();

        if(parser.front.type == ArgTokenType.EOF)
            return typeof(return).failure("defined without a value.");
        else if(parser.front.type != ArgTokenType.Text)
            return typeof(return).failure("expected a value, not an argument name.");

        return argInfo.actionFunc(parser.front.value, /*ref*/ commandInstance);
    }

    private Result!void parseRepeatableName(ref ArgPullParser parser, ref CommandT commandInstance, NamedArgumentInfo!CommandT argInfo)
    {
        auto parserCopy  = parser;
        auto incrementBy = 1;
        
        // Support "-vvvvv" syntax.
        parserCopy.popFront();
        if(parser.front.type == ArgTokenType.ShortHandArgument 
        && parserCopy.front.type == ArgTokenType.Text
        && parserCopy.front.value.all!(c => c == parser.front.value[0]))
        {
            incrementBy += parserCopy.front.value.length;
            parser.popFront(); // keep main parser up to date.
        }

        // .actionFunc will perform an increment each call.
        foreach(i; 0..incrementBy)
            argInfo.actionFunc(null, /*ref*/ commandInstance);

        return Result!void.success();
    }

    private ArgRuntimeInfo!(NamedArgumentInfo!CommandT)[] getNamedArgs()
    {
        typeof(return) toReturn;

        foreach(arg; Info.namedArgs)
        {
            arg.uda.pattern.assertNoWhitespace();
            toReturn ~= this.argInfoOf(arg);
        }

        // TODO: Forbid arguments that have the same pattern and/or subpatterns.

        return toReturn;
    }

    private ArgRuntimeInfo!(PositionalArgumentInfo!CommandT)[] getPositionalArgs()
    {
        typeof(return) toReturn;

        foreach(arg; Info.positionalArgs)
            toReturn ~= this.argInfoOf(arg);

        toReturn.sort!"a.argInfo.uda.position < b.argInfo.uda.position"();
        foreach(i, arg; toReturn)
        {
            assert(
                arg.argInfo.uda.position == i, 
                "Expected positional argument %s to take up position %s, not %s."
                .format(toReturn[i].argInfo.uda.name, i, arg.argInfo.uda.position)
            );
        }

        // TODO: Make sure there are no optional args appearing before any mandatory ones.

        return toReturn;
    }
    
    private Result!void validateArgs(
        ArgRuntimeInfo!(NamedArgumentInfo!CommandT)[] namedArgs,
        ArgRuntimeInfo!(PositionalArgumentInfo!CommandT)[] positionalArgs
    )
    {
        import std.algorithm : filter, map;
        import std.format    : format;
        import std.exception : assumeUnique;

        char[] error;
        error.reserve(512);

        // Check for missing args.
        auto missingNamedArgs      = namedArgs.filter!(a => !a.isNullable && !a.wasFound);
        auto missingPositionalArgs = positionalArgs.filter!(a => !a.isNullable && !a.wasFound);
        if(!missingNamedArgs.empty)
        {
            foreach(arg; missingNamedArgs)
            {
                const name = arg.argInfo.uda.pattern.defaultPattern;
                error ~= (name.length == 1) ? "-" : "--";
                error ~= name;
                error ~= ", ";
            }
        }
        if(!missingPositionalArgs.empty)
        {
            foreach(arg; missingPositionalArgs)
            {
                error ~= "<";
                error ~= arg.argInfo.uda.name;
                error ~= ">, ";
            }
        }

        if(error.length > 0)
        {
            error = error[0..$-2]; // Skip extra ", "
            return Result!void.failure("missing required arguments " ~ error.assumeUnique);
        }

        return Result!void.success();
    }
}

version(unittest)
{
    // For the most part, these are just some choice selections of tests from core.d that were moved over.

    // NOTE: The only reason it can see and use private @Commands is because they're in the same module.
    @Command("", "This is a test command")
    private struct CommandTest
    {
        // These are added to test that they are safely ignored.
        alias al = int;
        enum e = 2;
        struct S
        {
        }
        void f () {}

        @CommandNamedArg("a|avar", "A variable")
        int a;

        @CommandPositionalArg(0, "b")
        Nullable!string b;

        @CommandNamedArg("c")
        Nullable!bool c;
    }
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
    @("General test")

*/
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        auto command = CommandParser!CommandTest();
        auto instance = CommandTest();

        resultAssert(command.parse(["-a 20"], instance));
        assert(instance.a == 20);
        assert(instance.b.isNull);
        assert(instance.c.isNull);

        instance = CommandTest.init;
        resultAssert(command.parse(["20", "--avar 20"], instance));
        assert(instance.a == 20);
        assert(instance.b.get == "20");

        instance = CommandTest.init;
        resultAssert(command.parse(["-a 20", "-c"], instance));
        assert(instance.c.get);
    }
*/

    @Command("booltest", "Bool test")
    private struct BoolTestCommand
    {
        @CommandNamedArg("a")
        bool definedNoValue;

        @CommandNamedArg("b")
        bool definedFalseValue;

        @CommandNamedArg("c")
        bool definedTrueValue;

        @CommandNamedArg("d")
        bool definedNoValueWithArg;

        @CommandPositionalArg(0)
        string comesAfterD;
    }
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
    @("Test that booleans are handled properly")

*/
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        auto command = CommandParser!BoolTestCommand();
        auto instance = BoolTestCommand();

        resultAssert(command.parse(["-a", "-b=false", "-c", "true", "-d", "Lalafell"], instance));
        assert(instance.definedNoValue);
        assert(!instance.definedFalseValue);
        assert(instance.definedTrueValue);
        assert(instance.definedNoValueWithArg);
        assert(instance.comesAfterD == "Lalafell");
    }
*/

    @Command("rawListTest", "Test raw lists")
    private struct RawListTestCommand
    {
        @CommandNamedArg("a")
        bool dummyThicc;

        @CommandRawListArg
        string[] rawList;
    }
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
    @("Test that raw lists work")

*/
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        CommandParser!RawListTestCommand command;
        RawListTestCommand instance;

        resultAssert(command.parse(["-a", "--", "raw1", "raw2"], instance));
        assert(instance.rawList == ["raw1", "raw2"], "%s".format(instance.rawList));
    }
*/

    @ArgValidator
    private struct Expect(T)
    {
        T value;

        Result!void onValidate(T boundValue)
        {
            import std.format : format;

            return this.value == boundValue
            ? Result!void.success()
            : Result!void.failure("Expected value to equal '%s', not '%s'.".format(this.value, boundValue));
        }
    }

    @Command("validationTest", "Test validation")
    private struct ValidationTestCommand
    {
        @CommandPositionalArg(0)
        @Expect!string("lol")
        string value;
    }
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
    @("Test ArgBinder validation integration")

*/
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        CommandParser!ValidationTestCommand command;
        ValidationTestCommand instance;

        resultAssert(command.parse(["lol"], instance));
        assert(instance.value == "lol");
        
        assert(!command.parse(["nan"], instance).isSuccess);
    }
*/

    @Command("arg action count", "Test that the count arg action works")
    private struct ArgActionCount
    {
        @CommandNamedArg("c")
        @(CommandArgAction.count)
        int c;
    }
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
    @("Test that CommandArgAction.count works.")

*/
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        CommandParser!ArgActionCount command;

        void test(string[] args, int expectedCount)
        {
            ArgActionCount instance;
            resultAssert(command.parse(args, instance));
            assert(instance.c == expectedCount);
        }

        ArgActionCount instance;

        test([], 0);
        test(["-c"], 1);
        test(["-c", "-c"], 2);
        test(["-ccccc"], 5);
        assert(!command.parse(["-ccv"], instance).isSuccess); // -ccv -> [name '-c', positional 'cv']. -1 because too many positional args.
        test(["-c", "cccc"], 5); // Unfortunately this case also works because of limitations in ArgPullParser
    }
*/
}
/// Contains services that are used to easily load, modify, and store the program's configuration.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.config;

private
{
    import std.typecons : Flag;
    import std.traits   : isCopyable;
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.ioc;
}

alias WasExceptionThrown  = Flag!"wasAnExceptionThrown?";
alias SaveOnSuccess       = Flag!"configSaveOnSuccess";
alias RollbackOnFailure   = Flag!"configRollbackOnError";

/++
 + The simplest interface for configuration.
 +
 + This doesn't care about how data is loaded, stored, or saved. It simply provides
 + a bare-bones interface to accessing data, without needing to worry about the nitty-gritty stuff.
 + ++/
interface IConfig(T)
if(is(T == struct) || is(T == class))
{
    public
    {
        /// Loads the configuration. This should overwrite any unsaved changes.
        void load();

        /// Saves the configuration.
        void save();

        /// Returns: The current value for this configuration.
        @property
        T value();

        /// Sets the configuration's value.
        @property
        void value(T value);
    }

    public final
    {
        /++
         + Edit the value of this configuration using the provided `editFunc`, optionally
         + saving if no exceptions are thrown, and optionally rolling back any changes in the case an exception $(B is) thrown.
         +
         + Notes:
         +  Exceptions can be caught during either `editFunc`, or a call to `save`.
         +
         +  Functionally, "rolling back on success" simply means the configuration's `value[set]` property is never used.
         +
         +  This has a consequence - if your `editFunc` modifies the internal state of the value in a way that takes immediate effect on
         +  the original value (e.g. the value is a class type, so all changes will affect the original value), then "rolling back" won't
         +  be able to prevent any data changes.
         +
         +  Therefor, it's best to use structs for your configuration types if you're wanting to make use of "rolling back".
         +
         +  If an error occurs, then `UserIO.verboseException` is used to display the exception.
         +
         +  $(B Ensure your lambda parameter is marked `scope ref`, otherwise you'll get a compiler error.)
         +
         + Params:
         +  editFunc = The function that will edit the configuration's value.
         +  rollback = If `RollbackOnFailure.yes`, then should an error occur, the configuration's value will be left unchanged.
         +  save     = If `SaveOnSuccess.yes`, then if no errors occur, a call to `save` will be made.
         +
         + Returns:
         +  `WasExceptionThrown` to denote whether an error occured or not.
         + ++/
        WasExceptionThrown edit(
            void delegate(scope ref T value) editFunc,
            RollbackOnFailure rollback = RollbackOnFailure.yes,
            SaveOnSuccess save = SaveOnSuccess.no
        )
        {
            const uneditedValue = this.value;
            T     value         = uneditedValue; // So we can update the value in the event of `rollback.no`.
            try
            {
                editFunc(value); // Pass a temporary, so in the event of an error, changes shouldn't be half-committed.

                this.value = value;                
                if(save)
                    this.save();

                return WasExceptionThrown.no;
            }
            catch(Exception ex)
            {
//[CONTAINS_BLACKLISTED_IMPORT]                import jaster.cli.userio : UserIO;
                UserIO.verboseException(ex);

                this.value = (rollback) ? uneditedValue : value;
                return WasExceptionThrown.yes;
            }
        }

        /// Exactly the same as `edit`, except with the `save` parameter set to `yes`.
        void editAndSave(void delegate(scope ref T value) editFunc)
        {
            this.edit(editFunc, RollbackOnFailure.yes, SaveOnSuccess.yes);
        }

        /// Exactly the same as `edit`, except with the `save` parameter set to `yes`, and `rollback` set to `no`.
        void editAndSaveNoRollback(void delegate(scope ref T value) editFunc)
        {
            this.edit(editFunc, RollbackOnFailure.no, SaveOnSuccess.yes);
        }

        /// Exactly the same as `edit`, except with the `rollback` paramter set to `no`.
        void editNoRollback(void delegate(scope ref T value) editFunc)
        {
            this.edit(editFunc, RollbackOnFailure.no, SaveOnSuccess.no);
        }
    }
}
///
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    // This is mostly a unittest for testing, not as an example, but may as well show it as an example anyway.
    static struct Conf
    {
        string str;
        int num;
    }

    auto config = new InMemoryConfig!Conf();

    // Default: Rollback on failure, don't save on success.
    // First `edit` fails, so no data should be commited.
    // Second `edit` passes, so data is edited.
    // Test to ensure only the second `edit` committed changes.
    assert(config.edit((scope ref v) { v.str = "Hello"; v.num = 420; throw new Exception(""); }) == WasExceptionThrown.yes);
    assert(config.edit((scope ref v) { v.num = 21; })                                            == WasExceptionThrown.no);
    assert(config.value == Conf(null, 21));

    // Reset value, check that we didn't actually call `save` yet.
    config.load();
    assert(config.value == Conf.init);

    // Test editAndSave. Save on success, rollback on failure.
    // No longer need to test rollback's pass case, as that's now proven to work.
    config.editAndSave((scope ref v) { v.str = "Lalafell"; });
    config.value = Conf.init;
    config.load();
    assert(config.value.str == "Lalafell");

    // Reset value
    config.value = Conf.init;
    config.save();

    // Test editNoRollback, and then we'll have tested the pass & fail cases for saving and rollbacks.
    config.editNoRollback((scope ref v) { v.str = "Grubby"; throw new Exception(""); });
    assert(config.value.str == "Grubby", config.value.str);
}
*/

/++
 + A template that evaluates to a bool which determines whether the given `Adapter` can successfully
 + compile all the code needed to serialise and deserialise the `For` type.
 +
 + Adapters:
 +  Certain `IConfig` implementations may provide a level of flexibliity in the sense that they will offload the responsiblity
 +  of serialising/deserialising the configuration onto something called an `Adapter`.
 +
 +  For the most part, these `Adapters` are likely to simply be that: an adapter for an already existing serialisation library.
 +
 +  Adapters require two static functions, with the following or compatible signatures:
 +
 +  ```
 +  const(ubyte[]) serialise(For)(For value);
 +
 +  For deserialise(For)(const(ubyte[]) value);
 +  ```
 +
 + Builtin Adapters:
 +  Please note that any adapter that uses a third party library will only be compiled if your own project includes aforementioned library.
 +
 +  For example, `AsdfConfigAdapter` requires the asdf library, so will only be available if your dub project includes asdf (or specify the `Have_asdf` version).
 +
 +  e.g. if you want to use `AsdfConfigAdapter`, use a simple `dub add asdf` in your own project and then you're good to go.
 +
 +  JCLI provides the following adapters by default:
 +
 +  * `AsdfConfigAdapter` - An adapter for the asdf serialisation library. asdf is marked as an optional package.
 +
 + Notes:
 +  If for whatever reason the given `Adapter` cannot compile when being used with the `For` type, this template
 +  will attempt to instigate an error message from the compiler as to why.
 +
 +  If this template is being used inside a `static assert`, and fails, then the above attempt to provide an error message as to
 +  why the compliation failed will not be shown, as the `static assert is false` error is thrown before the compile has a chance to collect any other error message.
 +
 +  In such a case, please temporarily rewrite the `static assert` into storing the result of this template into an `enum`, as that should then allow
 +  the compiler to generate the error message.
 + ++/
template isConfigAdapterFor(Adapter, For)
{
    static if(isConfigAdapterForImpl!(Adapter, For))
        enum isConfigAdapterFor = true;
    else
    {
        alias _ErrorfulInstansiation = showAdapterCompilerErrors!(Adapter, For);
        enum isConfigAdapterFor = false;
    }
}

private enum isConfigAdapterForImpl(Adapter, For) = 
    __traits(compiles, { const ubyte[] data = Adapter.serialise!For(For.init); })
 && __traits(compiles, { const ubyte[] data; For value = Adapter.deserialise!For(data); });

private void showAdapterCompilerErrors(Adapter, For)()
{
    const ubyte[] data = Adapter.serialise!For(For.init);
    For value = Adapter.deserialise!For(data);
}

/// A very simple `IConfig` that simply stores the value in memory. This is mostly only useful for testing.
final class InMemoryConfig(For) : IConfig!For
if(isCopyable!For)
{
    private For _savedValue;
    private For _value;

    public override
    {
        void save()
        {
            this._savedValue = this._value;
        }

        void load()
        {
            this._value = this._savedValue;
        }

        @property
        For value()
        {
            return this._value;
        }

        @property
        void value(For newValue)
        {
            this._value = newValue;
        }
    }
}

/++
 + Returns:
 +  A Singleton `ServiceInfo` describing an `InMemoryConfig` that stores the `For` type.
 + ++/
ServiceInfo addInMemoryConfig(For)()
{
    return ServiceInfo.asSingleton!(IConfig!For, InMemoryConfig!For);
}

/// ditto.
ServiceInfo[] addInMemoryConfig(For)()
{
    services ~= addInMemoryConfig!For();
    return services;
}

/++
 + An `IConfig` with adapter support that uses the filesystem to store/retrieve its configuration value.
 +
 + Notes:
 +  This class will ensure the directory for the file exists.
 +
 +  This class will always create a backup ".bak" before every write attempt. It however does not
 +  attempt to restore this file in the event of an error.
 +
 +  If this class' config file doesn't exist, then `load` is no-op, leaving the `value` as `For.init`
 +
 + See_Also:
 +  The docs for `isConfigAdapterFor` to learn more about configs with adapter support.
 +
 +  `addFileConfig`
 + ++/
final class AdaptableFileConfig(For, Adapter) : IConfig!For
if(isConfigAdapterFor!(Adapter, For) && isCopyable!For)
{
    private For _value;
    private string _path;

    /++
     + Throws:
     +  `Exception` if the given `path` is invalid, after being converted into an absolute path.
     +
     + Params:
     +  path = The file path to store the configuration file at. This can be relative or absolute.
     + ++/
    this(string path)
    {
        import std.exception : enforce;
        import std.path : absolutePath, isValidPath;

        this._path = path.absolutePath();
        enforce(isValidPath(this._path), "The path '"~this._path~"' is invalid");
    }

    public override
    {
        void save()
        {
            import std.file      : write, exists, mkdirRecurse, copy;
            import std.path      : dirName, extension, setExtension;

            const pathDir = this._path.dirName;
            if(!exists(pathDir))
                mkdirRecurse(pathDir);

            const backupExt = this._path.extension ~ ".bak";
            const backupPath = this._path.setExtension(backupExt);
            if(exists(this._path))
                copy(this._path, backupPath);

            const ubyte[] data = Adapter.serialise!For(this._value);
            write(this._path, data);
        }

        void load()
        {
            import std.file : exists, read;

            if(!this._path.exists)
                return;

            this._value = Adapter.deserialise!For(cast(const ubyte[])read(this._path));
        }

        @property
        For value()
        {
            return this._value;
        }

        @property
        void value(For newValue)
        {
            this._value = newValue;
        }
    }
}

/++
 + Note:
 +  The base type of the resulting service is `IConfig!For`, so ensure that your dependency injected code asks for
 +  `IConfig!For` instead of `AdapatableFileConfig!(For, Adapter)`.
 +
 + Returns:
 +  A Singleton `ServiceInfo` describing an `AdapatableFileConfig` that serialises the given `For` type, into a file
 +  using the provided `Adapter` type.
 + ++/
ServiceInfo addFileConfig(For, Adapter)(string fileName)
{
    return ServiceInfo.asSingleton!(
        IConfig!For, 
        AdaptableFileConfig!(For, Adapter)
    )(
        (ref _)
        { 
            auto config = new AdaptableFileConfig!(For, Adapter)(fileName);
            config.load();

            return config;
        }
    );
}

/// ditto.
ServiceInfo[] addFileConfig(For, Adapter)(ref ServiceInfo[] services, string fileName)
{
    services ~= addFileConfig!(For, Adapter)(fileName);
    return services;
}
/// The default core provided by JCLI, the 'heart' of your command line tool.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.core;

private
{
    import std.typecons : Flag;
    import std.traits   : isSomeChar, hasUDA;
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.parser, jaster.cli.udas, jaster.cli.binder, jaster.cli.helptext, jaster.cli.resolver, jaster.cli.infogen, jaster.cli.commandparser, jaster.cli.result;
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.ioc;
}

public
{
    import std.typecons : Nullable;
}

/// 
alias IgnoreFirstArg = Flag!"ignoreFirst";

private alias CommandExecuteFunc = Result!int delegate(ArgPullParser parser, scope ref ServiceScope services, HelpTextBuilderSimple helpText);
private alias CommandCompleteFunc = void delegate(string[] before, string current, string[] after, ref char[] output);

/// See `CommandLineSettings.sink`
alias CommandLineSinkFunc = void delegate(string text);

/++
 + A service that allows commands to access the `CommandLineInterface.parseAndExecute` function of the command's `CommandLineInterface`.
 +
 + Notes:
 +  You **must** use `addCommandLineInterfaceService` to add the default implementation of this service into your `ServiceProvider`, you can of course
 +  create your own implementation, but note that `CommandLineInterface` has special support for the default implementation.
 +
 +  Alternatively, don't pass a `ServiceProvider` into your `CommandLineInterface`, and it'll create this service by itself.
 + ++/
interface ICommandLineInterface
{
    /// See: `CommandLineInterface.parseAndExecute`
    int parseAndExecute(string[] args, IgnoreFirstArg ignoreFirst = IgnoreFirstArg.yes);
}

private final class ICommandLineInterfaceImpl : ICommandLineInterface
{
    alias ParseAndExecuteT = int delegate(string[], IgnoreFirstArg);

    private ParseAndExecuteT _func;

    override int parseAndExecute(string[] args, IgnoreFirstArg ignoreFirst = IgnoreFirstArg.yes)
    {
        return this._func(args, ignoreFirst);
    }
}

/++
 + Returns:
 +  A Singleton `ServiceInfo` providing the default implementation for `ICommandLineInterface`.
 + ++/
ServiceInfo addCommandLineInterfaceService()
{
    return ServiceInfo.asSingleton!(ICommandLineInterface, ICommandLineInterfaceImpl);
}

/// ditto.
ServiceInfo[] addCommandLineInterfaceService(ref ServiceInfo[] services)
{
    services ~= addCommandLineInterfaceService();
    return services;
}

/+ COMMAND INFO CREATOR FUNCTIONS +/
private HelpTextBuilderSimple createHelpText(alias CommandT, alias ArgBinderInstance)(string appName)
{
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.commandhelptext;
    return CommandHelpText!(CommandT, ArgBinderInstance).init.toBuilder(appName);
}

private CommandCompleteFunc createCommandCompleteFunc(alias CommandT, alias ArgBinderInstance)()
{
    import std.algorithm : filter, map, startsWith, splitter, canFind;
    import std.exception : assumeUnique;

    enum Info = getCommandInfoFor!(CommandT, ArgBinderInstance);

    return (string[] before, string current, string[] after, ref char[] output)
    {
        // Check if there's been a null ("--") or '-' ("---"), and if there has, don't bother with completion.
        // Because anything past that is of course, the raw arg list.
        if(before.canFind(null) || before.canFind("-"))
            return;

        // See if the previous value was a non-boolean argument.
        const justBefore               = ArgPullParser(before[$-1..$]).front;
        auto  justBeforeNamedArgResult = Info.namedArgs.filter!(a => a.uda.pattern.matchSpaceless(justBefore.value));
        if((justBefore.type == ArgTokenType.LongHandArgument || justBefore.type == ArgTokenType.ShortHandArgument)
        && (!justBeforeNamedArgResult.empty && justBeforeNamedArgResult.front.parseScheme != CommandArgParseScheme.bool_))
        {
            // TODO: In the future, add support for specifying values to a parameter, either static and/or dynamically.
            return;
        }

        // Otherwise, we either need to autocomplete an argument's name, or something else that's predefined.

        string[] names;
        names.reserve(Info.namedArgs.length * 2);

        foreach(arg; Info.namedArgs)
        {
            foreach(pattern; arg.uda.pattern.byEach)
            {
                // Reminder: Confusingly for this use case, arguments don't have their leading dashes in the before and after arrays.
                if(before.canFind(pattern) || after.canFind(pattern))
                    continue;

                names ~= pattern;
            }
        }

        foreach(name; names.filter!(n => n.startsWith(current)))
        {
            output ~= (name.length == 1) ? "-" : "--";
            output ~= name;
            output ~= ' ';
        }
    };
}

private CommandExecuteFunc createCommandExecuteFunc(alias CommandT, alias ArgBinderInstance)(CommandLineSettings settings)
{
    import std.format    : format;
    import std.algorithm : filter, map;
    import std.exception : enforce, collectException;

    enum Info = getCommandInfoFor!(CommandT, ArgBinderInstance);

    // This is expecting the parser to have already read in the command's name, leaving only the args.
    return (ArgPullParser parser, scope ref ServiceScope services, HelpTextBuilderSimple helpText)
    {
        if(containsHelpArgument(parser))
        {
            settings.sink.get()(helpText.toString() ~ '\n');
            return Result!int.success(0);
        }

        // Cross-stage state.
        CommandT commandInstance;

        // Create the command and fetch its arg info.
        commandInstance = Injector.construct!CommandT(services);
        static if(is(T == class))
            assert(commandInstance !is null, "Dependency injection failed somehow.");

        // Execute stages
        auto commandParser = CommandParser!(CommandT, ArgBinderInstance)();
        auto parseResult = commandParser.parse(parser, commandInstance);
        if(!parseResult.isSuccess)
            return Result!int.failure(parseResult.asFailure.error);

        return onExecuteRunCommand!CommandT(/*ref*/ commandInstance);
    };
}

private Result!int onExecuteRunCommand(alias T)(ref T commandInstance)
{
    static assert(
        __traits(compiles, commandInstance.onExecute())
     || __traits(compiles, { int code = commandInstance.onExecute(); }),
        "Unable to call the `onExecute` function for command `"~__traits(identifier, T)~"` please ensure it's signature matches either:"
        ~"\n\tvoid onExecute();"
        ~"\n\tint onExecute();"
    );

    try
    {
        static if(__traits(compiles, {int i = commandInstance.onExecute();}))
            return Result!int.success(commandInstance.onExecute());
        else
        {
            commandInstance.onExecute();
            return Result!int.success(0);
        }
    }
    catch(Exception ex)
    {
        auto error = ex.msg;
        debug error ~= "\n\nSTACK TRACE:\n" ~ ex.info.toString(); // trace info
        return Result!int.failure(error);
    }
}


/++
 + Settings that can be provided to `CommandLineInterface` to change certain behaviour.
 + ++/
struct CommandLineSettings
{
    /++
     + The name of your application, this is only used when displaying error messages and help text.
     +
     + If left as `null`, then the executable's name is used instead.
     + ++/
    Nullable!string appName;

    /++
     + Whether or not `CommandLineInterface` should provide bash completion. Defaults to `false`.
     +
     + See_Also: The README for this project.
     + ++/
    bool bashCompletion = false;

    /++
     + A user-defined sink to call whenever `CommandLineInterface` itself (not it's subcomponents or commands) wants to
     + output text.
     +
     + If left as `null`, then a default sink is made where `std.stdio.write` is used.
     +
     + Notes:
     +  Strings passed to this function will already include a leading new line character where needed.
     + ++/
    Nullable!CommandLineSinkFunc sink;
}

/++
 + Provides the functionality of parsing command line arguments, and then calling a command.
 +
 + Description:
 +  The `Modules` template parameter is used directly with `jaster.cli.binder.ArgBinder` to provide the arg binding functionality.
 +  Please refer to `ArgBinder`'s documentation if you are wanting to use custom made binder funcs.
 +
 +  Commands are detected by looking over every module in `Modules`, and within each module looking for types marked with `@Command` and matching their patterns
 +  to the given input.
 +
 + Patterns:
 +  Patterns are pretty simple.
 +
 +  Example #1: The pattern "run" will match if the given command line args starts with "run".
 +
 +  Example #2: The pattern "run all" will match if the given command line args starts with "run all" (["run all"] won't work right now, only ["run", "all"] will)
 +
 +  Example #3: The pattern "r|run" will match if the given command line args starts with "r", or "run".
 +
 +  Longer patterns take higher priority than shorter ones.
 +
 +  Patterns with spaces are only allowed inside of `@Command` pattern UDAs. The `@CommandNamedArg` UDA is a bit more special.
 +
 +  For `@CommandNamedArg`, spaces are not allowed, since named arguments can't be split into spaces.
 +
 +  For `@CommandNamedArg`, patterns or subpatterns (When "|" is used to have multiple patterns) will be treated differently depending on their length.
 +  For patterns with only 1 character, they will be matched using short-hand argument form (See `ArgPullParser`'s documentation).
 +  For pattern with more than 1 character, they will be matched using long-hand argument form.
 +
 +  Example #4: The pattern (for `@CommandNamedArg`) "v|verbose" will match when either "-v" or "--verbose" is used.
 +
 +  Internally, `CommandResolver` is used to perform command resolution, and a solution custom to `CommandLineInterface` is used for everything else
 +  regarding patterns.
 +
 + Commands:
 +  A command is a struct or class that is marked with `@Command`.
 +
 +  A default command can be specified using `@CommandDefault` instead.
 +
 +  Commands have only one requirement - They have a function called `onExecute`.
 +
 +  The `onExecute` function is called whenever the command's pattern is matched with the command line arguments.
 +
 +  The `onExecute` function must be compatible with one of these signatures:
 +      `void onExecute();`
 +      `int onExecute();`
 +
 +  The signature that returns an `int` is used to return a custom status code.
 +
 +  If a command has its pattern matched, then its arguments will be parsed before `onExecute` is called.
 +
 +  Arguments are either positional (`@CommandPositionalArg`) or named (`@CommandNamedArg`).
 +
 + Dependency_Injection:
 +  Whenever a command object is created, it is created using dependency injection (via the `jioc` library).
 +
 +  Each command is given its own service scope, even when a command calls another command.
 +
 + Positional_Arguments:
 +  A positional arg is an argument that appears in a certain 'position'. For example, imagine we had a command that we wanted to
 +  execute by using `"myTool create SomeFile.txt \"This is some content\""`.
 +
 +  The shell will pass `["create", "SomeFile.txt", "This is some content"]` to our program. We will assume we already have a command that will match with "create".
 +  We are then left with the other two strings.
 +
 +  `"SomeFile.txt"` is in the 0th position, so its value will be binded to the field marked with `@CommandPositionalArg(0)`.
 +
 +  `"This is some content"` is in the 1st position, so its value will be binded to the field marked with `@CommandPositionalArg(1)`.
 +
 + Named_Arguments:
 +  A named arg is an argument that follows a name. Names are either in long-hand form ("--file") or short-hand form ("-f").
 +
 +  For example, imagine we execute a custom tool with `"myTool create -f=SomeFile.txt --content \"This is some content\""`.
 +
 +  The shell will pass `["create", "-f=SomeFile.txt", "--content", "This is some content"]`. Notice how the '-f' uses an '=' sign, but '--content' doesn't.
 +  This is because the `ArgPullParser` supports various different forms of named arguments (e.g. ones that use '=', and ones that don't).
 +  Please refer to its documentation for more information.
 +
 +  Imagine we already have a command made that matches with "create". We are then left with the rest of the arguments.
 +
 +  "-f=SomeFile.txt" is parsed as an argument called "f" with the value "SomeFile.txt". Using the logic specified in the "Binding Arguments" section (below), 
 +  we perform the binding of "SomeFile.txt" to whichever field marked with `@CommandNamedArg` matches with the name "f".
 +
 +  `["--content", "This is some content"]` is parsed as an argument called "content" with the value "This is some content". We apply the same logic as above.
 +
 + Binding_Arguments:
 +  Once we have matched a field marked with either `@CommandPositionalArg` or `@CommandNamedArg` with a position or name (respectively), then we
 +  need to bind the value to the field.
 +
 +  This is where the `ArgBinder` is used. First of all, please refer to its documentation as it's kind of important.
 +  Second of all, we esentially generate a call similar to: `ArgBinderInstance.bind(myCommandInstance.myMatchedField, valueToBind)`
 +
 +  So imagine we have this field inside a command - `@CommandPositionalArg(0) int myIntField;`
 +
 +  Now imagine we have the value "200" in the 0th position. This means it'll be matchd with `myIntField`.
 +
 +  This will esentially generate this call: `ArgBinderInstance.bind(myCommandInstance.myIntField, "200")`
 +
 +  From there, ArgBinder will do its thing of binding/converting the string "200" into the integer 200.
 +
 +  `ArgBinder` has support for user-defined binders (in fact, all of the built-in binders use this mechanism!). Please
 +  refer to its documentation for more information, or see example-04.
 +
 +  You can also specify validation for arguments, by attaching structs (that match the definition specified in `ArgBinder`'s documentation) as
 +  UDAs onto your fields.
 +
 +  $(B Beware) you need to attach your validation struct as `@Struct()` (or with args) and not `@Struct`, notice the first one has parenthesis.
 +
 + Boolean_Binding:
 +  Bool arguments have special logic in place.
 +
 +  By only passing the name of a boolean argument (e.g. "--verbose"), this is treated as setting "verbose" to "true" using the `ArgBinder`.
 +
 +  By passing a value alongside a boolean argument that is either "true" or "false" (e.g. "--verbose true", "--verbose=false"), then the resulting
 +  value is passed to the `ArgBinder` as usual. In other words, "--verbose" is equivalent to "--verbose true".
 +
 +  By passing a value alongside a boolean argument that $(B isn't) one of the preapproved words then: The value will be treated as a positional argument;
 +  the boolean argument will be set to true.
 +
 +  For example, "--verbose" sets "verbose" to "true". Passing "--verbose=false/true" will set "verbose" to "false" or "true" respectively. Passing
 +  "--verbose push" would leave "push" as a positional argument, and then set "verbose" to "true".
 +
 +  These special rules are made so that boolean arguments can be given an explicit value, without them 'randomly' treating positional arguments as their value.
 +
 + Optional_And_Required_Arguments:
 +  By default, all arguments are required.
 +
 +  To make an optional argument, you must make it `Nullable`. For example, to have an optional `int` argument you'd use `Nullable!int` as the type.
 +
 +  Note that `Nullable` is publicly imported by this module, for ease of use.
 +
 +  Before a nullable argument is binded, it is first lowered down into its base type before being passed to the `ArgBinder`.
 +  In other words, a `Nullable!int` argument will be treated as a normal `int` by the ArgBinder.
 +
 +  If **any** required argument is not provided by the user, then an exception is thrown (which in turn ends up showing an error message).
 +  This does not occur with missing optional arguments.
 +
 + Raw_Arguments:
 +  For some applications, they may allow the ability for the user to provide a set of unparsed arguments. For example, dub allows the user
 +  to provide a set of arguments to the resulting output, when using the likes of `dub run`, e.g. `dub run -- value1 value2 etc.`
 +
 +  `CommandLineInterface` also provides this ability. You can use either the double dash like in dub ('--') or a triple dash (legacy reasons, '---').
 +
 +  After that, as long as your command contains a `string[]` field marked with `@CommandRawListArg`, then any args after the triple dash are treated as "raw args" - they
 +  won't be parsed, passed to the ArgBinder, etc. they'll just be passed into the variable as-is.
 +
 +  For example, you have the following member in a command `@CommandRawListArg string[] rawList;`, and you are given the following command - 
 +  `["command", "value1", "--", "rawValue1", "rawValue2"]`, which will result in `rawList`'s value becoming `["rawValue1", "rawValue2"]`
 +
 + Arguments_Groups:
 +  Arguments can be grouped together so they are displayed in a more logical manner within your command's help text.
 +
 +  The recommended way to make an argument group, is to create an `@CommandArgGroup` UDA block:
 +
 +  ```
 +  @CommandArgGroup("Debug", "Flags relating the debugging.")
 +  {
 +      @CommandNamedArg("trace|t", "Enable tracing") Nullable!bool trace;
 +      ...
 +  }
 +  ```
 +
 +  While you *can* apply the UDA individually to each argument, there's one behaviour that you should be aware of - the group's description
 +  as displayed in the help text will use the description of the $(B last) found `@CommandArgGroup` UDA.
 +
 + Params:
 +  Modules = The modules that contain the commands and/or binder funcs to use.
 +
 + See_Also:
 +  `jaster.cli.infogen` if you'd like to introspect information about commands yourself.
 +
 +  `jaster.cli.commandparser` if you only require the ability to parse commands.
 + +/
final class CommandLineInterface(Modules...)
{
    private alias DefaultCommands = getSymbolsByUDAInModules!(CommandDefault, Modules);
    static assert(DefaultCommands.length <= 1, "Multiple default commands defined " ~ DefaultCommands.stringof);

    static if(DefaultCommands.length > 0)
    {
        static assert(is(DefaultCommands[0] == struct) || is(DefaultCommands[0] == class),
            "Only structs and classes can be marked with @CommandDefault. Issue Symbol = " ~ __traits(identifier, DefaultCommands[0])
        );
        static assert(!hasUDA!(DefaultCommands[0], Command),
            "Both @CommandDefault and @Command are used for symbol " ~ __traits(identifier, DefaultCommands[0])
        );
    }

    alias ArgBinderInstance = ArgBinder!Modules;

    private enum Mode
    {
        execute,
        complete,
        bashCompletion
    }

    private enum ParseResultType
    {
        commandFound,
        commandNotFound,
        showHelpText
    }

    private struct ParseResult
    {
        ParseResultType type;
        CommandInfo     command;
        string          helpText;
        ArgPullParser   argParserAfterAttempt;
        ArgPullParser   argParserBeforeAttempt;
        ServiceScope    services;
    }

    private struct CommandInfo
    {
        Pattern               pattern; // Patterns (and their helper functions) are still being kept around, so previous code can work unimpeded from the migration to CommandResolver.
        string                description;
        HelpTextBuilderSimple helpText;
        CommandExecuteFunc    doExecute;
        CommandCompleteFunc   doComplete;
    }

    /+ VARIABLES +/
    private
    {
        CommandResolver!CommandInfo _resolver;
        CommandLineSettings         _settings;
        ServiceProvider             _services;
        Nullable!CommandInfo        _defaultCommand;
    }

    /+ PUBLIC INTERFACE +/
    public final
    {
        this(ServiceProvider services = null)
        {
            this(CommandLineSettings.init, services);
        }

        /++
         + Params:
         +  services = The `ServiceProvider` to use for dependency injection.
         +             If this value is `null`, then a new `ServiceProvider` will be created containing an `ICommandLineInterface` service.
         + ++/
        this(CommandLineSettings settings, ServiceProvider services = null)
        {
            import std.algorithm : sort;
            import std.file      : thisExePath;
            import std.path      : baseName;
            import std.stdio     : write;

            if(settings.appName.isNull)
                settings.appName = thisExePath.baseName;

            if(settings.sink.isNull)
                settings.sink = (string str) { write(str); };

            if(services is null)
                services = new ServiceProvider([addCommandLineInterfaceService()]);

            this._services = services;
            this._settings = settings;
            this._resolver = new CommandResolver!CommandInfo();

            addDefaultCommand();

            static foreach(mod; Modules)
                this.addCommandsFromModule!mod();
        }
        
        /++
         + Parses the given `args`, and then executes the appropriate command (if one was found).
         +
         + Notes:
         +  If an exception is thrown, the error message is displayed on screen (as well as the stack trace, for non-release builds)
         +  and then -1 is returned.
         +
         + See_Also:
         +  The documentation for `ArgPullParser` to understand the format for `args`.
         +
         + Params:
         +  args        = The args to parse.
         +  ignoreFirst = Whether to ignore the first value of `args` or not.
         +                If `args` is passed as-is from the main function, then the first value will
         +                be the path to the executable, and should be ignored.
         +
         + Returns:
         +  The status code returned by the command, or -1 if an exception is thrown.
         + +/
        int parseAndExecute(string[] args, IgnoreFirstArg ignoreFirst = IgnoreFirstArg.yes)
        {
            if(ignoreFirst)
            {
                if(args.length <= 1)
                    args.length = 0;
                else
                    args = args[1..$];
            }

            return this.parseAndExecute(ArgPullParser(args));
        } 

        /// ditto
        int parseAndExecute(ArgPullParser args)
        {
            import std.algorithm : filter, any;
            import std.exception : enforce;
            import std.format    : format;

            if(args.empty && this._defaultCommand.isNull)
            {
                this.writeln(this.makeErrorf("No command was given."));
                this.writeln(this.createAvailableCommandsHelpText(args, "Available commands").toString());
                return -1;
            }

            Mode mode = Mode.execute;

            if(this._settings.bashCompletion && args.front.type == ArgTokenType.Text)
            {
                if(args.front.value == "__jcli:complete")
                    mode = Mode.complete;
                else if(args.front.value == "__jcli:bash_complete_script")
                    mode = Mode.bashCompletion;
            }

            ParseResult parseResult;

            parseResult.argParserBeforeAttempt = args; // If we can't find the exact command, sometimes we can get a partial match when showing help text.
            parseResult.type                   = ParseResultType.commandFound; // Default to command found.
            auto result                        = this._resolver.resolveAndAdvance(args);

            if(!result.success || result.value.type == CommandNodeType.partialWord)
            {
                if(args.containsHelpArgument())
                {
                    parseResult.type = ParseResultType.showHelpText;
                    if(!this._defaultCommand.isNull)
                        parseResult.helpText ~= this._defaultCommand.get.helpText.toString();

                    if(this._resolver.finalWords.length > 0)
                        parseResult.helpText ~= this.createAvailableCommandsHelpText(parseResult.argParserBeforeAttempt, "Available commands").toString();
                }
                else if(this._defaultCommand.isNull)
                {
                    parseResult.type      = ParseResultType.commandNotFound;
                    parseResult.helpText ~= this.makeErrorf("Unknown command '%s'.\n", parseResult.argParserBeforeAttempt.front.value);
                    parseResult.helpText ~= this.createAvailableCommandsHelpText(parseResult.argParserBeforeAttempt).toString();
                }
                else
                    parseResult.command = this._defaultCommand.get;
            }
            else
                parseResult.command = result.value.userData;

            parseResult.argParserAfterAttempt = args;
            parseResult.services              = this._services.createScope(); // Reminder: ServiceScope uses RAII.

            // Special support: For our default implementation of `ICommandLineInterface`, set its value.
            auto proxy = cast(ICommandLineInterfaceImpl)parseResult.services.getServiceOrNull!ICommandLineInterface();
            if(proxy !is null)
                proxy._func = &this.parseAndExecute;

            final switch(mode) with(Mode)
            {
                case execute:        return this.onExecute(parseResult);
                case complete:       return this.onComplete(parseResult);
                case bashCompletion: return this.onBashCompletionScript();
            }
        }
    }

    /+ COMMAND DISCOVERY AND REGISTRATION +/
    private final
    {
        void addDefaultCommand()
        {
            static if(DefaultCommands.length > 0)
                _defaultCommand = getCommand!(DefaultCommands[0]);
        }

        void addCommandsFromModule(alias Module)()
        {
            import std.traits : getSymbolsByUDA;

            static foreach(symbol; getSymbolsByUDA!(Module, Command))
            {{
                static assert(is(symbol == struct) || is(symbol == class),
                    "Only structs and classes can be marked with @Command. Issue Symbol = " ~ __traits(identifier, symbol)
                );

                enum Info = getCommandInfoFor!(symbol, ArgBinderInstance);

                auto info = getCommand!(symbol);
                info.pattern = Info.pattern;
                info.description = Info.description;

                foreach(pattern; info.pattern.byEach)
                    this._resolver.define(pattern, info);
            }}
        }

        CommandInfo getCommand(T)()
        {
            CommandInfo info;
            info.helpText   = createHelpText!(T, ArgBinderInstance)(this._settings.appName.get);
            info.doExecute  = createCommandExecuteFunc!(T, ArgBinderInstance)(this._settings);
            info.doComplete = createCommandCompleteFunc!(T, ArgBinderInstance)();

            return info;
        }
    }

    /+ MODE EXECUTORS +/
    private final
    {
        int onExecute(ref ParseResult result)
        {
            final switch(result.type) with(ParseResultType)
            {
                case showHelpText:
                    this.writeln(result.helpText);
                    return 0;

                case commandNotFound:
                    this.writeln(result.helpText);
                    return -1;

                case commandFound: break;
            }

            auto statusCode = result.command.doExecute(result.argParserAfterAttempt, result.services, result.command.helpText);
            if(!statusCode.isSuccess)
            {
                this.writeln(this.makeErrorf(statusCode.asFailure.error));
                return -1;
            }

            return statusCode.asSuccess.value;
        }

        int onComplete(ref ParseResult result)
        {
            // Parsing here shouldn't be affected by user-defined ArgBinders, so stuff being done here is done manually.
            // This way we gain reliability.
            //
            // Since this is also an internal function, error checking is much more lax.
            import std.array     : array;
            import std.algorithm : map, filter, splitter, equal, startsWith;
            import std.conv      : to;
            import std.stdio     : writeln; // Planning on moving this into its own component soon, so we'll just leave this writeln here.

            // Expected args:
            //  [0]    = COMP_CWORD
            //  [1..$] = COMP_WORDS
            result.argParserAfterAttempt.popFront(); // Skip __jcli:complete
            auto cword = result.argParserAfterAttempt.front.value.to!uint;
            result.argParserAfterAttempt.popFront();
            auto  words = result.argParserAfterAttempt.map!(t => t.value).array;

            cword -= 1;
            words = words[1..$]; // [0] is the exe name, which we don't care about.
            auto before  = words[0..cword];
            auto current = (cword < words.length)     ? words[cword]      : [];
            auto after   = (cword + 1 < words.length) ? words[cword+1..$] : [];

            auto beforeParser = ArgPullParser(before);
            auto commandInfo  = this._resolver.resolveAndAdvance(beforeParser);

            // Can't find command, so we're in "display command name" mode.
            if(!commandInfo.success || commandInfo.value.type == CommandNodeType.partialWord)
            {
                char[] output;
                output.reserve(1024); // Gonna be doing a good bit of concat.

                // Special case: When we have no text to look for, just display the first word of every command path.
                if(before.length == 0 && current is null)
                    commandInfo.value = this._resolver.root;

                // Otherwise try to match using the existing text.

                // Display the word of all children of the current command word.
                //
                // If the current argument word isn't null, then use that as a further filter.
                //
                // e.g.
                // Before  = ["name"]
                // Pattern = "name get"
                // Output  = "get"
                foreach(child; commandInfo.value.children)
                {
                    if(current.length > 0 && !child.word.startsWith(current))
                        continue;

                    output ~= child.word;
                    output ~= " ";
                }

                writeln(output);
                return 0;
            }

            // Found command, so we're in "display possible args" mode.
            char[] output;
            output.reserve(1024);

            commandInfo.value.userData.doComplete(before, current, after, /*ref*/ output); // We need black magic, so this is generated in addCommand.
            writeln(output);

            return 0;
        }

        int onBashCompletionScript()
        {
            import std.stdio : writefln;
            import std.file  : thisExePath;
            import std.path  : baseName;
//[CONTAINS_BLACKLISTED_IMPORT]            import jaster.cli.views.bash_complete : BASH_COMPLETION_TEMPLATE;

            const fullPath = thisExePath;
            const exeName  = fullPath.baseName;

            writefln(BASH_COMPLETION_TEMPLATE,
                exeName,
                fullPath,
                exeName,
                exeName
            );
            return 0;
        }
    }

    /+ UNCATEGORISED HELPERS +/
    private final
    {
        HelpTextBuilderTechnical createAvailableCommandsHelpText(ArgPullParser args, string sectionName = "Did you mean")
        {
            import std.array     : array;
            import std.algorithm : filter, sort, map, splitter, uniq;

            auto command = this._resolver.root;
            auto result  = this._resolver.resolveAndAdvance(args);
            if(result.success)
                command = result.value;

            auto builder = new HelpTextBuilderTechnical();
            builder.addSection(sectionName)
                   .addContent(
                       new HelpSectionArgInfoContent(
                           command.finalWords
                                  .uniq!((a, b) => a.userData.pattern == b.userData.pattern)
                                  .map!(c => HelpSectionArgInfoContent.ArgInfo(
                                       [c.userData.pattern.byEach.front],
                                       c.userData.description,
                                       ArgIsOptional.no
                                  ))
                                  .array
                                  .sort!"a.names[0] < b.names[0]"
                                  .array, // eww...
                            AutoAddArgDashes.no
                       )
            );

            return builder;
        }

        string makeErrorf(Args...)(string formatString, Args args)
        {
            import std.format : format;
            return "%s: %s".format(this._settings.appName.get, formatString.format(args));
        }

        void writeln(string str)
        {
            assert(!this._settings.sink.isNull, "The ctor should've set this.");

            auto sink = this._settings.sink.get();
            assert(sink !is null, "The sink was set, but it's still null.");

            sink(str);
            sink("\n");
        }
    }
}

// HELPER FUNCS

private bool containsHelpArgument(ArgPullParser args)
{
    import std.algorithm : any;

    return args.any!(t => t.type == ArgTokenType.ShortHandArgument && t.value == "h"
                       || t.type == ArgTokenType.LongHandArgument && t.value == "help");
}

version(unittest)
{
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.result;
    private alias InstansiationTest = CommandLineInterface!(jaster.cli.core);

    @CommandDefault("This is the default command.")
    private struct DefaultCommandTest
    {
        @CommandNamedArg("var", "A variable")
        int a;

        int onExecute()
        {
            return a % 2 == 0
            ? a
            : 0;
        }
    }

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
    @("Default command test")

*/
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        auto cli = new CommandLineInterface!(jaster.cli.core);
        assert(cli.parseAndExecute(["--var 1"], IgnoreFirstArg.no) == 0);
        assert(cli.parseAndExecute(["--var 2"], IgnoreFirstArg.no) == 2);
    }
*/

    @Command("arg group test", "Test arg groups work")
    private struct ArgGroupTestCommand
    {
        @CommandPositionalArg(0)
        string a;

        @CommandNamedArg("b")
        string b;

        @CommandArgGroup("group1", "This is group 1")
        {
            @CommandPositionalArg(1)
            string c;

            @CommandNamedArg("d")
            string d;
        }

        void onExecute(){}
    }
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
    @("Test that @CommandArgGroup is handled properly.")

*/
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        import std.algorithm : canFind;

        // Accessing a lot of private state here, but that's because we don't have a mechanism to extract the output properly.
        auto cli = new CommandLineInterface!(jaster.cli.core);
        auto helpText = cli._resolver.resolve("arg group test").value.userData.helpText;

        assert(helpText.toString().canFind(
            "group1:\n"
           ~"    This is group 1\n"
           ~"\n"
           ~"    VALUE"
        ));
    }
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
    @("Test that CommandLineInterface's sink works")

*/
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        import std.algorithm : canFind;

        string log;

        CommandLineSettings settings;
        settings.sink = (string str) { log ~= str; };

        auto cli = new CommandLineInterface!(jaster.cli.core)(settings);
        cli.parseAndExecute(["--help"], IgnoreFirstArg.no);

        assert(log.length > 0);
        assert(log.canFind("arg group test"), log); // The name of that unittest command has no real reason to change or to be removed, so I feel safe relying on it.
    }
*/
}

/// Utilities for creating help text.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.helptext;

private
{
    import std.typecons : Flag;
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.udas;
}

/// A flag that should be used by content classes that have the ability to auto add argument dashes to arg names.
/// (e.g. "-" and "--")
alias AutoAddArgDashes = Flag!"addArgDashes";

alias ArgIsOptional = Flag!"isOptional";

/++
 + The interface for any class that can be used to generate content inside of a help
 + text section.
 + ++/
interface IHelpSectionContent
{
    /++
     + Generates a string to display inside of a help text section.
     +
     + Params:
     +  options = Options regarding how the text should be formatted.
     +            Please try to match these options as closely as possible.
     +
     + Returns:
     +  The generated content string.
     + ++/
    string getContent(const HelpSectionOptions options);

    // Utility functions
    protected final
    {
        string lineWrap(const HelpSectionOptions options, const(char)[] value)
        {
//[CONTAINS_BLACKLISTED_IMPORT]            import jaster.cli.text : lineWrap, LineWrapOptions;

            return value.lineWrap(LineWrapOptions(options.lineCharLimit, options.linePrefix));
        }
    }
}

/++
 + A help text section.
 +
 + A section is basically something like "Description:", or "Arguments:", etc.
 +
 + Notes:
 +  Instances of this struct aren't ever really supposed to be kept around outside of `HelpTextBuilderTechnical`, so it's
 +  non-copyable.
 + ++/
struct HelpSection
{
    /// The name of the section.
    string name;

    /// The content of this section.
    IHelpSectionContent[] content;

    /// The formatting options for this section.
    HelpSectionOptions options;

    /++
     + Adds a new piece of content to this section.
     +
     + Params:
     +  content = The content to add.
     +
     + Returns:
     +  `this`
     + ++/
    ref HelpSection addContent(IHelpSectionContent content) return
    {
        assert(content !is null);
        this.content ~= content;

        return this;
    }

    @disable this(this){}
}

/++
 + Options on how the text of a section is formatted.
 +
 + Notes:
 +  It is up to the individual `IHelpSectionContent` implementors to follow these options.
 + ++/
struct HelpSectionOptions
{
    /// The prefix to apply to every new line of text inside the section.
    string linePrefix;

    /// How many chars there are per line. This should be seen as a hard limit.
    size_t lineCharLimit = 120;
}

/++
 + A class used to create help text, in an object oriented fashion.
 +
 + Technical_Versus_Simple:
 +  The Technical version of this class is meant to give the user full control of what's generated.
 +
 +  The Simple version (and any other versions the user may create) are meant to have more of a scope/predefined layout,
 +  and so are simpler to use.
 +
 + Isnt_This_Overcomplicated?:
 +  Kind of...
 +
 +  A goal of this library is to make it's foundational parts (such as this class, and the `ArgBinder` stuff) reusable on their own,
 +  so even if the user doesn't like how I've designed the core part of the library (Everything in `jaster.cli.core`, and the UDAs relating to it)
 +  they are given a small foundation to work off of to create their own version.
 +
 +  So I kind of need this to be a bit more complicated than it should be, so it's easy for me to provide built-in functionality that can be used
 +  or not used as wished by the user, while also allowing the user to create their own.
 + ++/
final class HelpTextBuilderTechnical
{
    /// The default options for a section.
    static const DEFAULT_SECTION_OPTIONS = HelpSectionOptions("    ", 120);

    private
    {
        string[]           _usages;
        HelpSection[]      _sections;
        HelpSectionOptions _sectionOptions = DEFAULT_SECTION_OPTIONS;
    }

    public final
    {
        /// Adds a new usage.
        void addUsage(string usageText)
        {
            this._usages ~= usageText;
        }

        /++
         + Adds a new section.
         +
         + Params:
         +  sectionName = The name of the section.
         +
         + Returns:
         +  A reference to the section, so that the `addContent` function can be called.
         + ++/
        ref HelpSection addSection(string sectionName)
        {
            this._sections.length += 1;
            this._sections[$-1].name = sectionName;
            this._sections[$-1].options = this._sectionOptions;

            return this._sections[$-1];
        }

        ///
        ref HelpSection getOrAddSection(string sectionName)
        {
            // If this is too slow then we can move to an AA
            // (p.s. std.algorithm doesn't see _sections as an input range, even if I import std.range for the array primitives)
            foreach(ref section; this._sections)
            {
                if(section.name == sectionName)
                    return section;
            }

            return this.addSection(sectionName);
        }

        /++
         + Modifies an existing section (by returning it by reference).
         +
         + Assertions:
         +  `sectionName` must exist.
         +
         + Params:
         +  sectionName = The name of the section to modify.
         +
         + Returns:
         +  A reference to the section, so it can be modified by calling code.
         + ++/
        ref HelpSection modifySection(string sectionName)
        {
            foreach(ref section; this._sections)
            {
                if(section.name == sectionName)
                    return section;
            }

            assert(false, "No section called '"~sectionName~"' was found.");
        }

        /++
         + Generates the help text based on the given usages and sections.
         +
         + Notes:
         +  The result of this function aren't cached yet.
         +
         + Returns:
         +  The generated text.
         + ++/
        override string toString()
        {
            import std.array     : appender;
            import std.algorithm : map, each, joiner;
            import std.exception : assumeUnique;
            import std.format    : format;

            char[] output;
            output.reserve(4096);

            // Usages
            this._usages.map!(u => "Usage: "~u)
                        .joiner("\n")
                        .each!(u => output ~= u);

            // Sections
            foreach(ref section; this._sections)
            {
                if(section.content.length == 0)
                    continue;

                // This could all technically be 'D-ified'/'rangeified' but I couldn't make it look nice.
                if(output.length > 0)
                    output ~= "\n\n";
                    
                output ~= section.name~":\n";
                section.content.map!(c => c.getContent(section.options))
                               .joiner("\n")
                               .each!(c => output ~= c);
            }

            return output.assumeUnique;
        }
    }
}

/++
 + A simpler version of `HelpTextBuilerTechnical`, as it has a fixed layout, and handles all of the section and content generation.
 +
 + Description:
 +  This help text builder contains the following:
 +
 +      * A single 'Usage' line, which is generated automatically from the rest of the given data.
 +      * A description section.
 +      * A section for positional parameters, which are given a position, description, and an optional display name.
 +      * A section for named parameters, which can have multiple names, and a description.
 +
 + Please see the unittest for an example of its usage and output.
 + ++/
final class HelpTextBuilderSimple
{
    private
    {
        alias NamedArg = HelpSectionArgInfoContent.ArgInfo;

        struct PositionalArg
        {
            size_t position;
            HelpSectionArgInfoContent.ArgInfo info;
        }

        struct ArgGroup
        {
            string name;
            string description;
            NamedArg[] named;
            PositionalArg[] positional;

            bool isDefaultGroup()
            {
                return this.name is null;
            }
        }

        struct ArgGroupOrder
        {
            string name;
            int order;
        }

        string           _commandName;
        string           _description;
        ArgGroup[string] _groups;
        ArgGroupOrder[]  _groupOrders;

        ref ArgGroup groupByName(string name)
        {
            return this._groups.require(name, () 
            { 
                this._groupOrders ~= ArgGroupOrder(name, cast(int)this._groupOrders.length);
                return ArgGroup(name); 
            }());
        }
    }

    public final
    {
        ///
        HelpTextBuilderSimple addNamedArg(string group, string[] names, string description, ArgIsOptional isOptional)
        {
            this.groupByName(group).named ~= HelpSectionArgInfoContent.ArgInfo(names, description, isOptional);
            return this;
        }

        ///
        HelpTextBuilderSimple addNamedArg(string group, string name, string description, ArgIsOptional isOptional)
        {
            return this.addNamedArg(group, [name], description, isOptional);
        }

        ///
        HelpTextBuilderSimple addNamedArg(string[] names, string description, ArgIsOptional isOptional)
        {
            return this.addNamedArg(null, names, description, isOptional);
        }

        ///
        HelpTextBuilderSimple addNamedArg(string name, string description, ArgIsOptional isOptional)
        {
            return this.addNamedArg(null, name, description, isOptional);
        }

        ///
        HelpTextBuilderSimple addPositionalArg(string group, size_t position, string description, ArgIsOptional isOptional, string displayName = null)
        {
            import std.conv : to;

            this.groupByName(group).positional ~= PositionalArg(
                position,
                HelpSectionArgInfoContent.ArgInfo(
                    (displayName is null) ? [] : [displayName],
                    description,
                    isOptional
                )
            );

            return this;
        }

        ///
        HelpTextBuilderSimple addPositionalArg(size_t position, string description, ArgIsOptional isOptional, string displayName = null)
        {
            return this.addPositionalArg(null, position, description, isOptional, displayName);
        }

        ///
        HelpTextBuilderSimple setGroupDescription(string group, string description)
        {
            this.groupByName(group).description = description;
            return this;
        }

        ///
        HelpTextBuilderSimple setDescription(string desc)
        {
            this.description = desc;
            return this;
        }

        ///
        HelpTextBuilderSimple setCommandName(string name)
        {
            this.commandName = name;
            return this;
        }

        ///
        @property
        ref string description()
        {
            return this._description;
        }
        
        ///
        @property
        ref string commandName()
        {
            return this._commandName;
        }

        override string toString()
        {
            import std.algorithm : map, joiner, sort, filter;
            import std.array     : array;
            import std.range     : tee;
            import std.format    : format;
            import std.exception : assumeUnique;

            auto builder = new HelpTextBuilderTechnical();

            char[] usageString;
            usageString.reserve(512);
            usageString ~= this._commandName;
            usageString ~= ' ';

            if(this.description !is null)
            {
                builder.addSection("Description")
                       .addContent(new HelpSectionTextContent(this._description));
            }

            void writePositionalArgs(ref HelpSection section, PositionalArg[] args)
            {
                section.addContent(new HelpSectionArgInfoContent(
                    args.tee!((p)
                        {
                            // Using git as a precedant for the angle brackets.
                            auto name = "%s".format(p.info.names.joiner("/"));
                            usageString ~= (p.info.isOptional)
                                            ? "["~name~"]"
                                            : "<"~name~">";
                            usageString ~= ' ';
                        })
                        .map!(p => p.info)
                        .array,
                        AutoAddArgDashes.no
                    )
                );
            }

            void writeNamedArgs(Range)(ref HelpSection section, Range args)
            {
                if(args.empty)
                    return;

                section.addContent(new HelpSectionArgInfoContent(
                    args.tee!((a)
                        {
                            auto name = "%s".format(
                                a.names
                                    .map!(n => (n.length == 1) ? "-"~n : "--"~n)
                                    .joiner("|")
                            );

                            usageString ~= (a.isOptional)
                                            ? "["~name~"]"
                                            : name;
                            usageString ~= ' ';
                        })
                        .array,
                        AutoAddArgDashes.yes
                    )
                );
            }

            ref HelpSection getGroupSection(ArgGroup group)
            {
                scope section = &builder.getOrAddSection(group.name);
                if(section.content.length == 0 && group.description !is null)
                {
                    // Section was just made, so add in the description.
                    section.addContent(new HelpSectionTextContent(group.description~"\n"));
                }

                return *section;
            }

            // Not overly efficient, but keep in mind in most programs this function will only ever be called once per run (if even that).
            // The speed is fast enough not to be annoying either.
            // O(3n) + whatever .sort is.
            //
            // The reason we're doing it this way is to ensure everything is shown in this order:
            //  Positional args
            //  Required named args
            //  Optional named args
            //
            // Otherwise you get a mess like: Usage: tool.exe complex <file> --iterations|-i [--verbose|-v] <output> --config|-c
            this._groupOrders.sort!"a.order < b.order"();
            auto groupsInOrder = this._groupOrders.map!(go => this._groups[go.name]);

            // Pre-make certain sections
            builder.addSection("Positional Args");
            builder.addSection("Named Args");

            // Pass #1: Write positional args first, since that puts the usage string in the right order.
            foreach(group; groupsInOrder)
            {
                if(group.positional.length == 0)
                    continue;

                scope section = (group.isDefaultGroup) ? &builder.getOrAddSection("Positional Args") : &getGroupSection(group);
                writePositionalArgs(*section, group.positional);
            }

            // Pass #2: Write required named args.
            foreach(group; groupsInOrder)
            {
                if(group.named.length == 0)
                    continue;

                scope section = (group.isDefaultGroup) ? &builder.getOrAddSection("Named Args") : &getGroupSection(group);
                writeNamedArgs(*section, group.named.filter!(arg => !arg.isOptional));
            }

            // Pass #3: Write optional named args.
            foreach(group; groupsInOrder)
            {
                if(group.named.length == 0)
                    continue;

                scope section = (group.isDefaultGroup) ? &builder.getOrAddSection("Named Args") : &getGroupSection(group);
                writeNamedArgs(*section, group.named.filter!(arg => arg.isOptional));
            }

            builder.addUsage(usageString.assumeUnique);
            return builder.toString();
        }
    }
}
///
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    auto builder = new HelpTextBuilderSimple();

    builder.addPositionalArg(0, "The input file.", ArgIsOptional.no, "InputFile")
           .addPositionalArg(1, "The output file.", ArgIsOptional.no, "OutputFile")
           .addPositionalArg("Utility", 2, "How much to compress the file.", ArgIsOptional.no, "CompressionLevel")
           .addNamedArg(["v","verbose"], "Verbose output", ArgIsOptional.yes)
           .addNamedArg("Utility", "encoding", "Sets the encoding to use.", ArgIsOptional.yes)
           .setCommandName("MyCommand")
           .setDescription("This is a command that transforms the InputFile into an OutputFile")
           .setGroupDescription("Utility", "Utility arguments used to modify the output.");

    assert(builder.toString() == 
        "Usage: MyCommand <InputFile> <OutputFile> <CompressionLevel> [-v|--verbose] [--encoding] \n"
       ~"\n"
       ~"Description:\n"
       ~"    This is a command that transforms the InputFile into an OutputFile\n"
       ~"\n"
       ~"Positional Args:\n"
       ~"    InputFile                    - The input file.\n"
       ~"    OutputFile                   - The output file.\n"
       ~"\n"
       ~"Named Args:\n"
       ~"    -v,--verbose                 - Verbose output\n"
       ~"\n"
       ~"Utility:\n"
       ~"    Utility arguments used to modify the output.\n"
       ~"\n"
       ~"    CompressionLevel             - How much to compress the file.\n"
       ~"    --encoding                   - Sets the encoding to use.",

        "\n"~builder.toString()
    );
}
*/

/+ BUILT IN SECTION CONTENT +/

/++
 + A simple content class the simply displays a given string.
 +
 + Notes:
 +  This class is fully compliant with the `HelpSectionOptions`.
 + ++/
final class HelpSectionTextContent : IHelpSectionContent
{
    ///
    string text;

    ///
    this(string text)
    {
        this.text = text;
    }

    string getContent(const HelpSectionOptions options)
    {
        return this.lineWrap(options, this.text);
    }
}
///
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.exception : assertThrown;

    auto options = HelpSectionOptions("\t", 7 + 2); // '+ 2' is for the prefix + ending new line. 7 is the wanted char limit.
    auto content = new HelpSectionTextContent("Hey Hip Lell Loll");
    assert(content.getContent(options) == 
        "\tHey Hip\n"
       ~"\tLell Lo\n"
       ~"\tll",
    
        "\n"~content.getContent(options)
    );

    options.lineCharLimit = 200;
    assert(content.getContent(options) == "\tHey Hip Lell Loll");

    options.lineCharLimit = 2; // Enough for the prefix and ending new line, but not enough for any piece of text.
    assertThrown(content.getContent(options));

    options.lineCharLimit = 3; // Useable, but not readable.
    assert(content.getContent(options) ==
        "\tH\n"
       ~"\te\n"
       ~"\ty\n"

       ~"\tH\n"
       ~"\ti\n"
       ~"\tp\n"

       ~"\tL\n"
       ~"\te\n"
       ~"\tl\n"
       ~"\tl\n"

       ~"\tL\n"
       ~"\to\n"
       ~"\tl\n"
       ~"\tl"
    );
}
*/

/++
 + A content class for displaying information about a command line argument.
 +
 + Notes:
 +  Please see this class' unittest to see an example of it's output.
 + ++/
final class HelpSectionArgInfoContent : IHelpSectionContent
{
    /// The divisor used to determine how many characters to use for the arg's name(s)
    enum NAME_CHAR_LIMIT_DIVIDER = 4;

    /// The string used to split an arg's name(s) from its description.
    const MIDDLE_AFFIX = " - ";

    /// The information about the arg.
    struct ArgInfo
    {
        /// The different names that this arg can be used with (e.g 'v', 'verbose').
        string[] names;

        /// The description of the argument.
        string description;

        /// Whether the arg is optional or not.
        ArgIsOptional isOptional;
    }

    /// All registered args.
    ArgInfo[] args;

    /// Whether to add the dash prefix to the args' name(s). e.g. "--option" vs "option"
    AutoAddArgDashes addDashes;
    
    ///
    this(ArgInfo[] args, AutoAddArgDashes addDashes)
    {
        this.args = args;
        this.addDashes = addDashes;
    }

    string getContent(const HelpSectionOptions options)
    {
        import std.array     : array;
        import std.algorithm : map, reduce, filter, count, max, splitter, substitute;
        import std.conv      : to;
        import std.exception : assumeUnique;
        import std.utf       : byChar;

        // Calculate some variables.
        const USEABLE_CHARS     = (options.lineCharLimit - options.linePrefix.length) - MIDDLE_AFFIX.length; // How many chars in total we can use.
        const NAME_CHARS        = USEABLE_CHARS / NAME_CHAR_LIMIT_DIVIDER;                                   // How many chars per line we can use for the names.
        const DESCRIPTION_CHARS = USEABLE_CHARS - NAME_CHARS;                                                // How many chars per line we can use for the description.
        const DESCRIPTION_START = options.linePrefix.length + NAME_CHARS + MIDDLE_AFFIX.length;              // How many chars in that the description starts.

        // Creating the options and padding for the names and description.
        HelpSectionOptions nameOptions;
        nameOptions.linePrefix    = options.linePrefix;
        nameOptions.lineCharLimit = NAME_CHARS + options.linePrefix.length;

        auto padding = new char[DESCRIPTION_START];
        padding[] = ' ';

        HelpSectionOptions descriptionOptions;
        descriptionOptions.linePrefix    = padding.assumeUnique;
        descriptionOptions.lineCharLimit = DESCRIPTION_CHARS + DESCRIPTION_START; // For the first line, the padding needs to be removed manually.

        char[] output;
        output.reserve(4096);

        // Hello inefficient code, my old friend...
        foreach(arg; this.args)
        {
            // Line wrap. (This line alone is like, O(3n), not even mentioning memory usage)
            auto nameText = lineWrap(
                nameOptions, 
                arg.names.map!(n => (this.addDashes) 
                                     ? (n.length == 1) ? "-"~n : "--"~n
                                     : n
                         )
                         .filter!(n => n.length > 0)
                         .reduce!((a, b) => a~","~b)
                         .byChar
                         .array
            );

            auto descriptionText = lineWrap(
                descriptionOptions,
                arg.description
            );

            if(descriptionText.length > descriptionOptions.linePrefix.length)
                descriptionText = descriptionText[descriptionOptions.linePrefix.length..$]; // Remove the padding from the first line.

            // Then create our output line-by-line
            auto nameLines = nameText.splitter('\n');
            auto descriptionLines = descriptionText.splitter('\n');

            bool isFirstLine = true;
            size_t nameLength = 0;
            while(!nameLines.empty || !descriptionLines.empty)
            {
                if(!nameLines.empty)
                {
                    nameLength = nameLines.front.length; // Need to keep track of this for the next two ifs.

                    output ~= nameLines.front;
                    nameLines.popFront();
                }
                else
                    nameLength = 0;

                if(isFirstLine)
                {
                    // Push the middle affix into the middle, where it should be.
                    const ptrdiff_t missingChars = (NAME_CHARS - nameLength) + nameOptions.linePrefix.length;
                    if(missingChars > 0)
                        output ~= descriptionOptions.linePrefix[0..missingChars];

                    output ~= MIDDLE_AFFIX;
                }

                if(!descriptionLines.empty)
                {
                    auto description = descriptionLines.front;
                    if(!isFirstLine)
                        description = description[nameLength..$]; // The name might be multi-line, so we need to adjust the padding.

                    output ~= description;
                    descriptionLines.popFront();
                }

                output ~= "\n";
                isFirstLine = false; // IMPORTANT for it to be here, please don't move it.
            }
        }

        // Void the last new line, as it provides consistency with HelpSectionTextContent
        if(output.length > 0 && output[$-1] == '\n')
            output = output[0..$-1];

        // debug
        // {
        //     char[] a;
        //     a.length = nameOptions.linePrefix.length;
        //     a[] = '1';
        //     output ~= a;

        //     a.length = NAME_CHARS;
        //     a[] = '2';
        //     output ~= a;

        //     a.length = MIDDLE_AFFIX.length;
        //     a[] = '3';
        //     output ~= a;

        //     a.length = DESCRIPTION_CHARS;
        //     a[] = '4';
        //     output ~= a;
        //     output ~= '\n';

        //     a.length = DESCRIPTION_START;
        //     a[] = '>';
        //     output ~= a;
        //     output ~= '\n';

        //     a.length = descriptionOptions.lineCharLimit;
        //     a[] = '*';
        //     output ~= a;
        //     output ~= '\n';

        //     a.length = options.lineCharLimit;
        //     a[] = '#';
        //     output ~= a;
        // }

        return output.assumeUnique;
    }
}
///
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    auto content = new HelpSectionArgInfoContent(
        [
            HelpSectionArgInfoContent.ArgInfo(["v", "verbose"],           "Display detailed information about what the program is doing."),
            HelpSectionArgInfoContent.ArgInfo(["f", "file"],              "The input file."),
            HelpSectionArgInfoContent.ArgInfo(["super","longer","names"], "Some unusuable command with long names and a long description.")
        ],

        AutoAddArgDashes.yes
    );
    auto options = HelpSectionOptions(
        "    ",
        80
    );

    assert(content.getContent(options) ==
        "    -v,--verbose       - Display detailed information about what the program is\n"
       ~"                         doing.\n"
       ~"    -f,--file          - The input file.\n"
       ~"    --super,--longer,  - Some unusuable command with long names and a long desc\n"
       ~"    --names              ription.",

        "\n"~content.getContent(options)
    );
}
*/
/// Contains the action functions for arguments.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.infogen.actions;

import std.format, std.traits, std.typecons : Nullable;
//[CONTAINS_BLACKLISTED_IMPORT]import jaster.cli.infogen, jaster.cli.binder, jaster.cli.result;

// ArgBinder knows how to safely discard UDAs it doesn't care about.
private alias getBinderUDAs(alias ArgT) = __traits(getAttributes, ArgT);

// Now you may think: "But Bradley, this is module-level, why does this need to be marked static?"
//
// Well now little Timmy, what you don't seem to notice is that D, for some reason, is embedding a "this" pointer (as a consequence of `ArgT` referencing a member field),
// however because this is still technically a `function` I can call it *without* providing a context pointer, which has led to some very
// interesting errors.

/// Sets the argument's value via `ArgBinder`.
static Result!void actionValueBind(alias CommandT, alias ArgT, alias ArgBinderInstance)(string value, ref CommandT commandInstance)
{
    import std.typecons : Nullable; // Don't ask me why, but I need to repeat the import here for the amalgamation to compile properly.
                                    // For some incredibly strange reason, if we don't do this, then `Nullable` evaluated to `void`.

    alias SymbolType = typeof(ArgT);

    static if(isInstanceOf!(Nullable, SymbolType))
    {
        // The Unqual removes the `inout` that `get` uses.
        alias ResultT = Unqual!(ReturnType!(SymbolType.get));
    }
    else
        alias ResultT = SymbolType;

    auto result = ArgBinderInstance.bind!(ResultT, getBinderUDAs!ArgT)(value);
    if(!result.isSuccess)
        return Result!void.failure(result.asFailure.error);

    mixin("commandInstance.%s = result.asSuccess.value;".format(__traits(identifier, ArgT)));
    return Result!void.success();
}

/// Increments the argument's value either by 1, or by the length of `value` if it is not null.
static Result!void actionCount(alias CommandT, alias ArgT, alias ArgBinderInstance)(string value, ref CommandT commandInstance)
{
    static assert(__traits(compiles, {typeof(ArgT) a; a++;}), "Type "~typeof(ArgT).stringof~" does not implement the '++' operator.");

    // If parser passes null then the user's input was: -v or -vsome_value
    // If parser passes value then the user's input was: -vv or -vvv(n+1)
    const amount = (value is null) ? 1 : value.length;

    // Simplify implementation for user-defined types by only using ++.
    foreach(i; 0..amount)
        mixin("commandInstance.%s++;".format(__traits(identifier, ArgT)));

    return Result!void.success();
}

/// Fails an assert if used.
static Result!void dummyAction(alias CommandT)(string value, ref CommandT commandInstance)
{
    assert(false, "This action doesn't do anything.");
}
/// The various datatypes provided by infogen.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.infogen.datatypes;

import std.typecons : Flag, Nullable;
//[CONTAINS_BLACKLISTED_IMPORT]import jaster.cli.parser, jaster.cli.infogen, jaster.cli.result;

/// Used with `Pattern.matchSpacefull`.
alias AllowPartialMatch = Flag!"partialMatch";

/++
 + Attach any value from this enum onto an argument to specify what parsing action should be performed on it.
 + ++/
enum CommandArgAction
{
    /// Perform the default parsing action.
    default_,

    /++
     + Increments an argument for every time it is defined inside the parameters.
     +
     + Arg Type: Named
     + Value Type: Any type that supports `++`.
     + Arg becomes optional: true
     + ++/
    count,
}

/++
 + Describes the existence of a command argument. i.e., how many times can it appear; is it optional, etc.
 + ++/
enum CommandArgExistence
{
    /// Can only appear once, and is mandatory.
    default_ = 0,

    /// Argument can be omitted.
    optional = 1 << 0,

    /// Argument can be redefined.
    multiple = 1 << 1,
}

/++
 + Describes the parsing scheme used when parsing the argument's value.
 + ++/
enum CommandArgParseScheme
{
    /// Default parsing scheme.
    default_,

    /// Parsing scheme that special cases bools.
    bool_,

    /// Allows: -v, -vvvv(n+1). Special case: -vsome_value ignores the "some_value" and leaves it for the next parse cycle.
    allowRepeatedName
}

/++
 + Describes a command and its parameters.
 +
 + Params:
 +  CommandT = The command that this information belongs to.
 +
 + See_Also:
 +  `jaster.cli.infogen.gen.getCommandInfoFor` for generating instances of this struct.
 + ++/
struct CommandInfo(CommandT)
{
    /// The command's `Pattern`, if it has one.
    Pattern pattern;

    /// The command's description.
    string description;

    /// Information about all of this command's named arguments.
    NamedArgumentInfo!CommandT[] namedArgs;

    /// Information about all of this command's positional arguments.
    PositionalArgumentInfo!CommandT[] positionalArgs;

    /// Information about this command's raw list argument, if it has one.
    Nullable!(RawListArgumentInfo!CommandT) rawListArg;
}

/// The function used to perform an argument's setter action.
alias ArgumentActionFunc(CommandT) = Result!void function(string value, ref CommandT commandInstance);

/++
 + Contains information about command's argument.
 +
 + Params:
 +  UDA = The UDA that defines the argument (e.g. `@CommandNamedArg`, `@CommandPositionalArg`)
 +  CommandT = The command type that this argument belongs to.
 +
 + See_Also:
 +  `jaster.cli.infogen.gen.getCommandInfoFor` for generating instances of this struct.
 + ++/
struct ArgumentInfo(UDA, CommandT)
{
    // NOTE: Do not use Nullable in this struct as it causes compile-time errors.
    //       It hits a code path that uses memcpy, which of course doesn't work in CTFE.

    /// The result of `__traits(identifier)` on the argument's symbol.
    string identifier;

    /// The UDA attached to the argument's symbol.
    UDA uda;

    /// The binding action performed to create the argument's value.
    CommandArgAction action;

    /// The user-defined `CommandArgGroup`, this is `.init` for the default group.
    CommandArgGroup group;

    /// Describes the existence properties for this argument.
    CommandArgExistence existence;

    /// Describes how this argument is to be parsed.
    CommandArgParseScheme parseScheme;

    // I wish I could defer this to another part of the library instead of here.
    // However, any attempt I've made to keep around aliases to parameters has resulted
    // in a dreaded "Cannot infer type from template arguments CommandInfo!CommandType".
    // 
    // My best guesses are: 
    //  1. More weird behaviour with the hidden context pointer D inserts.
    //  2. I might've hit some kind of internal template limit that the compiler is just giving a bad message for.

    /// The function used to perform the binding action for this argument.
    ArgumentActionFunc!CommandT actionFunc;
}

alias NamedArgumentInfo(CommandT) = ArgumentInfo!(CommandNamedArg, CommandT);
alias PositionalArgumentInfo(CommandT) = ArgumentInfo!(CommandPositionalArg, CommandT);
alias RawListArgumentInfo(CommandT) = ArgumentInfo!(CommandRawListArg, CommandT);

/++
 + A pattern is a simple string format for describing multiple "patterns" that can be matched to user provided input.
 +
 + Description:
 +  A simple pattern of "hello" would match, and only match "hello".
 +
 +  A pattern of "hello|world" would match either "hello" or "world".
 +
 +  Some patterns may contain spaces, other may not, it should be documented if possible.
 + ++/
struct Pattern
{
    import std.algorithm : all;
    import std.ascii : isWhite;

    /// The raw pattern string.
    string pattern;

    //invariant(pattern.length > 0, "Attempting to use null pattern.");

    /// Asserts that there is no whitespace within the pattern.
    void assertNoWhitespace() const
    {
        assert(this.pattern.all!(c => !c.isWhite), "The pattern '"~this.pattern~"' is not allowed to contain whitespace.");
    }

    /// Returns: An input range consisting of every subpattern within this pattern.
    auto byEach()
    {
        import std.algorithm : splitter;
        return this.pattern.splitter('|');
    }

    /++
     + The default subpattern can be used as the default 'user-facing' name to display to the user.
     +
     + Returns:
     +  Either the first subpattern, or "DEFAULT" if this pattern is null.
     + ++/
    string defaultPattern()
    {
        return (this.pattern is null) ? "DEFAULT" : this.byEach.front;
    }

    /++
     + Matches the given input string without splitting up by spaces.
     +
     + Params:
     +  toTestAgainst = The string to test for.
     +
     + Returns:
     +  `true` if there was a match for the given string, `false` otherwise.
     + ++/
    bool matchSpaceless(string toTestAgainst)
    {
        import std.algorithm : any;
        return this.byEach.any!(str => str == toTestAgainst);
    }
    ///
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        assert(Pattern("v|verbose").matchSpaceless("v"));
        assert(Pattern("v|verbose").matchSpaceless("verbose"));
        assert(!Pattern("v|verbose").matchSpaceless("lalafell"));
    }
*/

    /++
     + Advances the given token parser in an attempt to match with any of this pattern's subpatterns.
     +
     + Description:
     +  On successful or partial match (if `allowPartial` is `yes`) the given `parser` will be advanced to the first
     +  token that is not part of the match.
     +
     +  e.g. For the pattern ("hey there"), if you matched it with the tokens ["hey", "there", "me"], the resulting parser
     +  would only have ["me"] left.
     +
     +  On a failed match, the given parser is left unmodified.
     +
     + Bugs:
     +  If a partial match is allowed, and a partial match is found before a valid full match is found, then only the
     +  partial match is returned.
     +
     + Params:
     +  parser = The parser to match against.
     +  allowPartial = If `yes` then allow partial matches, otherwise only allow full matches.
     +
     + Returns:
     +  `true` if there was a full or partial (if allowed) match, otherwise `false`.
     + ++/
    bool matchSpacefull(ref ArgPullParser parser, AllowPartialMatch allowPartial = AllowPartialMatch.no)
    {
        import std.algorithm : splitter;

        foreach(subpattern; this.byEach)
        {
            auto savedParser = parser.save();
            bool isAMatch = true;
            bool isAPartialMatch = false;
            foreach(split; subpattern.splitter(" "))
            {
                if(savedParser.empty
                || !(savedParser.front.type == ArgTokenType.Text && savedParser.front.value == split))
                {
                    isAMatch = false;
                    break;
                }

                isAPartialMatch = true;
                savedParser.popFront();
            }

            if(isAMatch || (isAPartialMatch && allowPartial))
            {
                parser = savedParser;
                return true;
            }
        }

        return false;
    }
    ///
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        // Test empty parsers.
        auto parser = ArgPullParser([]);
        assert(!Pattern("v").matchSpacefull(parser));

        // Test that the parser's position is moved forward correctly.
        parser = ArgPullParser(["v", "verbose"]);
        assert(Pattern("v").matchSpacefull(parser));
        assert(Pattern("verbose").matchSpacefull(parser));
        assert(parser.empty);

        // Test that a parser that fails to match isn't moved forward at all.
        parser = ArgPullParser(["v", "verbose"]);
        assert(!Pattern("lel").matchSpacefull(parser));
        assert(parser.front.value == "v");

        // Test that a pattern with spaces works.
        parser = ArgPullParser(["give", "me", "chocolate"]);
        assert(Pattern("give me").matchSpacefull(parser));
        assert(parser.front.value == "chocolate");

        // Test that multiple patterns work.
        parser = ArgPullParser(["v", "verbose"]);
        assert(Pattern("lel|v|verbose").matchSpacefull(parser));
        assert(Pattern("lel|v|verbose").matchSpacefull(parser));
        assert(parser.empty);
    }
*/
}
/// Templates for generating information about commands.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.infogen.gen;

import std.traits, std.meta, std.typecons;
//[CONTAINS_BLACKLISTED_IMPORT]import jaster.cli.infogen, jaster.cli.udas, jaster.cli.binder;

/++
 + Generates a `CommandInfo!CommandT` populated with all the information about the command and its arguments.
 +
 + Description:
 +  This template can be useful to gather information about a command and its argument, without having any extra baggage attached.
 +
 +  This allows you to introspect information about the command in the same way as JCLI does.
 +
 + Params:
 +  CommandT = The Command to generate the information for.
 +  ArgBinderInstance = The `ArgBinder` to use when generating argument setter functions.
 + ++/
template getCommandInfoFor(alias CommandT, alias ArgBinderInstance)
{
    static assert(isSomeCommand!CommandT, "Type "~CommandT.stringof~" is not marked with @Command or @CommandDefault.");

    static if(hasUDA!(CommandT, Command))
    {
        enum CommandPattern = getSingleUDA!(CommandT, Command).pattern;
        enum CommandDescription = getSingleUDA!(CommandT, Command).description;

        static assert(CommandPattern.pattern !is null, "Null pattern names are deprecated, use `@CommandDefault` instead.");
    }
    else
    {
        enum CommandPattern = Pattern.init;
        enum CommandDescription = getSingleUDA!(CommandT, CommandDefault).description;
    }

    enum ArgInfoTuple = toArgInfoArray!(CommandT, ArgBinderInstance);

    enum getCommandInfoFor = CommandInfo!CommandT(
        CommandPattern,
        CommandDescription,
        ArgInfoTuple[0],
        ArgInfoTuple[1],
        ArgInfoTuple[2]
    );

    enum _dummy = assertGroupDescriptionConsistency!CommandT(getCommandInfoFor);
}
///
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.typecons : Nullable;

    @Command("test", "doe")
    static struct C
    {
        @CommandNamedArg("abc", "123") string arg;
        @CommandPositionalArg(20, "ray", "me") @CommandArgGroup("nam") Nullable!bool pos;
        @CommandNamedArg @(CommandArgAction.count) int b;
    }

    enum info = getCommandInfoFor!(C, ArgBinder!());
    static assert(info.pattern.matchSpaceless("test"));
    static assert(info.description == "doe");
    static assert(info.namedArgs.length == 2);
    static assert(info.positionalArgs.length == 1);

    static assert(info.namedArgs[0].identifier == "arg");
    static assert(info.namedArgs[0].uda.pattern.matchSpaceless("abc"));
    static assert(info.namedArgs[0].action == CommandArgAction.default_);
    static assert(info.namedArgs[0].group == CommandArgGroup.init);
    static assert(info.namedArgs[0].existence == CommandArgExistence.default_);
    static assert(info.namedArgs[0].parseScheme == CommandArgParseScheme.default_);

    static assert(info.positionalArgs[0].identifier == "pos");
    static assert(info.positionalArgs[0].uda.position == 20);
    static assert(info.positionalArgs[0].action == CommandArgAction.default_);
    static assert(info.positionalArgs[0].group.name == "nam");
    static assert(info.positionalArgs[0].existence == CommandArgExistence.optional);
    static assert(info.positionalArgs[0].parseScheme == CommandArgParseScheme.bool_);

    static assert(info.namedArgs[1].action == CommandArgAction.count);
}
*/

private auto toArgInfoArray(alias CommandT, alias ArgBinderInstance)()
{
    import std.typecons : tuple;

    alias NamedArgs = getNamedArguments!CommandT;
    alias PositionalArgs = getPositionalArguments!CommandT;

    auto namedArgs = new NamedArgumentInfo!CommandT[NamedArgs.length];
    auto positionalArgs = new PositionalArgumentInfo!CommandT[PositionalArgs.length];
    typeof(CommandInfo!CommandT.rawListArg) rawListArg;

    static foreach(i, ArgT; NamedArgs)
        namedArgs[i] = getArgInfoFor!(CommandT, ArgT, ArgBinderInstance);
    static foreach(i, ArgT; PositionalArgs)
        positionalArgs[i] = getArgInfoFor!(CommandT, ArgT, ArgBinderInstance);

    alias RawListArgSymbols = getSymbolsByUDA!(CommandT, CommandRawListArg);
    static if(RawListArgSymbols.length > 0)
    {
        static assert(RawListArgSymbols.length == 1, "Only one argument can be marked with @CommandRawListArg");
        static assert(!isSomeArgument!(RawListArgSymbols[0]), "@CommandRawListArg is mutually exclusive to the other command UDAs.");
        rawListArg = getArgInfoFor!(CommandT, RawListArgSymbols[0], ArgBinderInstance);
    }

    return tuple(namedArgs, positionalArgs, rawListArg);
}

private template getArgInfoFor(alias CommandT, alias ArgT, alias ArgBinderInstance)
{
    // Determine argument info type.
    static if(isNamedArgument!ArgT)
        alias ArgInfoT = NamedArgumentInfo!CommandT;
    else static if(isPositionalArgument!ArgT)
        alias ArgInfoT = PositionalArgumentInfo!CommandT;
    else static if(isRawListArgument!ArgT)
        alias ArgInfoT = RawListArgumentInfo!CommandT;
    else
        static assert(false, "Type "~ArgT~" cannot be recognised as an argument.");

    // Find what action to use.
    enum isActionUDA(alias UDA) = is(typeof(UDA) == CommandArgAction);
    enum ActionUDAs = Filter!(isActionUDA, __traits(getAttributes, ArgT));
    static if(ActionUDAs.length == 0)
        enum Action = CommandArgAction.default_;
    else static if(ActionUDAs.length == 1)
        enum Action = ActionUDAs[0];
    else
        static assert(false, "Multiple `CommandArgAction` UDAs detected for argument "~ArgT.stringof);
    alias ActionFunc = actionFuncFromAction!(Action, CommandT, ArgT, ArgBinderInstance);
    
    // Get the arg group if one is assigned.
    static if(hasUDA!(ArgT, CommandArgGroup))
        enum Group = getSingleUDA!(ArgT, CommandArgGroup);
    else
        enum Group = CommandArgGroup.init;

    // Determine existence and parse scheme traits.
    enum Existence = determineExistence!(CommandT, typeof(ArgT), Action);
    enum Scheme = determineParseScheme!(CommandT, ArgT, Action);

    enum getArgInfoFor = ArgInfoT(
        __traits(identifier, ArgT),
        getSingleUDA!(ArgT, typeof(ArgInfoT.uda)),
        Action,
        Group,
        Existence,
        Scheme,
        &ActionFunc
    );
}

private template actionFuncFromAction(CommandArgAction Action, alias CommandT, alias ArgT, alias ArgBinderInstance)
{
    import std.conv;

    static if(isRawListArgument!ArgT)
        alias actionFuncFromAction = dummyAction!CommandT;
    else static if(Action == CommandArgAction.default_)
        alias actionFuncFromAction = actionValueBind!(CommandT, ArgT, ArgBinderInstance);
    else static if(Action == CommandArgAction.count)
        alias actionFuncFromAction = actionCount!(CommandT, ArgT, ArgBinderInstance);
    else
    {
        pragma(msg, Action.to!string);
        pragma(msg, CommandT);
        pragma(msg, __traits(identifier, ArgT));
        pragma(msg, ArgBinderInstance);
        static assert(false, "No suitable action found.");
    }
}

private CommandArgExistence determineExistence(alias CommandT, alias ArgTType, CommandArgAction Action)()
{
    import std.typecons : Nullable;

    CommandArgExistence value;

    static if(isInstanceOf!(Nullable, ArgTType))
        value |= CommandArgExistence.optional;
    static if(Action == CommandArgAction.count)
    {
        value |= CommandArgExistence.multiple;
        value |= CommandArgExistence.optional;
    }

    return value;
}

private template determineParseScheme(alias CommandT, alias ArgT, CommandArgAction Action)
{
    import std.typecons : Nullable;

    static if(is(typeof(ArgT) == bool) || is(typeof(ArgT) == Nullable!bool))
        enum determineParseScheme = CommandArgParseScheme.bool_;
    else static if(Action == CommandArgAction.count)
        enum determineParseScheme = CommandArgParseScheme.allowRepeatedName;
    else
        enum determineParseScheme = CommandArgParseScheme.default_;
}

private bool assertGroupDescriptionConsistency(alias CommandT)(CommandInfo!CommandT info)
{
    import std.algorithm : map, filter, all, uniq, joiner;
    import std.range     : chain;
    import std.conv      : to;

    auto groups = info.namedArgs
                      .map!(a => a.group).chain(
                          info.positionalArgs
                              .map!(a => a.group)
                      );
    auto uniqueGroupNames = groups.map!(g => g.name).uniq;

    foreach(name; uniqueGroupNames)
    {
        auto descriptionsForGroupName = groups.filter!(g => g.name == name).map!(g => g.description);
        auto firstNonNullDescription = descriptionsForGroupName.filter!(d => d !is null);
        if(firstNonNullDescription.empty)
            continue;

        const canonDescription = firstNonNullDescription.front;
        assert(
            descriptionsForGroupName.all!(d => d is null || d == canonDescription),
            "Group '"~name~"' has multiple conflicting descriptions. Canon description is '"~canonDescription~"' but the following conflicts were found: "
           ~"["
           ~descriptionsForGroupName.filter!(d => d !is null && d != canonDescription).map!(d => `"`~d~`"`).joiner(" <-> ").to!string
           ~"]"
        );
    }

    return true; // Dummy value, just so I can do enum assignment
}
/// Contains all the utilities for gathering information about a command and its arguments.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.infogen;

//[CONTAINS_BLACKLISTED_IMPORT]public import jaster.cli.infogen.datatypes, jaster.cli.infogen.udas, jaster.cli.infogen.gen, jaster.cli.infogen.actions;
/// Contains the UDAs used and recognised by infogen, and any systems built on top of it.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.infogen.udas;

import std.meta : staticMap, Filter;
import std.traits;
//[CONTAINS_BLACKLISTED_IMPORT]import jaster.cli.infogen, jaster.cli.udas;

/++
 + Attach this to any struct/class that represents the default command.
 +
 + See_Also:
 +  `jaster.cli
 + ++/
struct CommandDefault
{
    /// The command's description.
    string description = "N/A";
}

/++
 + Attach this to any struct/class that represents a command.
 +
 + See_Also:
 +  `jaster.cli.core.CommandLineInterface` for more details.
 + +/
struct Command
{
    /// The pattern used to match against this command. Can contain spaces.
    Pattern pattern;

    /// The command's description.
    string description;

    ///
    this(string pattern, string description = "N/A")
    {
        this.pattern = Pattern(pattern);
        this.description = description;
    }
}

/++
 + Attach this to any member field to mark it as a named argument.
 +
 + See_Also:
 +  `jaster.cli.core.CommandLineInterface` for more details.
 + +/
struct CommandNamedArg
{
    /// The pattern used to match against this argument. Cannot contain spaces.
    Pattern pattern;

    /// The argument's description.
    string description;

    ///
    this(string pattern, string description = "N/A")
    {
        this.pattern = Pattern(pattern);
        this.description = description;
    }
}

/++
 + Attach this to any member field to mark it as a positional argument.
 +
 + See_Also:
 +  `jaster.cli.core.CommandLineInterface` for more details.
 + +/
struct CommandPositionalArg
{
    /// The position that this argument appears at.
    size_t position;

    /// The name of this argument. Used during help-text generation.
    string name = "VALUE";

    /// The description of this argument.
    string description = "N/A";
}

/++
 + Attach this to any member field to add it to a help text group.
 +
 + See_Also:
 +  `jaster.cli.core.CommandLineInterface` for more details.
 + +/
struct CommandArgGroup
{
    /// The name of the group to put the arg under.
    string name;

    /++
     + The description of the group.
     +
     + Notes:
     +  The intended usage of this UDA is to apply it to a group of args at the same time, instead of attaching it onto
     +  singular args:
     +
     +  ```
     +  @CommandArgGroup("group1", "Some description")
     +  {
     +      @CommandPositionalArg...
     +  }
     +  ```
     + ++/
    string description;
}

/++
 + Attach this onto a `string[]` member field to mark it as the "raw arg list".
 +
 + TLDR; Given the command `"tool.exe command value1 value2 --- value3 value4 value5"`, the member field this UDA is attached to
 + will be populated as `["value3", "value4", "value5"]`
 + ++/
struct CommandRawListArg {}

// Legacy, keep undocumented.
alias CommandRawArg = CommandRawListArg;

enum isSomeCommand(alias CommandT) = hasUDA!(CommandT, Command) || hasUDA!(CommandT, CommandDefault);

enum isSymbol(alias ArgT) = __traits(compiles, __traits(getAttributes, ArgT));

enum isRawListArgument(alias ArgT)    = isSymbol!ArgT && hasUDA!(ArgT, CommandRawListArg); // Don't include in isSomeArgument
enum isNamedArgument(alias ArgT)      = isSymbol!ArgT && hasUDA!(ArgT, CommandNamedArg);
enum isPositionalArgument(alias ArgT) = isSymbol!ArgT && hasUDA!(ArgT, CommandPositionalArg);
enum isSomeArgument(alias ArgT)       = isNamedArgument!ArgT || isPositionalArgument!ArgT;

package template getCommandArguments(alias CommandT)
{
    static assert(is(CommandT == struct) || is(CommandT == class), "Only classes or structs can be used as commands.");
    static assert(isSomeCommand!CommandT, "Type "~CommandT.stringof~" is not marked with @Command or @CommandDefault.");

    alias toSymbol(string name) = __traits(getMember, CommandT, name);
    alias Members = staticMap!(toSymbol, __traits(allMembers, CommandT));
    alias getCommandArguments = Filter!(isSomeArgument, Members);
}
///
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    @CommandDefault
    static struct C 
    {
        @CommandNamedArg int a;
        @CommandPositionalArg int b;
        int c;
    }

    static assert(getCommandArguments!C.length == 2);
    static assert(getNamedArguments!C.length == 1);
    static assert(getPositionalArguments!C.length == 1);
}
*/

package alias getNamedArguments(alias CommandT) = Filter!(isNamedArgument, getCommandArguments!CommandT);
package alias getPositionalArguments(alias CommandT) = Filter!(isPositionalArgument, getCommandArguments!CommandT);
/// Internal utilities.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.internal;

/// pragma(msg) only used in debug mode, if version JCLI_Verbose is specified.
void debugPragma(string Message)()
{
    version(JCLI_Verbose)
        debug pragma(msg, "[JCLI]<DEBUG> "~Message);
}
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli;

/*[CONTAINS_BLACKLISTED_IMPORT]

              jaster.cli.udas, jaster.cli.shell, jaster.cli.ansi, jaster.cli.userio,
              jaster.cli.config, jaster.cli.adapters.config.asdf, jaster.cli.text,
              jaster.cli.resolver, jaster.cli.result, jaster.cli.commandparser, jaster.cli.infogen,
              jaster.cli.commandhelptext;
*/
/// Contains a pull parser for command line arguments.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.parser;

private
{
    import std.typecons : Flag;
}

/// What type of data an `ArgToken` stores.
enum ArgTokenType
{
    /// None. If this ever gets returned by the `ArgPullParser`, it's an error.
    None,
    
    /// Plain text. Note that these values usually do have some kind of meaning (e.g. the value of a named argument) but it's
    /// too inaccurate for the parser to determine their meanings. So it's up to whatever is using the parser.
    Text,

    /// The name of a short hand argument ('-h', '-c', etc.) $(B without) the leading '-'.
    ShortHandArgument,

    /// The name of a long hand argument ('--help', '--config', etc.) $(B without) the leading '--'.
    LongHandArgument,
    
    /// End of file/input.
    EOF
}

/// Contains information about a token.
struct ArgToken
{
    /// The value making up the token.
    string value;

    /// The type of data this token represents.
    ArgTokenType type;
}

/++
 + A pull parser for command line arguments.
 +
 + Notes:
 +  The input is given as a `string[]`. This mostly only matters for `ArgTokenType.Text` values.
 +  This is because the parser does not split up plain text by spaces like a shell would.
 +
 +  e.g. There will be different results between `ArgPullParser(["env set OAUTH_SECRET 29ef"])` and
 +  `ArgPullParser(["env", "set", "OAUTH_SECRET", "29ef"])`
 +
 +  The former is given back as a single token containing the entire string. The latter will return 4 tokens, containing the individual strings.
 +
 +  This behaviour is used because this parser is designed to take its input directly from the main function's args, which have already been
 +  processed by a shell.
 +
 + Argument Formats:
 +  The following named argument formats are supported.
 +
 +  '-n'         - Shorthand with no argument. (returns `ArgTokenTypes.ShortHandArgument`)
 +  '-n ARG'     - Shorthand with argument. (`ArgTokenTypes.ShortHandArgument` and `ArgTokenTypes.Text`)
 +  '-n=ARG'     - Shorthand with argument with an equals sign. The equals sign is removed from the token output. (`ArgTokenTypes.ShortHandArgument` and `ArgTokenTypes.Text`)
 +  '-nARG       - Shorthand with argument with no space between them. (`ArgTokenTypes.ShortHandArgument` and `ArgTokenTypes.Text`)
 +
 +  '--name'     - Longhand with no argument.
 +  '--name ARG' - Longhand with argument.
 +  '--name=ARG' - Longhand with argument with an equals sign. The equals sign is removed from the token output.
 + ++/
@safe
struct ArgPullParser
{
    /// Variables ///
    private
    {
        alias OrEqualSign = Flag!"equalSign";
        alias OrSpace = Flag!"space";

        string[] _args;
        size_t   _currentArgIndex;  // Current index into _args.
        size_t   _currentCharIndex; // Current index into the current arg.
        ArgToken _currentToken = ArgToken(null, ArgTokenType.EOF);
    }
    
    /++
     + Params:
     +  args = The arguments to parse. Please see the 'notes' section for `ArgPullParser`.
     + ++/
    this(string[] args)
    {
        this._args = args;
        this.popFront();
    }

    /// Range interface ///
    public
    {
        /// Parses the next token.
        void popFront()
        {
            this.nextToken();
        }

        /// Returns: the last parsed token.
        ArgToken front()
        {
            return this._currentToken;
        }

        /// Returns: Whether there's no more characters to parse.
        bool empty()
        {
            return this._currentToken.type == ArgTokenType.EOF;
        }
        
        /// Returns: A copy of the pull parser in it's current state.
        ArgPullParser save()
        {
            ArgPullParser parser;
            parser._args             = this._args;
            parser._currentArgIndex  = this._currentArgIndex;
            parser._currentCharIndex = this._currentCharIndex;
            parser._currentToken     = this._currentToken;

            return parser;
        }

        /// Returns: The args that have yet to be parsed.
        @property
        string[] unparsedArgs()
        {
            return (this._currentArgIndex + 1 < this._args.length)
                   ? this._args[this._currentArgIndex + 1..$]
                   : null;
        }
    }

    /// Parsing ///
    private
    {
        @property
        string currentArg()
        {
            return this._args[this._currentArgIndex];
        }

        @property
        string currentArgSlice()
        {
            return this.currentArg[this._currentCharIndex..$];
        }

        void skipWhitespace()
        {
            import std.ascii : isWhite;

            if(this._currentArgIndex >= this._args.length)
                return;

            // Current arg could be empty, so get next arg.
            // *Next* arg could also be empty, so repeat until we either run out of args, or we find a non-empty one.
            while(this.currentArgSlice.length == 0)
            {
                this.nextArg();

                if(this._currentArgIndex >= this._args.length)
                    return;
            }

            auto arg = this.currentArg;
            while(arg[this._currentCharIndex].isWhite)
            {
                this._currentCharIndex++;
                if(this._currentCharIndex >= arg.length)
                {
                    // Next arg might start with whitespace, so we have to keep going.
                    // We recursively call this function so we don't have to copy the empty-check logic at the start of this function.
                    this.nextArg();
                    return this.skipWhitespace();
                }
            }
        }

        string readToEnd(OrSpace orSpace = OrSpace.no, OrEqualSign orEqualSign = OrEqualSign.no)
        {
            import std.ascii : isWhite;

            this.skipWhitespace();
            if(this._currentArgIndex >= this._args.length)
                return null;

            // Small optimisation: If we're at the very start, and we only need to read until the end, then just
            // return the entire arg.
            if(this._currentCharIndex == 0 && !orSpace && !orEqualSign)
            {
                auto arg = this.currentArg;

                // Force skipWhitespace to call nextArg on its next call.
                // We can't call nextArg here, as it breaks assumptions that unparsedArgs relies on.
                this._currentCharIndex = this.currentArg.length;
                return arg;
            }
            
            auto slice = this.currentArgSlice;
            size_t end = 0;
            while(end < slice.length)
            {
                if((slice[end].isWhite && orSpace)
                || (slice[end] == '=' && orEqualSign)
                )
                {
                    break;
                }

                end++;
                this._currentCharIndex++;
            }

            // Skip over whatever char we ended up on.
            // This is mostly to skip over the '=' sign if we're using that, but also saves 'skipWhitespace' a bit of hassle.
            if(end < slice.length)
                this._currentCharIndex++;

            return slice[0..end];
        }

        void nextArg()
        {
            this._currentArgIndex++;
            this._currentCharIndex = 0;
        }

        void nextToken()
        {
            import std.exception : enforce;

            this.skipWhitespace();
            if(this._currentArgIndex >= this._args.length)
            {
                this._currentToken = ArgToken("", ArgTokenType.EOF);
                return;
            }

            auto slice = this.currentArgSlice;
            if(slice.length >= 2 && slice[0..2] == "--")
            {
                this._currentCharIndex += 2;

                // Edge case: Since readToEnd can advance the "currentArgSlice", we get into this common situation
                //            of ["--", "b"] where this should be an unnamed long hand arg followed by the text "b", but
                //            instead it gets treated as "--b", which we don't want. So we're just checking for this here.
                if(this._currentCharIndex >= this.currentArg.length || this.currentArg[this._currentCharIndex] == ' ')
                    this._currentToken = ArgToken("", ArgTokenType.LongHandArgument);
                else
                    this._currentToken = ArgToken(this.readToEnd(OrSpace.yes, OrEqualSign.yes), ArgTokenType.LongHandArgument);
                return;
            }
            else if(slice.length >= 1 && slice[0] == '-')
            {
                this._currentCharIndex += (slice.length == 1) ? 1 : 2; // += 2 so we skip over the arg name.
                this._currentToken = ArgToken((slice.length == 1) ? "" : slice[1..2], ArgTokenType.ShortHandArgument);

                // Skip over the equals sign if there is one.
                if(this._currentCharIndex < this.currentArg.length
                && this.currentArg[this._currentCharIndex] == '=')
                    this._currentCharIndex++;

                // If it's unnamed, then sometimes the "name" can be a space, so we'll just handle that here
                if(this._currentToken.value == " ")
                    this._currentToken.value = null;

                return;
            }
            else if(slice.length != 0)
            {
                this._currentToken = ArgToken(this.readToEnd(), ArgTokenType.Text);
                return;
            }
            
            assert(false, "EOF should've been returned. SkipWhitespace might not be working.");
        }
    }
}
///
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.array : array;

    auto args = 
    [
        // Some plain text.
        "env", "set", 
        
        // Long hand named arguments.
        "--config=MyConfig.json", "--config MyConfig.json",

        // Short hand named arguments.
        "-cMyConfig.json", "-c=MyConfig.json", "-c MyConfig.json",

        // Simple example to prove that you don't need the arg name and value in the same string.
        "-c", "MyConfig.json",

        // Plain text.
        "Some Positional Argument",

        // Raw Nameless named args
        "- a", "-", "a",
        "-- a", "--", "a"
    ];
    auto tokens = ArgPullParser(args).array;

    // import std.stdio;
    // writeln(tokens);

    // Plain text.
    assert(tokens[0]  == ArgToken("env",                         ArgTokenType.Text));
    assert(tokens[1]  == ArgToken("set",                         ArgTokenType.Text));

    // Long hand named arguments.
    assert(tokens[2]  == ArgToken("config",                      ArgTokenType.LongHandArgument));
    assert(tokens[3]  == ArgToken("MyConfig.json",               ArgTokenType.Text));
    assert(tokens[4]  == ArgToken("config",                      ArgTokenType.LongHandArgument));
    assert(tokens[5]  == ArgToken("MyConfig.json",               ArgTokenType.Text));

    // Short hand named arguments.
    assert(tokens[6]  == ArgToken("c",                           ArgTokenType.ShortHandArgument));
    assert(tokens[7]  == ArgToken("MyConfig.json",               ArgTokenType.Text));
    assert(tokens[8]  == ArgToken("c",                           ArgTokenType.ShortHandArgument));
    assert(tokens[9]  == ArgToken("MyConfig.json",               ArgTokenType.Text));
    assert(tokens[10] == ArgToken("c",                           ArgTokenType.ShortHandArgument));
    assert(tokens[11] == ArgToken("MyConfig.json",               ArgTokenType.Text));
    assert(tokens[12] == ArgToken("c",                           ArgTokenType.ShortHandArgument));
    assert(tokens[13] == ArgToken("MyConfig.json",               ArgTokenType.Text));

    // Plain text.
    assert(tokens[14] == ArgToken("Some Positional Argument",    ArgTokenType.Text));

    // Raw Nameless named args.
    assert(tokens[15] == ArgToken("", ArgTokenType.ShortHandArgument));
    assert(tokens[16] == ArgToken("a", ArgTokenType.Text));
    assert(tokens[17] == ArgToken("", ArgTokenType.ShortHandArgument));
    assert(tokens[18] == ArgToken("a", ArgTokenType.Text));
    assert(tokens[19] == ArgToken("", ArgTokenType.LongHandArgument));
    assert(tokens[20] == ArgToken("a", ArgTokenType.Text));
    assert(tokens[21] == ArgToken("", ArgTokenType.LongHandArgument));
    assert(tokens[22] == ArgToken("a", ArgTokenType.Text));
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Issue: .init.empty must be true")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    assert(ArgPullParser.init.empty);
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test unparsedArgs")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    auto args = 
    [
        "one", "-t", "--three", "--unfortunate=edgeCase" // Despite this containing two tokens, they currently both get skipped over, even only one was parsed so far ;/
    ];
    auto parser = ArgPullParser(args);

    assert(parser.unparsedArgs == args[1..$]);
    foreach(i; 0..3)
    {
        parser.popFront();
        assert(parser.unparsedArgs == args[2 + i..$]);
    }

    assert(parser.unparsedArgs is null);
}
*/
/// Functionality for defining and resolving command "sentences".
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.resolver;

import std.range;
//[CONTAINS_BLACKLISTED_IMPORT]import jaster.cli.parser;

/// The type of a `CommandNode`.
enum CommandNodeType
{
    /// Failsafe
    ERROR,

    /// Used for the root `CommandNode`.
    root,

    /// Used for `CommandNodes` that don't contain a command, but instead contain child `CommandNodes`.
    ///
    /// e.g. For "build all libraries", "build" and "all" would be `partialWords`.
    partialWord,

    /// Used for `CommandNodes` that contain a command.
    ///
    /// e.g. For "build all libraries", "libraries" would be a `finalWord`.
    finalWord
}

/++
 + The result of a command resolution attempt.
 +
 + Params:
 +  UserDataT = See `CommandResolver`'s documentation.
 + ++/
struct CommandResolveResult(UserDataT)
{
    /// Whether the resolution was successful (true) or not (false).
    bool success;

    /// The resolved `CommandNode`. This value is undefined when `success` is `false`.
    CommandNode!UserDataT value;
}

/++
 + Contains a single "word" within a command "sentence", see `CommandResolver`'s documentation for more.
 +
 + Params:
 +  UserDataT = See `CommandResolver`'s documentation.
 + ++/
@safe
struct CommandNode(UserDataT)
{
    /// The word this node contains.
    string word;

    /// What type of node this is.
    CommandNodeType type;

    /// The children of this node.
    CommandNode!UserDataT[] children;

    /// User-provided data for this node. Note that partial words don't contain any user data.
    UserDataT userData;

    /// A string of the entire sentence up to (and including) this word, please note that $(B currently only final words) have this field set.
    string sentence;

    /// See_Also: `CommandResolver.resolve`
    CommandResolveResult!UserDataT byCommandSentence(RangeOfStrings)(RangeOfStrings range)
    {        
        auto current = this;
        for(; !range.empty; range.popFront())
        {
            auto commandWord = range.front;
            auto currentBeforeChange = current;

            foreach(child; current.children)
            {
                if(child.word == commandWord)
                {
                    current = child;
                    break;
                }
            }

            // Above loop failed.
            if(currentBeforeChange.word == current.word)
            {
                current = this; // Makes result.success become false.
                break;
            }
        }

        typeof(return) result;
        result.value   = current;
        result.success = range.empty && current.word != this.word;
        return result;
    }
    
    /++
     + Retrieves all child `CommandNodes` that are of type `CommandNodeType.finalWord`.
     +
     + Notes:
     +  While similar to `CommandResolver.finalWords`, this function has one major difference.
     +
     +  It is less efficient, since `CommandResolver.finalWords` builds and caches its value whenever a sentence is defined, while
     +  this function (currently) has to recreate its value each time.
     +
     +  Furthermore, as with `CommandResolver.finalWords`, the returned array of nodes are simply copies of the actual nodes used
     +  and returned by `CommandResolver.resolve`. So don't expect any changes to be reflected anywhere. 
     +
     +  Technically the same could be done here, but I'm lazy, so for now you get extra GC garbage.
     +
     + Returns:
     +  All child final words.
     + ++/
    CommandNode!UserDataT[] finalWords()
    {
        if(this.type != CommandNodeType.partialWord && this.type != CommandNodeType.root)
            return null;

        typeof(return) nodes;

        void addFinalNodes(CommandNode!UserDataT repetitionNode)
        {
            foreach(childNode; repetitionNode.children)
            {
                if(childNode.type == CommandNodeType.finalWord)
                    nodes ~= childNode;
                else if(childNode.type == CommandNodeType.partialWord)
                    addFinalNodes(childNode);
                else
                    assert(false, "Malformed tree.");
            }
        }

        addFinalNodes(this);
        return nodes;
    }
}

/++
 + A helper class where you can define command "sentences", and then resolve (either partially or fully) commands
 + from "sentences" provided by the user.
 +
 + Params:
 +  UserDataT = User-provided data for each command (`CommandNodes` of type `CommandNodeType.finalWord`).
 +
 + Description:
 +  In essence, this class is just an abstraction around a basic tree structure (`CommandNode`), to make it easy to
 +  both define and search the tree.
 +
 +  First of all, JCLI supports commands having multiple "words" within them, such as "build all libs"; "remote get-url", etc.
 +  This entire collection of "words" is referred to as a "sentence".
 +
 +  The tree for the resolver consists of words pointing to any following words (`CommandNodeType.partialWord`), ultimately ending each
 +  branch with the final command word (`CommandNodeType.finalWord`).
 +
 +  For example, if we had the following commands "build libs"; "build apps", and "test libs", the tree would look like the following.
 +
 +  Legend = `[word] - partial word` and `<word> - final word`.
 +
 +```
 +         root
 +         /  \
 +    [test]  [build]
 +      |       |    \  
 +    <libs>  <libs>  <apps>
 +```
 +
 +  Because this class only handles resolving commands, and nothing more than that, the application can attach whatever data it wants (`UserDataT`)
 +  so it can later perform its own processing (description; arg info; execution delegates, etc.)
 +
 +  I'd like to point out however, $(B only final words) are given user data as partial words aren't supposed to represent commands.
 +
 +  Finally, given the above point, if you tried to define "build release" and "build" at the same time, you'd fail an assert as "build" cannot be
 +  a partial word and a final word at the same time. This does kind of suck in some cases, but there are workarounds e.g. defining "build", then passing "release"/"debug"
 +  as arguments.
 +
 + Usage:
 +  Build up your tree by using `CommandResolver.define`.
 +
 +  Resolve commands via `CommandResolver.resolve` or `CommandResolver.resolveAndAdvance`.
 + ++/
@safe
final class CommandResolver(UserDataT)
{
    /// The `CommandNode` instatiation for this resolver.
    alias NodeT = CommandNode!UserDataT;

    private
    {
        CommandNode!UserDataT _rootNode;
        string[]              _sentences;
        NodeT[]               _finalWords;
    }

    this()
    {
        this._rootNode.type = CommandNodeType.root;
    }

    /++
     + Defines a command sentence.
     +
     + Description:
     +  A "sentence" consists of multiple "words". A "word" is a string of characters, each seperated by any amount of spaces.
     +
     +  For instance, `"build all libs"` contains the words `["build", "all", "libs"]`.
     +
     +  The last word within a sentence is known as the final word (`CommandNodeType.finalWord`), which is what defines the
     +  actual command associated with this sentence. The final word is the only word that has the `userDataForFinalNode` associated with it.
     +
     +  The rest of the words are known as partial words (`CommandNodeType.partialWord`) as they are only a partial part of a full sentence.
     +  (I hate all of this as well, don't worry).
     +
     +  So for example, if you wanted to define the command "build all libs" with some custom user data containing, for example, a description and
     +  an execute function, you could do something such as.
     +
     +  `myResolver.define("build all libs", MyUserData("Builds all Libraries", &buildAllLibsCommand))`
     +
     +  You can then later use `CommandResolver.resolve` or `CommandResolver.resolveAndAdvance`, using a user-provided string, to try and resolve
     +  to the final command.
     +
     + Params:
     +  commandSentence      = The sentence to define.
     +  userDataForFinalNode = The `UserDataT` to attach to the `CommandNode` for the sentence's final word.
     + ++/
    void define(string commandSentence, UserDataT userDataForFinalNode)
    {
        import std.algorithm : splitter, filter, any, countUntil;
        import std.format    : format; // For errors.
        import std.range     : walkLength;
        import std.uni       : isWhite;

        auto words = commandSentence.splitter!(a => a == ' ').filter!(w => w.length > 0);
        assert(!words.any!(w => w.any!isWhite), "Words inside a command sentence cannot contain whitespace.");

        const wordCount   = words.walkLength;
        scope currentNode = &this._rootNode;
        size_t wordIndex  = 0;
        foreach(word; words)
        {
            const isLastWord = (wordIndex == wordCount - 1);
            wordIndex++;

            const existingNodeIndex = currentNode.children.countUntil!(c => c.word == word);

            NodeT node;
            node.word     = word;
            node.type     = (isLastWord) ? CommandNodeType.finalWord : CommandNodeType.partialWord;
            node.userData = (isLastWord) ? userDataForFinalNode : UserDataT.init;
            node.sentence = (isLastWord) ? commandSentence : null;

            if(isLastWord)
                this._finalWords ~= node;

            if(existingNodeIndex == -1)
            {
                currentNode.children ~= node;
                currentNode = &currentNode.children[$-1];
                continue;
            }
            
            currentNode = &currentNode.children[existingNodeIndex];
            assert(
                currentNode.type == CommandNodeType.partialWord, 
                "Cannot append word '%s' onto word '%s' as the latter word is not a partialWord, but instead a %s."
                .format(word, currentNode.word, currentNode.type)
            );
        }

        this._sentences ~= commandSentence;
    }
    
    /++
     + Attempts to resolve a range of words/a sentence into a `CommandNode`.
     +
     + Notes:
     +  The overload taking a `string` will split the string by spaces, the same way `CommandResolver.define` works.
     +
     + Description:
     +  There are three potential outcomes of this function.
     +
     +  1. The words provided fully match a command sentence. The value of `returnValue.value.type` will be `CommandNodeType.finalWord`.
     +  2. The words provided a partial match of a command sentence. The value of `returnValue.value.type` will be `CommandNodeType.partialWord`.
     +  3. Neither of the above. The value of `returnValue.success` will be `false`.
     +
     +  How you handle these outcomes, and which ones you handle, are entirely up to your application.
     +
     + Params:
     +  words = The words to resolve.
     +
     + Returns:
     +  A `CommandResolveResult`, specifying the result of the resolution.
     + ++/
    CommandResolveResult!UserDataT resolve(RangeOfStrings)(RangeOfStrings words)
    {
        return this._rootNode.byCommandSentence(words);
    }

    /// ditto.
    CommandResolveResult!UserDataT resolve(string sentence) pure
    {
        import std.algorithm : splitter, filter;
        return this.resolve(sentence.splitter(' ').filter!(w => w.length > 0));
    }

    /++
     + Peforms the same task as `CommandResolver.resolve`, except that it will also advance the given `parser` to the
     + next unparsed argument.
     +
     + Description:
     +  For example, you've defined `"set verbose"` as a command, and you pass in an `ArgPullParser(["set", "verbose", "true"])`.
     +
     +  This function will match with the `"set verbose"` sentence, and will advance the parser so that it will now be `ArgPullParser(["true"])`, ready
     +  for your application code to perform additional processing (e.g. arguments).
     +
     + Params:
     +  parser = The `ArgPullParser` to use and advance.
     +
     + Returns:
     +  Same thing as `CommandResolver.resolve`.
     + ++/
    CommandResolveResult!UserDataT resolveAndAdvance(ref ArgPullParser parser)
    {
        import std.algorithm : map;
        import std.range     : take;

        typeof(return) lastSuccessfulResult;
        
        auto   parserCopy   = parser;
        size_t amountToTake = 0;
        while(true)
        {
            if(parser.empty || parser.front.type != ArgTokenType.Text)
                return lastSuccessfulResult;

            auto result = this.resolve(parserCopy.take(++amountToTake).map!(t => t.value));
            if(!result.success)
                return lastSuccessfulResult;

            lastSuccessfulResult = result;
            parser.popFront();
        }
    }
    
    /// Returns: The root `CommandNode`, for whatever you need it for.
    @property
    NodeT root()
    {
        return this._rootNode;
    }

    /++
     + Notes:
     +  While the returned array is mutable, the nodes stored in this array are *not* the same nodes stored in the actual search tree.
     +  This means that any changes made to this array will not be reflected by the results of `resolve` and `resolveAndAdvance`.
     +
     +  The reason this isn't marked `const` is because that'd mean that your user data would also be marked `const`, which, in D,
     +  can be *very* annoying and limiting. Doubly so since your intentions can't be determined due to the nature of user data. So behave with this.
     +
     + Returns:
     +  All of the final words currently defined.
     + ++/
    @property
    NodeT[] finalWords()
    {
        return this._finalWords;
    }
}
///
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Main test for CommandResolver")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.algorithm : map, equal;

    // Define UserData as a struct containing an execution method. Define a UserData which toggles a value.
    static struct UserData
    {
        void delegate() @safe execute;
    }

    bool executeValue;
    void toggleValue() @safe
    {
        executeValue = !executeValue;
    }

    auto userData = UserData(&toggleValue);

    // Create the resolver and define three command paths: "toggle", "please toggle", and "please tog".
    // Tree should look like:
    //       [root]
    //      /      \
    // toggle       please
    //             /      \
    //          toggle    tog
    auto resolver = new CommandResolver!UserData;
    resolver.define("toggle", userData);
    resolver.define("please toggle", userData);
    resolver.define("please tog", userData);

    // Resolve 'toggle' and call its execute function.
    auto result = resolver.resolve("toggle");
    assert(result.success);
    assert(result.value.word == "toggle");
    assert(result.value.sentence == "toggle");
    assert(result.value.type == CommandNodeType.finalWord);
    assert(result.value.userData.execute !is null);
    result.value.userData.execute();
    assert(executeValue == true);

    // Resolve 'please' and confirm that it's only a partial match.
    result = resolver.resolve("please");
    assert(result.success);
    assert(result.value.word            == "please");
    assert(result.value.sentence        is null);
    assert(result.value.type            == CommandNodeType.partialWord);
    assert(result.value.children.length == 2);
    assert(result.value.userData        == UserData.init);
    
    // Resolve 'please toggle' and call its execute function.
    result = resolver.resolve("please toggle");
    assert(result.success);
    assert(result.value.word == "toggle");
    assert(result.value.sentence == "please toggle");
    assert(result.value.type == CommandNodeType.finalWord);
    result.value.userData.execute();
    assert(executeValue == false);

    // Resolve 'please tog' and call its execute function. (to test nodes with multiple children).
    result = resolver.resolve("please tog");
    assert(result.success);
    assert(result.value.word == "tog");
    assert(result.value.sentence == "please tog");
    assert(result.value.type == CommandNodeType.finalWord);
    result.value.userData.execute();
    assert(executeValue == true);

    // Resolve a few non-existing command sentences, and ensure that they were unsuccessful.
    assert(!resolver.resolve(null).success);
    assert(!resolver.resolve("toggle please").success);
    assert(!resolver.resolve("He she we, wombo.").success);

    // Test that final words are properly tracked.
    assert(resolver.finalWords.map!(w => w.word).equal(["toggle", "toggle", "tog"]));
    assert(resolver.root.finalWords.equal(resolver.finalWords));

    auto node = resolver.resolve("please").value;
    assert(node.finalWords().map!(w => w.word).equal(["toggle", "tog"]));
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test CommandResolver.resolveAndAdvance")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    // Resolution should stop once a non-Text argument is found "--c" in this case.
    // Also the parser should be advanced, where .front is the argument that wasn't part of the resolved command.
    auto resolver = new CommandResolver!int();
    auto parser   = ArgPullParser(["a", "b", "--c", "-d", "e"]);

    resolver.define("a b e", 0);

    auto parserCopy = parser;
    auto result     = resolver.resolveAndAdvance(parserCopy);
    assert(result.success);
    assert(result.value.type == CommandNodeType.partialWord);
    assert(result.value.word == "b");
    assert(parserCopy.front.value == "c", parserCopy.front.value);
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test CommandResolver.resolve possible edge case")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    auto resolver = new CommandResolver!int();
    auto parser   = ArgPullParser(["set", "value", "true"]);
    
    resolver.define("set value", 0);

    auto result = resolver.resolveAndAdvance(parser);
    assert(result.success);
    assert(result.value.type == CommandNodeType.finalWord);
    assert(result.value.word == "value");
    assert(parser.front.value == "true");

    result = resolver.resolve("set verbose true");
    assert(!result.success);
}
*/
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.result;

import std.format : format;
import std.meta   : AliasSeq;

/++
 + A basic result object use by various parts of JCLI.
 +
 + Params:
 +  T = The type that is returned by this result object.
 + ++/
struct Result(T)
{
    // Can't use Algebraic as it's not nothrow, @nogc, and @safe.
    // Not using a proper union as to simplify attribute stuff.
    // Using an enum instead of `TypeInfo` as Object.opEquals has no attributes.
    // All functions are templated to allow them to infer certain annoying attributes (e.g. for types that have a postblit).
    static struct Success { static if(!is(T == void)) T value; }
    static struct Failure { string error; }

    private enum Type
    {
        ERROR,
        Success,
        Failure
    }
    private enum TypeToEnum(alias ResultType) = mixin("Type.%s".format(__traits(identifier, ResultType)));
    private enum TypeToUnionAccess(alias ResultType) = "this._value.%s_".format(__traits(identifier, ResultType));

    private static struct ResultUnion
    {
        Success Success_;
        Failure Failure_;
    }

    private Type _type;
    private ResultUnion _value;

    static foreach(ResultType; AliasSeq!(Success, Failure))
    {
        ///
        this()(ResultType value)
        {
            this._type = TypeToEnum!ResultType;
            mixin(TypeToUnionAccess!ResultType ~ " = value;");
        }

        mixin("alias is%s = isType!(%s);".format(__traits(identifier, ResultType), __traits(identifier, ResultType)));
        mixin("alias as%s = asType!(%s);".format(__traits(identifier, ResultType), __traits(identifier, ResultType)));
    }
    
    ///
    bool isType(ResultType)()
    {
        return this._type == TypeToEnum!ResultType;
    }

    ///
    ResultType asType(ResultType)()
    {
        return mixin(TypeToUnionAccess!ResultType);
    }

    /// Constructs a successful result, returning the given value.
    static Result!T success()(T value){ return typeof(this)(Success(value)); }
    static if(is(T == void))
        static Result!void success()(){ return typeof(this)(Success()); }

    /// Constructs a failure result, returning the given error.
    static Result!T failure()(string error){ return typeof(this)(Failure(error)); }

    /// Constructs a failure result if the `condition` is true, otherwise constructs a success result with the given `value`.
    static Result!T failureIf()(bool condition, T value, string error) { return condition ? failure(error) : success(value); }
    static if(is(T == void))
        static Result!T failureIf()(bool condition, string error) { return condition ? failure(error) : success(); }
}

void resultAssert(ResultT, ValueT)(ResultT result, ValueT expected)
{
    assert(result.isSuccess, result.asFailure.error);
    assert(result.asSuccess.value == expected);
}

void resultAssert(ResultT)(ResultT result)
{
    assert(result.isSuccess, result.asFailure.error);
}
/// Contains functions for interacting with the shell.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.shell;

/++
 + Contains utility functions regarding the Shell/process execution.
 + ++/
static final abstract class Shell
{
    import std.stdio : writeln, writefln;
    import std.traits : isInstanceOf;
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.binder;
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.userio : UserIO;

    /// The result of executing a process.
    struct Result
    {
        /// The output produced by the process.
        string output;

        /// The status code returned by the process.
        int statusCode;
    }

    private static
    {
        string[] _locationStack;
    }

    /+ LOGGING +/
    public static
    {
        deprecated("Use UserIO.configure().useVerboseLogging")
        bool useVerboseOutput = false;

        deprecated("Use UserIO.verbosef, or one of its helper functions.")
        void verboseLogfln(Args...)(string format, Args args)
        {
            if(Shell.useVerboseOutput)
                writefln(format, args);
        }
    }

    /+ COMMAND EXECUTION +/
    public static
    {
        /++
         + Executes a command via `std.process.executeShell`, and collects its results.
         +
         + Params:
         +  command = The command string to execute.
         +
         + Returns:
         +  The `Result` of the execution.
         + ++/
        Result execute(string command)
        {
            import std.process : executeShell;

            UserIO.verboseTracef("execute: %s", command);
            auto result = executeShell(command);
            UserIO.verboseTracef(result.output);

            return Result(result.output, result.status);
        }

        /++
         + Executes a command via `std.process.executeShell`, enforcing that the process' exit code was 0.
         +
         + Throws:
         +  `Exception` if the process' exit code was anything other than 0.
         +
         + Params:
         +  command = The command string to execute.
         +
         + Returns:
         +  The `Result` of the execution.
         + ++/
        Result executeEnforceStatusZero(string command)
        {
            import std.format    : format;
            import std.exception : enforce;

            auto result = Shell.execute(command);
            enforce(result.statusCode == 0,
                "The command '%s' did not return status code 0, but returned %s."
                .format(command, result.statusCode)
            );

            return result;
        }

        /++
         + Executes a command via `std.process.executeShell`, enforcing that the process' exit code was >= 0.
         +
         + Notes:
         +  Positive exit codes may still indicate an error.
         +
         + Throws:
         +  `Exception` if the process' exit code was anything other than 0 or above.
         +
         + Params:
         +  command = The command string to execute.
         +
         + Returns:
         +  The `Result` of the execution.
         + ++/
        Result executeEnforceStatusPositive(string command)
        {
            import std.format    : format;
            import std.exception : enforce;

            auto result = Shell.execute(command);
            enforce(result.statusCode >= 0,
                "The command '%s' did not return a positive status code, but returned %s."
                .format(command, result.statusCode)
            );

            return result;
        }

        /++
         + Executes a command via `std.process.executeShell`, and checks to see if the output was empty.
         +
         + Params:
         +  command = The command string to execute.
         +
         + Returns:
         +  Whether the process' output was either empty, or entirely made up of white space.
         + ++/
        bool executeHasNonEmptyOutput(string command)
        {
            import std.ascii     : isWhite;
            import std.algorithm : all;

            return !Shell.execute(command).output.all!isWhite;
        }
    }

    /+ WORKING DIRECTORY +/
    public static
    {
        /++
         + Pushes the current working directory onto a stack, and then changes directory.
         +
         + Usage:
         +  Use `Shell.popLocation` to go back to the previous directory.
         +
         +  Combining `pushLocation` with `scope(exit) Shell.popLocation` is a good practice.
         +
         + See also:
         +  Powershell's `Push-Location` cmdlet.
         +
         + Params:
         +  dir = The directory to change to.
         + ++/
        void pushLocation(string dir)
        {
            import std.file : chdir, getcwd;

            UserIO.verboseTracef("pushLocation: %s", dir);
            this._locationStack ~= getcwd();
            chdir(dir);
        }

        /++
         + Pops the working directory stack, and then changes the current working directory to it.
         +
         + Assertions:
         +  The stack must not be empty.
         + ++/
        void popLocation()
        {
            import std.file : chdir;

            assert(this._locationStack.length > 0, 
                "The location stack is empty. This indicates a bug as there is a mis-match between `pushLocation` and `popLocation` calls."
            );

            UserIO.verboseTracef("popLocation: [dir after pop] %s", this._locationStack[$-1]);
            chdir(this._locationStack[$-1]);
            this._locationStack.length -= 1;
        }
    }

    /+ MISC +/
    public static
    {
        /++
         + $(B Tries) to determine if the current shell is Powershell.
         +
         + Notes:
         +  On Windows, this will always be `false` because Windows.
         + ++/
        bool isInPowershell()
        {
            // Seems on Windows, powershell isn't used when using `execute`, even if the program itself is launched in powershell.
            version(Windows) return false;
            else return Shell.executeHasNonEmptyOutput("$verbosePreference");
        }

        /++
         + $(B Tries) to determine if the given command exists.
         +
         + Notes:
         +  In Powershell, `Get-Command` is used.
         +
         +  On Posix, `command -v` is used.
         +
         +  On Windows, `where` is used.
         +
         + Params:
         +  command = The command/executable to check.
         +
         + Returns:
         +  `true` if the command exists, `false` otherwise.
         + ++/
        bool doesCommandExist(string command)
        {
            if(Shell.isInPowershell)
                return Shell.executeHasNonEmptyOutput("Get-Command "~command);

            version(Posix) // https://stackoverflow.com/questions/762631/find-out-if-a-command-exists-on-posix-system
                return Shell.executeHasNonEmptyOutput("command -v "~command);
            else version(Windows)
            {
                import std.algorithm : startsWith;

                auto result = Shell.execute("where "~command);
                if(result.output.length == 0)
                    return false;

                if(result.output.startsWith("INFO: Could not find files"))
                    return false;

                return true;
            }
            else
                static assert(false, "`doesCommandExist` is not implemented for this platform. Feel free to make a PR!");
        }

        /++
         + Enforce that the given command/executable exists.
         +
         + Throws:
         +  `Exception` if the given `command` doesn't exist.
         +
         + Params:
         +  command = The command to check for.
         + ++/
        void enforceCommandExists(string command)
        {
            import std.exception : enforce;
            enforce(Shell.doesCommandExist(command), "The command '"~command~"' does not exist or is not on the PATH.");
        }
    }
}

/// Contains various utilities for displaying and formatting text.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.text;

import std.typecons : Flag;
//[CONTAINS_BLACKLISTED_IMPORT]import jaster.cli.ansi : AnsiChar;

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

    /++
     + Calculates the amount of characters per line that can be used for the user's provided text.
     +
     + In other words, how many characters are left after the `linePrefix`, `lineSuffix`, and any `additionalChars` are considered for.
     +
     + Params:
     +  additionalChars = The amount of additional chars that are outputted with every line, e.g. if you want to add new lines or tabs or whatever.
     +
     + Returns:
     +  The amount of characters per line, not including "static" characters such as the `linePrefix` and so on.
     +
     +  0 is returned on underflow.
     + ++/
    @safe @nogc
    size_t charsPerLine(size_t additionalChars = 0) nothrow pure const
    {
        const value = this.lineCharLimit - (this.linePrefix.length + this.lineSuffix.length + additionalChars);

        return (value > this.lineCharLimit) ? 0 : value; // Check for underflow.
    }
    ///
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        assert(LineWrapOptions(120).charsPerLine               == 120);
        assert(LineWrapOptions(120).charsPerLine(20)           == 100);
        assert(LineWrapOptions(120, "ABC", "123").charsPerLine == 114);
        assert(LineWrapOptions(120).charsPerLine(200)          == 0); // Underflow
    }
*/
}

/++
 + Same thing as `asLineWrapped`, except it is eagerly evaluated.
 +
 + Throws:
 +  `Exception` if the char limit is too small to show any text.
 +
 + Params:
 +  text    = The text to line wrap.
 +  options = The options to line wrap with.
 +
 + Performance:
 +  With character-based wrapping, this function can calculate the entire amount of space needed for the resulting string, resulting in only
 +  a single GC allocation.
 +
 + Returns:
 +  A newly allocated `string` containing the eagerly-evaluated results of `asLineWrapped(text, options)`.
 +
 + See_Also:
 +  `LineWrapRange` for full documentation.
 +
 +  `asLineWrapped` for a lazily evaluated version.
 + ++/
@trusted // Can't be @safe due to assumeUnique
string lineWrap(const(char)[] text, const LineWrapOptions options = LineWrapOptions(120)) pure
{
    import std.exception : assumeUnique, enforce;

    const charsPerLine = options.charsPerLine(LineWrapRange!string.ADDITIONAL_CHARACTERS_PER_LINE);
    if(charsPerLine == 0)
        LineWrapRange!string("", options); // Causes the ctor to throw an exception with a proper error message.

    const estimatedLines = (text.length / charsPerLine);

    char[] actualText;
    actualText.reserve(
        text.length 
      + (options.linePrefix.length * estimatedLines) 
      + (options.lineSuffix.length * estimatedLines)
      + estimatedLines // For new line characters.
    ); // This can overallocate, because we can strip off leading space characters.

    foreach(segment; text.asLineWrapped(options))
        actualText ~= segment;

    return actualText.assumeUnique;
}
///
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    const options = LineWrapOptions(8, "\t", "-");
    const text    = "Hello world".lineWrap(options);
    assert(text == "\tHello-\n\tworld-", text);
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("issue #2")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    const options = LineWrapOptions(4, "");
    const text    = lineWrap("abcdefgh", options);

    assert(text[$-1] != '\n', "lineWrap is inserting a new line at the end again.");
    assert(text == "abc\ndef\ngh", text);
}
*/

/++
 + An InputRange that wraps a piece of text into seperate lines, based on the given options.
 +
 + Throws:
 +  `Exception` if the char limit is too small to show any text.
 +
 + Notes:
 +  Other than the constructor, this range is entirely `@nogc nothrow`.
 +
 +  Currently, this performs character-wrapping instead of word-wrapping, so words
 +  can be split between multiple lines. There is no technical reason for this outside of I'm lazy.
 +  The option between character and word wrapping will become a toggle inside of `LineWrapOptions`, so don't fear about
 +  this range magically breaking in the future.
 +
 +  For every line created from the given `text`, the starting and ending spaces (not all whitespace, just spaces)
 +  are stripped off. This is so the user doesn't have to worry about random leading/trailling spaces, making it
 +  easier to format for the general case (though specific cases might find this undesirable, I'm sorry).
 +  $(B This does not apply to prefixes and suffixes).
 +
 +  I may expand `LineWrapOptions` so that the user can specify an array of characters to be stripped off, instead of it being hard coded to spaces.
 +
 + Output:
 +  For every line that needs to be wrapped by this range, it will return values in the following pattern.
 +
 +  Prefix (`LineWrapOptions.prefix`) -> Text (from input) -> Suffix (`LineWrapOptions.suffix`) -> New line character (if this isn't the last line).
 +
 +  $(B Prefixes and suffixes are only outputted if they are not) `null`.
 +
 +  Please refer to the example unittest for this struct, as it will show you this pattern more clearly.
 +
 + Peformance:
 +  This range performs no allocations other than if the ctor throws an exception.
 +
 +  For character-based wrapping, the part of the code that handles getting the next range of characters from the user-provided input, totals
 +  to `O(l+s)`, where "l" is the amount of lines that this range will produce (`input.length / lineWrapOptions.charsPerLine(1)`), and "s" is the amount
 +  of leading spaces that the range needs to skip over. In general, "l" will be the main speed factor.
 +
 +  For character-based wrapping, once leading spaces have been skipped over, it is able to calculate the start and end for the range of user-provided
 +  characters to return. In other words, it doesn't need to iterate over every single character (unless every single character is a space >:D), making it very fast.
 + ++/
@safe
struct LineWrapRange(StringT)
{
    // So basically, we want to return the same type we get, instead of going midway with `const(char)[]`.
    //
    // This is because it's pretty annoying when you pass a `string` in, with plans to store things as `string`s, but then
    // find out that you're only getting a `const(char)[]`.
    //
    // Also we're working directly with arrays instead of ranges, so we don't have to allocate.
    static assert(
        is(StringT : const(char)[]),
        "StringT must either be a `string` or a `char[]` of some sort."
    );

    private
    {
        enum Next
        {
            prefix,
            text,
            suffix,
            newline
        }

        enum ADDITIONAL_CHARACTERS_PER_LINE = 1; // New line

        StringT         _input;
        StringT         _front;
        size_t          _cursor;
        Next            _nextFront;
        LineWrapOptions _options;
    }

    this(StringT input, LineWrapOptions options = LineWrapOptions(120)) pure
    {
        import std.exception : enforce;

        this._input   = input;
        this._options = options;

        enforce(
            options.charsPerLine(ADDITIONAL_CHARACTERS_PER_LINE) > 0,
            "The lineCharLimit is too low. There's not enough space for any text (after factoring the prefix, suffix, and ending new line characters)."
        );

        this.popFront();
    }

    @nogc nothrow pure:

    StringT front()
    {
        return this._front;
    }

    bool empty()
    {
        return this._front is null;
    }

    void popFront()
    {
        switch(this._nextFront) with(Next)
        {
            case prefix:
                if(this._options.linePrefix is null)
                {
                    this._nextFront = Next.text;
                    this.popFront();
                    return;
                }
                
                this._front     = this._options.linePrefix;
                this._nextFront = Next.text;   
                return;

            case suffix:
                if(this._options.lineSuffix is null)
                {
                    this._nextFront = Next.newline;
                    this.popFront();
                    return;
                }
                
                this._front     = this._options.lineSuffix;
                this._nextFront = Next.newline;
                return;

            case text: break; // The rest of this function is the logic for .text, so just break.
            default:   break; // We want to hide .newline behind the End of text check, otherwise we'll end up with a stray newline at the end that we don't want.
        }

        // end of text check
        if(this._cursor >= this._input.length)
        {
            this._front = null;
            return;
        }

        // Only add the new lines if we've not hit end of text.
        if(this._nextFront == Next.newline)
        {
            this._front = "\n";
            this._nextFront  = Next.prefix;
            return;
        }

        // This is the logic for Next.text
        // BUG: "end" can very technically wrap around, causing a range error.
        //      If you're line wrapping a 4 billion+/whatever ulong.max is, sized string, you have other issues I imagine.
        
        // Find the range for the next piece of text.
        const charsPerLine = this._options.charsPerLine(ADDITIONAL_CHARACTERS_PER_LINE);
        size_t end         = (this._cursor + charsPerLine);
        
        // Strip off whitespace, so things format properly.
        while(this._cursor < this._input.length && this._input[this._cursor] == ' ')
        {
            this._cursor++;
            end++;
        }
        
        this._front     = this._input[this._cursor..(end >= this._input.length) ? this._input.length : end];
        this._cursor   += charsPerLine;
        this._nextFront = Next.suffix;
    }
}
///
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.algorithm : equal;
    import std.format    : format;

    auto options = LineWrapOptions(8, "\t", "-");
    assert(options.charsPerLine(1) == 5);

    // This is the only line that's *not* @nogc nothrow, as it can throw an exception.
    auto range = "Hello world".asLineWrapped(options);

    assert(range.equal([
        "\t", "Hello", "-", "\n",
        "\t", "world", "-"        // Leading spaces were trimmed. No ending newline.
    ]), "%s".format(range));

    // If the suffix/prefix are null, then they don't get outputted
    options.linePrefix = null;
    options.lineCharLimit--;
    range = "Hello world".asLineWrapped(options);

    assert(range.equal([
        "Hello", "-", "\n",
        "world", "-"
    ]));
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test that a LineWrapRange that only creates a single line, works fine.")

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.algorithm : equal;

    const options = LineWrapOptions(6);
    auto range    = "Hello".asLineWrapped(options);
    assert(!range.empty, "Range created no values");
    assert(range.equal(["Hello"]));
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("LineWrapRange.init must be empty")

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    assert(LineWrapRange!string.init.empty);
}
*/

// Two overloads to make it clear there's a behaviour difference.

/++
 + Returns an InputRange (`LineWrapRange`) that will wrap the given `text` onto seperate lines.
 +
 + Params:
 +  text    = The text to line wrap.
 +  options = The options to line wrap with, such as whether to add a prefix and suffix.
 +
 + Returns:
 +  A `LineWrapRange` that will wrap the given `text` onto seperate lines.
 +
 + See_Also:
 +  `LineWrapRange` for full documentation.
 +
 +  `lineWrap` for an eagerly evaluated version.
 + ++/
@safe
LineWrapRange!string asLineWrapped(string text, LineWrapOptions options = LineWrapOptions(120)) pure
{
    return typeof(return)(text, options);
}

/// ditto
@safe
LineWrapRange!(const(char)[]) asLineWrapped(CharArrayT)(CharArrayT text, LineWrapOptions options = LineWrapOptions(120)) pure
if(is(CharArrayT == char[]) || is(CharArrayT == const(char)[]))
{
    // If it's not clear, if the user passes in "char[]" then it gets promoted into "const(char)[]".
    return typeof(return)(text, options);
}
///
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    auto constChars   = cast(const(char)[])"Hello";
    auto mutableChars = ['H', 'e', 'l', 'l', 'o'];

    // Mutable "char[]" is promoted to const "const(char)[]".
    LineWrapRange!(const(char)[]) constRange   = constChars.asLineWrapped;
    LineWrapRange!(const(char)[]) mutableRange = mutableChars.asLineWrapped;
}
*/

/++
 + A basic rectangle struct, used to specify the bounds of a `TextBufferWriter`.
 +
 + Notes:
 +  This struct is not fully @nogc due to the use of `std.format` within assert messages.
 + ++/
@safe
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

    /++
     + Finds the relative center point on the X axis, optionally taking into account the width of another object (e.g. text).
     +
     + Params:
     +  width = The optional width to take into account.
     +
     + Returns:
     +  The relative center X position, optionally offset by `width`.
     + ++/
    size_t centerX(const size_t width = 0) pure
    {
        return this.centerAxis(this.width, width);
    }
    ///
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
    @safe pure

*/
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        auto bounds = TextBufferBounds(0, 0, 10, 0);
        assert(bounds.centerX == 5);
        assert(bounds.centerX(2) == 4);
        assert(bounds.centerX(5) == 2);

        bounds.left = 20000;
        assert(bounds.centerX == 5); // centerX provides a relative point, not absolute.
    }
*/

    /++
     + Finds the relative center point on the Y axis, optionally taking into account the height of another object (e.g. text).
     +
     + Params:
     +  height = The optional height to take into account.
     +
     + Returns:
     +  The relative center Y position, optionally offset by `height`.
     + ++/
    size_t centerY(const size_t height = 0) pure
    {
        return this.centerAxis(this.height, height);
    }

    private size_t centerAxis(const size_t axis, const size_t offset) pure
    {
        import std.format : format;
        assert(offset <= axis, "Cannot use offset as it's larger than the axis. Axis = %s, offset = %s".format(axis, offset));
        return (axis - offset) / 2;
    }

    /// 2D point to 1D array index.
    @nogc
    private size_t pointToIndex(size_t x, size_t y, size_t bufferWidth) const nothrow pure
    {
        return (x + this.left) + (bufferWidth * (y + this.top));
    }
    ///
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
    @safe @nogc nothrow pure

*/
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        auto b = TextBufferBounds(0, 0, 5, 5);
        assert(b.pointToIndex(0, 0, 5) == 0);
        assert(b.pointToIndex(0, 1, 5) == 5);
        assert(b.pointToIndex(4, 4, 5) == 24);

        b = TextBufferBounds(1, 1, 3, 2);
        assert(b.pointToIndex(0, 0, 5) == 6);
        assert(b.pointToIndex(1, 0, 5) == 7);
        assert(b.pointToIndex(0, 1, 5) == 11);
        assert(b.pointToIndex(1, 1, 5) == 12);
    }
*/

    private void assertPointInBounds(size_t x, size_t y, size_t bufferWidth, size_t bufferSize) const pure
    {
        import std.format : format;

        assert(x < this.width,  "X is larger than width. Width = %s, X = %s".format(this.width, x));
        assert(y < this.height, "Y is larger than height. Height = %s, Y = %s".format(this.height, y));

        const maxIndex   = this.pointToIndex(this.width - 1, this.height - 1, bufferWidth);
        const pointIndex = this.pointToIndex(x, y, bufferWidth);
        assert(pointIndex <= maxIndex,  "Index is outside alloted bounds. Max = %s, given = %s".format(maxIndex, pointIndex));
        assert(pointIndex < bufferSize, "Index is outside of the TextBuffer's bounds. Max = %s, given = %s".format(bufferSize, pointIndex));
    }
    ///
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        // Testing what error messages look like.
        auto b = TextBufferBounds(5, 5, 5, 5);
        //b.assertPointInBounds(6, 0, 0, 0);
        //b.assertPointInBounds(0, 6, 0, 0);
        //b.assertPointInBounds(1, 0, 0, 0);
    }
*/
}

/++
 + A mutable random-access range of `AnsiChar`s that belongs to a certain bounded area (`TextBufferBound`) within a `TextBuffer`.
 +
 + You can use this range to go over a certain rectangular area of characters using the range API; directly index into this rectangular area,
 + and directly modify elements in this rectangular range.
 +
 + Reading:
 +  Since this is a random-access range, you can either use the normal `foreach`, `popFront` + `front` combo, and you can directly index
 +  into this range.
 +
 +  Note that popping the elements from this range $(B does) affect indexing. So if you `popFront`, then [0] is now what was previous [1], and so on.
 +
 + Writing:
 +  This range implements `opIndexAssign` for both `char` and `AnsiChar` parameters.
 +
 +  You can either index in a 1D way (using 1 index), or a 2D ways (using 2 indicies, $(B not implemented yet)).
 +
 +  So if you wanted to set the 7th index to a certain character, then you could do `range[6] = '0'`.
 +
 +  You could also do it like so - `range[6] = AnsiChar(...params here)`
 +
 + See_Also:
 +  `TextBufferWriter.getArea` 
 + ++/
@safe
struct TextBufferRange
{
    private pure
    {
        TextBuffer       _buffer;
        TextBufferBounds _bounds;
        size_t           _cursorX;
        size_t           _cursorY;
        AnsiChar   _front;

        this(TextBuffer buffer, TextBufferBounds bounds)
        {
            assert(buffer !is null, "Buffer is null.");

            this._buffer = buffer;
            this._bounds = bounds;

            assert(bounds.width > 0,  "Width is 0");
            assert(bounds.height > 0, "Height is 0");
            bounds.assertPointInBounds(bounds.width - 1, bounds.height - 1, buffer._width, buffer._chars.length);

            this.popFront();
        }

        @property
        ref AnsiChar opIndexImpl(size_t i)
        {
            import std.format : format;
            assert(i < this.length, "Index out of bounds. Length = %s, Index = %s.".format(this.length, i));

            i           += this.progressedLength - 1; // Number's always off by 1.
            const line   = i / this._bounds.width;
            const column = i % this._bounds.width;
            const index  = this._bounds.pointToIndex(column, line, this._buffer._width);

            return this._buffer._chars[index];
        }
    }

    ///
    void popFront() pure
    {
        if(this._cursorY == this._bounds.height)
        {
            this._buffer = null;
            return;
        }

        const index = this._bounds.pointToIndex(this._cursorX++, this._cursorY, this._buffer._width);
        this._front = this._buffer._chars[index];

        if(this._cursorX >= this._bounds.width)
        {
            this._cursorX = 0;
            this._cursorY++;
        }
    }

    @safe pure:
    
    /// Returns: The character at the specified index.
    @property
    AnsiChar opIndex(size_t i)
    {
        return this.opIndexImpl(i);
    }

    /++
     + Sets the character value of the `AnsiChar` at index `i`.
     +
     + Notes:
     +  This preserves the colouring and styling of the `AnsiChar`, as we're simply changing its value.
     +
     + Params:
     +  ch = The character to use.
     +  i  = The index of the ansi character to change.
     + ++/
    @property
    void opIndexAssign(char ch, size_t i)
    {
        this.opIndexImpl(i).value = ch;
        this._buffer.makeDirty();
    }

    /// ditto.
    @property
    void opIndexAssign(AnsiChar ch, size_t i)
    {
        this.opIndexImpl(i) = ch;
        this._buffer.makeDirty();
    }

    @safe @nogc nothrow pure:

    ///
    @property
    AnsiChar front()
    {
        return this._front;
    }

    ///
    @property
    bool empty() const
    {
        return this._buffer is null;
    }

    /// The bounds that this range are constrained to.
    @property
    TextBufferBounds bounds() const
    {
        return this._bounds;
    }

    /// Effectively how many times `popFront` has been called.
    @property
    size_t progressedLength() const
    {
        return (this._cursorX + (this._cursorY * this._bounds.width));
    }

    /// How many elements are left in the range.
    @property
    size_t length() const
    {
        return (this.empty) ? 0 : ((this._bounds.width * this._bounds.height) - this.progressedLength) + 1; // + 1 is to deal with the staggered empty logic, otherwise this is 1 off constantly.
    }
    alias opDollar = length;
}

/++
 + The main way to modify and read data into/from a `TextBuffer`.
 +
 + Performance:
 +  Outside of error messages (only in asserts), there shouldn't be any allocations.
 + ++/
@safe
struct TextBufferWriter
{
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.ansi : AnsiColour, AnsiTextFlags, AnsiText;

    @nogc
    private nothrow pure
    {
        TextBuffer       _buffer;
        TextBufferBounds _originalBounds;
        TextBufferBounds _bounds;
        AnsiColour       _fg;
        AnsiColour       _bg;
        AnsiTextFlags    _flags;

        this(TextBuffer buffer, TextBufferBounds bounds)
        {
            this._originalBounds = bounds;
            this._buffer         = buffer;
            this._bounds         = bounds;

            this.updateSize();
        }

        void setSingleChar(size_t index, char ch, AnsiColour fg, AnsiColour bg, AnsiTextFlags flags)
        {
            scope value = &this._buffer._chars[index];
            value.value = ch;
            value.fg    = fg;
            value.bg    = bg;
            value.flags = flags;
        }

        void fixSize(ref size_t size, const size_t offset, const size_t maxSize)
        {
            if(size == TextBuffer.USE_REMAINING_SPACE)
                size = maxSize - offset;
        }
    }

    /++
     + Updates the size of this `TextBufferWriter` to reflect any size changes within the underlying
     + `TextBuffer`.
     +
     + For example, if this `TextBufferWriter`'s height is set to `TextBuffer.USE_REMAINING_SPACE`, and the underlying
     + `TextBuffer`'s height is changed, then this function is used to reflect these changes.
     + ++/
    @nogc
    void updateSize() nothrow pure
    {
        if(this._originalBounds.width == TextBuffer.USE_REMAINING_SPACE)
            this._bounds.width = this._buffer._width - this._bounds.left;
        if(this._originalBounds.height == TextBuffer.USE_REMAINING_SPACE)
            this._bounds.height = this._buffer._height - this._bounds.top;
    }

    /++
     + Sets a character at a specific point.
     +
     + Assertions:
     +  The point (x, y) must be in bounds.
     +
     + Params:
     +  x  = The x position of the point.
     +  y  = The y position of the point.
     +  ch = The character to place.
     +
     + Returns:
     +  `this`, for function chaining.
     + ++/
    TextBufferWriter set(size_t x, size_t y, char ch) pure
    {
        const index = this._bounds.pointToIndex(x, y, this._buffer._width);
        this._bounds.assertPointInBounds(x, y, this._buffer._width, this._buffer._chars.length);

        this.setSingleChar(index, ch, this._fg, this._bg, this._flags);
        this._buffer.makeDirty();

        return this;
    }

    /++
     + Fills an area with a specific character.
     +
     + Assertions:
     +  The point (x, y) must be in bounds.
     +
     + Params:
     +  x      = The starting x position.
     +  y      = The starting y position.
     +  width  = How many characters to fill.
     +  height = How many lines to fill.
     +  ch     = The character to place.
     +
     + Returns:
     +  `this`, for function chaining.
     + ++/
    TextBufferWriter fill(size_t x, size_t y, size_t width, size_t height, char ch) pure
    {
        this.fixSize(/*ref*/ width, x, this.bounds.width);
        this.fixSize(/*ref*/ height, y, this.bounds.height);

        const bufferLength = this._buffer._chars.length;
        const bufferWidth  = this._buffer._width;
        foreach(line; 0..height)
        {
            foreach(column; 0..width)
            {
                // OPTIMISATION: We should be able to fill each line in batch, rather than one character at a time.
                const newX  = x + column;
                const newY  = y + line;
                const index = this._bounds.pointToIndex(newX, newY, bufferWidth);
                this._bounds.assertPointInBounds(newX, newY, bufferWidth, bufferLength);
                this.setSingleChar(index, ch, this._fg, this._bg, this._flags);
            }
        }

        this._buffer.makeDirty();
        return this;
    }

    /++
     + Writes some text starting at the given point.
     +
     + Notes:
     +  If there's too much text to write, it'll simply be left out.
     +
     +  Text will automatically overflow onto the next line down, starting at the given `x` position on each new line.
     +
     +  New line characters are handled properly.
     +
     +  When text overflows onto the next line, any spaces before the next visible character are removed.
     +
     +  ANSI text is $(B only) supported by the overload of this function that takes an `AnsiText` instead of a `char[]`.
     +
     + Params:
     +  x    = The starting x position.
     +  y    = The starting y position.
     +  text = The text to write.
     +
     + Returns:
     +  `this`, for function chaining.
     + +/
    TextBufferWriter write(size_t x, size_t y, const char[] text) pure
    {
        // Underflow doesn't matter, since it'll fail the assert check a few lines down anyway, unless
        // the buffer's size is in the billions+, which is... unlikely.
        const width  = this.bounds.width - x;
        const height = this.bounds.height - y;
        
        const bufferLength = this._buffer._chars.length;
        const bufferWidth  = this._buffer._width;
        this.bounds.assertPointInBounds(x,               y,                bufferWidth, bufferLength);
        this.bounds.assertPointInBounds(x + (width - 1), y + (height - 1), bufferWidth, bufferLength); // - 1 to make the width and height exclusive.

        auto cursorX = x;
        auto cursorY = y;

        void nextLine(ref size_t i)
        {
            cursorX = x;
            cursorY++;

            // Eat any spaces, similar to how lineWrap functions.
            // TODO: I think I should make a lineWrap range for situations like this, where I specifically won't use lineWrap due to allocations.
            //       And then I can just make the original lineWrap function call std.range.array on the range.
            while(i < text.length - 1 && text[i + 1] == ' ')
                i++;
        }
        
        for(size_t i = 0; i < text.length; i++)
        {
            const ch = text[i];
            if(ch == '\n')
            {
                nextLine(i);

                if(cursorY >= height)
                    break;
            }

            const index = this.bounds.pointToIndex(cursorX, cursorY, bufferWidth);
            this.setSingleChar(index, ch, this._fg, this._bg, this._flags);

            cursorX++;
            if(cursorX == x + width)
            {
                nextLine(i);

                if(cursorY >= height)
                    break;
            }
        }

        this._buffer.makeDirty();
        return this;
    }

    /// ditto.
    TextBufferWriter write(size_t x, size_t y, AnsiText text) pure
    {
        const fg    = this.fg;
        const bg    = this.bg;
        const flags = this.flags;

        this.fg    = text.fg;
        this.bg    = text.bg;
        this.flags = text.flags();

        this.write(x, y, text.rawText); // Can only fail asserts, never exceptions, so we don't need scope(exit/failure).

        this.fg    = fg;
        this.bg    = bg;
        this.flags = flags;
        return this;
    }

    /++
     + Assertions:
     +  The point (x, y) must be in bounds.
     +
     + Params:
     +  x = The x position.
     +  y = The y position.
     +
     + Returns:
     +  The `AnsiChar` at the given point (x, y)
     + ++/
    AnsiChar get(size_t x, size_t y) pure
    {
        const index = this._bounds.pointToIndex(x, y, this._buffer._width);
        this._bounds.assertPointInBounds(x, y, this._buffer._width, this._buffer._chars.length);

        return this._buffer._chars[index];
    }

    /++
     + Returns a mutable, random-access (indexable) range (`TextBufferRange`) containing the characters
     + of the specified area.
     +
     + Params:
     +  x      = The x position to start at.
     +  y      = The y position to start at.
     +  width  = How many characters per line.
     +  height = How many lines.
     +
     + Returns:
     +  A `TextBufferRange` that is configured for the given area.
     + ++/
    TextBufferRange getArea(size_t x, size_t y, size_t width, size_t height) pure
    {
        auto bounds = TextBufferBounds(this._bounds.left + x, this._bounds.top + y);
        this.fixSize(/*ref*/ width,  bounds.left, this.bounds.width);
        this.fixSize(/*ref*/ height, bounds.top,  this.bounds.height);

        bounds.width  = width;
        bounds.height = height;

        return TextBufferRange(this._buffer, bounds);
    }

    @safe @nogc nothrow pure:

    /// The bounds that this `TextWriter` is constrained to.
    @property
    TextBufferBounds bounds() const
    {
        return this._bounds;
    }
    
    /// Set the foreground for any newly-written characters.
    /// Returns: `this`, for function chaining.
    @property
    TextBufferWriter fg(AnsiColour fg) { this._fg = fg; return this; }
    /// Set the background for any newly-written characters.
    /// Returns: `this`, for function chaining.
    @property
    TextBufferWriter bg(AnsiColour bg) { this._bg = bg; return this; }
    /// Set the flags for any newly-written characters.
    /// Returns: `this`, for function chaining.
    @property
    TextBufferWriter flags(AnsiTextFlags flags) { this._flags = flags; return this; }

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
///
/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.format : format;
    import jaster.cli.ansi;

    auto buffer         = new TextBuffer(5, 4);
    auto writer         = buffer.createWriter(1, 1, 3, 2); // Offset X, Offset Y, Width, Height.
    auto fullGridWriter = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

    // Clear grid to be just spaces.
    fullGridWriter.fill(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE, ' ');

    // Write some stuff in the center.
    with(writer)
    {
        set(0, 0, 'A');
        set(1, 0, 'B');
        set(2, 0, 'C');

        fg = AnsiColour(Ansi4BitColour.green);

        set(0, 1, 'D');
        set(1, 1, 'E');
        set(2, 1, 'F');
    }

    assert(buffer.toStringNoDupe() == 
        "     "
       ~" ABC "
       ~" \033[32mDEF\033[0m " // \033 stuff is of course, the ANSI codes. In this case, green foreground, as we set above.
       ~"     ",

       buffer.toStringNoDupe() ~ "\n%s".format(buffer.toStringNoDupe())
    );

    assert(writer.get(1, 1) == AnsiChar(AnsiColour(Ansi4BitColour.green), AnsiColour.bgInit, AnsiTextFlags.none, 'E'));
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Testing that basic operations work")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
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
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Testing that ANSI works (but only when the entire thing is a single ANSI command)")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
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
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Testing that a mix of ANSI and plain text works")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.format : format;
    import jaster.cli.ansi : AnsiText, Ansi4BitColour, AnsiColour;

    auto buffer = new TextBuffer(3, 4);
    auto writer = buffer.createWriter(0, 1, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

    buffer.createWriter(0, 0, 3, 1).fill(0, 0, 3, 1, ' '); // So we can also test that the y-offset works.

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
         "   "
        ~"\033[%smABC%s".format(cast(int)Ansi4BitColour.green, AnsiText.RESET_COMMAND)
        ~"DEF"
        ~"\033[%smGHI%s".format(cast(int)Ansi4BitColour.green, AnsiText.RESET_COMMAND)
    , "%s".format(buffer.toStringNoDupe()));
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Various fill tests")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    auto buffer = new TextBuffer(5, 4);
    auto writer = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

    writer.fill(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE, ' '); // Entire grid fill
    auto spaces = new char[buffer._chars.length];
    spaces[] = ' ';
    assert(buffer.toStringNoDupe() == spaces);

    writer.fill(0, 0, TextBuffer.USE_REMAINING_SPACE, 1, 'A'); // Entire line fill
    assert(buffer.toStringNoDupe()[0..5] == "AAAAA");

    writer.fill(1, 1, TextBuffer.USE_REMAINING_SPACE, 1, 'B'); // Partial line fill with X-offset and automatic width.
    assert(buffer.toStringNoDupe()[5..10] == " BBBB", buffer.toStringNoDupe()[5..10]);

    writer.fill(1, 2, 3, 2, 'C'); // Partial line fill, across multiple lines.
    assert(buffer.toStringNoDupe()[10..20] == " CCC  CCC ");
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Issue with TextBufferRange length")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.range : walkLength;

    auto buffer = new TextBuffer(3, 2);
    auto writer = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);
    auto range  = writer.getArea(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

    foreach(i; 0..6)
    {
        assert(!range.empty);
        assert(range.length == 6 - i);
        range.popFront();
    }
    assert(range.empty);
    assert(range.length == 0);
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test TextBufferRange")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.algorithm   : equal;
    import std.format      : format;
    import std.range       : walkLength;
    import jaster.cli.ansi : AnsiColour, AnsiTextFlags;

    auto buffer = new TextBuffer(3, 2);
    auto writer = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

    with(writer)
    {
        set(0, 0, 'A');
        set(1, 0, 'B');
        set(2, 0, 'C');
        set(0, 1, 'D');
        set(1, 1, 'E');
        set(2, 1, 'F');
    }
    
    auto range = writer.getArea(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);
    assert(range.walkLength == buffer.toStringNoDupe().length, "%s != %s".format(range.walkLength, buffer.toStringNoDupe().length));
    assert(range.equal!"a.value == b"(buffer.toStringNoDupe()));

    range = writer.getArea(1, 1, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);
    assert(range.walkLength == 2);

    range = writer.getArea(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);
    range[0] = '1';
    range[1] = '2';
    range[2] = '3';

    foreach(i; 0..3)
        range.popFront();

    // Since the range has been popped, the indicies have moved forward.
    range[1] = AnsiChar(AnsiColour.init, AnsiColour.init, AnsiTextFlags.none, '4');

    assert(buffer.toStringNoDupe() == "123D4F", buffer.toStringNoDupe());
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test write")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.format      : format;    
    import jaster.cli.ansi : AnsiColour, AnsiTextFlags, ansi, Ansi4BitColour;

    auto buffer = new TextBuffer(6, 4);
    auto writer = buffer.createWriter(1, 1, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

    buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE)
          .fill(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE, ' ');
    writer.write(0, 0, "Hello World!");

    assert(buffer.toStringNoDupe() ==
        "      "
       ~" Hello"
       ~" World"
       ~" !    ",
       buffer.toStringNoDupe()
    );

    writer.write(1, 2, "Pog".ansi.fg(Ansi4BitColour.green));
    assert(buffer.toStringNoDupe() ==
        "      "
       ~" Hello"
       ~" World"
       ~" !\033[32mPog\033[0m ",
       buffer.toStringNoDupe()
    );
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test addNewLine mode")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import jaster.cli.ansi : AnsiColour, Ansi4BitColour;

    auto buffer = new TextBuffer(3, 3, TextBufferOptions(TextBufferLineMode.addNewLine));
    auto writer = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

    writer.write(0, 0, "ABC DEF GHI");
    assert(buffer.toStringNoDupe() ==
        "ABC\n"
       ~"DEF\n"
       ~"GHI"
    );

    writer.fg = AnsiColour(Ansi4BitColour.green);
    writer.write(0, 0, "ABC DEF GHI");
    assert(buffer.toStringNoDupe() ==
        "\033[32mABC\n"
       ~"DEF\n"
       ~"GHI\033[0m"
    );
}
*/

/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]
@("Test height changes")
@safe

*/
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    auto buffer     = new TextBuffer(4, 0);
    auto leftColumn = buffer.createWriter(0, 0, 1, TextBuffer.USE_REMAINING_SPACE);

    void addLine(string text)
    {
        buffer.height = buffer.height + 1;
        auto writer = buffer.createWriter(1, buffer.height - 1, 3, 1);
        
        leftColumn.updateSize();
        leftColumn.fill(0, 0, 1, TextBuffer.USE_REMAINING_SPACE, '#');

        writer.write(0, 0, text);
    }

    addLine("lol");
    addLine("omg");
    addLine("owo");

    assert(buffer.toStringNoDupe() == 
        "#lol"
       ~"#omg"
       ~"#owo"
    );

    buffer.height = 2;
    assert(buffer.toStringNoDupe() == 
        "#lol"
       ~"#omg",
       buffer.toStringNoDupe()
    );
}
*/

/++
 + Determines how a `TextBuffer` handles writing out each of its internal "lines".
 + ++/
enum TextBufferLineMode
{
    /// Each "line" inside of the `TextBuffer` is written sequentially, without any non-explicit new lines between them.
    sideBySide,

    /// Each "line" inside of the `TextBuffer` is written sequentially, with an automatically inserted new line between them.
    /// Note that the inserted new line doesn't count towards the character limit for each line.
    addNewLine
}

/++
 + Options for a `TextBuffer`
 + ++/
struct TextBufferOptions
{
    /// Determines how a `TextBuffer` writes each of its "lines".
    TextBufferLineMode lineMode = TextBufferLineMode.sideBySide;
}

// I want reference semantics.
/++
 + An ANSI-enabled class used to easily manipulate a text buffer of a fixed width and height.
 +
 + Description:
 +  This class was inspired by the GPU component from the OpenComputers Minecraft mod.
 +
 +  I thought having something like this, where you can easily manipulate a 2D grid of characters (including colour and the like)
 +  would be quite valuable.
 +
 +  For example, the existence of this class can be the stepping stone into various other things such as: a basic (and I mean basic) console-based UI functionality;
 +  other ANSI-enabled components such as tables which can otherwise be a pain due to the non-uniform length of ANSI text (e.g. ANSI codes being invisible characters),
 +  and so on.
 +
 + Examples:
 +  For now you'll have to explore the source (text.d) and have a look at the module-level unittests to see some testing examples.
 +
 +  When I can be bothered, I'll add user-facing examples :)
 +
 + Limitations:
 +  Currently the buffer can only be resized vertically, not horizontally.
 +
 +  This is due to how the memory's laid out, resizing vertically requires a slightly more complicated algorithm that I'm too lazy to do right now.
 +
 +  Creating the final string output (via `toString` or `toStringNoDupe`) is unoptimised. It performs pretty well for a 180x180 buffer with a sparing amount of colours,
 +  but don't expect it to perform too well right now.
 +  One big issue is that *any* change will cause the entire output to be reconstructed, which I'm sure can be changed to be a bit more optimal.
 + ++/
@safe
final class TextBuffer
{
    /// Used to specify that a writer's width or height should use all the space it can.
    enum USE_REMAINING_SPACE = size_t.max;

    private
    {
        AnsiChar[] _charsBuffer;
        AnsiChar[] _chars;
        size_t     _width;
        size_t     _height;

        char[] _output;
        char[] _cachedOutput;

        TextBufferOptions _options;

        @nogc
        void makeDirty() nothrow pure
        {
            this._cachedOutput = null;
        }
    }

    /++
     + Creates a new `TextBuffer` with the specified width and height.
     +
     + Params:
     +  width   = How many characters each line can contain.
     +  height  = How many lines in total there are.
     +  options = Configuration options for this `TextBuffer`.
     + ++/
    this(size_t width, size_t height, TextBufferOptions options = TextBufferOptions.init) nothrow pure
    {
        this._width              = width;
        this._height             = height;
        this._options            = options;
        this._charsBuffer.length = width * height;
        this._chars              = this._charsBuffer[0..$];
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
    @nogc
    TextBufferWriter createWriter(TextBufferBounds bounds) nothrow pure
    {
        return TextBufferWriter(this, bounds);
    }

    /// ditto.
    @nogc
    TextBufferWriter createWriter(size_t left, size_t top, size_t width = USE_REMAINING_SPACE, size_t height = USE_REMAINING_SPACE) nothrow pure
    {
        return this.createWriter(TextBufferBounds(left, top, width, height));
    }
    
    /// Returns: The height of this `TextBuffer`.
    @property @nogc
    size_t height() const nothrow pure
    {
        return this._height;
    }
    
    /++
     + Sets the height (number of lines) for this `TextBuffer`.
     +
     + Notes:
     +  `TextBufferWriters` will not automatically update their sizes to take into account this size change.
     +
     +  You will have to manually call `TextBufferWriter.updateSize` to reflect any changes, such as properly updating
     +  writers that use `TextBuffer.USE_REMAINING_SPACE` as one of their sizes.
     +
     + Performance:
     +  As is a common theme with this class, it will try to reuse an internal buffer.
     +
     +  So if you're shrinking the height, no allocations should be made.
     +
     +  If you're growing the height, allocations are only made if the new height is larger than its ever been set to.
     +
     +  As a side effect, whenever you grow the buffer the data that occupies the new space will either be `AnsiChar.init`, or whatever
     +  was previously left there.
     +
     + Side_Effects:
     +  This function clears any cached output, so `toStringNoDupe` and `toString` will have to completely reconstruct the output.
     +
     +  Any `TextBufferWriter`s with a non-dynamic size (e.g. no `TextBuffer.USE_REMAINING_SPACE`) that end up becoming out-of-bounds,
     +  will not be useable until they're remade, or until the height is changed again.
     +
     +  Any `TextBufferRange`s that exist prior to resizing are not affected in anyway, and can still access parts of the buffer that
     +  should now technically be "out of bounds" (in the event of shrinking).
     +
     + Params:
     +  lines = The new amount of lines.
     + ++/
    @property
    void height(size_t lines) nothrow
    {
        this._height   = lines;
        const newCount = this._width * this._height;

        if(newCount > this._charsBuffer.length)
            this._charsBuffer.length = newCount;

        this._chars = this._charsBuffer[0..newCount];
        this._cachedOutput = null;
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
//[CONTAINS_BLACKLISTED_IMPORT]        import jaster.cli.ansi : AnsiComponents, populateActiveAnsiComponents, AnsiText;

        if(this._output is null)
            this._output = new char[this._chars.length * 2]; // Optimistic overallocation, to lower amount of resizes

        if(this._cachedOutput !is null)
            return this._cachedOutput;

        size_t outputCursor;
        size_t ansiCharCursor;
        size_t nonAnsiCount;

        // Auto-increments outputCursor while auto-resizing the output buffer.
        void putChar(char c, bool isAnsiChar)
        {
            if(!isAnsiChar)
                nonAnsiCount++;

            if(outputCursor >= this._output.length)
                this._output.length *= 2;

            this._output[outputCursor++] = c;

            // Add new lines if the option is enabled.
            if(!isAnsiChar
            && this._options.lineMode == TextBufferLineMode.addNewLine
            && nonAnsiCount           == this._width)
            {
                this._output[outputCursor++] = '\n';
                nonAnsiCount = 0;
            }
        }
        
        // Finds the next sequence of characters that have the same foreground, background, and flags.
        // e.g. the next sequence of characters that can be used with the same ANSI command.
        // Returns `null` once we reach the end.
        AnsiChar[] getNextAnsiRange()
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

                putChar('\033', true);
                putChar('[', true);
                foreach(ch; components[0..activeCount].joiner(";").byChar)
                    putChar(ch, true);
                putChar('m', true);
            }

            foreach(ansiChar; sequence)
                putChar(ansiChar.value, false);

            // Remove final new line, since it's more expected for it not to be there.
            if(this._options.lineMode         == TextBufferLineMode.addNewLine
            && ansiCharCursor                 >= this._chars.length
            && this._output[outputCursor - 1] == '\n')
                outputCursor--; // For non ANSI, we just leave the \n orphaned, for ANSI, we just overwrite it with the reset command below.

            if(first.usesAnsi)
            {
                foreach(ch; AnsiText.RESET_COMMAND)
                    putChar(ch, true);
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
/// Contains helpful templates relating to UDAs.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.udas;

/++
 + Gets a single specified `UDA` from the given `Symbol`.
 +
 + Assertions:
 +  If the given `Symbol` has either 0, or more than 1 instances of the specified `UDA`, a detailed error message will be displayed.
 + ++/
template getSingleUDA(alias Symbol, alias UDA)
{
    import std.traits : getUDAs;

    // Check if they created an instance `@UDA()`
    //
    // or if they just attached the type itself `@UDA`
    static if(__traits(compiles, {enum UDAs = getUDAs!(Symbol, UDA);}))
        enum UDAs = getUDAs!(Symbol, UDA);
    else
        enum UDAs = [UDA.init];
    
    static if(UDAs.length == 0)
        static assert(false, "The symbol `"~Symbol.stringof~"` does not have the `@"~UDA.stringof~"` UDA");
    else static if(UDAs.length > 1)
        static assert(false, "The symbol `"~Symbol.stringof~"` contains more than one `@"~UDA.stringof~"` UDA");

    enum getSingleUDA = UDAs[0];
}
///
version(unittest)
{
//[CONTAINS_BLACKLISTED_IMPORT]    import jaster.cli.infogen : Command;

    private struct A {}

    @Command("One")
    private struct B {}

    @Command("One")
    @Command("Two")
    private struct C {}
}

/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import jaster.cli.infogen : Command;

    static assert(!__traits(compiles, getSingleUDA!(A, Command)));
    static assert(!__traits(compiles, getSingleUDA!(C, Command)));
    static assert(getSingleUDA!(B, Command).pattern.pattern == "One");
}
*/

/++
 + Sometimes code needs to support both `@UDA` and `@UDA()`, so this template is used
 + to ensure that the given `UDA` is an actual object, not just a type.
 + ++/
template ctorUdaIfNeeded(alias UDA)
{
    import std.traits : isType;
    static if(isType!UDA)
        enum ctorUdaIfNeeded = UDA.init;
    else
        alias ctorUdaIfNeeded = UDA;
}

/++
 + Gets all symbols that have specified UDA from all specified modules
 + ++/
template getSymbolsByUDAInModules(alias attribute, Modules...)
{
    import std.meta: AliasSeq;
    import std.traits: getSymbolsByUDA;

    static if(Modules.length == 0)
    {
        alias getSymbolsByUDAInModules = AliasSeq!();
    }
    else
    {
        alias tail = getSymbolsByUDAInModules!(attribute, Modules[1 .. $]);

        alias getSymbolsByUDAInModules = AliasSeq!(getSymbolsByUDA!(Modules[0], attribute), tail);
    }
}

/*[NO_UNITTESTS_ALLOWED]
unittest
{
    import std.meta: AliasSeq;
    import jaster.cli.infogen : Command;

    static assert(is(getSymbolsByUDAInModules!(Command, jaster.cli.udas) == AliasSeq!(B, C)));
    static assert(is(getSymbolsByUDAInModules!(Command, jaster.cli.udas, jaster.cli.udas) == AliasSeq!(B, C, B, C)));
}
*/

/// Contains functions for getting input, and sending output to the user.
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.userio;

//[CONTAINS_BLACKLISTED_IMPORT]import jaster.cli.ansi, jaster.cli.binder;
import std.experimental.logger : LogLevel;
import std.traits : isInstanceOf;

/++
 + Provides various utilities:
 +  - Program-wide configuration via `UserIO.configure`
 +  - Logging, including debug-only and verbose-only logging via `logf`, `debugf`, and `verbosef`
 +  - Logging helpers, for example `logTracef`, `debugInfof`, and `verboseErrorf`.
 +  - Easily getting input from the user via `getInput`, `getInputNonEmptyString`, `getInputFromList`, and more.
 + ++/
final static class UserIO
{
    /++++++++++++++++
     +++   VARS   +++
     ++++++++++++++++/
    private static
    {
        UserIOConfig _config;
    }

    public static
    {
        /++
         + Configure the settings for `UserIO`, can be called multiple times.
         +
         + Returns:
         +  A `UserIOConfigBuilder`, which is a fluent-builder based struct used to set configuration options.
         + ++/
        UserIOConfigBuilder configure()
        {
            return UserIOConfigBuilder();
        }
    }

    /+++++++++++++++++
     +++  LOGGING  +++
     +++++++++++++++++/
    public static
    {
        /++
         + Logs the given `output` to the console, as long as `level` is >= the configured minimum log level.
         +
         + Configuration:
         +  If `UserIOConfigBuilder.useColouredText` (see `UserIO.configure`) is set to `true`, then the text will be coloured
         +  according to its log level.
         +
         +  trace - gray;
         +  info - default;
         +  warning - yellow;
         +  error - red;
         +  critical & fatal - bright red.
         +
         +  If `level` is lower than `UserIOConfigBuilder.useMinimumLogLevel`, then no output is logged.
         +
         + Params:
         +  output = The output to display.
         +  level  = The log level of this log.
         + ++/
        void log(const char[] output, LogLevel level)
        {
            import std.stdio : writeln;

            if(cast(int)level < UserIO._config.global.minLogLevel)
                return;

            if(!UserIO._config.global.useColouredText)
            {
                writeln(output);
                return;
            }

            AnsiText colouredOutput;
            switch(level) with(LogLevel)
            {
                case trace:     colouredOutput = output.ansi.fg(Ansi4BitColour.brightBlack); break;
                case warning:   colouredOutput = output.ansi.fg(Ansi4BitColour.yellow);      break;
                case error:     colouredOutput = output.ansi.fg(Ansi4BitColour.red);         break;
                case critical:  
                case fatal:     colouredOutput = output.ansi.fg(Ansi4BitColour.brightRed);   break;

                default: break;
            }

            if(colouredOutput == colouredOutput.init)
                colouredOutput = output.ansi;

            writeln(colouredOutput);
        }

        /// Variant of `UserIO.log` that uses `std.format.format` to format the final output.
        void logf(Args...)(const char[] fmt, LogLevel level, Args args)
        {
            import std.format : format;

            UserIO.log(format(fmt, args), level);
        }

        /// Variant of `UserIO.logf` that only shows output in non-release builds.
        void debugf(Args...)(const char[] format, LogLevel level, Args args)
        {
            debug UserIO.logf(format, level, args);
        }

        /// Variant of `UserIO.logf` that only shows output if `UserIOConfigBuilder.useVerboseLogging` is set to `true`.
        void verbosef(Args...)(const char[] format, LogLevel level, Args args)
        {
            if(UserIO._config.global.useVerboseLogging)
                UserIO.logf(format, level, args);
        }

        /// Logs an exception, using the given `LogFunc`, as an error.
        ///
        /// Prefer the use of `logException`, `debugException`, and `verboseException`.
        void exception(alias LogFunc)(Exception ex)
        {
            LogFunc(
                "----EXCEPTION----\nFile: %s\nLine: %s\nType: %s\nMessage: '%s'\nTrace: %s",
                ex.file,
                ex.line,
                ex.classinfo,
                ex.msg,
                ex.info
            );
        }

        // I'm not auto-generating these, as I want autocomplete (e.g. vscode) to be able to pick these up.

        /// Helper functions for `logf`, to easily use a specific log level.
        void logTracef   (Args...)(const char[] format, Args args){ UserIO.logf(format, LogLevel.trace, args);    }
        /// ditto
        void logInfof    (Args...)(const char[] format, Args args){ UserIO.logf(format, LogLevel.info, args);     }
        /// ditto
        void logWarningf (Args...)(const char[] format, Args args){ UserIO.logf(format, LogLevel.warning, args);  }
        /// ditto
        void logErrorf   (Args...)(const char[] format, Args args){ UserIO.logf(format, LogLevel.error, args);    }
        /// ditto
        void logCriticalf(Args...)(const char[] format, Args args){ UserIO.logf(format, LogLevel.critical, args); }
        /// ditto
        void logFatalf   (Args...)(const char[] format, Args args){ UserIO.logf(format, LogLevel.fatal, args);    }
        /// ditto
        alias logException = exception!logErrorf;

        /// Helper functions for `debugf`, to easily use a specific log level.
        void debugTracef   (Args...)(const char[] format, Args args){ UserIO.debugf(format, LogLevel.trace, args);    }
        /// ditto
        void debugInfof    (Args...)(const char[] format, Args args){ UserIO.debugf(format, LogLevel.info, args);     }
        /// ditto
        void debugWarningf (Args...)(const char[] format, Args args){ UserIO.debugf(format, LogLevel.warning, args);  }
        /// ditto
        void debugErrorf   (Args...)(const char[] format, Args args){ UserIO.debugf(format, LogLevel.error, args);    }
        /// ditto
        void debugCriticalf(Args...)(const char[] format, Args args){ UserIO.debugf(format, LogLevel.critical, args); }
        /// ditto
        void debugFatalf   (Args...)(const char[] format, Args args){ UserIO.debugf(format, LogLevel.fatal, args);    }
        /// ditto
        alias debugException = exception!debugErrorf;

        /// Helper functions for `verbosef`, to easily use a specific log level.
        void verboseTracef   (Args...)(const char[] format, Args args){ UserIO.verbosef(format, LogLevel.trace, args);    }
        /// ditto
        void verboseInfof    (Args...)(const char[] format, Args args){ UserIO.verbosef(format, LogLevel.info, args);     }
        /// ditto
        void verboseWarningf (Args...)(const char[] format, Args args){ UserIO.verbosef(format, LogLevel.warning, args);  }
        /// ditto
        void verboseErrorf   (Args...)(const char[] format, Args args){ UserIO.verbosef(format, LogLevel.error, args);    }
        /// ditto
        void verboseCriticalf(Args...)(const char[] format, Args args){ UserIO.verbosef(format, LogLevel.critical, args); }
        /// ditto
        void verboseFatalf   (Args...)(const char[] format, Args args){ UserIO.verbosef(format, LogLevel.fatal, args);    }
        /// ditto
        alias verboseException = exception!verboseErrorf;
    }

    /+++++++++++++++++
     +++  CURSOR   +++
     +++++++++++++++++/
    public static
    {
        @safe
        private void singleArgCsiCommand(char command)(size_t n)
        {
            import std.conv   : to;
            import std.stdio  : write;
            import std.format : sformat;

            enum FORMAT_STRING = "\033[%s"~command;
            enum SIZET_LENGTH  = size_t.max.to!string.length;

            char[SIZET_LENGTH] buffer;
            const used = sformat!FORMAT_STRING(buffer, n);

            // Pretty sure this is safe right? It copies the buffer, right?
            write(used);
        }

        // Again, not auto generated since I don't trust autocomplete to pick up aliases properly.

        /++
         + Moves the console's cursor down and moves the cursor to the start of that line.
         +
         + Params:
         +  lineCount = The amount of lines to move down.
         + ++/
        @safe
        void moveCursorDownByLines(size_t lineCount) { UserIO.singleArgCsiCommand!'E'(lineCount); }

        /++
         + Moves the console's cursor up and moves the cursor to the start of that line.
         +
         + Params:
         +  lineCount = The amount of lines to move up.
         + ++/
        @safe
        void moveCursorUpByLines(size_t lineCount) { UserIO.singleArgCsiCommand!'F'(lineCount); }
    }

    /+++++++++++++++
     +++  INPUT  +++
     +++++++++++++++/
    public static
    {
        /++
         + Gets input from the user, and uses the given `ArgBinder` (or the default one, if one isn't passed) to
         + convert the string to a `T`.
         +
         + Notes:
         +  Because `ArgBinder` is responsible for the conversion, if for example you wanted `T` to be a custom struct,
         +  then you could create an `@ArgBinderFunc` to perform the conversion, and then this function (and all `UserIO.getInput` variants)
         +  will be able to convert the user's input to that type.
         +
         +  See also the documentation for `ArgBinder`.
         +
         + Params:
         +  T       = The type to conver the string to, via `Binder`.
         +  Binder  = The `ArgBinder` that knows how to convert a string -> `T`.
         +  prompt  = The prompt to display to the user, note that no extra characters or spaces are added, the prompt is shown as-is.
         +
         + Returns:
         +  A `T` that was created by the user's input given to `Binder`.
         + ++/
        T getInput(T, Binder = ArgBinder!())(string prompt)
        if(isInstanceOf!(ArgBinder, Binder))
        {
            import std.string : chomp;
            import std.stdio  : readln, write;
            
            write(prompt);

            T value;
            Binder.bind(readln().chomp, value);

            return value;
        }

        /++
         + A variant of `UserIO.getInput` that'll constantly prompt the user until they enter a non-null, non-whitespace-only string.
         +
         + Notes:
         +  The `Binder` is only used to convert a string to a string, in case there's some weird voodoo you want to do with it.
         + ++/
        string getInputNonEmptyString(Binder = ArgBinder!())(string prompt)
        {
            import std.algorithm : all;
            import std.ascii     : isWhite;

            string value;
            while(value.length == 0 || value.all!isWhite)
                value = UserIO.getInput!(string, Binder)(prompt);

            return value;
        }

        /++
         + A variant of `UserIO.getInput` that'll constantly prompt the user until they enter a value that doesn't cause an
         + exception (of type `Ex`) to be thrown by the `Binder`.
         + ++/
        T getInputCatchExceptions(T, Ex: Exception = Exception, Binder = ArgBinder!())(string prompt, void delegate(Ex) onException = null)
        {
            while(true)
            {
                try return UserIO.getInput!(T, Binder)(prompt);
                catch(Ex ex)
                {
                    if(onException !is null)
                        onException(ex);
                }
            }
        }

        /++
         + A variant of `UserIO.getInput` that'll constantly prompt the user until they enter a value from the given `list`.
         +
         + Behaviour:
         +  All items of `list` are converted to a string (via `std.conv.to`), and the user must enter the *exact* value of one of these
         +  strings for this function to return, so if you're wanting to use a struct then ensure you make `toString` provide a user-friendly
         +  value.
         +
         +  This function $(B does not) use `Binder` to provide the final value, it will instead simply return the appropriate
         +  item from `list`. This is because the value already exists (inside of `list`) so there's no reason to perform a conversion.
         +
         +  The `Binder` is only used to convert the user's input from a string into another string, in case there's any transformations
         +  you'd like to perform on it.
         +
         + Prompt:
         +  The prompt layout for this variant is a bit different than other variants.
         +
         +  `$prompt[$list[0], $list[1], ...]$promptPostfix`
         +
         +  For example `Choose colour[red, blue, green]: `
         + ++/
        T getInputFromList(T, Binder = ArgBinder!())(string prompt, T[] list, string promptPostfix = ": ")
        {
            import std.stdio     : write;
            import std.conv      : to;
            import std.exception : assumeUnique;

            auto listAsStrings = new string[list.length];
            foreach(i, item; list)
                listAsStrings[i] = item.to!string();

            // 2 is for the "[" and "]", list.length * 2 is for the ", " added between each item.
            // list.length * 10 is just to try and overallocate a little bit.
            char[] promptBuilder;
            promptBuilder.reserve(prompt.length + 2 + (list.length * 2) + (list.length * 10) + promptPostfix.length);

            promptBuilder ~= prompt;
            promptBuilder ~= "[";
            foreach(i, item; list)
            {
                promptBuilder ~= listAsStrings[i];
                if(i != list.length - 1)
                    promptBuilder ~= ", ";
            }
            promptBuilder ~= "]";
            promptBuilder ~= promptPostfix;

            prompt = promptBuilder.assumeUnique;
            while(true)
            {
                const input = UserIO.getInput!(string, Binder)(prompt);
                foreach(i, str; listAsStrings)
                {
                    if(input == str)
                        return list[i];
                }
            }
        }
    }
}

private struct UserIOConfigScope
{
    bool useVerboseLogging;
    bool useColouredText = true;
    LogLevel minLogLevel;
}

private struct UserIOConfig
{
    UserIOConfigScope global;
}

/++
 + A struct that provides an easy and fluent way to configure how `UserIO` works.
 + ++/
struct UserIOConfigBuilder
{
    private ref UserIOConfigScope getScope()
    {
        // For future purposes.
        return UserIO._config.global;
    }

    /++
     + Determines whether `UserIO.log` uses coloured output based on log level.
     + ++/
    UserIOConfigBuilder useColouredText(bool value = true)
    {
        this.getScope().useColouredText = value;
        return this;
    }

    /++
     + Determines whether `UserIO.verbosef` and friends are allowed to output anything at all.
     + ++/
    UserIOConfigBuilder useVerboseLogging(bool value = true)
    {
        this.getScope().useVerboseLogging = value;
        return this;
    }

    /++
     + Sets the minimum log level. Any logs must be >= this `level` in order to be printed out on screen.
     + ++/
    UserIOConfigBuilder useMinimumLogLevel(LogLevel level)
    {
        this.getScope().minLogLevel = level;
        return this;
    }
}
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.cli.views.bash_complete;

const BASH_COMPLETION_TEMPLATE = `
# [1][3][4] is non-spaced name of exe.
# [2] is full path to exe.
# I hate this btw.

__completion_for_%s() {
    words_as_string=$( IFS=$' '; echo "${COMP_WORDS[*]}" ) ;
    output=$( %s __jcli:complete $COMP_CWORD $words_as_string ) ;
    IFS=$' ' ;
    read -r -a COMPREPLY <<< "$output" ;
}

complete -F __completion_for_%s %s
`;
//[NO_MODULE_STATEMENTS_ALLOWED]module jcli;

//[CONTAINS_BLACKLISTED_IMPORT]public import jaster.cli;
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.ioc.depinject;

/// Describes the lifetime of a service.
enum ServiceLifetime
{
    /++
     + The service is constructed every single time it is requested.
     +
     + These services are the most expensive to use, as they need to be constructed *every single time* they're requested, which also
     + puts strain on the GC.
     + ++/
    Transient,

    /++
     + The service is only constructed a single time for every `ServiceProvider`, regardless of which scope is used to access it.
     +
     + These services are the least expensive to use, as they are only constructed a single time per `ServiceProvider`.
     + ++/
    Singleton,

    /++
     + The service is constructed once per scope.
     +
     + These services are between `Transient` and `Singleton` in terms of performance. It mostly depends on how often scopes are created/destroyed
     + in your program.
     +
     + See_Also:
     +  `ServiceProvider.createScope`
     + ++/
    Scoped
}

// Mixin for things like asSingletonRuntime, or asTransient. aka: boilerplate
private mixin template ServiceLifetimeFunctions(ServiceLifetime Lifetime)
{
    import std.conv : to;
    enum Suffix         = Lifetime.to!string; // I *wish* this could be `const` instead of `enum`, but it produces a weird `cannot modify struct because immutable members` error.
    enum FullLifetime   = "ServiceLifetime."~Suffix;

    @safe nothrow pure
    public static
    {
        ///
        mixin("alias as"~Suffix~"Runtime = asRuntime!("~FullLifetime~");");

        ///
        mixin("alias as"~Suffix~"(alias BaseType, alias ImplType) = asTemplated!("~FullLifetime~", BaseType, ImplType);");

        ///
        mixin("alias as"~Suffix~"(alias ImplType) = asTemplated!("~FullLifetime~", ImplType, ImplType);");
    }
}

/++
 + Describes a service.
 +
 + This struct shouldn't be created directly, you must use one of the static construction functions.
 +
 + For example, if you wanted the service to be a singleton, you could do `asSingleton!(IBaseType, ImplementationType)`.
 + ++/
struct ServiceInfo
{
    alias FactoryFunc               = Object delegate(ref ServiceScope);
    alias FactoryFuncFor(T)         = T delegate(ref ServiceScope);
    enum  isValidBaseType(T)        = (is(T == class) || is(T == interface));
    enum  isValidImplType(BaseT, T) = (is(T == class) && (is(T : BaseT) || is(T == BaseT)));
    enum  isValidImplType(T)        = isValidImplType!(T, T);

    private
    {
        TypeInfo        _baseType;
        TypeInfo        _implType;
        FactoryFunc     _factory;
        ServiceLifetime _lifetime;
        TypeInfo[]      _dependencies;

        @safe @nogc
        this(TypeInfo baseType, TypeInfo implType, FactoryFunc func, ServiceLifetime lifetime, TypeInfo[] dependencies) nothrow pure
        {
            this._baseType      = baseType;
            this._implType      = implType;
            this._factory       = func;
            this._lifetime      = lifetime;
            this._dependencies  = dependencies;

            assert(func !is null, "The factory function is null. The `asXXXRuntime` functions can't auto-generate one sadly, so provide your own.");
        }
    }

    /// This is mostly for unit tests.
    @safe
    bool opEquals(const ServiceInfo rhs) const pure nothrow
    {
        return 
        (
            this._baseType is rhs._baseType
         && this._implType is rhs._implType
         && this._lifetime == rhs._lifetime
        );
    }

    /// So we can use this struct as an AA key more easily
    @trusted // @trusted since we're only converting a pointer to a number, without doing anything else to it. 
    size_t toHash() const pure nothrow
    {
        const baseTypePointer  = cast(size_t)(cast(void*)this._baseType);
        const implTypePointer  = cast(size_t)(cast(void*)this._implType);
        const lifetimeAsNumber = cast(size_t)this._lifetime;

        // NOTE: This is just something completely random I made up. I'll research into a proper technique eventually, this just has to exist *in some form* for now.
        return (baseTypePointer ^ implTypePointer) * lifetimeAsNumber;
    }

    @safe nothrow pure
    public static
    {
        /++
         + An internal function, public due to necessity, however will be used to explain the `asXXXRuntime` functions.
         +
         + e.g. `asSingletonRuntime`, `asTransientRuntime`, and `asScopedRuntime`.
         +
         + Notes:
         +  Unlike the `asTemplated` constructor (and things like `asSingleton`, `asScoped`, etc.), this function isn't able to produce
         +  a list of dependency types, so therefore will need to be provided by you, the user, if you're hoping to make use of `ServiceProvider`'s
         +  dependency loop guard.
         +
         +  You only need to provide a list of types that the `factory` function will try to directly retrieve from a `ServiceScope`, not the *entire* dependency chain.
         + ++/
        ServiceInfo asRuntime(ServiceLifetime Lifetime)(TypeInfo baseType, TypeInfo implType, FactoryFunc factory, TypeInfo[] dependencies = null)
        {
            return ServiceInfo(baseType, implType, factory, Lifetime, dependencies);
        }

        /++
         + An internal function, public due to necessity, however will be used to explain the `asXXX` functions.
         +
         + e.g. `asSingleton`, `asTransient`, and `asScoped`.
         +
         + Notes:
         +  This constructor is able to automatically generate the list of dependencies, which will allow `ServiceProvider` to check for
         +  dependency loops.
         +
         +  If `factory` is `null`, then the factory becomes a call to `Injector.construct!ImplType`, which should be fine for most cases.
         + ++/
        ServiceInfo asTemplated(ServiceLifetime Lifetime, alias BaseType, alias ImplType)(FactoryFuncFor!ImplType factory = null)
        if(isValidBaseType!BaseType && isValidImplType!(BaseType, ImplType))
        {
            import std.meta : Filter;
            import std.traits : Parameters;

            enum isClassOrInterface(T)  = is(T == class) || is(T == interface);
            alias ImplTypeCtor          = Injector.FindCtor!ImplType;
            alias CtorParams            = Parameters!ImplTypeCtor;
            alias CtorParamsFiltered    = Filter!(isClassOrInterface, CtorParams);

            TypeInfo[] deps;
            deps.length = CtorParamsFiltered.length;

            static foreach(i, dep; CtorParamsFiltered)
                deps[i] = typeid(dep);

            if(factory is null)
                factory = (ref services) => Injector.construct!ImplType(services);

            return ServiceInfo(typeid(BaseType), typeid(ImplType), factory, Lifetime, deps);
        }
    }

    mixin ServiceLifetimeFunctions!(ServiceLifetime.Singleton);
    mixin ServiceLifetimeFunctions!(ServiceLifetime.Transient);
    mixin ServiceLifetimeFunctions!(ServiceLifetime.Scoped);
}
///
//@safe nothrow pure
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    static interface I {}
    static class C : I {}

    Object dummyFactory(ref ServiceScope){ return null; }

    // Testing: All 3 aliases can be found, 1 alias per lifetime, which also tests that all lifetimes are handled properly.
    assert(
        ServiceInfo.asSingletonRuntime(typeid(I), typeid(C), &dummyFactory)
        ==
        ServiceInfo(typeid(I), typeid(C), &dummyFactory, ServiceLifetime.Singleton, null)
    );

    assert(
        ServiceInfo.asTransient!(I, C)((ref provider) => new C())
        ==
        ServiceInfo(typeid(I), typeid(C), &dummyFactory, ServiceLifetime.Transient, null) // NOTE: Factory func is ignored in opEquals, so `dummyFactory` here is fine.
    );

    assert(
        ServiceInfo.asScoped!C()
        ==
        ServiceInfo(typeid(C), typeid(C), &dummyFactory, ServiceLifetime.Scoped, null)
    );

    // opEquals and opHash don't care about dependencies (technically I think they should, but meh), so we have to test directly.
    static class WithDeps
    {
        this(C c, I i, int a){}
    }
    
    auto deps = ServiceInfo.asScoped!WithDeps()._dependencies;
    assert(deps.length == 2);
    assert(deps[0] is typeid(C));
    assert(deps[1] is typeid(I));
}
*/

/++
 + Provides access to a service scope.
 +
 + Description:
 +  The idea of having 'scopes' for services comes from the fact that this library was inspired by ASP Core's Dependency Injection,
 +  which provides similar functionality.
 +
 +  In ASP Core there is a need for each HTTP request to have its own 'ecosystem' for services (its own 'scope').
 +
 +  For example, you don't want your database context to be shared between different requests at the same time, as each request needs
 +  to make/discard their own chnages to the database. Having a seperate database context between each request (scope) allows this to be
 +  achieved easily.
 +
 +  For a lot of programs, you probably won't need to use scopes at all, and can simply use `ServiceProvider.defaultScope` for all of your
 +  needs. Use what's best for your case.
 +
 +  See https://docs.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection as the documentation there is mostly appropriate for this library as well.
 +
 + Master & Slave `ServiceScope`:
 +  There are two variants of `ServiceScope` that can be accessed - master scopes, and slave scopes.
 +
 +  The principal is pretty simple: Master scopes are the 'true' accessor to the scope so therefore contain the ability to also destroy the scope.
 +
 +  Slave scopes, however, can be seen more as a 'reference' accessor to the scope, meaning that they cannot destroy the underlying scope in anyway.
 +
 + Destroying a scope:
 +  There are two ways for a service scope to be destroyed.
 +
 +  1. The master `ServiceScope` object has its dtor run. Because the `ServiceScope` is the master accessor, then the scope's lifetime is directly tied to the `ServiceScope`'s lifetime.
 +
 +  2. A call to `ServiceProvider.destroyScope` is made, where a master `ServiceScope` is passed to it.
 +
 +  The `ServiceScope` object is non-copyable, so can only be moved via functions like `std.algorithm.mutation.move`
 +
 +  Currently when a scope it destroyed nothing really happens except that the `ServiceProvider` clears its cache of service instances for that specific scope, and allows
 +  another scope to be created in its place.
 +
 +  In the future I will be adding more functionality onto when a scope is destroyed, as the current behaviour is a bit undesirable for multiple reasons (e.g.
 +  if you destroy a scope, any uses of a `ServiceScopeAccessor` for the destroyed scope can trigger a bug-check assert).
 +
 + See_Also:
 +  `ServiceProvider.createScope`, `ServiceProvider.destroyScope`
 + ++/
struct ServiceScope
{
    private size_t          _index;
    private ServiceProvider _provider;
    private bool            _isMasterReference; // True = Scope is destroyed via this object. False = Scope can't be destroyed via this object.

    @disable
    this(this);

    ~this()
    {
        if(this._provider !is null && this._isMasterReference)
            this._provider.destroyScope(this);
    }

    /++
     + Attempts to retrieve a service of the given `baseType`, otherwise returns `null`.
     + ++/
    Object getServiceOrNull(TypeInfo baseType)
    {
        return this._provider.getServiceOrNull(baseType, this);
    }

    /++
     + Attempts to retrieve a service of the given base type `T`, otherwise returns `null`.
     + ++/
    T getServiceOrNull(alias T)()
    if(ServiceInfo.isValidBaseType!T)
    {
        auto service = this.getServiceOrNull(typeid(T));
        if(service is null)
            return null;

        auto casted = cast(T)service;
        assert(casted !is null, "Invalid cast.");

        return casted;
    }
    ///
/*[NO_UNITTESTS_ALLOWED]
    unittest
    {
        static interface IPrime
        {
            int getPrime();
        }

        static class PrimeThree : IPrime
        {
            int getPrime()
            {
                return 3;
            }
        }

        auto services = new ServiceProvider([ServiceInfo.asTransient!(IPrime, PrimeThree)]);
        auto service = services.defaultScope.getServiceOrNull!IPrime();
        assert(service !is null);
        assert(service.getPrime() == 3);
    }
*/
}

// Not an interface since a testing-specific implementation has no worth atm, and it'd mean making `serviceScope` virtual.
/++
 + A built-in service that allows access to a slave `ServiceScope` for whichever scope this service
 + was constructed for.
 +
 + Description:
 +  Because `ServiceScope` cannot be copied, it can be a bit annoying for certain services to gain access to it should they need
 +  manual access of fetching scoped services.
 +
 +  As an alternative, services can be injected with this helper service which allows the creation of slave `ServiceScope`s.
 +
 + See_Also:
 +  The documentation for `ServiceScope`.
 + ++/
final class ServiceScopeAccessor
{
    // Since ServiceScope can't be copied, and we shouldn't exactly move it from its default location, we need to re-store
    // some of its info for later.
    private ServiceProvider _provider; 
    private size_t          _index;

    private this(ref ServiceScope serviceScope)
    {
        this._provider = serviceScope._provider;
        this._index    = serviceScope._index;
    }

    /++
     + Returns: A slave `ServiceScope`.
     + ++/
    @property @safe @nogc
    ServiceScope serviceScope() nothrow pure
    {
        return ServiceScope(this._index, this._provider, false); // false = Not master scope object.
    }
}

// Not an interface since a testing-specific implementation has little worth atm, and it'd mean making functions virtual.
/++
 + Provides most of the functionality for managing and using services.
 +
 + Dependency_Checking:
 +  During construction, the `ServiceProvider` will perform a check to ensure that none of its registered services contain a 
 +  dependency loop, i.e. making sure that no service directly/indirectly depends on itself.
 +
 +  If you're creating your `ServiceInfo` via the `ServiceInfo.asSingleton`, `ServiceInfo.asTransient`, or `ServiceInfo.asScoped` constructors,
 +  then this functionality is entirely automatic.
 +
 +  If however you're using the `asXXXRuntime` constructor varient, then it is down to the user to provide an array of `TypeInfo` to that constructor,
 +  representing the service's dependencies. Failing to provide the correct data will cause this guard check to not detect the loop, and later down the line
 +  this will cause an infinite loop leading into a crash.
 +
 +  In the future, I may add a `version()` block that will make `ServiceProvider.getServiceOrNull` also perform dependency loop checks. The reason this is not
 +  performed by default is due to performance concerns (especially once your services start to grow in number).
 +
 + Lifetime_Checking:
 +  During construction, the `ServiceProvider` will perform a check to ensure that none of its registered services contains a dependency on
 +  another service with an incompatible lifetime.
 +
 +  Likewise with depenency checking (see section above), you will need to ensure that you provide the correct data when using the `asXXXRuntime` constructors
 +  for `ServiceInfo`.
 +
 +  The following is a table of valid lifetime pairings:
 +
 +      * Transient - [Transient, Singleton]
 +
 +      * Scoped - [Transient, Scoped, Singleton]
 +
 +      * Singleton - [Transient, Singleton]
 + ++/
final class ServiceProvider
{
    import std.typecons : Nullable, nullable;

    alias ServiceInstanceDictionary = Object[ServiceInfo];
    enum BITS_PER_MASK = long.sizeof * 8;

    private
    {
        struct ScopeInfo
        {
            ServiceInstanceDictionary instances;
            ServiceScopeAccessor      accessor; // Written in a way that they only have to be constructed once, so GC isn't as mad.
        }

        ServiceScope                _defaultScope;
        ServiceInfo[]               _allServices;
        ScopeInfo[]                 _scopes;
        ServiceInstanceDictionary   _singletons;
        long[]                      _scopeInUseMasks;

        Object getServiceOrNull(TypeInfo baseType, ref scope ServiceScope serviceScope)
        {
            assert(serviceScope._provider is this, "Attempting to use service scope who does not belong to this `ServiceProvider`.");

            auto infoNullable = this.getServiceInfoForBaseType(baseType);
            if(infoNullable.isNull)
                return null;

            auto info = infoNullable.get();
            final switch(info._lifetime) with(ServiceLifetime)
            {
                case Transient:
                    return info._factory(serviceScope);

                case Scoped:
                    auto ptr = (cast()info in this._scopes[serviceScope._index].instances); // 'cus apparently const is too painful for it to handle.
                    if(ptr !is null)
                        return *ptr;

                    auto instance = info._factory(serviceScope);
                    this._scopes[serviceScope._index].instances[cast()info] = instance;
                    return instance;

                case Singleton:
                    // TODO: Functionise this
                    auto ptr = (cast()info in this._singletons); // 'cus apparently const is too painful for it to handle.
                    if(ptr !is null)
                        return *ptr;

                    auto instance = info._factory(serviceScope);
                    this._singletons[cast()info] = instance;
                    return instance;
            }
        }

        @safe
        ref long getScopeMaskByScopeIndex(size_t index) nothrow
        {
            const indexIntoArray = (index / BITS_PER_MASK);

            if(indexIntoArray >= this._scopeInUseMasks.length)
                this._scopeInUseMasks.length = indexIntoArray + 1;

            return this._scopeInUseMasks[indexIntoArray];
        }

        @safe
        bool isScopeInUse(size_t index) nothrow
        {
            const bitInMask = (index % BITS_PER_MASK);
            const mask      = this.getScopeMaskByScopeIndex(index);

            return (mask & (1 << bitInMask)) > 0;
        }

        @safe
        void setScopeInUse(size_t index, bool isInUse) nothrow
        {
            const bitInMask = (index % BITS_PER_MASK);
            const bitToUse  = (1 << bitInMask);

            if(isInUse)
                this.getScopeMaskByScopeIndex(index) |= bitToUse;
            else
                this.getScopeMaskByScopeIndex(index) &= ~bitToUse;
        }
        ///
/*[NO_UNITTESTS_ALLOWED]
        unittest
        {
            auto services = new ServiceProvider(null);
            assert(!services.isScopeInUse(65));

            services.setScopeInUse(65, true);
            assert(services.isScopeInUse(65));
            assert(services._scopeInUseMasks.length == 2);
            assert(services._scopeInUseMasks[1] == 0b10); // 65 % 64 = 1. 1 << 1 = 0b10
            
            services.setScopeInUse(65, false);
            assert(!services.isScopeInUse(65));
        }
*/

        @safe
        void assertLifetimesAreCompatible()
        {
            @safe
            bool areCompatible(const ServiceLifetime consumer, const ServiceLifetime dependency)
            {
                final switch(consumer) with(ServiceLifetime)
                {
                    case Transient:
                    case Singleton:
                        return dependency != Scoped;

                    case Scoped:
                        return true;
                }
            }

            foreach(service; this._allServices)
            {
                foreach(dependency; service._dependencies)
                {
                    auto dependencyInfo = this.getServiceInfoForBaseType(dependency);
                    if(dependencyInfo.isNull)
                        continue;

                    if(!areCompatible(service._lifetime, dependencyInfo.get._lifetime))
                    {
                        import std.format : format;
                        assert(
                            false,
                            "%s service %s cannot depend on %s service %s as their lifetimes are incompatible".format(
                                service._lifetime,
                                service._baseType,
                                dependencyInfo.get._lifetime,
                                dependency
                            )
                        );
                    }
                }
            }
        }
        //
/*[NO_UNITTESTS_ALLOWED]
        unittest
        {
            import std.exception : assertThrown, assertNotThrown;

            static class Scoped
            {
            }

            static class Transient
            {
                this(Scoped){}
            }

            static class GoodTransient
            {
            }

            static class GoodScoped
            {
                this(GoodTransient){}
            }

            assertThrown!Throwable(new ServiceProvider([
                ServiceInfo.asScoped!Scoped,
                ServiceInfo.asTransient!Transient
            ]));

            assertNotThrown!Throwable(new ServiceProvider([
                ServiceInfo.asScoped!GoodScoped,
                ServiceInfo.asTransient!GoodTransient
            ]));

            // Uncomment when tweaking the error message.
            // new ServiceProvider([
            //     ServiceInfo.asScoped!Scoped,
            //     ServiceInfo.asTransient!Transient
            // ]);
        }
*/

        @safe
        void assertNoDependencyLoops()
        {
            TypeInfo[] typeToTestStack;
            TypeInfo[] typeToTestStackWhenLoopIsFound; // Keep a copy of the stack once a loop is found, so we can print out extra info.
            
            @trusted
            bool dependsOn(TypeInfo typeToTest, TypeInfo dependencyType)
            {
                import std.algorithm : canFind;

                if(typeToTestStack.canFind!"a is b"(typeToTest))
                    return false; // Since we would've returned true otherwise, which would end the recursion.

                typeToTestStack ~= typeToTest;
                scope(exit) typeToTestStack.length -= 1;

                auto serviceInfoNullable = this.getServiceInfoForBaseType(typeToTest);
                if(serviceInfoNullable.isNull)
                    return false; // Since the service doesn't exist anyway.

                auto serviceInfo = serviceInfoNullable.get();
                foreach(dependency; serviceInfo._dependencies)
                {
                    if(dependency is dependencyType || dependsOn(cast()dependency, dependencyType))
                    {
                        if(typeToTestStackWhenLoopIsFound.length == 0)
                            typeToTestStackWhenLoopIsFound = typeToTestStack.dup;

                        return true;
                    }
                }

                return false;
            }

            foreach(service; this._allServices)
            {
                if(dependsOn(service._baseType, service._baseType))
                {
                    import std.algorithm : map, joiner;
                    import std.format : format;

                    assert(
                        false,
                        "Circular dependency detected, %s depends on itself:\n%s -> %s".format(
                            service._baseType,
                            typeToTestStackWhenLoopIsFound.map!(t => t.toString())
                                                          .joiner(" -> "),
                            service._baseType
                        )
                    );
                }
            }
        }
        ///
/*[NO_UNITTESTS_ALLOWED]
        unittest
        {
            import std.exception : assertThrown;

            // Technically shouldn't catch asserts, but this is just for testing.
            assertThrown!Throwable(new ServiceProvider([
                ServiceInfo.asSingleton!CA,
                ServiceInfo.asSingleton!CB
            ]));

            // Uncomment when tweaking with the error message.
            // new ServiceProvider([
            //     ServiceInfo.asSingleton!CA,
            //     ServiceInfo.asSingleton!CB
            // ]);
        }
*/
        version(unittest) // Because of forward referencing being required.
        {
            static class CA
            {
                this(CB){}
            }
            static class CB
            {
                this(CA) {}
            }
        }
    }

    /++
     + Constructs a new `ServiceProvider` that makes use of the given `services`.
     +
     + Builtin_Services:
     +  * [Singleton] `ServiceProvider` - `this`
     +  
     +  * [Scoped] `ServiceScopeAccessor` - A service for easily accessing slave `ServiceScope`s.
     +
     + Assertions:
     +  No service inside of `services` is allowed to directly or indirectly depend on itself.
     +  e.g. A depends on B which depends on A. This is not allowed.
     +
     + Params:
     +  services = Information about all of the services that can be provided.
     + ++/
    this(ServiceInfo[] services)
    {
        this._defaultScope = this.createScope();

        // I'm doing it this weird way to try and make the GC less angry.
        const EXTRA_SERVICES = 2;
        this._allServices.length                = services.length + EXTRA_SERVICES;
        this._allServices[0..services.length]   = services[0..$];
        this._allServices[services.length]      = ServiceInfo.asSingleton!ServiceProvider((ref _) => this); // Allow ServiceProvider to be injected.
        this._allServices[services.length + 1]  = ServiceInfo.asScoped!ServiceScopeAccessor((ref serviceScope) // Add service to allowed services to access their scope's... scope.
        {
            auto instance = this._scopes[serviceScope._index].accessor;
            if(instance !is null)
                return instance;

            instance = new ServiceScopeAccessor(serviceScope);
            this._scopes[serviceScope._index].accessor = instance;

            return instance;            
        });

        this.assertNoDependencyLoops();
        this.assertLifetimesAreCompatible();
    }

    public final
    {
        /++
         + Creates a new scope.
         +
         + Performance:
         +  For creating a scope, most of the performance cost is only made during the very first creation of a scope of a specific
         +  index. e.g. If you create scope[index=1], destroy it, then make another scope[index=1], the second scope should be made faster.
         +
         +  The speed difference is likely negligable either way though.
         +
         +  Most of the performance costs of making a scope will come from the creation of scoped services for each new scope, but those
         +  are only performed lazily anyway.
         +
         + Returns:
         +  A master `ServiceScope`.
         + ++/
        @safe
        ServiceScope createScope()
        {
            size_t index = 0;
            foreach(i; 0..ulong.sizeof * 8)
            {
                if(!this.isScopeInUse(i))
                {
                    index = i;
                    this.setScopeInUse(i, true);
                    break;
                }
            }

            if(this._scopes.length <= index)
                this._scopes.length = (index + 1);

            return ServiceScope(index, this, true);
        }
        ///
/*[NO_UNITTESTS_ALLOWED]
        unittest
        {
            import std.format : format;

            // Basic test to make sure the "in use" mask works properly.
            auto provider = new ServiceProvider(null);

            ServiceScope[3] scopes;
            foreach(i; 0..scopes.length)
            {
                scopes[i] = provider.createScope();
                assert(scopes[i]._index == i + 1, format("%s", scopes[i]._index));
            }

            provider.destroyScope(scopes[1]); // Index 2
            assert(scopes[1]._index == 0);
            assert(scopes[1]._provider is null);
            assert(provider._scopeInUseMasks[0] == 0b1011);

            scopes[1] = provider.createScope();
            assert(scopes[1]._index == 2);
            assert(provider._scopeInUseMasks[0] == 0b1111);
        }
*/

        /++
         + Destroys a scope.
         +
         + Behaviour:
         +  Currently, destroying a scope simply means that the `ServiceProvider` can reuse a small amount of memory
         +  whenever a new scope is created.
         +
         +  In the future I'd like to add more functionality, such as detecting scoped services that implement specific
         +  interfaces for things such as `IDisposableService`, `IReusableService`, etc.
         +
         + Params:
         +  serviceScope = The master `ServiceScope` representing the scope to destroy.
         + ++/
        void destroyScope(ref scope ServiceScope serviceScope)
        {
            assert(serviceScope._provider is this, "Attempting to destroy service scope who does not belong to this `ServiceProvider`.");
            assert(this.isScopeInUse(serviceScope._index), "Bug?");
            assert(serviceScope._isMasterReference, "Attempting to destroy service scope who is not the master reference for the scope. (Did this ServiceScope come from ServiceScopeAccessor?)");

            // For now, just clear the AA. Later on I'll want to add more behaviour though.
            this.setScopeInUse(serviceScope._index, false);
            this._scopes[serviceScope._index].instances.clear();

            serviceScope._index = 0;
            serviceScope._provider = null;
        }

        /++
         + Returns:
         +  The `ServiceInfo` for the given `baseType`, or `null` if the `baseType` is not known by this `ServiceProvider`.
         + ++/
        @safe
        Nullable!(const(ServiceInfo)) getServiceInfoForBaseType(TypeInfo baseType) const nothrow pure
        {
            foreach(service; this._allServices)
            {
                if(service._baseType is baseType)
                    return nullable(service);
            }

            return typeof(return).init;
        }

        /// ditto
        Nullable!(const(ServiceInfo)) getServiceInfoForBaseType(alias BaseType)() const
        if(ServiceInfo.isValidBaseType!BaseType)
        {
            return this.getServiceInfoForBaseType(typeid(BaseType));
        }
        ///
/*[NO_UNITTESTS_ALLOWED]
        unittest
        {
            static class C {}

            auto info = ServiceInfo.asScoped!C();
            const provider = new ServiceProvider([info]);

            assert(provider.getServiceInfoForBaseType!C() == info);
        }
*/

        @property @safe @nogc
        ref ServiceScope defaultScope() nothrow pure
        {
            return this._defaultScope;
        }
    }
}

/++
 + A static class containing functions to easily construct objects with Dependency Injection, or
 + execute functions where their parameters are injected via Dependency Injection.
 + ++/
static final class Injector
{
    import std.traits : ReturnType, isSomeFunction;

    public static final
    {
        /++
         + Executes a function where all of its parameters are retrieved from the given `ServiceScope`.
         +
         + Limitations:
         +  Currently you cannot provide your own values for parameters that shouldn't be injected.
         +
         + Behaviour:
         +  For parameters that are a `class` or `interface`, an attempt to retrieve them as a service from
         +  `services` is made. These parameters will be `null` if no service for them was found.
         +
         +  For parameters of other types, they are left as their `.init` value.
         +
         + Params:
         +  services = The `ServiceScope` allowing access to any services to be injected into the function call.
         +  func     = The function to execute.
         +
         + Returns:
         +  Whatever `func` returns.
         + ++/
        ReturnType!F execute(F)(ref ServiceScope services, F func)
        if(isSomeFunction!F)
        {
            import std.traits : Parameters;

            alias FuncParams = Parameters!F;
            FuncParams params;

            static foreach(i, ParamT; FuncParams)
            {{
                static if(is(ParamT == class) || is(ParamT == interface))
                    params[i] = services.getServiceOrNull!ParamT;
            }}

            static if(is(ReturnType!F == void))
                func(params);
            else
                return func(params);
        }
        ///
/*[NO_UNITTESTS_ALLOWED]
        unittest
        {
            static class AandB
            {
                int a = 1;
                int b = 3;
            }

            static int addAandB(AandB ab)
            {
                return ab.a + ab.b;
            }

            auto services = new ServiceProvider([ServiceInfo.asSingleton!AandB]);
            
            assert(Injector.execute(services.defaultScope, &addAandB) == 4);
        }
*/

        /++
         + Constructs a `class` or `struct` via Dependency Injection.
         +
         + Limitations:
         +  See `Injector.execute`.
         +
         +  There are no guard checks implemented to ensure services with incompatible lifetimes aren't being used together. However, `ServiceProvider` does contain
         +  a check for this, please refer to its documentation.
         +
         +  There are no guard checks implemented to block circular references between services. However, `ServiceProvider` does contain
         +  a check for this, please refer to its documentation.
         +
         + Behaviour:
         +  See `Injector.execute` for what values are injected into the ctor's parameters.
         +
         +  If the type has a normal ctor, then the result of `__traits(getMember, T, "__ctor")` is used as the constructor.
         +  Types with multiple ctors are undefined behaviour.
         +
         +  If the type contains a static function called `injectionCtor`, then that function takes priority over any normal ctor
         +  and will be used to construct the object. Types with multiple `injectionCtor`s are undefined behaviour.
         +
         +  If the type does not contain any of the above ctor functions then:
         +   
         +      * If the type is a class, `new T()` is used (if possible, otherwise compiler error).
         +
         +      * If the type is a `struct`, `T.init` is used.
         +
         + Params:
         +  services = The `ServiceScope` allowing access to any services to be injected into the newly constructed object.
         +
         + Returns:
         +  The newly constructed object.
         + ++/
        T construct(alias T)(ref ServiceScope services)
        if(is(T == class) || is(T == struct))
        {
            import std.traits : Parameters;

            alias Ctor = Injector.FindCtor!T;

            static if(Injector.isStaticFuncCtor!Ctor) // Special ctors like `injectionCtor`
            {
                alias CtorParams = Parameters!Ctor;
                return Injector.execute(services, (CtorParams params) => T.injectionCtor(params));
            }
            else static if(Injector.isBuiltinCtor!Ctor) // Normal ctor
            {
                alias CtorParams = Parameters!Ctor;

                static if(is(T == class))
                    return Injector.execute(services, (CtorParams params) => new T(params));
                else
                    return Injector.execute(services, (CtorParams params) => T(params));
            }
            else // NoValidCtor
            {
                static if(is(T == class))
                    return new T();
                else
                    return T.init;
            }
        }

        /// `FindCtor` will evaluate to this no-op function if it can't find a proper ctor.
        static void NoValidCtor(){}

        /++
         + Finds the most appropriate ctor for use with injection.
         +
         + Notes:
         +  Types that have multiple overloads of a ctor produce undefined behaviour.
         +
         +  You can use `Injector.isBuiltinCtor` and `Injector.isStaticFuncCtor` to determine what type of Ctor was chosen.
         +
         + Returns:
         +  Either the type's `__ctor`, the type's `injectionCtor`, or `NoValidCtor` if no appropriate ctor was found.
         + ++/
        template FindCtor(T)
        {
            static if(__traits(hasMember, T, "injectionCtor"))
                alias FindCtor = __traits(getMember, T, "injectionCtor");
            else static if(__traits(hasMember, T, "__ctor"))
                alias FindCtor = __traits(getMember, T, "__ctor");
            else
                alias FindCtor = NoValidCtor;
        }

        enum isBuiltinCtor(alias F)     = __traits(identifier, F) == "__ctor";
        enum isStaticFuncCtor(alias F)  = !isBuiltinCtor!F && __traits(identifier, F) != "NoValidCtor";
    }
}

// Testing transient services
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    static class Transient
    {
        int increment = 0;

        int getI()
        {
            return this.increment++;
        }
    }

    auto services = new ServiceProvider([ServiceInfo.asTransient!Transient]);
    
    auto serviceA = services.defaultScope.getServiceOrNull!Transient();
    auto serviceB = services.defaultScope.getServiceOrNull!Transient();

    assert(serviceA.getI() == 0);
    assert(serviceA.getI() == 1);
    assert(serviceB.getI() == 0);
}
*/

// Testing scoped services
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    static class Scoped
    {
        int increment = 0;

        int getI()
        {
            return this.increment++;
        }
    }

    auto services = new ServiceProvider([ServiceInfo.asScoped!Scoped]);
    auto scopeB   = services.createScope();

    auto serviceA1 = services.defaultScope.getServiceOrNull!Scoped();
    auto serviceA2 = services.defaultScope.getServiceOrNull!Scoped(); // So I can test that it's using the same one.
    auto serviceB  = scopeB.getServiceOrNull!Scoped();
    
    assert(serviceA1 is serviceA2, "Scoped didn't work ;(");
    assert(serviceA1.getI() == 0);
    assert(serviceA2.getI() == 1);
    assert(serviceB.getI() == 0);

    services.destroyScope(scopeB);

    scopeB   = services.createScope();
    serviceB = scopeB.getServiceOrNull!Scoped();
    assert(serviceB.getI() == 0);
}
*/

// Testing singleton services
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    static class Singleton
    {
        int increment = 0;

        int getI()
        {
            return this.increment++;
        }
    }

    auto services = new ServiceProvider([ServiceInfo.asSingleton!Singleton]);
    auto scopeB   = services.createScope();

    auto serviceA = services.defaultScope.getServiceOrNull!Singleton;
    auto serviceB = scopeB.getServiceOrNull!Singleton;

    assert(serviceA !is null && serviceA is serviceB);
    assert(serviceA.getI() == 0);
    assert(serviceB.getI() == 1);
}
*/

// Testing scope dtor behaviour
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    auto services = new ServiceProvider(null);
    auto scopeB = services.createScope();
    assert(scopeB._index == 1);

    // Test #1, seeing if setting a new value for a scope variable performs the dtor properly.
    {
        scopeB = services.createScope();
        assert(scopeB._index == 2);
        assert(services._scopeInUseMasks[0] == 0b101);
    }

    services.destroyScope(scopeB);

    // Test #2, seeing if going out of scope uses the dtor properly (it should if the first case works, but may as well add a test anyway :P)
    {
        auto scopedScope = services.createScope();
        assert(scopedScope._index == 1);

        scopeB = services.createScope();
        assert(scopeB._index == 2);
    }

    assert(services._scopeInUseMasks[0] == 0b101);
    scopeB = services.createScope();
    assert(scopeB._index == 1);
    assert(services._scopeInUseMasks[0] == 0b11);
}
*/

// Test ServiceProvider injection
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    auto services = new ServiceProvider(null);

    assert(services.defaultScope.getServiceOrNull!ServiceProvider() is services);
}
*/

// Test ServiceScopeAccessor
/*[NO_UNITTESTS_ALLOWED]
unittest
{
    auto services = new ServiceProvider(null);
    
    // Also test to make sure the slaveScope doesn't destroy the scope outright.
    {
        const slaveScope = services.defaultScope.getServiceOrNull!ServiceScopeAccessor().serviceScope;
        assert(slaveScope._provider is services);
        assert(slaveScope._index == 0);
        assert(!slaveScope._isMasterReference);
    }
    assert(services._scopeInUseMasks[0] == 0b1);

    // Test to make sure we only construct the accessor a single time per scope index.
    auto masterScope = services.createScope();
    assert(services._scopes[1].accessor is null);
    assert(masterScope.getServiceOrNull!ServiceScopeAccessor() !is null);
    assert(services._scopes[1].accessor !is null);

    auto accessor = masterScope.getServiceOrNull!ServiceScopeAccessor();
    services.destroyScope(masterScope);
    masterScope = services.createScope();
    assert(services._scopes[1].accessor is accessor);
}
*/
//[NO_MODULE_STATEMENTS_ALLOWED]module jaster.ioc;

//[CONTAINS_BLACKLISTED_IMPORT]public import jaster.ioc.depinject;
