module jcli.argparser.parser;

import std.range;

struct ArgParser(TRange)
    if (isInputRange!TRange && is(typeof(TRange.front) == string))
{
    static struct ElementType
    {
        enum Kind
        {
            /// Uninitialized.
            none = 0,
            /// 2 dashes have a special meaning of a delimiter.
            twoDashesDelimiter = 1,
            /// Arguments that appear after any named arguments.
            // rawText,

            /// The bit! Used to check if it's the argument name.
            argumentNameBit = 16,
            /// Example: --stuff
            fullNamedArgumentName = argumentNameBit | 1,
            /// Example: -a
            shortNamedArgumentName = argumentNameBit | 2,

            /// The bit! Indicating whether it contains a value.
            valueBit = 32,
            /// The right part of -a=b, -a b, --stuff b or --stuff=b.
            namedArgumentValue = valueBit | 1,
            /// Arguments that appear before any named arguments.
            positionalArgument = valueBit | 2,
            
            /// The bit! indicating that an error has occured.
            errorBit = 48,
            /// 3 dashes are ambiguous and are not allowed.
            error_threeOrMoreDashes = errorBit | 1,
            /// Lonely dash not allowed.
            error_singleDash = errorBit | 2,
            /// `--arg="` causes this error.
            error_malformedQuotes = errorBit | 3,
            /// `--arg=` causes this error.
            error_noValueForNamedArgument = errorBit | 4,
            /// `--arg="...` causes this error.
            error_unclosedQuotes = errorBit | 5,
            /// `--arg="..."...` causes this error.
            error_inputAfterClosedQuote = errorBit | 6,
        }

        Kind kind;

        string fullSlice;

        union
        {
            string valueSlice;
            string nameSlice;
        }
    }

    TRange _range;
    ElementType _front;
    size_t _positionWithinCurrentString;

    string front() const @safe @nogc nothrow pure
    {
        return _front;
    }

    bool empty() const @safe @nogc nothrow pure
    {
        return _range.empty;
    }

    /// This function may throw if the characters of argument values are not valid utf8 characters.
    /// This function fails in debug if the passed arguments are not properly shell escaped.
    /// This function assumes that all option names are valid ascii symbols.
    void popFront() @safe @nogc pure
    {
        assert(!empty);

        const currentSlice = _range.front;
        const initialPosition = _positionWithinCurrentString;
        string getCurrentFullSlice()
        {
            return currentSlice[initialPosition .. _positionWithinCurrentString];
        }
        char getCurrentCharacter()
        {
            return currentSlice[_positionWithinCurrentString];
        }

        void popFrontAndReset()
        {
            _range.popFront();
            _positionWithinCurrentString = 0;

            // string newCurrent = _range.front;
            // size_t currentIndex = 0;
            // while (currentIndex < newCurrent.length
            //     && isWhite(newCurrent[currentIndex]))
            // {
            //     currentIndex++;
            // }
            // // Either it's a zero length argument, or it's all whitespace.
            // // We will treat it as is.
            // // The variable we set indicates that the next popFront should
            // // return the entire thing and just skip until the next one.
            // if (currentIndex == newCurrent.length)
            // {
            //     _isNextArgumentEmptyOrWhitespace = true;
            // }
            // else
            // {
            //     _positionWithinCurrentString = currentIndex;
            // }
        }

        ElementType parseArgumentName()
        {
            // This function assumes the current character is a dash
            // Note to devs: if you want the logic after that, extract another local function.
            assert(getCurrentCharacter() == "-");
            _positionWithinCurrentString++;

            Kind potentialNamedArgumentKind;
            // A lonely dash without a name is not allowed.
            if (currentSlice.length == _positionWithinCurrentString)
            {
                const fullSlice  = getCurrentFullSlice();
                const valueSlice = "";
                popFrontAndReset();
                return ElementType(Kind.error_singleDash, fullSlice, valueSlice);
            }
            // Double dash.
            else if (getCurrentCharacter() == "-")
            {
                potentialNamedArgumentKind = Kind.fullNamedArgumentName;
                _positionWithinCurrentString++;
            }
            // Shorthand argument.
            else
            {
                potentialNamedArgumentKind = Kind.shortNamedArgumentName;
            }

            // Two dashes without name following them mean the delimiter.
            if (currentSlice.length < _positionWithinCurrentString)
            {
                const fullSlice  = getCurrentFullSlice();
                const valueSlice = "";
                popFrontAndReset();
                return ElementType(Kind.twoDashesDelimiter, fullSlice, valueSlice);
            }

            // If there is a space, at that point it must have been split already.
            assert(getCurrentCharacter() != ' ',
                "The arguments must be shell escaped prior to sending them to the parser.");

            if (getCurrentCharacter() == '-')
            {
                const kind       = Kind.error_threeOrMoreDashes;
                const fullSlice  = getCurrentFullSlice();
                const valueSlice = "";
                popFrontAndReset();
                return ElementType(kind, fullSlice, valueSlice);
            }

            // Even though in the struct definition it is called "value slice",
            // I figured "name slice" in this context makes more sense, because
            // we're parsing an option name.
            const nameStartPosition = _positionWithinCurrentString;
            string getCurrentNameSlice()
            {
                return currentSlice[nameStartPosition .. _positionWithinCurrentString];
            }

            while (_positionWithinCurrentString < currentSlice.length)
            {
                char ch = getCurrentCharacter();
                if (ch == '=')
                {
                    const fullSlice = getCurrentFullSlice();
                    const nameSlice = getCurrentNameSlice();
                    _positionWithinCurrentString++;
                    return ElementType(potentialNamedArgumentKind, fullSlice, nameSlice);
                }
                if (!isWhite(ch))
                {
                    _positionWithinCurrentString++;
                    continue;
                }
                break;
            }

            {
                const fullSlice = getCurrentFullSlice();
                const nameSlice = getCurrentNameSlice();
                
                if (_positionWithinCurrentString == currentSlice.length)
                {
                    popFrontAndReset();
                }

                return ElementType(potentialNamedArgumentKind, fullSlice, nameSlice);
            }
        }

        switch (_front.kind)
        {
            alias Kind = ElementType.Kind;

            case Kind.namedArgumentValue:
            case Kind.fullNamedArgumentName:
            {
                // If the position is not 0, that means we're taking off after an option
                // has been specified and we're on the other side of '='.
                const bool isRHSOfEqual = _positionWithinCurrentString > 0;

                // We must always parse the value that follows as a value literal, allowing any characters.
                // For simplicity, let's say we only allow quoting with "" and not with ^^ or any other nonsense.
                if (isRHSOfEqual)
                {
                    // `--arg=`
                    if (_positionWithinCurrentString == currentSlice.length)
                    {
                        const kind       = Kind.error_noValueForNamedArgument;
                        const fullSlice  = "";
                        const valueSlice = "";
                        popFrontAndReset();
                        return ElementType(kind, fullSlice, valueSlice);
                    }

                    if (getCurrentCharacter() == '"')
                    {
                        _positionWithinCurrentString++;

                        // `--arg="`
                        if (_positionWithinCurrentString == currentSlice.length)
                        {
                            const kind       = Kind.error_malformedQuotes;
                            const fullSlice  = getCurrentFullSlice();
                            const valueSlice = fullSlice;
                            popFrontAndReset();
                            return ElementType(kind, fullSlice, valueSlice);
                        }

                        const valueStartIndex = _positionWithinCurrentString;

                        // At this point we might as well use the phobos indexOf funicton, because this part
                        // might have non-ascii characters so comparing bytes is just wrong. 
                        import std.string : indexOf;
                        int indexOfQuote = indexOf(currentSlice[valueStartIndex .. $], '"');

                        // `--arg="...`
                        if (indexOfQuote == -1)
                        {
                            const kind       = Kind.error_unclosedQuotes;
                            const fullSlice  = currentSlice[initialPosition .. $];
                            const valueSlice = currentSlice[valueStartIndex .. $];
                            popFrontAndReset();
                            return ElementType(kind, fullSlice, valueSlice);
                        }
                        
                        // `--arg="..."...`
                        if (currentSlice.length - 1 != indexOfQuote)
                        {
                            const kind       = Kind.error_inputAfterClosedQuote;
                            const fullSlice  = currentSlice[initialPosition .. $];
                            const valueSlice = currentSlice[valueStartIndex .. indexOfQuote];
                            popFrontAndReset();
                            return ElementType(kind, fullSlice, valueSlice);
                        }

                        // `--arg="..."`
                        {
                            const kind       = Kind.namedArgumentValue;
                            const fullSlice  = currentSlice[initialPosition .. $];
                            const valueSlice = currentSlice[valueStartIndex .. indexOfQuote];
                            popFrontAndReset();
                            return ElementType(kind, fullSlice, valueSlice);
                        }
                    }

                    // `--arg=...`
                    {
                        const kind       = Kind.namedArgumentValue;
                        const fullSlice  = currentSlice[initialPosition .. $];
                        const valueSlice = currentSlice[initialPosition .. $];
                        
                        // If the spaces got into the string, it was malformed from the start
                        import std.string : indexOf;
                        assert(indexOf(valueSlice, ' ') == -1,
                            "Detected spaces on the right hand side of a named argument value assignment. You forgot to shell escape the string (most likely)");

                        return ElementType(kind, fullSlice, valueSlice);
                    }
                }

                if (getCurrentCharacter() == '-')
                {
                    return parseArgumentName();
                }

                // Otherwise the entire string are just an argument value like the "value" below.
                // ["--name", "value"].
                // We don't care whether it was quoted on not in the source, we just return the whole thing.
                {
                    const kind       = Kind.namedArgumentValue;
                    const fullSlice  = currentSlice;
                    const valueSlice = currentSlice;
                    _range.popFront();
                    return ElementType(kind, fullSlice, valueSlice);
                }
            }

            case none:
        }
    }
}


