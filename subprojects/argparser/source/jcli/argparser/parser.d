module jcli.argparser.parser;

import std.range;

struct ArgToken 
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
        /// The bit indicating the argument value may correspond to a named argument
        _namedArgumentValueBit = 1,
        /// The bit indicating the argument value may correspond to a positional argument
        _positionalArgumentBit = 2,
        /// The right part of -a=b, -a="b", --stuff=b or --stuff="b".
        namedArgumentValue = valueBit | _namedArgumentValueBit,
        /// --stuff value
        namedArgumentValueOrPositionalArgument = valueBit | _namedArgumentValueBit | _positionalArgumentBit,
        /// Arguments that appear before any named arguments.
        /// value --stuff not_this_one
        positionalArgument = valueBit | _positionalArgumentBit,
        
        /// The bit! indicating that an error has occured.
        errorBit = 48,
        /// 3 dashes are ambiguous and are not allowed.
        error_threeOrMoreDashes = errorBit | 1,
        /// Lonely dash not allowed. (Should it be parsed as positional instead??)
        error_singleDash = errorBit | 2,
        /// `--arg="` causes this error.
        error_malformedQuotes = errorBit | 3,
        /// `--arg=` causes this error.
        error_noValueForNamedArgument = errorBit | 4,
        /// `--arg="...` causes this error.
        error_unclosedQuotes = errorBit | 5,
        /// `--arg="..."...` causes this error.
        error_inputAfterClosedQuote = errorBit | 6,
        /** 
            `--arg= `
            
            Can happen in a situation, when a user invokes a command like this:
            --name "--arg= "
            
            Which the program sees like this:
            ["--name", "--arg= "]
            
            So it assumes "--name" is a flag, and "--arg" is the name of the next argument,
            while in fact the "--arg=" part is an argument to the previous command.
            In this situation we emit this error, which you should fix with `--name="--args"`.
            
            However, the situation `--name "--arg"` cannot be physically accounted for,
            so in that case we emit this error in the binder, which has semantic info.
        */
        error_spaceAfterAssignment = errorBit | 7,
        /// ditto
        error_spaceAfterDashes = errorBit | 8,
    }

    this(Kind kind, string fullSlice, string valueSlice) @safe pure @nogc nothrow
    {
        this.kind = kind;
        this.fullSlice = fullSlice;
        this.valueSlice = valueSlice;
    }

    Kind kind;
    string fullSlice;

    union
    {
        string valueSlice;
        string nameSlice;
    }
}

