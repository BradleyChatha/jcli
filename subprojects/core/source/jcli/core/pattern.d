module jcli.core.pattern;

struct Pattern
{
    import std.ascii;
    import std.algorithm;
    import std.exception : assumeWontThrow;

    string[] items;
    alias items this;
    
    this(string[] items) @safe pure nothrow
    in
    {
        assert(items.length > 0, "The pattern must contain at least one item.");
        assert(items.all!(i => i.all!isASCII.assumeWontThrow), "The pattern items must be ascii.");
        assert(items.all!(i => i.length > 0), "The pattern must not contain empty items.");
        assert(items.map!(i => i.length).maxIndex == 0, "The first item in the items list must be the longest");
    }
    do
    {
        this.items = items;
    }
    
    static Pattern parse(string patternString) @safe pure 
    {
        import std.string : split;
        
        auto items = patternString.split('|');
        return Pattern(items);
    }

    @safe // TODO: when and how does it allocate tho? @nogc
    auto matches(bool caseInsensitive)(string input) pure nothrow
    {
        return items.filter!((p) {
            import std.algorithm : map, equal;

            static if (caseInsensitive)
            {
                import std.ascii : toLower;
                if (p.length != input.length)
                    return false;
                foreach (index; 0 .. p.length)
                {
                    if (toLower(p[index]) != toLower(input[index]))
                        return false;
                }
                return true;
            }
            else
                return p == input;
        });
    }
    ///
    unittest
    {
        import std.algorithm : equal;
        auto p = Pattern.parse("a|A");
        {
            enum caseInsensitive = true;
            assert(equal(p.matches!(caseInsensitive)("a"), ["a", "A"]));
            assert(equal(p.matches!(caseInsensitive)("b"), string[].init));
        }
        {
            enum caseInsensitive = false;
            assert(equal(p.matches!(caseInsensitive)("a"), ["a"]));
            assert(equal(p.matches!(caseInsensitive)("A"), ["A"]));
            assert(equal(p.matches!(caseInsensitive)("b"), string[].init));
        }
    }
    // @safe @nogc
    // string firstMatch(bool caseInsensitive)(string input) nothrow pure
    // {
    //     static struct Result
    //     {
    //         bool matched;
    //         string pattern;
    //     }
    //     auto m = matches!caseInsensitive(input);
    //     if (m.empty)
    //         return Result(false, null);
    //     return Result(true, m.front);
    // }
}