struct ArgParserSplitter
{
    private
    {
        string[] _input;
        size_t   _elCursor;
        size_t   _arrCursor;
        string   _front;
        bool     _empty;
    }

    this(string[] input)
    {
        this._input = input;
        this.popFront();
    }

    @property @safe @nogc
    string front() nothrow pure const
    {
        return this._front;
    }

    @property @safe @nogc
    bool empty() nothrow pure const
    {
        return this._empty;
    }

    @safe @nogc
    void popFront() nothrow pure
    {
        if(this._input.length == 0 || this._arrCursor == this._input.length)
        {
            this._empty = true;
            return;
        }

        if(this._input[this._arrCursor].length == 0)
        {
            this._arrCursor++;
            this._elCursor = 0;
            this.popFront();
            return;
        }

        if(this._elCursor == 0 && this._input[this._arrCursor][0] != '-')
        {
            this._front = this._input[this._arrCursor++];
            return;
        }

        const start = this._elCursor;
        while(
            this._elCursor < this._input[this._arrCursor].length
        &&  this._input[this._arrCursor][this._elCursor] != ' '
        &&  this._input[this._arrCursor][this._elCursor] != '='
        )
            this._elCursor++;

        this._front = this._input[this._arrCursor][start..this._elCursor];
        if(this._elCursor == this._input[this._arrCursor].length)
        {
            this._elCursor = 0;
            this._arrCursor++;
        }
        else
            this._elCursor++; // Skip the delim
    }
}
///
unittest
{
    import std.algorithm.comparison : equal;
    assert(
        ArgParserSplitter([
            "a", "b c", "--one", "-tw o", "--thr=ee"
        ]).equal([
            "a", "b c", "--one", "-tw", "o", "--thr", "ee"
        ])
    );
}

