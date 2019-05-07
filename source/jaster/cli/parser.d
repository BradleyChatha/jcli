module jaster.cli.parser;

private
{
    import std.typecons : Flag;
}

enum ArgTokenType
{
    None,
    Text,
    ArgumentName,
    EOF
}

struct ArgToken
{
    string value;
    ArgTokenType type;
}

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
        ArgToken _currentToken;
    }

    this(string[] args)
    {
        this._args = args;
        this.popFront();
    }

    /// Range interface ///
    public
    {
        void popFront()
        {
            this.nextToken();
        }

        ArgToken front()
        {
            return this._currentToken;
        }

        bool empty()
        {
            return this._currentToken.type == ArgTokenType.EOF;
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
                this.nextArg();
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
                this._currentToken = ArgToken(this.readToEnd(OrSpace.yes, OrEqualSign.yes), ArgTokenType.ArgumentName);
                return;
            }
            else if(slice.length >= 1 && slice[0] == '-')
            {
                enforce(slice.length > 1, "Unfinished argument name. Found '-' but no character following it.");

                this._currentCharIndex += 2; // += 2 so we skip over the arg name.
                this._currentToken = ArgToken(slice[1..2], ArgTokenType.ArgumentName);

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
    assert(tokens[2]  == ArgToken("config",                      ArgTokenType.ArgumentName));
    assert(tokens[3]  == ArgToken("MyConfig.json",               ArgTokenType.Text));
    assert(tokens[4]  == ArgToken("config",                      ArgTokenType.ArgumentName));
    assert(tokens[5]  == ArgToken("MyConfig.json",               ArgTokenType.Text));

    // Short hand named arguments.
    assert(tokens[6]  == ArgToken("c",                           ArgTokenType.ArgumentName));
    assert(tokens[7]  == ArgToken("MyConfig.json",               ArgTokenType.Text));
    assert(tokens[8]  == ArgToken("c",                           ArgTokenType.ArgumentName));
    assert(tokens[9]  == ArgToken("MyConfig.json",               ArgTokenType.Text));
    assert(tokens[10] == ArgToken("c",                           ArgTokenType.ArgumentName));
    assert(tokens[11] == ArgToken("MyConfig.json",               ArgTokenType.Text));

    // Plain text.
    assert(tokens[12] == ArgToken("Some Positional Argument",    ArgTokenType.Text));
}