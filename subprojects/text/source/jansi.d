/// Utilities for writing and reading ANSI styled text.
module jansi;

import std.range : isOutputRange;
import std.typecons : Flag;

/+++ CONSTANTS +++/

version(JANSI_BetterC)
{
    private enum BetterC = true;
}
else
{
    version(D_BetterC)
    {
        private enum BetterC = true;
    }
    else
    {
        private enum BetterC = false;
    }
}

/// Used to determine if an `AnsiColour` is a background or foreground colour.
alias IsBgColour = Flag!"isBg";

/// Used by certain functions to determine if they should only output an ANSI sequence, or output their entire sequence + data.
alias AnsiOnly = Flag!"ansiOnly";

/// An 8-bit ANSI colour - an index into the terminal's colour palette.
alias Ansi8BitColour = ubyte;

/// The string that starts an ANSI command sequence.
immutable ANSI_CSI                = "\033[";

/// The character that delimits ANSI parameters.
immutable ANSI_SEPARATOR          = ';';

/// The character used to denote that the sequence is an SGR sequence.
immutable ANSI_COLOUR_END         = 'm';

/// The sequence used to reset all styling.
immutable ANSI_COLOUR_RESET       = ANSI_CSI~"0"~ANSI_COLOUR_END;

/// The amount to increment an `Ansi4BitColour` by in order to access the background version of the colour.
immutable ANSI_FG_TO_BG_INCREMENT = 10;

/+++ COLOUR TYPES +++/

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

/++
 + Contains a 3-byte, RGB colour.
 + ++/
@safe
struct AnsiRgbColour
{
    union
    {
        /// The RGB components as an array.
        ubyte[3] components;

        struct {
            /// The red component.
            ubyte r;

            /// The green component.
            ubyte g;

            /// The blue component.
            ubyte b;
        }
    }

    @safe @nogc nothrow pure:

    /++
     + Construct this colour from 3 ubyte components, in RGB order.
     +
     + Params:
     +  components = The components to use.
     + ++/
    this(ubyte[3] components)
    {
        this.components = components;
    }

    /++
     + Construct this colour from the 3 provided ubyte components.
     +
     + Params:
     +  r = The red component.
     +  g = The green component.
     +  b = The blue component.
     + ++/
    this(ubyte r, ubyte g, ubyte b)
    {
        this.r = r;
        this.g = g;
        this.b = b;
    }
}

private union AnsiColourUnion
{
    Ansi4BitColour fourBit;
    Ansi8BitColour eightBit;
    AnsiRgbColour  rgb;
}

/++
 + Contains any type of ANSI colour and provides the ability to create a valid SGR command to set the foreground/background.
 +
 + This struct overloads `opAssign` allowing easy assignment from `Ansi4BitColour`, `Ansi8BitColour`, `AnsiRgbColour`, and any user-defined type
 + that satisfies `isUserDefinedRgbType`.
 + ++/
@safe
struct AnsiColour
{
    private static immutable FG_MARKER        = "38";
    private static immutable BG_MARKER        = "48";
    private static immutable EIGHT_BIT_MARKER = '5';
    private static immutable RGB_MARKER       = '2';

    /++
     + The maximum amount of characters any singular `AnsiColour` sequence may use.
     +
     + This is often used to create a static array to temporarily, and without allocation, store the sequence for an `AnsiColour`.
     + ++/
    enum MAX_CHARS_NEEDED = "38;2;255;255;255".length;

    private
    {
        AnsiColourUnion _value;
        AnsiColourType  _type;
        IsBgColour      _isBg;

        @safe @nogc nothrow
        this(IsBgColour isBg) pure
        {
            this._isBg = isBg;
        }
    }

    /// A variant of `.init` that is used for background colours.
    static immutable bgInit = AnsiColour(IsBgColour.yes);

    /+++ CTORS AND PROPERTIES +++/
    @safe @nogc nothrow pure
    {
        // Seperate, non-templated constructors as that's a lot more documentation-generator-friendly.

        /++
         + Construct a 4-bit colour.
         +
         + Params:
         +  colour = The 4-bit colour to use.
         +  isBg   = Determines whether this colour sets the foreground or the background.
         + ++/
        this(Ansi4BitColour colour, IsBgColour isBg = IsBgColour.no)
        {
            this = colour;
            this._isBg = isBg;
        }
        
        /++
         + Construct an 8-bit colour.
         +
         + Params:
         +  colour = The 8-bit colour to use.
         +  isBg   = Determines whether this colour sets the foreground or the background.
         + ++/
        this(Ansi8BitColour colour, IsBgColour isBg = IsBgColour.no)
        {
            this = colour;
            this._isBg = isBg;
        }

        /++
         + Construct an RGB colour.
         +
         + Params:
         +  colour = The RGB colour to use.
         +  isBg   = Determines whether this colour sets the foreground or the background.
         + ++/
        this(AnsiRgbColour colour, IsBgColour isBg = IsBgColour.no)
        {
            this = colour;
            this._isBg = isBg;
        }

        /++
         + Construct an RGB colour.
         +
         + Params:
         +  r      = The red component.
         +  g      = The green component.
         +  b      = The blue component.
         +  isBg   = Determines whether this colour sets the foreground or the background.
         + ++/
        this(ubyte r, ubyte g, ubyte b, IsBgColour isBg = IsBgColour.no)
        {
            this(AnsiRgbColour(r, g, b), isBg);
        }

        /++
         + Construct an RGB colour.
         +
         + Params:
         +  colour = The user-defined colour type that satisfies `isUserDefinedRgbType`.
         +  isBg   = Determines whether this colour sets the foreground or the background.
         + ++/
        this(T)(T colour, IsBgColour isBg = IsBgColour.no)
        if(isUserDefinedRgbType!T)
        {
            this = colour;
            this._isBg = isBg;
        }

        /++
         + Allows direct assignment from any type that can also be used in any of this struct's ctors.
         + ++/
        auto opAssign(T)(T colour) return
        if(!is(T == typeof(this)))
        {
            static if(is(T == Ansi4BitColour))
            {
                this._value.fourBit = colour;
                this._type = AnsiColourType.fourBit;
            }
            else static if(is(T == Ansi8BitColour))
            {
                this._value.eightBit = colour;
                this._type = AnsiColourType.eightBit;
            }
            else static if(is(T == AnsiRgbColour))
            {
                this._value.rgb = colour;
                this._type = AnsiColourType.rgb;
            }
            else static if(isUserDefinedRgbType!T)
            {
                this = colour.to!AnsiColour();
            }
            else static assert(false, "Cannot implicitly convert "~T.stringof~" into an AnsiColour.");
            
            return this;
        }

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
        Ansi4BitColour asFourBit() const
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
        ubyte asEightBit() const
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
        AnsiRgbColour asRgb() const
        {
            assert(this.type == AnsiColourType.rgb);
            return this._value.rgb;
        }
    }
    
    /+++ OUTPUT +++/

    static if(!BetterC)
    {
        /++
         + [Not enabled in -betterC] Converts this `AnsiColour` into a GC-allocated sequence string.
         +
         + See_Also:
         +  `toSequence`
         + ++/
        @trusted nothrow
        string toString() const
        {
            import std.exception : assumeUnique;

            auto chars = new char[MAX_CHARS_NEEDED];
            return this.toSequence(chars[0..MAX_CHARS_NEEDED]).assumeUnique;
        }
        ///
        @("AnsiColour.toString")
        unittest
        {
            assert(AnsiColour(255, 128, 64).toString() == "38;2;255;128;64");
        }
    }

