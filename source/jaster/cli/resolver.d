module jaster.cli.resolver;

import std.range;
import jaster.cli.parser;

enum CommandNodeType
{
    ERROR,
    root,
    partialWord,
    finalWord
}

struct CommandResolveResult(UserDataT)
{
    bool                  success;
    CommandNode!UserDataT value;
}

@safe
struct CommandNode(UserDataT)
{
    string                  word;
    CommandNodeType         type;
    CommandNode!UserDataT[] children;
    UserDataT               userData;

    CommandResolveResult!UserDataT byCommandSentence(RangeOfStrings)(RangeOfStrings range)
    {        
        auto current = this;
        for(; !range.empty; range.popFront())
        {
            auto commandWord = range.front;
            auto currentBeforeChange = current;

            foreach(child; current.children)
            {
                if(child.word == commandWord)
                {
                    current = child;
                    break;
                }
            }

            // Above loop failed.
            if(currentBeforeChange.word == current.word)
            {
                current = this; // Makes result.success become false.
                break;
            }
        }

        typeof(return) result;
        result.value   = current;
        result.success = range.empty && current.word != this.word;
        return result;
    }
}

@safe
final class CommandResolver(UserDataT)
{
    alias NodeT = CommandNode!UserDataT;

    private
    {
        CommandNode!UserDataT _rootNode;
    }

    this()
    {
        this._rootNode.type = CommandNodeType.root;
    }

    void define(string commandSentence, UserDataT userDataForFinalNode)
    {
        import std.algorithm : splitter, filter, any, countUntil;
        import std.format    : format; // For errors.
        import std.range     : walkLength;
        import std.uni       : isWhite;

        auto words = commandSentence.splitter!(a => a == ' ').filter!(w => w.length > 0);
        assert(!words.any!(w => w.any!isWhite), "Words inside a command sentence cannot contain whitespace.");

        const wordCount   = words.walkLength;
        scope currentNode = &this._rootNode;
        size_t wordIndex  = 0;
        foreach(word; words)
        {
            const isLastWord = (wordIndex == wordCount - 1);
            wordIndex++;

            const existingNodeIndex = currentNode.children.countUntil!(c => c.word == word);

            NodeT node;
            node.word     = word;
            node.type     = (isLastWord) ? CommandNodeType.finalWord : CommandNodeType.partialWord;
            node.userData = (isLastWord) ? userDataForFinalNode : UserDataT.init;

            if(existingNodeIndex == -1)
            {
                currentNode.children ~= node;
                currentNode = &currentNode.children[$-1];
                continue;
            }
            
            currentNode = &currentNode.children[existingNodeIndex];
            assert(
                currentNode.type == CommandNodeType.partialWord, 
                "Cannot append word '%s' onto word '%s' as the latter word is not a partialWord, but instead a %s."
                .format(word, currentNode.word, currentNode.type)
            );
        }
    }

    CommandResolveResult!UserDataT resolve(RangeOfStrings)(RangeOfStrings words)
    {
        return this._rootNode.byCommandSentence(words);
    }

    CommandResolveResult!UserDataT resolve(string sentence) pure
    {
        import std.algorithm : splitter, filter;
        return this.resolve(sentence.splitter(' ').filter!(w => w.length > 0));
    }

    CommandResolveResult!UserDataT resolveAndAdvance(ref ArgPullParser parser)
    {
        import std.algorithm : map;
        import std.range     : take;

        typeof(return) lastSuccessfulResult;
        
        // Pretty sure this is like O(n^n), but if you ever have an "n" higher than 5, you have different issues.
        auto   parserCopy   = parser;
        size_t amountToTake = 0;
        while(true)
        {
            if(parser.empty || parser.front.type != ArgTokenType.Text)
                return lastSuccessfulResult;

            auto result = this.resolve(parserCopy.take(++amountToTake).map!(t => t.value));
            if(!result.success)
                return lastSuccessfulResult;

            lastSuccessfulResult = result;
            parser.popFront();
        }
    }

    @property
    NodeT root()
    {
        return this._rootNode;
    }
}
///
@("Main test for CommandResolver")
@safe
unittest
{
    // Define UserData as a struct containing an execution method. Define a UserData which toggles a value.
    static struct UserData
    {
        void delegate() @safe execute;
    }

    bool executeValue;
    void toggleValue() @safe
    {
        executeValue = !executeValue;
    }

    auto userData = UserData(&toggleValue);

    // Create the resolver and define three command paths: "toggle", "please toggle", and "please tog".
    // Tree should look like:
    //       [root]
    //      /      \
    // toggle       please
    //             /      \
    //          toggle    tog
    auto resolver = new CommandResolver!UserData;
    resolver.define("toggle", userData);
    resolver.define("please toggle", userData);
    resolver.define("please tog", userData);

    auto result = resolver.resolve("toggle");
    assert(result.success);
    assert(result.value.word == "toggle");
    assert(result.value.type == CommandNodeType.finalWord);
    assert(result.value.userData.execute !is null);
    result.value.userData.execute();
    assert(executeValue == true);

    result = resolver.resolve("please");
    assert(result.success);
    assert(result.value.word            == "please");
    assert(result.value.type            == CommandNodeType.partialWord);
    assert(result.value.children.length == 2);
    assert(result.value.userData        == UserData.init);

    result = resolver.resolve("please toggle");
    assert(result.success);
    assert(result.value.word == "toggle");
    assert(result.value.type == CommandNodeType.finalWord);
    result.value.userData.execute();
    assert(executeValue == false);

    result = resolver.resolve("please tog");
    assert(result.success);
    assert(result.value.word == "tog");
    assert(result.value.type == CommandNodeType.finalWord);
    result.value.userData.execute();
    assert(executeValue == true);

    assert(!resolver.resolve(null).success);
    assert(!resolver.resolve("toggle please").success);
    assert(!resolver.resolve("He she we, wombo.").success);
}

@("Test CommandResolver.resolveAndAdvance")
@safe
unittest
{
    auto resolver = new CommandResolver!int();
    auto parser   = ArgPullParser(["a", "b", "--c", "-d", "e"]);

    resolver.define("a b e", 0);

    auto parserCopy = parser;
    auto result     = resolver.resolveAndAdvance(parserCopy);
    assert(result.success);
    assert(result.value.type == CommandNodeType.partialWord);
    assert(result.value.word == "b");
    assert(parserCopy.front.value == "c", parserCopy.front.value);
}