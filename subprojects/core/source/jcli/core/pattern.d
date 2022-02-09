module jcli.core.pattern;

struct Pattern
{
    string[] patterns;
    
    @safe
    static Pattern fromString(string pattern) pure 
    {
        import std.string : split;
        return Pattern(pattern.split('|'));
    }

    @safe @nogc
    auto matches(bool caseInsensitive)(string input) pure nothrow
    {
        return patterns.filter!((p) {
            import std.uni;
            static if (caseInsensitive)
                return (sicmp(pattern, input) == 0);
            else
                return p == input;
        });
    }
    ///
    unittest
    {
        import std.algorithm : equal;
        auto p = Pattern.fromString("a|A");
        {
            enum caseInsensitive = true;
            assert(equal(p.matches!(caseInsensitive)("a"), ["a", "A"]));
            assert(equal(p.matches!(caseInsensitive)("b"), []));
        }
        {
            enum caseInsensitive = false;
            assert(equal(p.matches!(caseInsensitive)("a"), ["a"]));
            assert(equal(p.matches!(caseInsensitive)("A"), ["A"]));
            assert(equal(p.matches!(caseInsensitive)("b"), []));
        }
    }

    @safe @nogc
    string firstMatch(bool caseInsensitive)(string input) nothrow pure
    {
        static struct Result
        {
            bool matched;
            string pattern;
        }
        auto m = matches!caseInsensitive(input);
        if (m.empty)
            return Result(false, null);
        return Result(true, m.front);
    }
    
}