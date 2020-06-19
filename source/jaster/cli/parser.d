/// Contains a pull parser for command line arguments.
module jaster.cli.parser;

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
                enforce(slice.length > 2, "Unfinished argument name. Found '--' but no characters following it.");

                this._currentCharIndex += 2;
                this._currentToken = ArgToken(this.readToEnd(OrSpace.yes, OrEqualSign.yes), ArgTokenType.LongHandArgument);
                return;
            }
            else if(slice.length >= 1 && slice[0] == '-')
            {
                enforce(slice.length > 1, "Unfinished argument name. Found '-' but no character following it.");

                this._currentCharIndex += 2; // += 2 so we skip over the arg name.
                this._currentToken = ArgToken(slice[1..2], ArgTokenType.ShortHandArgument);

                // Skip over the equals sign if there is one.
                if(this._currentCharIndex < this.currentArg.length
                && this.currentArg[this._currentCharIndex] == '=')
                    this._currentCharIndex++;

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
        "Some Positional Argument"
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
}

// Issue: .init.empty must be true
unittest
{
    assert(ArgPullParser.init.empty);
}

// Test: unparsedArgs
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