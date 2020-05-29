/// Utilities to create ANSI coloured text.
module jaster.cli.ansi;

import std.traits : EnumMembers;

private enum AnsiColourType
{
    none,
    fourBit,
    eightBit,
    rgb
}

/++
 + An enumeration of standard 4-bit colours.
 +
 + These colours will have the widest support between platforms.
 + ++/
enum Ansi4Bit
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
    Ansi8BitColour eightBit;
    AnsiRgbColour  rgb;
}

private struct Ansi4BitColour
{
    Ansi4Bit colour;
}

private struct Ansi8BitColour
{
    ubyte colour;
}

private struct AnsiRgbColour
{
    ubyte r;
    ubyte g;
    ubyte b;
}

private struct AnsiColour
{
    AnsiColourType  type;
    AnsiColourUnion value;
    bool            isBg;

    string toString() const
    {
        import std.format : format;

        final switch(this.type) with(AnsiColourType)
        {
            case none: return null;
            case fourBit:
                auto value = cast(int)this.value.fourBit.colour;
                return "%s".format(this.isBg ? value + 10 : value);

            case eightBit:
                auto marker = (this.isBg) ? "48" : "38";
                auto value  = this.value.eightBit.colour;
                return "%s;5;%s".format(marker, value);

            case rgb:
                auto marker = (this.isBg) ? "48" : "38";
                auto value  = this.value.rgb;
                return "%s;2;%s;%s;%s".format(marker, value.r, value.g, value.b);
        }
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

/++
 + A struct used to compose together a piece of ANSI text.
 +
 + Notes:
 +  A reset command (`\033[0m`) is automatically appended, so you don't have to worry about that.
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
struct AnsiText
{
    import std.format : format;

    private
    {
        string        _cachedText;
        const(char)[] _text;
        AnsiColour    _fg;
        AnsiColour    _bg;
        AnsiTextFlags _flags;

        ref AnsiText setColour(T)(ref AnsiColour colour, T value) return
        {
            static if(is(T == Ansi4BitColour))
            {
                colour.type = AnsiColourType.fourBit;
                colour.value.fourBit = value;
            }
            else static if(is(T == Ansi8BitColour))
            {
                colour.type = AnsiColourType.eightBit;
                colour.value.eightBit = value;
            }
            else static if(is(T == AnsiRgbColour))
            {
                colour.type = AnsiColourType.rgb;
                colour.value.rgb = value;
            }
            else static assert(false);

            this._cachedText = null;
            return this;
        }

        ref AnsiText setColour4(ref AnsiColour colour, Ansi4Bit value) return
        {
            return this.setColour(colour, Ansi4BitColour(value));
        }

        ref AnsiText setColour8(ref AnsiColour colour, ubyte value) return
        {
            return this.setColour(colour, Ansi8BitColour(value));
        }

        ref AnsiText setColourRgb(ref AnsiColour colour, ubyte r, ubyte g, ubyte b) return
        {
            return this.setColour(colour, AnsiRgbColour(r, g, b));
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
    this(const(char)[] text)
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
    string toString()
    {
        import std.algorithm : joiner, filter;

        if(this._bg.type == AnsiColourType.none 
        && this._fg.type == AnsiColourType.none
        && this._flags   == AnsiTextFlags.none)
            return this._text.idup;

        if(this._cachedText !is null)
            return this._cachedText;

        // Find all 'components' that have been enabled
        string[2 + FLAG_COUNT] components; // fg + bg + all supported flags.
        size_t componentIndex;

        components[componentIndex++] = this._fg.type == AnsiColourType.none ? null : this._fg.toString();
        components[componentIndex++] = this._bg.type == AnsiColourType.none ? null : this._bg.toString();

        foreach(i; 0..FLAG_COUNT)
        {
            if((this._flags & (1 << i)) > 0)
                components[componentIndex++] = FLAG_AS_ANSI_CODE_MAP[i];
        }

        // Then join them together.
        this._cachedText = "\033[%sm%s\033[0m".format(
            components[].filter!(s => s !is null).joiner(";"), 
            cast(string)this._text // cast(string) is so format doesn't format as an array.
        ); 
        return this._cachedText;
    }

    /// Sets the foreground/background as a 4-bit colour. Widest supported option.
    ref AnsiText fg(Ansi4Bit fourBit) return          { return this.setColour4  (this._fg, fourBit);  }
    /// ditto
    ref AnsiText bg(Ansi4Bit fourBit) return          { return this.setColour4  (this._bg, fourBit);  }

    /// Sets the foreground/background as an 8-bit colour. Please see this image for reference: https://i.stack.imgur.com/KTSQa.png
    ref AnsiText fg(ubyte eightBit) return            { return this.setColour8  (this._fg, eightBit); }
    /// ditto
    ref AnsiText bg(ubyte eightBit) return            { return this.setColour8  (this._bg, eightBit); }

    /// Sets the forground/background as an RGB colour.
    ref AnsiText fg(ubyte r, ubyte g, ubyte b) return { return this.setColourRgb(this._fg, r, g, b);  }
    /// ditto
    ref AnsiText bg(ubyte r, ubyte g, ubyte b) return { return this.setColourRgb(this._bg, r, g, b);  }

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
}

/++
 + A helper UFCS function used to fluently convert any piece of text into an `AnsiText`.
 + ++/
AnsiText ansi(const char[] text)
{
    return AnsiText(text);
}
///
unittest
{
    assert("Hello".ansi.toString() == "Hello");
    assert("Hello".ansi.fg(Ansi4Bit.black).toString() == "\033[30mHello\033[0m");
    assert("Hello".ansi.bold.strike.bold(false).italic.toString() == "\033[3;9mHello\033[0m");
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