struct ArgParser
{
    static struct Result
    {
        

        string fullSlice;
        string dashSlice;
        string nameSlice;
        Kind kind;

        bool isShortHand()
        {
            return this.dashSlice.length == 1;
        }
    }

    private
    {
        ArgParserSplitter   _range;
        bool                _empty;
        Result              _front;
    }

    this(string[] args)
    {
        this._range = ArgParserSplitter(args);
        this.popFront();
    }

    @property @safe @nogc
    Result front() nothrow pure const
    {
        return this._front;
    }

    @property @safe @nogc
    bool empty() nothrow pure const
    {
        return this._empty;
    }

    @safe @nogc
    void popFront() nothrow pure
    {
        if(_range.empty)
        {
            _empty = true;
            return;
        }

        Result result;
        result.fullSlice = this._range.front;

        if(result.fullSlice.length && result.fullSlice[0] == '-')
        {
            this._front.kind = Result.Kind.argument;
            
            const start = 0;
            int end = 1;
            while(end < this._front.fullSlice.length && this._front.fullSlice[end] == '-')
                end++;
            this._front.dashSlice = this._front.fullSlice[start..end];
            this._front.nameSlice = this._front.fullSlice[end..$];
        }
        else
            this._front.kind = Result.Kind.rawText;

        this._front = result;
        _range.popFront();
    }

    @property @safe @nogc nothrow inout
    auto remainingArgs()
    {
        return this._range;
    }
}
///
unittest
{
    import std.algorithm.comparison : equal;
    assert(
        ArgParser([
            "dub", "run", "-b", "release", "--compiler=ldc", "--", "abc"
        ]).equal([
            ArgParser.Result("dub", null, null, ArgParser.Result.Kind.rawText),
            ArgParser.Result("run", null, null, ArgParser.Result.Kind.rawText),
            ArgParser.Result("-b", "-", "b", ArgParser.Result.Kind.argument),
            ArgParser.Result("release", null, null, ArgParser.Result.Kind.rawText),
            ArgParser.Result("--compiler", "--", "compiler", ArgParser.Result.Kind.argument),
            ArgParser.Result("ldc", null, null, ArgParser.Result.Kind.rawText),
            ArgParser.Result("--", "--", "", ArgParser.Result.Kind.argument),
            ArgParser.Result("abc", null, null, ArgParser.Result.Kind.rawText),
        ])
    );
}