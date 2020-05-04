module jaster.cli.ansi;

enum AnsiColourType
{
    none,
    fourBit,
    eightBit,
    rgb
}

enum Ansi4Bit
{
    // To get Background code, just add 10
    Black           = 30,
    Red             = 31,
    Green           = 32,
    Yellow          = 33,
    Blue            = 34,
    Magenta         = 35,
    Cyan            = 36,
    White           = 37,
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

struct AnsiColour
{
    AnsiColourType  type;
    AnsiColourUnion value;
    bool            isBg;

    string toString()
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

struct AnsiText
{
    import std.format : format;

    private
    {
        const char[] _text;
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

    this(const char[] text)
    {
        this._text = text;
        this._bg.isBg = true;
    }

    string toString()
    {
        auto semicolon = (this._bg.type == AnsiColourType.none || this._fg.type == AnsiColourType.none)
                         ? null
                         : ";";
        return "\033[%s%s%sm%s\033[0m".format(this._fg, semicolon, this._bg, cast(string)this._text); // cast(string) is so format doesn't format as an array.
    }

    ref AnsiText fg(Ansi4Bit fourBit)         { return this.setColour4  (this._fg, fourBit);  }
    ref AnsiText fg(ubyte eightBit)           { return this.setColour8  (this._fg, eightBit); }
    ref AnsiText fg(ubyte r, ubyte g, ubyte b){ return this.setColourRgb(this._fg, r, g, b);  }
    ref AnsiText bg(Ansi4Bit fourBit)         { return this.setColour4  (this._bg, fourBit);  }
    ref AnsiText bg(ubyte eightBit)           { return this.setColour8  (this._bg, eightBit); }
    ref AnsiText bg(ubyte r, ubyte g, ubyte b){ return this.setColourRgb(this._bg, r, g, b);  }
}

AnsiText ansi(const char[] text)
{
    return AnsiText(text);
}