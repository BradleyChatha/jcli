/// The various datatypes provided by infogen.
module jaster.cli.infogen.datatypes;

import std.typecons : Flag, Nullable;
import jaster.cli.parser, jaster.cli.infogen, jaster.cli.result;

/// Used with `Pattern.matchSpacefull`.
alias AllowPartialMatch = Flag!"partialMatch";

/++
 + Describes the existence of a command argument. i.e., how many times can it appear; is it optional, etc.
 + ++/
enum CommandArgExistence
{
    /// Can only appear once, and is mandatory.
    default_ = 0,

    /// Argument can be omitted.
    optional = 1 << 0,

    /// Argument can be redefined.
    multiple = 1 << 1,
}

/++
 + Describes the parsing scheme used when parsing the argument's value.
 + ++/
enum CommandArgParseScheme
{
    /// Default parsing scheme.
    default_,

    /// Parsing scheme that special cases bools.
    bool_,

    /// Allows: -v, -vvvv(n+1). Special case: -vsome_value ignores the "some_value" and leaves it for the next parse cycle.
    allowRepeatedName
}

/++
 + Describes a command and its parameters.
 +
 + Params:
 +  CommandT = The command that this information belongs to.
 +
 + See_Also:
 +  `jaster.cli.infogen.gen.getCommandInfoFor` for generating instances of this struct.
 + ++/
struct CommandInfo(CommandT)
{
    /// The command's `Pattern`, if it has one.
    Pattern pattern;

    /// The command's description.
    string description;

    /// Information about all of this command's named arguments.
    NamedArgumentInfo!CommandT[] namedArgs;

    /// Information about all of this command's positional arguments.
    PositionalArgumentInfo!CommandT[] positionalArgs;

    /// Information about this command's raw list argument, if it has one.
    Nullable!(RawListArgumentInfo!CommandT) rawListArg;
}

/// The function used to perform an argument's setter action.
alias ArgumentActionFunc(CommandT) = Result!void function(string value, ref CommandT commandInstance);

/++
 + Contains information about command's argument.
 +
 + Params:
 +  UDA = The UDA that defines the argument (e.g. `@CommandNamedArg`, `@CommandPositionalArg`)
 +  CommandT = The command type that this argument belongs to.
 +
 + See_Also:
 +  `jaster.cli.infogen.gen.getCommandInfoFor` for generating instances of this struct.
 + ++/
struct ArgumentInfo(UDA, CommandT)
{
    // NOTE: Do not use Nullable in this struct as it causes compile-time errors.
    //       It hits a code path that uses memcpy, which of course doesn't work in CTFE.

    /// The result of `__traits(identifier)` on the argument's symbol.
    string identifier;

    /// The UDA attached to the argument's symbol.
    UDA uda;

    /// The binding action performed to create the argument's value.
    CommandArgAction action;

    /// The user-defined `CommandArgGroup`, this is `.init` for the default group.
    CommandArgGroup group;

    /// Describes the existence properties for this argument.
    CommandArgExistence existence;

    /// Describes how this argument is to be parsed.
    CommandArgParseScheme parseScheme;

    /// Describes the configuration of this specific argument.
    CommandArgConfig config;

    // I wish I could defer this to another part of the library instead of here.
    // However, any attempt I've made to keep around aliases to parameters has resulted
    // in a dreaded "Cannot infer type from template arguments CommandInfo!CommandType".
    // 
    // My best guesses are: 
    //  1. More weird behaviour with the hidden context pointer D inserts.
    //  2. I might've hit some kind of internal template limit that the compiler is just giving a bad message for.

    /// The function used to perform the binding action for this argument.
    ArgumentActionFunc!CommandT actionFunc;
}

alias NamedArgumentInfo(CommandT) = ArgumentInfo!(CommandNamedArg, CommandT);
alias PositionalArgumentInfo(CommandT) = ArgumentInfo!(CommandPositionalArg, CommandT);
alias RawListArgumentInfo(CommandT) = ArgumentInfo!(CommandRawListArg, CommandT);

/++
 + A pattern is a simple string format for describing multiple "patterns" that can be matched to user provided input.
 +
 + Description:
 +  A simple pattern of "hello" would match, and only match "hello".
 +
 +  A pattern of "hello|world" would match either "hello" or "world".
 +
 +  Some patterns may contain spaces, other may not, it should be documented if possible.
 + ++/
struct Pattern
{
    import std.algorithm : all;
    import std.ascii : isWhite;

    /// The raw pattern string.
    string pattern;

    //invariant(pattern.length > 0, "Attempting to use null pattern.");

    /// Asserts that there is no whitespace within the pattern.
    void assertNoWhitespace() const
    {
        assert(this.pattern.all!(c => !c.isWhite), "The pattern '"~this.pattern~"' is not allowed to contain whitespace.");
    }

    /// Returns: An input range consisting of every subpattern within this pattern.
    auto byEach()
    {
        import std.algorithm : splitter;
        return this.pattern.splitter('|');
    }

    /++
     + The default subpattern can be used as the default 'user-facing' name to display to the user.
     +
     + Returns:
     +  Either the first subpattern, or "DEFAULT" if this pattern is null.
     + ++/
    string defaultPattern()
    {
        return (this.pattern is null) ? "DEFAULT" : this.byEach.front;
    }

    /++
     + Matches the given input string without splitting up by spaces.
     +
     + Params:
     +  toTestAgainst = The string to test for.
     +  isCaseSensitive = `true` if casing matters, `false` otherwise.
     +
     + Returns:
     +  `true` if there was a match for the given string, `false` otherwise.
     + ++/
    bool matchSpaceless(string toTestAgainst, bool isCaseSensitive = true)
    {
        import std.algorithm : any, equal;
        import std.string : toLower;
        return this.byEach.any!(str => (isCaseSensitive) ? str == toTestAgainst : str.toLower.equal(toTestAgainst.toLower));
    }
    ///
    unittest
    {
        assert(Pattern("v|verbose").matchSpaceless("v"));
        assert(Pattern("v|verbose").matchSpaceless("verbose"));
        assert(!Pattern("v|verbose").matchSpaceless("lalafell"));

        assert(Pattern("abc").matchSpaceless("abc", true));
        assert(!Pattern("abc").matchSpaceless("abC", true));
        assert(Pattern("abc").matchSpaceless("abc", false));
        assert(Pattern("abc").matchSpaceless("abC", false));
    }

    /++
     + Advances the given token parser in an attempt to match with any of this pattern's subpatterns.
     +
     + Description:
     +  On successful or partial match (if `allowPartial` is `yes`) the given `parser` will be advanced to the first
     +  token that is not part of the match.
     +
     +  e.g. For the pattern ("hey there"), if you matched it with the tokens ["hey", "there", "me"], the resulting parser
     +  would only have ["me"] left.
     +
     +  On a failed match, the given parser is left unmodified.
     +
     + Bugs:
     +  If a partial match is allowed, and a partial match is found before a valid full match is found, then only the
     +  partial match is returned.
     +
     + Params:
     +  parser = The parser to match against.
     +  allowPartial = If `yes` then allow partial matches, otherwise only allow full matches.
     +
     + Returns:
     +  `true` if there was a full or partial (if allowed) match, otherwise `false`.
     + ++/
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