    /++
     + Creates an ANSI SGR command that either sets the foreground, or the background (`isBg`) to the colour
     + stored inside of this `AnsiColour`.
     +
     + Please note that the CSI (`ANSI_CSI`/`\033[`) and the SGR marker (`ANSI_COLOUR_END`/`m`) are not included
     + in this output.
     +
     + Notes:
     +  Any characters inside of `buffer` that are not covered by the returned slice, are left unmodified.
     +
     +  If this colour hasn't been initialised or assigned a value, then the returned value is simply `null`.
     +
     + Params:
     +  buffer = The statically allocated buffer used to store the result of this function.
     +
     + Returns:
     +  A slice into `buffer` that contains the output of this function.
     + ++/
    @safe @nogc
    char[] toSequence(ref return char[MAX_CHARS_NEEDED] buffer) nothrow const
    {
        if(this.type == AnsiColourType.none)
            return null;

        size_t cursor;

        void numIntoBuffer(ubyte num)
        {
            char[3] text;
            const slice = numToStrBase10(text[0..3], num);
            buffer[cursor..cursor + slice.length] = slice[];
            cursor += slice.length;
        }

        if(this.type != AnsiColourType.fourBit)
        {
            // 38; or 48;
            auto marker = (this.isBg) ? BG_MARKER : FG_MARKER;
            buffer[cursor..cursor+2] = marker[0..$];
            cursor += 2;
            buffer[cursor++] = ANSI_SEPARATOR;
        }

        // 4bit, 5;8bit, or 2;r;g;b
        final switch(this.type) with(AnsiColourType)
        {
            case none: assert(false);
            case fourBit: 
                numIntoBuffer(cast(ubyte)((this.isBg) ? this._value.fourBit + 10 : this._value.fourBit)); 
                break;

            case eightBit:
                buffer[cursor++] = EIGHT_BIT_MARKER;
                buffer[cursor++] = ANSI_SEPARATOR;
                numIntoBuffer(this._value.eightBit);
                break;
                
            case rgb:
                buffer[cursor++] = RGB_MARKER;
                buffer[cursor++] = ANSI_SEPARATOR;

                numIntoBuffer(this._value.rgb.r); 
                buffer[cursor++] = ANSI_SEPARATOR;
                numIntoBuffer(this._value.rgb.g); 
                buffer[cursor++] = ANSI_SEPARATOR;
                numIntoBuffer(this._value.rgb.b); 
                break;
        }

        return buffer[0..cursor];
    }
    ///
    @("AnsiColour.toSequence(char[])")
    unittest
    {
        char[AnsiColour.MAX_CHARS_NEEDED] buffer;

        void test(string expected, AnsiColour colour)
        {
            const slice = colour.toSequence(buffer);
            assert(slice == expected);
        }

        test("32",               AnsiColour(Ansi4BitColour.green));
        test("42",               AnsiColour(Ansi4BitColour.green, IsBgColour.yes));
        test("38;5;1",           AnsiColour(Ansi8BitColour(1)));
        test("48;5;1",           AnsiColour(Ansi8BitColour(1), IsBgColour.yes));
        test("38;2;255;255;255", AnsiColour(255, 255, 255));
        test("48;2;255;128;64",  AnsiColour(255, 128, 64, IsBgColour.yes));
    }
}

/+++ MISC TYPES +++/

/++
 + A list of styling options provided by ANSI SGR.
 +
 + As a general rule of thumb, assume most of these won't work inside of a Windows command prompt (unless it's the new Windows Terminal).
 + ++/
enum AnsiSgrStyle
{
    none      = 0,
    bold      = 1,
    dim       = 2,
    italic    = 3,
    underline = 4,
    slowBlink = 5,
    fastBlink = 6,
    invert    = 7,
    strike    = 9
}

private template getMaxSgrStyleCharCount()
{
    import std.traits : EnumMembers;

    // Can't even use non-betterC features in CTFE, so no std.conv.to!string :(
    size_t numberOfChars(int num)
    {
        size_t amount;

        do
        {
            amount++;
            num /= 10;
        } while(num > 0);

        return amount;
    }

    size_t calculate()
    {
        size_t amount;
        static foreach(member; EnumMembers!AnsiSgrStyle)
            amount += numberOfChars(cast(int)member) + 1; // + 1 for the semi-colon after.

        return amount;
    }

    enum getMaxSgrStyleCharCount = calculate();
}

/++
 + Contains any number of styling options from `AnsiStyleSgr`, and provides the ability to generate
 + an ANSI SGR command to apply all of the selected styling options.
 + ++/
@safe
struct AnsiStyle
{
    /++
     + The maximum amount of characters any singular `AnsiStyle` sequence may use.
     +
     + This is often used to create a static array to temporarily, and without allocation, store the sequence for an `AnsiStyle`.
     + ++/
    enum MAX_CHARS_NEEDED = getMaxSgrStyleCharCount!();

    private
    {
        ushort _sgrBitmask; // Each set bit index corresponds to the value from `AnsiSgrStyle`.

        @safe @nogc nothrow
        int sgrToBit(AnsiSgrStyle style) pure const
        {
            return 1 << (cast(int)style);
        }

        @safe @nogc nothrow
        void setSgrBit(bool setOrUnset)(AnsiSgrStyle style) pure
        {
            static if(setOrUnset)
                this._sgrBitmask |= this.sgrToBit(style);
            else
                this._sgrBitmask &= ~this.sgrToBit(style);
        }

        @safe @nogc nothrow
        bool getSgrBit(AnsiSgrStyle style) pure const
        {
            return (this._sgrBitmask & this.sgrToBit(style)) > 0;
        }
    }

    // Seperate functions for better documentation generation.
    //
    // Tedious, as this otherwise could've all been auto-generated.
    /+++ SETTERS +++/
    @safe @nogc nothrow pure
    {
        /// Removes all styling from this `AnsiStyle`.
        AnsiStyle reset() return
        {
            this._sgrBitmask = 0;
            return this;
        }

        /++
         + Enables/Disables a certain styling option.
         +
         + Params:
         +  style  = The styling option to enable/disable.
         +  enable = If true, enable the option. If false, disable it.
         +
         + Returns:
         +  `this` for chaining.
         + ++/
        AnsiStyle set(AnsiSgrStyle style, bool enable) return
        {
            if(enable)
                this.setSgrBit!true(style);
            else
                this.setSgrBit!false(style);
            return this;
        }

        ///
        AnsiStyle bold(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.bold); return this; }
        ///
        AnsiStyle dim(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.dim); return this; }
        ///
        AnsiStyle italic(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.italic); return this; }
        ///
        AnsiStyle underline(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.underline); return this; }
        ///
        AnsiStyle slowBlink(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.slowBlink); return this; }
        ///
        AnsiStyle fastBlink(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.fastBlink); return this; }
        ///
        AnsiStyle invert(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.invert); return this; }
        ///
        AnsiStyle strike(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.strike); return this; }
    }

    /+++ GETTERS +++/
    @safe @nogc nothrow pure const
    {
        /++
         + Get the status of a certain styling option.
         +
         + Params:
         +  style = The styling option to get.
         +
         + Returns:
         +  `true` if the styling option is enabled, `false` otherwise.
         + ++/
        bool get(AnsiSgrStyle style)
        {
            return this.getSgrBit(style);
        }
        
        ///
        bool bold() { return this.getSgrBit(AnsiSgrStyle.bold); }
        ///
        bool dim() { return this.getSgrBit(AnsiSgrStyle.dim); }
        ///
        bool italic() { return this.getSgrBit(AnsiSgrStyle.italic); }
        ///
        bool underline() { return this.getSgrBit(AnsiSgrStyle.underline); }
        ///
        bool slowBlink() { return this.getSgrBit(AnsiSgrStyle.slowBlink); }
        ///
        bool fastBlink() { return this.getSgrBit(AnsiSgrStyle.fastBlink); }
        ///
        bool invert() { return this.getSgrBit(AnsiSgrStyle.invert); }
        ///
        bool strike() { return this.getSgrBit(AnsiSgrStyle.strike); }
    }

    /+++ OUTPUT +++/

    static if(!BetterC)
    {
        /++
         + [Not enabled in -betterC] Converts this `AnsiStyle` into a GC-allocated sequence string.
         +
         + See_Also:
         +  `toSequence`
         + ++/
        @trusted nothrow
        string toString() const
        {
            import std.exception : assumeUnique;

            auto chars = new char[MAX_CHARS_NEEDED];
            return this.toSequence(chars[0..MAX_CHARS_NEEDED]).assumeUnique;
        }
    }

    /++
     + Creates an ANSI SGR command that enables all of the desired styling options, while leaving all of the other options unchanged.
     +
     + Please note that the CSI (`ANSI_CSI`/`\033[`) and the SGR marker (`ANSI_COLOUR_END`/`m`) are not included
     + in this output.
     +
     + Notes:
     +  Any characters inside of `buffer` that are not covered by the returned slice, are left unmodified.
     +
     +  If this colour hasn't been initialised or assigned a value, then the returned value is simply `null`.
     +
     + Params:
     +  buffer = The statically allocated buffer used to store the result of this function.
     +
     + Returns:
     +  A slice into `buffer` that contains the output of this function.
     + ++/
    @safe @nogc
    char[] toSequence(ref return char[MAX_CHARS_NEEDED] buffer) nothrow const
    {
        import std.traits : EnumMembers;

        if(this._sgrBitmask == 0)
            return null;

        size_t cursor;
        void numIntoBuffer(uint num)
        {
            char[10] text;
            const slice = numToStrBase10(text[0..$], num);
            buffer[cursor..cursor + slice.length] = slice[];
            cursor += slice.length;
        }

        bool isFirstValue = true;
        static foreach(flag; EnumMembers!AnsiSgrStyle)
        {{
            if(this.getSgrBit(flag))
            {
                if(!isFirstValue)
                    buffer[cursor++] = ANSI_SEPARATOR;
                isFirstValue = false;

                numIntoBuffer(cast(uint)flag);
            }
        }}

        return buffer[0..cursor];
    }
    ///
    @("AnsiStyle.toSequence(char[])")
    unittest
    {
        static if(!BetterC)
        {
            char[AnsiStyle.MAX_CHARS_NEEDED] buffer;
            
            void test(string expected, AnsiStyle style)
            {
                const slice = style.toSequence(buffer);
                assert(slice == expected, "Got '"~slice~"' wanted '"~expected~"'");
            }

            test("", AnsiStyle.init);
            test("1;2;3", AnsiStyle.init.bold.dim.italic);
        }
    }
}

