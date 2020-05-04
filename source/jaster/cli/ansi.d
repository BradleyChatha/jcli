/// Utilities to create ANSI coloured text.
module jaster.cli.ansi;

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
    Black           = 30,
    Red             = 31,
    Green           = 32,
    /// On Powershell, this is displayed as a very white colour.
    Yellow          = 33,
    Blue            = 34,
    Magenta         = 35,
    Cyan            = 36,
    /// More gray than true white, use `BrightWhite` for true white.
    White           = 37,
    /// Grayer than `White`.
    BrightBlack     = 90,
    BrightRed       = 91,
    BrightGreen     = 92,
    BrightYellow    = 93,
    BrightBlue      = 94,
    BrightMagenta   = 95,
    BrightCyan      = 96,
    BrightWhite     = 97
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
        char[]       _text;
        AnsiColour   _fg;
        AnsiColour   _bg;

        ref AnsiText setColour(T)(ref AnsiColour colour, T value)
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

            return this;
        }

        ref AnsiText setColour4(ref AnsiColour colour, Ansi4Bit value)
        {
            return this.setColour(colour, Ansi4BitColour(value));
        }

        ref AnsiText setColour8(ref AnsiColour colour, ubyte value)
        {
            return this.setColour(colour, Ansi8BitColour(value));
        }

        ref AnsiText setColourRgb(ref AnsiColour colour, ubyte r, ubyte g, ubyte b)
        {
            return this.setColour(colour, AnsiRgbColour(r, g, b));
        }
    }

    ///
    this(const char[] text)
    {
        this._text = cast(char[])text; // WE CAST AWAY CONST because otherwise the struct becomes immovable, it is still effectively const though.
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
    string toString() const
    {
        if(this._bg.type == AnsiColourType.none && this._fg.type == AnsiColourType.none)
            return this._text.idup;

        auto semicolon = (this._bg.type == AnsiColourType.none || this._fg.type == AnsiColourType.none)
                         ? null
                         : ";";
        return "\033[%s%s%sm%s\033[0m".format(this._fg, semicolon, this._bg, cast(string)this._text); // cast(string) is so format doesn't format as an array.
    }

    /// Sets the foreground/background as a 4-bit colour. Widest supported option.
    ref AnsiText fg(Ansi4Bit fourBit)         { return this.setColour4  (this._fg, fourBit);  }
    /// ditto
    ref AnsiText bg(Ansi4Bit fourBit)         { return this.setColour4  (this._bg, fourBit);  }

    /// Sets the foreground/background as an 8-bit colour. Please see this image for reference: https://i.stack.imgur.com/KTSQa.png
    ref AnsiText fg(ubyte eightBit)           { return this.setColour8  (this._fg, eightBit); }
    /// ditto
    ref AnsiText bg(ubyte eightBit)           { return this.setColour8  (this._bg, eightBit); }

    /// Sets the forground/background as an RGB colour.
    ref AnsiText fg(ubyte r, ubyte g, ubyte b){ return this.setColourRgb(this._fg, r, g, b);  }
    /// ditto
    ref AnsiText bg(ubyte r, ubyte g, ubyte b){ return this.setColourRgb(this._bg, r, g, b);  }
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
    assert("Hello".ansi.fg(Ansi4Bit.Black).toString() == "\033[30mHello\033[0m");
}