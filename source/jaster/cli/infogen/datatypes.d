module jaster.cli.infogen.datatypes;

import std.typecons : Flag, Nullable;
import jaster.cli.parser, jaster.cli.infogen, jaster.cli.result;

alias AllowPartialMatch = Flag!"partialMatch";

/++
 + Attach any value from this enum onto an argument to specify what parsing action should be performed on it.
 + ++/
enum CommandArgAction
{
    /// Perform the default parsing action.
    default_,

    /++
     + Increments an argument for every time it is defined inside the parameters.
     +
     + Arg Type: Named
     + Value Type: Any type that supports `++`.
     + Arg becomes optional: true
     + ++/
    count,
}

enum CommandArgExistance
{
    default_ = 0, // Can only appear once, and is mandatory.
    optional = 1 << 0,
    multiple = 1 << 1,
}

enum CommandArgParseScheme
{
    default_,
    bool_,
    allowRepeatedName // Allows: -v, -vvvv(n+1). Special case: -vsome_value ignores the "some_value" and leaves it for the next parse cycle.
}

struct CommandInfo(CommandT)
{
    Pattern pattern;
    string description;
    NamedArgumentInfo!CommandT[] namedArgs;
    PositionalArgumentInfo!CommandT[] positionalArgs;
    Nullable!(RawListArgumentInfo!CommandT) rawListArg;
}

alias ArgumentActionFunc(CommandT) = Result!void function(string value, ref CommandT commandInstance);
struct ArgumentInfo(UDA, CommandT)
{
    // NOTE: Do not use Nullable in this struct as it causes compile-time errors.
    //       It hits a code path that uses memcpy, which of course doesn't work in CTFE.

    string identifier;
    UDA uda;
    CommandArgAction action;
    CommandArgGroup group;
    CommandArgExistance existance;
    CommandArgParseScheme parseScheme;

    // I wish I could defer this to another part of the library instead of here.
    // However, any attempt I've made to keep around aliases to parameters has resulted
    // in a dreaded "Cannot infer type from template arguments CommandInfo!CommandType".
    // 
    // My best guesses are: 
    //  1. More weird behaviour with the hidden context pointer D inserts.
    //  2. I might've hit some kind of internal template limit that the compiler is just giving a bad message for.
    ArgumentActionFunc!CommandT actionFunc;
}

alias NamedArgumentInfo(CommandT) = ArgumentInfo!(CommandNamedArg, CommandT);
alias PositionalArgumentInfo(CommandT) = ArgumentInfo!(CommandPositionalArg, CommandT);
alias RawListArgumentInfo(CommandT) = ArgumentInfo!(CommandRawListArg, CommandT);

struct Pattern
{
    import std.algorithm : all;
    import std.ascii : isWhite;

    string pattern;

    //invariant(pattern.length > 0, "Attempting to use null pattern.");

    void assertNoWhitespace() const
    {
        assert(this.pattern.all!(c => !c.isWhite), "The pattern '"~this.pattern~"' is not allowed to contain whitespace.");
    }

    auto byEach()
    {
        import std.algorithm : splitter;
        return this.pattern.splitter('|');
    }

    string defaultPattern()
    {
        return (this.pattern is null) ? "DEFAULT" : this.byEach.front;
    }

    bool matchSpaceless(string toTestAgainst)
    {
        import std.algorithm : any;
        return this.byEach.any!(str => str == toTestAgainst);
    }
    ///
    unittest
    {
        assert(Pattern("v|verbose").matchSpaceless("v"));
        assert(Pattern("v|verbose").matchSpaceless("verbose"));
        assert(!Pattern("v|verbose").matchSpaceless("lalafell"));
    }

    bool matchSpacefull(ref ArgPullParser parser, AllowPartialMatch allowPartial = AllowPartialMatch.no)
    {
        import std.algorithm : splitter;

        foreach(subpattern; this.byEach)
        {
            auto savedParser = parser.save();
            bool isAMatch = true;
            bool isAPartialMatch = false;
            foreach(split; subpattern.splitter(" "))
            {
                if(savedParser.empty
                || !(savedParser.front.type == ArgTokenType.Text && savedParser.front.value == split))
                {
                    isAMatch = false;
                    break;
                }

                isAPartialMatch = true;
                savedParser.popFront();
            }

            if(isAMatch || (isAPartialMatch && allowPartial))
            {
                parser = savedParser;
                return true;
            }
        }

        return false;
    }
    ///
    unittest
    {
        // Test empty parsers.
        auto parser = ArgPullParser([]);
        assert(!Pattern("v").matchSpacefull(parser));

        // Test that the parser's position is moved forward correctly.
        parser = ArgPullParser(["v", "verbose"]);
        assert(Pattern("v").matchSpacefull(parser));
        assert(Pattern("verbose").matchSpacefull(parser));
        assert(parser.empty);

        // Test that a parser that fails to match isn't moved forward at all.
        parser = ArgPullParser(["v", "verbose"]);
        assert(!Pattern("lel").matchSpacefull(parser));
        assert(parser.front.value == "v");

        // Test that a pattern with spaces works.
        parser = ArgPullParser(["give", "me", "chocolate"]);
        assert(Pattern("give me").matchSpacefull(parser));
        assert(parser.front.value == "chocolate");

        // Test that multiple patterns work.
        parser = ArgPullParser(["v", "verbose"]);
        assert(Pattern("lel|v|verbose").matchSpacefull(parser));
        assert(Pattern("lel|v|verbose").matchSpacefull(parser));
        assert(parser.empty);
    }
}