/+++ DATA WITH COLOUR TYPES +++/

/++
 + Contains an `AnsiColour` for the foreground, an `AnsiColour` for the background, and an `AnsiStyle` for additional styling,
 + and provides the ability to create an ANSI SGR command to set the foreground, background, and overall styling of the terminal.
 +
 + A.k.a This is just a container over two `AnsiColour`s and an `AnsiStyle`.
 + ++/
@safe
struct AnsiStyleSet
{
    /++
     + The maximum amount of characters any singular `AnsiStyle` sequence may use.
     +
     + This is often used to create a static array to temporarily, and without allocation, store the sequence for an `AnsiStyle`.
     + ++/
    enum MAX_CHARS_NEEDED = (AnsiColour.MAX_CHARS_NEEDED * 2) + AnsiStyle.MAX_CHARS_NEEDED;

    private AnsiColour _fg;
    private AnsiColour _bg;
    private AnsiStyle _style;

    // As usual, functions are manually made for better documentation.

    /+++ SETTERS +++/
    @safe @nogc nothrow
    {
        ///
        AnsiStyleSet fg(AnsiColour colour) return { this._fg = colour; this._fg.isBg = IsBgColour.no; return this; }
        ///
        AnsiStyleSet fg(Ansi4BitColour colour) return { return this.fg(AnsiColour(colour)); }
        ///
        AnsiStyleSet fg(Ansi8BitColour colour) return { return this.fg(AnsiColour(colour)); }
        ///
        AnsiStyleSet fg(AnsiRgbColour colour) return { return this.fg(AnsiColour(colour)); }

        ///
        AnsiStyleSet bg(AnsiColour colour) return { this._bg = colour; this._bg.isBg = IsBgColour.yes; return this; }
        ///
        AnsiStyleSet bg(Ansi4BitColour colour) return { return this.bg(AnsiColour(colour)); }
        ///
        AnsiStyleSet bg(Ansi8BitColour colour) return { return this.bg(AnsiColour(colour)); }
        ///
        AnsiStyleSet bg(AnsiRgbColour colour) return { return this.bg(AnsiColour(colour)); }
        ///

        ///
        AnsiStyleSet style(AnsiStyle style) return { this._style = style; return this; }
    }

    /+++ GETTERS +++/
    @safe @nogc nothrow const
    {
        ///
        AnsiColour fg() { return this._fg; }
        ///
        AnsiColour bg() { return this._bg; }
        ///
        AnsiStyle style() { return this._style; }
    }

    /+++ OUTPUT ++/
    /++
     + Creates an ANSI SGR command that sets the foreground colour, sets the background colour,
     + and enables all of the desired styling options, while leaving all of the other options unchanged.
     +
     + Please note that the CSI (`ANSI_CSI`/`\033[`) and the SGR marker (`ANSI_COLOUR_END`/`m`) are not included
     + in this output.
     +
     + Notes:
     +  Any characters inside of `buffer` that are not covered by the returned slice, are left unmodified.
     +
     +  If this colour hasn't been initialised or assigned a value, then the returned value is simply `null`.
     +
     + Params:
     +  buffer = The statically allocated buffer used to store the result of this function.
     +
     + Returns:
     +  A slice into `buffer` that contains the output of this function.
     + ++/
    @safe @nogc
    char[] toSequence(ref return char[MAX_CHARS_NEEDED] buffer) nothrow const
    {
        size_t cursor;

        char[AnsiColour.MAX_CHARS_NEEDED] colour;
        char[AnsiStyle.MAX_CHARS_NEEDED] style;

        auto slice = this._fg.toSequence(colour);
        buffer[cursor..cursor + slice.length] = slice[];
        cursor += slice.length;

        slice = this._bg.toSequence(colour);
        if(slice.length > 0 && cursor > 0)
            buffer[cursor++] = ANSI_SEPARATOR;
        buffer[cursor..cursor + slice.length] = slice[];
        cursor += slice.length;

        slice = this.style.toSequence(style);
        if(slice.length > 0 && cursor > 0)
            buffer[cursor++] = ANSI_SEPARATOR;
        buffer[cursor..cursor + slice.length] = slice[];
        cursor += slice.length;

        return buffer[0..cursor];
    }
    ///
    @("AnsiStyleSet.toSequence")
    unittest
    {
        char[AnsiStyleSet.MAX_CHARS_NEEDED] buffer;

        void test(string expected, AnsiStyleSet ch)
        {
            auto slice = ch.toSequence(buffer);
            assert(slice == expected, "Got '"~slice~"' expected '"~expected~"'");
        }

        test("", AnsiStyleSet.init);
        test(
            "32;48;2;255;128;64;1;4", 
            AnsiStyleSet.init
                    .fg(Ansi4BitColour.green)
                    .bg(AnsiRgbColour(255, 128, 64))
                    .style(AnsiStyle.init.bold.underline)
        );
    }
}

/++
 + An enumeration used by an `AnsiText` implementation to describe any special features that `AnsiText` needs to mold
 + itself around.
 + ++/
enum AnsiTextImplementationFeatures
{
    /// Supports at least `.put`, `.toSink`, `char[] .newSlice`, and allows `AnsiText` to handle the encoding.
    basic = 0, 
}