struct ArgTokenizer(TRange)
    if (isInputRange!TRange 
        && is(ElementType!TRange == string))
{
    alias ElementType = ArgToken;

    private
    {
        TRange _range;
        bool _empty = false;
        ElementType _front = ElementType.init;
        size_t _positionWithinCurrentString = 0;
        bool _hasParsedAnyNamedArguments = false;
    }

    @safe pure @nogc:
    
    ArgToken front() const nothrow pure @safe
    {
        return _front;
    }

    bool empty() const nothrow pure @safe 
    {
        return _empty;
    }

    /// NOTE: this property does not take into account the position within the string.
    inout(TRange) leftoverRange() inout nothrow pure @safe
    {
        return _range;
    }

    /// This function may throw if the characters of argument values are not valid utf8 characters.
    /// This function fails in debug if the passed arguments are not properly shell escaped.
    /// This function assumes that all option names are valid ascii symbols.
    void popFront()
    {
        if (_range.empty)
        {
            _empty = true;
            return;
        }
        _front = _popFrontInternal();
    }

    /// ditto
    private ElementType _popFrontInternal()
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

        alias Kind = ElementType.Kind;
        Kind previousKind = _front.kind;

        ElementType parseArgumentName()
        {
            // This function assumes the current character is a dash
            // Note to devs: if you want the logic after that, extract another local function.
            assert(getCurrentCharacter() == '-');
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
            else if (getCurrentCharacter() == '-')
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
            if (_positionWithinCurrentString == currentSlice.length)
            {
                const fullSlice  = getCurrentFullSlice();
                const valueSlice = fullSlice;
                popFrontAndReset();
                return ElementType(Kind.twoDashesDelimiter, fullSlice, valueSlice);
            }

            // If there is a space, at that point it must have been split already.
            // See `Kind.error_spaceAfterDashes`.
            if (getCurrentCharacter() == ' ')
            {
                // "The arguments must be shell escaped prior to sending them to the parser.");
                const kind       = Kind.error_spaceAfterDashes;
                const fullSlice  = currentSlice[_positionWithinCurrentString .. $];
                const valueSlice = fullSlice;
                popFrontAndReset();
                return ElementType(kind, fullSlice, valueSlice);
            }

            if (getCurrentCharacter() == '-')
            {
                _positionWithinCurrentString++;
                const kind       = Kind.error_threeOrMoreDashes;
                const fullSlice  = getCurrentFullSlice();
                const valueSlice = fullSlice;
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
                import std.ascii : isWhite;
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

        if (previousKind & Kind.argumentNameBit)
        {
            // If the position is not 0, that means we're taking off after an option
            // has been specified and we're on the other side of '='.
            const bool isRHSOfEqual = _positionWithinCurrentString > 0;

            // We must always parse the value that follows as a value literal, allowing any characters.
            // For simplicity, let's say we only allow quoting with "" and not with ^^ or any other nonsense.
            if (isRHSOfEqual)
            {
                assert(_hasParsedAnyNamedArguments);

                // `--arg=`
                if (_positionWithinCurrentString == currentSlice.length)
                {
                    const kind       = Kind.error_noValueForNamedArgument;
                    // We have the possibility to put more info here, if needed.
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
                    auto indexOfQuote = indexOf(currentSlice[valueStartIndex .. $], '"');

                    // `--arg="...`
                    if (indexOfQuote == -1)
                    {
                        const kind       = Kind.error_unclosedQuotes;
                        const fullSlice  = currentSlice[initialPosition .. $];
                        const valueSlice = currentSlice[valueStartIndex .. $];
                        popFrontAndReset();
                        return ElementType(kind, fullSlice, valueSlice);
                    }

                    indexOfQuote += valueStartIndex;
                    
                    // `--arg="..."...`
                    if (currentSlice.length != indexOfQuote + 1)
                    {
                        const kind       = Kind.error_inputAfterClosedQuote;
                        const fullSlice  = currentSlice[initialPosition .. $];
                        const valueSlice = currentSlice[valueStartIndex .. $];
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
                    const fullSlice  = currentSlice[initialPosition .. $];
                    const valueSlice = currentSlice[initialPosition .. $];
                    
                    // We might want to display some more info here.
                    const kind =
                    (){
                        import std.string : indexOf;
                        const indexOfSpace = indexOf(valueSlice, ' ');
                        if (indexOfSpace == -1)
                        {
                            return Kind.namedArgumentValue;
                        }
                        
                        // If the spaces got into the string, it was malformed from the start,
                        // or we have a rare edge case (see Kind.error_spaceAfterAssignment).
                        return Kind.error_spaceAfterAssignment;
                    }();

                    popFrontAndReset();
                    return ElementType(kind, fullSlice, valueSlice);
                }
            }

            if (getCurrentCharacter() == '-')
            {
                return parseArgumentName();
            }

            // Otherwise the entire string is just an argument value like the "value" below.
            // ["--name", "value"].
            // We don't care whether it was quoted on not in the source, we just return the whole thing.
            {
                const kind       = Kind.namedArgumentValueOrPositionalArgument;
                const fullSlice  = currentSlice;
                const valueSlice = currentSlice;
                _range.popFront();
                return ElementType(kind, fullSlice, valueSlice);
            }
        }
        // is not a named arg (technically these checks are not needed, but let's do it just in case).
        else if (
            // covers all special cases
            previousKind < Kind.valueBit
        
            || (previousKind & (Kind.errorBit | Kind.valueBit)) > 0)
        {
            assert(_positionWithinCurrentString == 0, "??");

            if (getCurrentCharacter() == '-')
            {
                _hasParsedAnyNamedArguments = true;
                return parseArgumentName();
            }

            {
                // If it's not a named arg, then it's just a value like this
                // --arg value
                // or like this
                // --arg "ba ba ba"
                // We see it unqouted, so we just return the value
                const kind = _hasParsedAnyNamedArguments
                    ? Kind.namedArgumentValueOrPositionalArgument
                    : Kind.positionalArgument;
                const fullSlice  = currentSlice;
                const valueSlice = currentSlice;
                _range.popFront();
                return ElementType(kind, fullSlice, valueSlice);
            }

        }
        else assert(false, "??");
    }
}

ArgTokenizer!TRange argTokenizer(TRange)(TRange range)
{
    auto result = ArgTokenizer!TRange(range);
    result.popFront();
    return result;
}

unittest
{
    import std.algorithm : equal;
    alias Kind = ArgToken.Kind;
    {
        auto args = ["hello", "world"];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.positionalArgument, "hello", "hello"),
            ArgToken(Kind.positionalArgument, "world", "world"),
        ]));
    }
    {
        auto args = ["--hello", "world"];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.fullNamedArgumentName, "--hello", "hello"),
            ArgToken(Kind.namedArgumentValueOrPositionalArgument, "world", "world"),
        ]));
    }
    {
        auto args = ["-hello", "world"];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.shortNamedArgumentName, "-hello", "hello"),
            ArgToken(Kind.namedArgumentValueOrPositionalArgument, "world", "world"),
        ]));
    }
    {
        auto args = ["-hello=world"];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.shortNamedArgumentName, "-hello", "hello"),
            ArgToken(Kind.namedArgumentValue, "world", "world"),
        ]));
    }
    {
        auto args = [`--hello="world"`];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.fullNamedArgumentName, "--hello", "hello"),
            ArgToken(Kind.namedArgumentValue, `"world"`, "world"),
        ]));
    }
    {
        auto args = [`--hello="--world"`];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.fullNamedArgumentName, "--hello", "hello"),
            ArgToken(Kind.namedArgumentValue, `"--world"`, "--world"),
        ]));
    }
    {
        auto args = ["--"];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.twoDashesDelimiter, "--", "--"),
        ]));
    }
    {
        auto args = ["-"];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.error_singleDash, "-", ""),
        ]));
    }
    {
        auto args = ["---"];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.error_threeOrMoreDashes, "---", "---"),
        ]));
    }
    {
        auto args = [" "];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.positionalArgument, " ", " "),
        ]));
    }
    {
        auto args = ["--arg="];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.fullNamedArgumentName, "--arg", "arg"),
            ArgToken(Kind.error_noValueForNamedArgument, "", ""),
        ]));
    }
    {
        auto args = [`--arg="`];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.fullNamedArgumentName, "--arg", "arg"),
            ArgToken(Kind.error_malformedQuotes, `"`, `"`),
        ]));
    }
    {
        auto args = [`--arg="" stuff`];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.fullNamedArgumentName, "--arg", "arg"),
            ArgToken(Kind.error_inputAfterClosedQuote, `"" stuff`, `" stuff`),
        ]));
    }
    {
        auto args = [`--arg="stuff`];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.fullNamedArgumentName, "--arg", "arg"),
            ArgToken(Kind.error_unclosedQuotes, `"stuff`, "stuff"),
        ]));
    }
    {
        auto args = [`--arg= `];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.fullNamedArgumentName, "--arg", "arg"),
            ArgToken(Kind.error_spaceAfterAssignment, " ", " "),
        ]));
    }
    {
        // --arg "--arg=stuff"
        // is expected to parse as
        // --arg --arg=stuff
        auto args = [`--arg`, `--arg=stuff`];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.fullNamedArgumentName, "--arg", "arg"),
            ArgToken(Kind.fullNamedArgumentName, "--arg", "arg"),
            ArgToken(Kind.namedArgumentValue, "stuff", "stuff"),
        ]));
    }
    {
        auto args = ["a", "--a", "a", "-a=a"];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.positionalArgument, "a", "a"),

            ArgToken(Kind.fullNamedArgumentName, "--a", "a"),
            ArgToken(Kind.namedArgumentValueOrPositionalArgument, "a", "a"),
            
            ArgToken(Kind.shortNamedArgumentName, "-a", "a"),
            ArgToken(Kind.namedArgumentValue, "a", "a"),
        ]));
    }
    {
        auto args = ["--a", "Штука"];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.fullNamedArgumentName, "--a", "a"),
            ArgToken(Kind.namedArgumentValueOrPositionalArgument, "Штука", "Штука"),
        ]));
    }
    {
        auto args = [`--a="Штука"`];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.fullNamedArgumentName, "--a", "a"),
            ArgToken(Kind.namedArgumentValue, `"Штука"`, "Штука"),
        ]));
    }
    {
        auto args = ["--a", "物事"];
        assert(equal(argTokenizer(args), [
            ArgToken(Kind.fullNamedArgumentName, "--a", "a"),
            ArgToken(Kind.namedArgumentValueOrPositionalArgument, "物事", "物事"),
        ]));
    }
    
    // // Copy and paste around for debugging.

    // import std.stdio : writeln;
    // import std.array : array;
    
    // auto p = argTokenizer(args);

    // writeln(p.front);
    // writeln(p.front.valueSlice);
    // // writeln(p._range.front[p._positionWithinCurrentString]);
    // writeln(p._positionWithinCurrentString);
    
    // p.popFront();
    
    // auto a = p.front();
    // writeln(a);
    // writeln(a.fullSlice);
    // writeln(a.nameSlice);
    // writeln(a.kind);
    // writeln(p._positionWithinCurrentString);

    // p.popFront();
    // writeln(p.empty);
}

