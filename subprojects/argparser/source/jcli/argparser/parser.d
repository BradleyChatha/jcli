module jcli.argparser.parser;

import std;

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
    void popFront() nothrow
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
        enum Kind
        {
            rawText,
            argument
        }

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
    void popFront() nothrow
    {
        scope(exit) this._range.popFront();

        this._front = Result.init;
        if(this._range.empty)
        {
            this._empty = true;
            return;
        }

        this._front.fullSlice = this._range.front;
        if(this._front.fullSlice[0] == '-')
        {
            this._front.kind = Result.Kind.argument;
            const start = 0;
            auto end = 0;
            while(end < this._front.fullSlice.length && this._front.fullSlice[end] == '-')
                end++;
            this._front.dashSlice = this._front.fullSlice[start..end];
            this._front.nameSlice = this._front.fullSlice[end..$];
        }
        else
            this._front.kind = Result.Kind.rawText;
    }
}
///
unittest
{
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