/++
 + A lightweight alternative to `AnsiText` which only supports a singular coloured string, at the cost
 + of removing most of the other complexity & dynamic allocation needs of `AnsiText`.
 +
 + If you only need to style your string in one certain way, or want to avoid `AnsiText` altogether, then this struct
 + is the way to go.
 +
 + Usage_(Manually):
 +  First, retrieve and the ANSI styling sequence via `AnsiTextLite.toFullStartSequence` and output it.
 +
 +  Second, output `AnsiTextLite.text`.
 +
 +  Finally, and optionally, retrieve the ANSI reset sequence via `AnsiTextLite.toFullEndSequence` and output it.
 +
 + Usage_(Range):
 +  Call `AnsiTextLite.toRange` to get the range, please read its documentation as it is important (it'll return slices to stack-allocated memory).
 +
 + Usage_(GC):
 +  If you're not compiling under `-betterc`, then `AnsiTextLite.toString()` will provide you with a GC-allocated string containing:
 +  the start ANSI sequence; the text to display; and the end ANSI sequence. i.e. A string that is just ready to be printed.
 +
 +  This struct also implements the sink-based version of `toString`, which means that when used directly with things like `writeln`, this struct
 +  is able to avoid allocations (unless the sink itself allocates). See the unittest for an example.
 +
 + See_Also:
 +  `ansi` for fluent creation of an `AnsiTextLite`.
 +
 +  This struct's unittest for an example of usage.
 + ++/
struct AnsiTextLite
{
    /++
     + The maximum amount of chars required by the start sequence of an `AnsiTextLite` (`toFullStartSequence`).
     + ++/
    enum MAX_CHARS_NEEDED = AnsiStyleSet.MAX_CHARS_NEEDED + ANSI_CSI.length + 1; // + 1 for the ANSI_COLOUR_END

    /// The text to output.
    const(char)[] text;
    
    /// The styling to apply to the text.
    AnsiStyleSet styleSet;

    /+++ SETTERS +++/
    // TODO: Should probably make a mixin template for this, but I need to see how the documentation generators handle that.
    //       I also can't just do an `alias this`, as otherwise the style functions wouldn't return `AnsiTextLite`, but instead `AnsiStyleSet`.
    //       Or just suck it up and make some of the setters templatised, much to the dismay of documentation.
    @safe @nogc nothrow
    {
        ///
        AnsiTextLite fg(AnsiColour colour) return { this.styleSet.fg = colour; this.styleSet.fg.isBg = IsBgColour.no; return this; }
        ///
        AnsiTextLite fg(Ansi4BitColour colour) return { return this.fg(AnsiColour(colour)); }
        ///
        AnsiTextLite fg(Ansi8BitColour colour) return { return this.fg(AnsiColour(colour)); }
        ///
        AnsiTextLite fg(AnsiRgbColour colour) return { return this.fg(AnsiColour(colour)); }

        ///
        AnsiTextLite bg(AnsiColour colour) return { this.styleSet.bg = colour; this.styleSet.bg.isBg = IsBgColour.yes; return this; }
        ///
        AnsiTextLite bg(Ansi4BitColour colour) return { return this.bg(AnsiColour(colour)); }
        ///
        AnsiTextLite bg(Ansi8BitColour colour) return { return this.bg(AnsiColour(colour)); }
        ///
        AnsiTextLite bg(AnsiRgbColour colour) return { return this.bg(AnsiColour(colour)); }
        ///

        ///
        AnsiTextLite style(AnsiStyle style) return { this.styleSet.style = style; return this; }
    }

    /+++ GETTERS +++/
    @safe @nogc nothrow const
    {
        ///
        AnsiColour fg() { return this.styleSet.fg; }
        ///
        AnsiColour bg() { return this.styleSet.bg; }
        ///
        AnsiStyle style() { return this.styleSet.style; }
    }

    @safe @nogc nothrow const
    {
        /++
         + Populates the given buffer with the full ANSI sequence needed to enable the styling
         + defined within this `AnsiTextLite`
         +
         + Unlike the usual `toSequence` functions, this function includes the `ANSI_CSI` and `ANSI_COLOUR_END` markers,
         + meaning the output from this function is ready to be printed as-is.
         +
         + Do note that this function doesn't insert a null-terminator, so if you're using anything based on C strings, you need
         + to insert that yourself.
         +
         + Notes:
         +  Any parts of the `buffer` that are not populated by this function are left untouched.
         +
         + Params:
         +  buffer = The buffer to populate.
         +
         + Returns:
         +  The slice of `buffer` that has been populated.
         + ++/
        char[] toFullStartSequence(ref return char[MAX_CHARS_NEEDED] buffer)
        {
            size_t cursor;

            buffer[0..ANSI_CSI.length] = ANSI_CSI[];
            cursor += ANSI_CSI.length;

            char[AnsiStyleSet.MAX_CHARS_NEEDED] styleBuffer;
            const styleSlice = this.styleSet.toSequence(styleBuffer);
            buffer[cursor..cursor+styleSlice.length] = styleSlice[];
            cursor += styleSlice.length;

            buffer[cursor++] = ANSI_COLOUR_END;

            return buffer[0..cursor];
        }

        /++
         + Returns:
         +  The end ANSI sequence for `AnsiTextLite`, which is simply a statically allocated version of the `ANSI_COLOUR_RESET` constant.
         + ++/
        char[ANSI_COLOUR_RESET.length] toFullEndSequence()
        {
            typeof(return) buffer;
            buffer[0..$] = ANSI_COLOUR_RESET[];
            return buffer;
        }

        /++
         + Provides a range that returns, in this order: The start sequence (`.toFullStartSequence`); the output text (`.text`),
         + and finally the end sequence (`.toFullEndSequence`).
         +
         + This range is $(B weakly-safe) as it $(B returns slices to stack memory) so please ensure that $(B any returned slices don't outlive the origin range object).
         +
         + Please also note that non of the returned slices contain null terminators.
         +
         + Returns:
         +  An Input Range that returns all the slices required to correctly display this `AnsiTextLite` onto a console.
         + ++/
        auto toRange()
        {
            static struct Range
            {
                char[MAX_CHARS_NEEDED] start;
                const(char)[] middle;
                char[ANSI_COLOUR_RESET.length] end;
                char[] startSlice;

                size_t sliceCount;

                @safe @nogc nothrow:

                bool empty()
                {
                    return this.sliceCount >= 3;
                }

                void popFront()
                {
                    this.sliceCount++;
                }

                @trusted
                const(char)[] front() return
                {
                    switch(sliceCount)
                    {
                        case 0: return this.startSlice;
                        case 1: return this.middle;
                        case 2: return this.end[0..$];
                        default: assert(false, "Cannot use empty range.");
                    }   
                }
            }

            Range r;
            r.startSlice = this.toFullStartSequence(r.start);
            r.middle = this.text;
            r.end = this.toFullEndSequence();

            return r;
        }
    }

    static if(!BetterC)
    /++
     + Notes:
     +  This struct implements the sink-based `toString` which performs no allocations, so the likes of `std.stdio.writeln` will
     +  automatically use the sink-based version if you pass this struct to it directly.
     +
     + Returns: 
     +  A GC-allocated string containing this `AnsiTextLite` as an ANSI-encoded string, ready for printing.
     + ++/
    @trusted nothrow // @trusted due to .assumeUnique
    string toString() const
    {
        import std.exception : assumeUnique;

        char[MAX_CHARS_NEEDED] styleBuffer;
        const styleSlice = this.toFullStartSequence(styleBuffer);

        auto buffer = new char[styleSlice.length + this.text.length + ANSI_COLOUR_RESET.length];
        buffer[0..styleSlice.length]                                  = styleSlice[];
        buffer[styleSlice.length..styleSlice.length+this.text.length] = this.text[];
        buffer[$-ANSI_COLOUR_RESET.length..$]                         = ANSI_COLOUR_RESET[];

        return buffer.assumeUnique;
    }

    /++
     + The sink-based version of `toString`, which doesn't allocate by itself unless the `sink` decides to allocate.
     +
     + Params:
     +  sink = The sink to output into.
     +
     + See_Also:
     +  `toSink` for a templatised version of this function which can infer attributes, and supports any form of Output Range instead of just a delegate.
     + ++/
    void toString(scope void delegate(const(char)[]) sink) const
    {
        foreach(slice; this.toRange())
            sink(slice);
    }

    /++
     + Outputs in order: The start sequence (`.toFullStartSequence`), the output text (`.text`), and the end sequence (`.toFullEndSequence`)
     + into the given `sink`.
     +
     + This function by itself does not allocate memory.
     +
     + This function will infer attributes, so as to be used in whatever attribute-souped environment your sink supports.
     +
     + $(B Please read the warnings described in `.toRange`) TLDR; don't persist the slices given to the sink under any circumstance. You must
     + copy the data as soon as you get it.
     +
     + Params:
     +  sink = The sink to output into.
     + ++/
    void toSink(Sink)(scope ref Sink sink) const
    {
        foreach(slice; this.toRange())
            sink.put(slice);
    }
}
///
@("AnsiTextLite")
unittest
{
    static if(!BetterC)
    {
        auto text = "Hello!".ansi
                            .fg(Ansi4BitColour.green)
                            .bg(AnsiRgbColour(128, 128, 128))
                            .style(AnsiStyle.init.bold.underline);

        // Usage 1: Manually
        import core.stdc.stdio : printf;
        import std.stdio : writeln, write;
        version(JANSI_TestOutput) // Just so test output isn't clogged. This still shows you how to use things though.
        {
            char[AnsiTextLite.MAX_CHARS_NEEDED + 1] startSequence; // + 1 for null terminator.
            const sliceFromStartSequence = text.toFullStartSequence(startSequence[0..AnsiTextLite.MAX_CHARS_NEEDED]);
            startSequence[sliceFromStartSequence.length] = '\0';

            char[200] textBuffer;
            textBuffer[0..text.text.length] = text.text[];
            textBuffer[text.text.length] = '\0';

            char[ANSI_COLOUR_RESET.length + 1] endSequence;
            endSequence[0..ANSI_COLOUR_RESET.length] = text.toFullEndSequence()[];
            endSequence[$-1] = '\0';

            printf("%s%s%s\n", startSequence.ptr, textBuffer.ptr, endSequence.ptr);
        }

        // Usage 2: Range (RETURNS STACK MEMORY, DO NOT ALLOW SLICES TO OUTLIVE RANGE OBJECT WITHOUT EXPLICIT COPY)
        version(JANSI_TestOutput)
        {
            // -betterC
            foreach(slice; text.toRange)
            {
                char[200] buffer;
                buffer[0..slice.length] = slice[];
                buffer[slice.length] = '\0';
                printf("%s", buffer.ptr);
            }
            printf("\n");

            // GC
            foreach(slice; text.toRange)
                write(slice);
            writeln();
        }
        
        // Usage 3: toString (Sink-based, so AnsiTextLite doesn't allocate, but writeln/the sink might)
        version(JANSI_TestOutput)
        {
            writeln(text); // Calls the sink-based .toString();
        }

        // Usage 4: toString (non-sink, non-betterc only)
        version(JANSI_TestOutput)
        {
            writeln(text.toString());
        }

        // Usage 5: toSink
        version(JANSI_TestOutput)
        {
            struct CustomOutputRange
            {
                char[] output;
                @safe
                void put(const(char)[] slice) nothrow
                {
                    const start = output.length;
                    output.length += slice.length;
                    output[start..$] = slice[];
                }
            }

            CustomOutputRange sink;
            ()@safe nothrow{ text.toSink(sink); }();
            
            writeln(sink.output);
        }
    }
}

/++
 + Contains a string that supports the ability for different parts of the string to be styled seperately.
 +
 + This struct is highly flexible and dynamic, as it requires the use of external code to provide some
 + of the implementation.
 +
 + Because this is provided via a `mixin template`, implementations can also $(B extend) this struct to 
 + provide their own functionality, make things non-copyable if needed, allows data to be stored via ref-counting, etc.
 +
 + This struct itself is mostly just a consistant user-facing interface that all implementations share, while the implementations
 + themselves can transform this struct to any level it requires.
 +
 + Implementations_:
 +  While implementations can add whatever functions, operator overloads, constructors, etc. that they want, there is a small
 +  set of functions and value that each implmentation must define in order to be useable.
 +
 +  Every implementation must define an enum called `Features` who's value is one of the values of `AnsiTextImplementationFeatures`.
 +  For example: `enum Features = AnsiTextImplementationFeatures.xxx`
 +
 +  Builtin implementations consist of `AnsiTextGC` (not enabled with -betterC), `AnsiTextStack`, and `AnsiTextMalloc`, which are self-descriptive.
 +
 + Basic_Implemetations:
 +  An implementation that doesn't require anything noteworthy from `AnsiText` itself should define their features as `AnsiTextImplementationFeatures.basic`.
 +
 +  This type of implementation must implement the following functions (expressed here as an interface for simplicity):
 +
 +  ```
 interface BasicImplementation
 {
     /// Provides `AnsiText` with a slice that is of at least `minLength` in size.
     ///
     /// This function is called `AnsiText` needs to insert more styled characters into the string.
     ///
     /// How this slice is stored and allocated and whatever else, is completely down to the implementation.
     /// Remember that because you're a mixin template, you can use referencing counting, disable the copy ctor, etc!
     ///
     /// The slice will never be escaped by `AnsiText` itself, and will not be stored beyond a single function call.
     char[] newSlice(size_t minLength);

     /// Outputs the styled string into the provided sink.
     ///
     /// Typically this is an OutputRange that can handle `char[]`s, but it can really be whatever the implementation wants to support.
     void toSink(Sink)(Sink sink);

     static if(NotCompilingUnderBetterC && ImplementationDoesntDefineToString)
     final string toString()
     {
         // Autogenerated GC-based implementation provided by `AnsiText`.
         //
         // For implementations where this can be generated, it just makes them a little easier for the user
         // to use with things like `writeln`.
         //
         // The `static if` shows the conditions for this to happen.
     }
 }
 +  ```
 + ++/
struct AnsiText(alias ImplementationMixin)
{
    mixin ImplementationMixin;
    alias ___TEST = TestAnsiTextImpl!(typeof(this));

    void put()(const(char)[] text, AnsiColour fg = AnsiColour.init, AnsiColour bg = AnsiColour.bgInit, AnsiStyle style = AnsiStyle.init)
    {
        fg.isBg = IsBgColour.no;
        bg.isBg = IsBgColour.yes;

        char[AnsiStyleSet.MAX_CHARS_NEEDED] sequence;
        auto sequenceSlice = AnsiStyleSet.init.fg(fg).bg(bg).style(style).toSequence(sequence);

        auto minLength = ANSI_CSI.length + sequenceSlice.length + /*ANSI_COLOUR_END*/1 + text.length + ((sequenceSlice.length > 0) ? 2 : 1); // Last one is for the '0' or '0;'
        char[] slice = this.newSlice(minLength);
        size_t cursor;

        void appendToSlice(const(char)[] source)
        {
            slice[cursor..cursor+source.length] = source[];
            cursor += source.length;
        }

        appendToSlice(ANSI_CSI);
        appendToSlice("0"); // Reset all previous styling
        if(sequenceSlice.length > 0)
            slice[cursor++] = ANSI_SEPARATOR;
        appendToSlice(sequenceSlice);
        slice[cursor++] = ANSI_COLOUR_END;
        appendToSlice(text);
    }

    /// ditto.
    void put()(const(char)[] text, AnsiStyleSet styling)
    {
        this.put(text, styling.fg, styling.bg, styling.style);
    }

    /// ditto.
    void put()(AnsiTextLite text)
    {
        this.put(text.text, text.fg, text.bg, text.style);
    }

    // Generate a GC-based toString if circumstances allow.
    static if(
        Features == AnsiTextImplementationFeatures.basic
     && !__traits(hasMember, typeof(this), "toString")
     && !BetterC
     && __traits(compiles, { struct S{void put(const(char)[]){}} S s; typeof(this).init.toSink(s); }) // Check if this toSink can take a char[] output range.
    )
    {
        /++
         + [Not enabled with -betterC] Provides this `AnsiText` as a printable string.
         +
         + If the implementation is a basic implementation (see the documentation for `AnsiText`); if the
         + implementation doesn't define its own `toString`, and if we're not compliling under -betterC, then
         + `AnsiText` will generate this function on behalf of the implementation.
         +
         + Description:
         +  For basic implementations this function will call `toSink` with an `Appender!(char[])` as the sink.
         +
         +  For $(B this default generated) implementation of `toString`, it is a seperate GC-allocated string so is
         +  fine for any usage. If an implementation defines its own `toString` then it should also document what the lifetime
         +  of its returned string is.
         +
         + Returns:
         +  This `AnsiText` as a useable string.
         + ++/
        string toString()()
        {
            import std.array : Appender;
            import std.exception : assumeUnique;

            Appender!(char[]) output;
            this.toSink(output);

            return ()@trusted{return output.data.assumeUnique;}();
        }

        /++
         + [Not enabled with -betterC] Provides the sink-based version of the autogenerated `toString`.
         +
         + This functions and is generated under the same conditions as the parameterless `toString`, except it
         + supports the sink-based interface certain parts of Phobos recognises, helping to prevent needless allocations.
         +
         + This function simply wraps the given `sink` and forwards it to the implementation's `toSink` function, so there's no
         + implicit GC overhead as with the other `toString`. (At least, not by `AnsiText` itself.)
         + ++/
        void toString(scope void delegate(const(char)[]) sink)
        {
            struct Sink
            {
                void put(const(char)[] slice)
                {
                    sink(slice);
                }
            }
            
            Sink s;
            this.toSink(s);
        }
    }
}

private template TestAnsiTextImpl(alias TextT)
{
    // Ensures that the implementation has the required functions, and that they can be used in every required way.
    static assert(__traits(hasMember, TextT, "Features"),
        "Implementation must define: `enum Features = AnsiTextImplementationFeatures.xxx;`"
    );

    static if(TextT.Features == AnsiTextImplementationFeatures.basic)
    {
        static assert(__traits(hasMember, TextT, "newSlice"),
            "Implementation must define: `char[] newSlice(size_t minLength)`"
        );
        static assert(__traits(hasMember, TextT, "toSink"),
            "Implementation must define: `void toSink(Sink)(Sink sink)`"
        );
    }
}

@("AnsiText.toString - Autogenerated GC-based")
unittest
{
    static if(!BetterC)
    {
        import std.format : format;

        void genericTest(AnsiTextT)(auto ref AnsiTextT text)
        {
            text.put("Hello, ");
            text.put("Wor", AnsiColour(1, 2, 3), AnsiColour(3, 2, 1), AnsiStyle.init.bold.underline);
            text.put("ld!", AnsiColour(Ansi4BitColour.green));

            auto str      = text.toString();
            auto expected = "\033[0mHello, \033[0;38;2;1;2;3;48;2;3;2;1;1;4mWor\033[0;32mld!\033[0m";

            assert(
                str == expected, 
                "Got is %s chars long. Expected is %s chars long\nGot: %s\nExp: %s".format(str.length, expected.length, [str], [expected])
            );

            version(JANSI_TestOutput)
            {
                import std.stdio, std.traits;
                static if(isCopyable!AnsiTextT)
                    writeln(text);
            }
        }

        genericTest(AnsiTextGC.init);
        genericTest(AnsiTextMalloc.init);
        genericTest(AnsiTextStack!100.init);
    }
}

static if(!BetterC)
{
    // Very naive implementation just so I have something to start off with.
    ///
    mixin template AnsiTextGCImplementation()
    {
        private char[][] _slices;

        enum Features = AnsiTextImplementationFeatures.basic;

        @safe
        char[] newSlice(size_t minLength) nothrow
        {
            this._slices ~= new char[minLength];
            return this._slices[$-1];
        }

        void toSink(Sink)(ref scope Sink sink)
        if(isOutputRange!(Sink, char[]))
        {
            foreach(slice; this._slices)
                sink.put(slice);
            sink.put(ANSI_COLOUR_RESET);
        }
    }

    /++
     + A basic implementation that uses the GC for memory storage.
     +
     + Since the memory is GC allocated there's no real fears to note.
     +
     + Allows `AnsiText` to be copied, but changes between copies are not reflected between eachother. Remember to use `ref`!
     + ++/
    alias AnsiTextGC = AnsiText!AnsiTextGCImplementation;
}

///
mixin template AnsiTextMallocImplementation()
{
    import std.experimental.allocator.mallocator, std.experimental.allocator;

    enum Features = AnsiTextImplementationFeatures.basic;

    // Again, very naive implementation just to get stuff to show off.
    private char[][] _slices;

    // Stuff like this is why I went for this very strange design decision of using user-defined mixin templates.
    @disable this(this){}

    @nogc
    ~this() nothrow
    {
        if(this._slices !is null)
        {
            foreach(slice; this._slices)
                Mallocator.instance.dispose(slice);
            Mallocator.instance.dispose(this._slices);
        }
    }

    @nogc
    char[] newSlice(size_t minLength) nothrow
    {
        auto slice = Mallocator.instance.makeArray!char(minLength);
        if(this._slices is null)
            this._slices = Mallocator.instance.makeArray!(char[])(1);
        else
            Mallocator.instance.expandArray(this._slices, 1);
        this._slices[$-1] = slice;
        return slice;
    }

    void toSink(Sink)(ref scope Sink sink)
    if(isOutputRange!(Sink, char[]))
    {
        foreach(slice; this._slices)
            sink.put(slice);
        sink.put(ANSI_COLOUR_RESET);
    }
}

/++
 + A basic implementation using `malloc` backed memory.
 +
 + This implementation disables copying for `AnsiText`, as it makes use of RAII to cleanup its resources.
 +
 + Sinks should keep in mind that they are being passed manually managed memory, so it should be considered an error
 + if the sink stores any provided slices outside of its `.put` function. i.e. Copy the data, don't keep it around unless you know what you're doing.
 + ++/
alias AnsiTextMalloc = AnsiText!AnsiTextMallocImplementation;

///
template AnsiTextStackImplementation(size_t Capacity)
{
    mixin template AnsiTextStackImplementation()
    {
        enum Features = AnsiTextImplementationFeatures.basic;

        private char[Capacity] _output;
        private size_t _cursor;

        // This code by itself is *technically* safe, but the way the user uses it might not be.

        @safe @nogc
        char[] newSlice(size_t minLength) nothrow
        {
            const end = this._cursor + minLength;
            assert(end <= this._output.length, "Ran out of space.");

            auto slice = this._output[this._cursor..end];
            this._cursor = end;

            return slice;
        }

        void toSink(Sink)(ref Sink sink)
        if(isOutputRange!(Sink, char[]))
        {
            sink.put(this.asStackSlice);
            sink.put(ANSI_COLOUR_RESET);
        }

        @safe @nogc
        char[] asStackSlice() nothrow
        {
            return this._output[0..this._cursor];    
        }

        @safe @nogc
        char[Capacity] asStackSliceCopy(ref size_t lengthInUse) nothrow
        {
            lengthInUse = this._cursor;
            return this._output;
        }
    }
}

/++
 + A basic implementation using a static amount of stack memory.
 +
 + Sinks should keep in mind that they're being passed a slice to stack memory, so should not persist slices outside of their `.put` function,
 + they must instead make a copy of the data.
 +
 + This implementation will fail an assert if the user attempts to push more data into it than it can handle.
 +
 + Params:
 +  Capacity = The amount of characters to use on the stack.
 + ++/
alias AnsiTextStack(size_t Capacity) = AnsiText!(AnsiTextStackImplementation!Capacity);

/+++ READING/PARSING +++/

/++
 + Executes the SGR sequence found in `input`, and populates the passed in `style` based on the command sequence.
 +
 + Anything directly provided by this library is supported.
 +
 + The previous state of `style` is preserved unless specifically untoggled/reset via the command sequence (e.g. `ESC[0m` to reset everything).
 +
 + If an error occurs during execution of the sequence, the given `style` is left completely unmodified.
 +
 + Params:
 +  input     = The slice containing the command sequence. The first character should be the start (`ANSI_CSI`) character of the sequence (`\033`), and
 +              characters will continue to be read until the command sequence has been finished. Any characters after the command sequence are left unread.
 +  style     = A reference to an `AnsiStyleSet` to populate. As mentioned, this function will only untoggle styling, or reset the style if the command sequence specifies.
 +              This value is left unmodified if an error is encountered.
 +  charsRead = This value will be set to the amount of chars read from the given `input`, so the caller knows where to continue reading from (if applicable).
 +              This value is populated on both error and success.
 +
 + Returns:
 +  Either `null` on success, or a string describing the error that was encountered.
 + ++/
@safe @nogc
string ansiExecuteSgrSequence(const(char)[] input, ref AnsiStyleSet style, out size_t charsRead) nothrow
{
    import std.traits : EnumMembers;

    enum ReadResult { foundEndMarker, foundSemiColon, foundEnd, foundBadCharacter }

    if(input.length < 3)
        return "A valid SGR is at least 3 characters long: ESC[m";

    if(input[0..ANSI_CSI.length] != ANSI_CSI)
        return "Input does not start with the CSI: ESC[";

    auto styleCopy = style;

    charsRead = 2;
    ReadResult readToSemiColonOrEndMarker(ref const(char)[] slice)
    {
        const start = charsRead;
        while(true)
        {
            if(charsRead >= input.length)
                return ReadResult.foundEnd;

            const ch = input[charsRead];
            if(ch == 'm')
            {
                slice = input[start..charsRead];
                return ReadResult.foundEndMarker;
            }
            else if(ch == ';')
            {
                slice = input[start..charsRead];
                return ReadResult.foundSemiColon;
            }
            else if(ch >= '0' && ch <= '9')
            {
                charsRead++;
                continue;
            }
            else
                return ReadResult.foundBadCharacter;
        }
    }

    int toValue(const(char)[] slice)
    {
        return (slice.length == 0) ? 0 : slice.strToNum!int;
    }

    string resultToString(ReadResult result)
    {
        final switch(result) with(ReadResult)
        {
            case foundEnd: return "Unexpected end of input.";
            case foundBadCharacter: return "Unexpected character in input.";

            case foundSemiColon: return "Unexpected semi-colon.";
            case foundEndMarker: return "Unexpected end marker ('m').";
        }
    }

    const(char)[] generalSlice;
    while(charsRead < input.length)
    {
        const ch = input[charsRead];

        switch(ch)
        {
            case '0':..case '9':
                auto result = readToSemiColonOrEndMarker(generalSlice);
                if(result != ReadResult.foundSemiColon && result != ReadResult.foundEndMarker)
                    return resultToString(result);

                const commandAsNum = toValue(generalSlice);
                Switch: switch(commandAsNum)
                {
                    // Full reset
                    case 0: styleCopy = AnsiStyleSet.init; break;

                    // Basic style flag setters.
                    static foreach(member; EnumMembers!AnsiSgrStyle)
                    {
                        static if(member != AnsiSgrStyle.none)
                        {
                            case cast(int)member:
                                styleCopy.style = styleCopy.style.set(member, true);
                                break Switch;
                        }
                    }

                    // Set foreground to a 4-bit colour.
                    case 30:..case 37:
                    case 90:..case 97:
                        styleCopy.fg = cast(Ansi4BitColour)commandAsNum;
                        break;

                    // Set background to a 4-bit colour.
                    case 40:..case 47:
                    case 100:..case 107:
                        styleCopy.bg = cast(Ansi4BitColour)(commandAsNum - ANSI_FG_TO_BG_INCREMENT); // Since we work in the foreground colour until we're outputting to sequences.
                        break;
                    
                    // Set foreground (38) or background (48) to an 8-bit (5) or 24-bit (2) colour.
                    case 38:
                    case 48:
                        if(result == ReadResult.foundEndMarker)
                            return "Incomplete 'set foreground/background' command, expected another parameter, got none.";
                        charsRead++; // Skip semi-colon.

                        result = readToSemiColonOrEndMarker(generalSlice);
                        if(result != ReadResult.foundEndMarker && result != ReadResult.foundSemiColon)
                            return resultToString(result);
                        if(result == ReadResult.foundSemiColon)
                            charsRead++;

                        const subcommand = toValue(generalSlice);
                        if(subcommand == 5)
                        {
                            result = readToSemiColonOrEndMarker(generalSlice);
                            if(result != ReadResult.foundEndMarker && result != ReadResult.foundSemiColon)
                                return resultToString(result);
                            if(result == ReadResult.foundSemiColon)
                                charsRead++;

                            if(commandAsNum == 38) styleCopy.fg = cast(Ansi8BitColour)toValue(generalSlice);
                            else                   styleCopy.bg = cast(Ansi8BitColour)toValue(generalSlice);
                        }
                        else if(subcommand == 2)
                        {
                            ubyte[3] components;
                            foreach(i; 0..3)
                            {
                                result = readToSemiColonOrEndMarker(generalSlice);
                                if(result != ReadResult.foundEndMarker && result != ReadResult.foundSemiColon)
                                    return resultToString(result);
                                if(result == ReadResult.foundSemiColon)
                                    charsRead++;

                                components[i] = cast(ubyte)toValue(generalSlice);
                            }

                            if(commandAsNum == 38) styleCopy.fg = AnsiRgbColour(components);
                            else                   styleCopy.bg = AnsiRgbColour(components);
                        }
                        else
                            break; // Assume it's a valid command, just that we don't support this specific sub command.
                        break;

                    default: continue; // Assume it's just a command we don't support.
                }
                break;

            case 'm':
                charsRead++;
                style = styleCopy;
                return null;

            case ';': charsRead++; continue;
            default: return null; // Assume we've hit an end-marker we don't support.
        }
    }

    return "Input did not contain an end marker.";
}
///
@("ansiExecuteSgrSequence")
unittest
{
    static if(!BetterC)
    {
        import std.conv : to;
        import std.traits : EnumMembers;

        void test(AnsiStyleSet sourceAndExpected)
        {
            char[AnsiStyleSet.MAX_CHARS_NEEDED] buffer;
            const sequence = ANSI_CSI~sourceAndExpected.toSequence(buffer)~ANSI_COLOUR_END;

            AnsiStyleSet got;
            size_t charsRead;
            const error = ansiExecuteSgrSequence(sequence, got, charsRead);
            if(error !is null)
                assert(false, error);

            assert(charsRead == sequence.length, "Read "~charsRead.to!string~" not "~sequence.length.to!string);
            assert(sourceAndExpected == got, "Expected "~sourceAndExpected.to!string~" got "~got.to!string);
        }

        test(AnsiStyleSet.init.fg(Ansi4BitColour.green));
        test(AnsiStyleSet.init.fg(Ansi4BitColour.brightGreen));
        test(AnsiStyleSet.init.bg(Ansi4BitColour.green));
        test(AnsiStyleSet.init.bg(Ansi4BitColour.brightGreen));
        test(AnsiStyleSet.init.fg(Ansi4BitColour.green).bg(Ansi4BitColour.brightRed));

        test(AnsiStyleSet.init.fg(20));
        test(AnsiStyleSet.init.bg(40));
        test(AnsiStyleSet.init.fg(20).bg(40));

        test(AnsiStyleSet.init.fg(AnsiRgbColour(255, 128, 64)));
        test(AnsiStyleSet.init.bg(AnsiRgbColour(255, 128, 64)));
        test(AnsiStyleSet.init.fg(AnsiRgbColour(255, 128, 64)).bg(AnsiRgbColour(64, 128, 255)));
        
        static foreach(member; EnumMembers!AnsiSgrStyle)
        static if(member != AnsiSgrStyle.none)
            test(AnsiStyleSet.init.style(AnsiStyle.init.set(member, true)));

        test(AnsiStyleSet.init.style(AnsiStyle.init.bold.underline.slowBlink.italic));
    }
}

/++
 + The resulting object from `AnsiSectionRange`, describes whether a slice of text is an ANSI sequence or not.
 + ++/
struct AnsiSection
{
    /// `true` if the slice is an ANSI sequence, `false` if it's just text.
    bool isAnsiSequence;

    /// The slice of text that this section consists of.
    const(char)[] slice;
}

/++
 + An input range of `AnsiSection`s that splits a piece of text up into ANSI sequence and plain text sections.
 +
 + For example, the text "\033[37mABC\033[0m" has three sections: [ANSI "\033[37m", TEXT "ABC", ANSI "\033[0m"].
 + ++/
struct AnsiSectionRange
{
    private
    {
        const(char)[] _input;
        size_t        _cursor;
        AnsiSection   _front;
        bool          _empty = true; // So .init.empty is true
    }
    
    @safe @nogc nothrow pure:

    ///
    this(const(char)[] input)
    {
        this._input = input;
        this._empty = false;
        this.popFront();
    }

    ///
    bool empty() const
    {
        return this._empty;
    }
    
    ///
    AnsiSection front() const
    {
        return this._front;
    }

    ///
    void popFront()
    {
        assert(!this.empty, "Cannot pop empty range.");

        if(this._cursor >= this._input.length)
        {
            this._empty = true;
            return;
        }

        if((this._input.length - this._cursor) >= ANSI_CSI.length 
        && this._input[this._cursor..this._cursor + ANSI_CSI.length] == ANSI_CSI)
            this.readSequence();
        else
            this.readText();
    }

    private void readText()
    {
        const start = this._cursor;
        
        while(this._cursor < this._input.length)
        {
            if((this._input.length - this._cursor) >= 2 && this._input[this._cursor..this._cursor+2] == ANSI_CSI)
                break;

            this._cursor++;
        }

        this._front.isAnsiSequence = false;
        this._front.slice = this._input[start..this._cursor];
    }

    private void readSequence()
    {
        const start = this._cursor;
        this._cursor += ANSI_CSI.length; // Already validated by popFront.

        while(this._cursor < this._input.length 
           && this.isValidAnsiChar(this._input[this._cursor]))
           this._cursor++;

        if(this._cursor < this._input.length)
            this._cursor++; // We've hit a non-ansi character, so we increment to include it in the output.

        this._front.isAnsiSequence = true;
        this._front.slice = this._input[start..this._cursor];
    }

    private bool isValidAnsiChar(char ch)
    {
        return (
            (ch >= '0' && ch <= '9')
         || ch == ';'
        );
    }
}
///
@("AnsiSectionRange")
unittest
{
    assert(AnsiSectionRange.init.empty);
    assert("".asAnsiSections.empty);

    auto r = "No Ansi".asAnsiSections;
    assert(!r.empty);
    assert(!r.front.isAnsiSequence);
    assert(r.front.slice == "No Ansi");

    r = "\033[m".asAnsiSections;
    assert(!r.empty);
    assert(r.front.isAnsiSequence);
    assert(r.front.slice == "\033[m");

    r = "\033[38;2;255;128;64;1;4;48;5;2m".asAnsiSections;
    assert(!r.empty);
    assert(r.front.isAnsiSequence);
    assert(r.front.slice == "\033[38;2;255;128;64;1;4;48;5;2m");

    r = "\033[mABC\033[m".asAnsiSections;
    assert(r.front.isAnsiSequence);
    assert(r.front.slice == "\033[m", r.front.slice);
    r.popFront();
    assert(!r.empty);
    assert(!r.front.isAnsiSequence);
    assert(r.front.slice == "ABC", r.front.slice);
    r.popFront();
    assert(!r.empty);
    assert(r.front.isAnsiSequence);
    assert(r.front.slice == "\033[m");
    r.popFront();
    assert(r.empty);

    r = "ABC\033[mDEF".asAnsiSections;
    assert(!r.front.isAnsiSequence);
    assert(r.front.slice == "ABC");
    r.popFront();
    assert(r.front.isAnsiSequence);
    assert(r.front.slice == "\033[m");
    r.popFront();
    assert(!r.front.isAnsiSequence);
    assert(r.front.slice == "DEF");
    r.popFront();
    assert(r.empty);
}

/+++ PUBLIC HELPERS +++/

/// Determines if `CT` is a valid RGB data type.
enum isUserDefinedRgbType(CT) =
(
    __traits(hasMember, CT, "r")
 && __traits(hasMember, CT, "g")
 && __traits(hasMember, CT, "b")
);

/++
 + Converts any suitable data type into an `AnsiColour`.
 +
 + Params:
 +  colour = The colour to convert.
 +
 + Returns:
 +  An `AnsiColour` created from the given `colour`.
 +
 + See_Also:
 +  `isUserDefinedRgbType`
 + ++/
AnsiColour to(T : AnsiColour, CT)(CT colour)
if(isUserDefinedRgbType!CT)
{
    return AnsiColour(colour.r, colour.g, colour.b);
}
///
@("to!AnsiColour(User defined)")
@safe @nogc nothrow pure
unittest
{
    static struct RGB
    {
        ubyte r;
        ubyte g;
        ubyte b;
    }

    assert(RGB(255, 128, 64).to!AnsiColour == AnsiColour(255, 128, 64));
}

/// ditto.
AnsiColour toBg(T)(T c)
{
    auto colour = to!AnsiColour(c);
    colour.isBg = IsBgColour.yes;
    return colour;
}
///
@("toBg")
@safe @nogc nothrow pure
unittest
{
    static struct RGB
    {
        ubyte r;
        ubyte g;
        ubyte b;
    }

    assert(RGB(255, 128, 64).toBg == AnsiColour(255, 128, 64, IsBgColour.yes));
}

/++
 + Creates an `AnsiTextLite` from the given `text`. This function is mostly used when using
 + the fluent UFCS chaining pattern.
 +
 + Params:
 +  text = The text to use.
 +
 + Returns:
 +  An `AnsiTextLite` from the given `text`.
 + ++/
@safe @nogc
AnsiTextLite ansi(const(char)[] text) nothrow pure
{
    return AnsiTextLite(text);
}
///
@("ansi")
unittest
{
    version(none)
    {
        import std.stdio;
        writeln("Hello, World!".ansi
                               .fg(Ansi4BitColour.red)
                               .bg(AnsiRgbColour(128, 128, 128))
                               .style(AnsiStyle.init.bold.underline)
        );
    }
}

/++
 + Constructs an `AnsiSectionRange` from the given `slice`.
 + ++/
@safe @nogc
AnsiSectionRange asAnsiSections(const(char)[] slice) nothrow pure
{
    return AnsiSectionRange(slice);
}

/++
 + Enables ANSI support on windows via `SetConsoleMode`. This function is no-op on non-Windows platforms.
 + ++/
void ansiEnableWindowsSupport() @nogc nothrow
{
    version(Windows)
    {
        import core.sys.windows.windows : HANDLE, DWORD, GetStdHandle, STD_OUTPUT_HANDLE, GetConsoleMode, SetConsoleMode, ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        HANDLE stdOut = GetStdHandle(STD_OUTPUT_HANDLE);
        DWORD mode = 0;
        GetConsoleMode(stdOut, &mode);
        mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        SetConsoleMode(stdOut, mode);
    }
}

/+++ PRIVATE HELPERS +++/
private char[] numToStrBase10(NumT)(char[] buffer, NumT num)
{
    if(num == 0)
    {
        if(buffer.length > 0)
        {
            buffer[0] = '0';
            return buffer[0..1];
        }
        else
            return null;
    }

    const CHARS = "0123456789";

    ptrdiff_t i = buffer.length;
    while(i > 0 && num > 0)
    {
        buffer[--i] = CHARS[num % 10];
        num /= 10;
    }

    return buffer[i..$];
}
///
@("numToStrBase10")
unittest
{
    char[2] b;
    assert(numToStrBase10(b, 32) == "32");
}

private NumT strToNum(NumT)(const(char)[] slice)
{
    NumT num;

    foreach(i, ch; slice)
    {
        const exponent = slice.length - (i + 1);
        const tens     = 10 ^^ exponent;
        const chNum    = cast(NumT)(ch - '0');

        if(tens == 0)
            num += chNum;
        else
            num += chNum * tens;
    }

    return num;
}
///
@("strToNum")
unittest
{
    assert("1".strToNum!int == 1);
    assert("11".strToNum!int == 11);
    assert("901".strToNum!int == 901);
}