module jcli.core.pattern;

import std;

struct Pattern
{
    static struct Result
    {
        bool matched;
        string pattern;
    }

    private string _pattern;

    @safe @nogc
    this(string pattern) nothrow pure
    {
        this._pattern = pattern;
    }

    @safe /*@nogc*/
    auto patterns() /*nothrow*/ pure inout
    {
        return this._pattern.splitter('|');
    }
    ///
    unittest
    {
        auto p = Pattern("a|bc|one|two three");
        assert(p.patterns.equal([
            "a",
            "bc",
            "one",
            "two three"
        ]));
    }

    @safe /*@nogc*/
    inout(Result) match(string input, bool insensitive = false) /*nothrow*/ pure inout
    {
        Result r;
        foreach(pattern; this.patterns)
        {
            import std.uni : toLower;
            if(
                (!insensitive && pattern == input)
                || (insensitive && pattern.equal(input.map!toLower.map!(ch => cast(char)ch)))
            )
            {
                r = Result(true, pattern);
                break;
            }
        }
        return r;
    }
    ///
    unittest
    {
        auto p = Pattern("a|bc|one|two three");
        assert(p.match("a")         == Result(true, "a"));
        assert(p.match("one")       == Result(true, "one"));
        assert(p.match("two three") == Result(true, "two three"));
        assert(p.match("cb")        == Result(false, null));
    }

    @safe @nogc
    string pattern() nothrow pure const
    {
        return this._pattern;
    }
}