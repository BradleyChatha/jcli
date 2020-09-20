/// Functionality for defining and resolving command "sentences".
module jaster.cli.resolver;

import std.range;
import jaster.cli.parser;

/// The type of a `CommandNode`.
enum CommandNodeType
{
    /// Failsafe
    ERROR,

    /// Used for the root `CommandNode`.
    root,

    /// Used for `CommandNodes` that don't contain a command, but instead contain child `CommandNodes`.
    ///
    /// e.g. For "build all libraries", "build" and "all" would be `partialWords`.
    partialWord,

    /// Used for `CommandNodes` that contain a command.
    ///
    /// e.g. For "build all libraries", "libraries" would be a `finalWord`.
    finalWord
}

/++
 + The result of a command resolution attempt.
 +
 + Params:
 +  UserDataT = See `CommandResolver`'s documentation.
 + ++/
struct CommandResolveResult(UserDataT)
{
    /// Whether the resolution was successful (true) or not (false).
    bool success;

    /// The resolved `CommandNode`. This value is undefined when `success` is `false`.
    CommandNode!UserDataT value;
}

/++
 + Contains a single "word" within a command "sentence", see `CommandResolver`'s documentation for more.
 +
 + Params:
 +  UserDataT = See `CommandResolver`'s documentation.
 + ++/
@safe
struct CommandNode(UserDataT)
{
    /// The word this node contains.
    string word;

    /// What type of node this is.
    CommandNodeType type;

    /// The children of this node.
    CommandNode!UserDataT[] children;

    /// User-provided data for this node. Note that partial words don't contain any user data.
    UserDataT userData;

    /// A string of the entire sentence up to (and including) this word, please note that $(B currently only final words) have this field set.
    string sentence;

    /// See_Also: `CommandResolver.resolve`
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
    
    /++
     + Retrieves all child `CommandNodes` that are of type `CommandNodeType.finalWord`.
     +
     + Notes:
     +  While similar to `CommandResolver.finalWords`, this function one major difference.
     +
     +  It is less efficient, since `CommandResolver.finalWords` builds and caches its value whenever a sentence is defined, while
     +  this function (currently) has to recreate its value each time.
     +
     +  Furthermore, as with `CommandResolver.finalWords`, the returned array of nodes are simply copies of the actual nodes used
     +  and returned by `CommandResolver.resolve`. So don't expect any changes to be reflected anywhere. 
     +
     +  Technically the same could be done here, but I'm lazy, so for now you get extra GC garbage.
     +
     + Returns:
     +  All child final words.
     + ++/
    CommandNode!UserDataT[] finalWords()
    {
        if(this.type != CommandNodeType.partialWord && this.type != CommandNodeType.root)
            return null;

        typeof(return) nodes;

        void addFinalNodes(CommandNode!UserDataT repetitionNode)
        {
            foreach(childNode; repetitionNode.children)
            {
                if(childNode.type == CommandNodeType.finalWord)
                    nodes ~= childNode;
                else if(childNode.type == CommandNodeType.partialWord)
                    addFinalNodes(childNode);
                else
                    assert(false, "Malformed tree.");
            }
        }

        addFinalNodes(this);
        return nodes;
    }
}

/++
 + A helper class where you can define command "sentences", and then resolve (either partially or fully) commands
 + from "sentences" provided by the user.
 +
 + Params:
 +  UserDataT = User-provided data for each command (`CommandNodes` of type `CommandNodeType.finalWord`).
 +
 + Description:
 +  In essence, this class is just an abstraction around a basic tree structure (`CommandNode`), to make it easy to
 +  both define and search the tree.
 +
 +  First of all, JCLI supports commands having multiple "words" within them, such as "build all libs"; "remote get-url", etc.
 +  This entire collection of "words" is referred to as a "sentence".
 +
 +  The tree for the resolver consists of words pointing to any following words (`CommandNodeType.partialWord`), ultimately ending each
 +  branch with the final command word (`CommandNodeType.finalWord`).
 +
 +  For example, if we had the following commands "build libs"; "build apps", and "test libs", the tree would look like the following.
 +
 +  Legend = `[word] - partial word` and `<word> - final word`.
 +
 +```
 +         root
 +         /  \
 +    [test]  [build]
 +      |       |    \  
 +    <libs>  <libs>  <apps>
 +```
 +
 +  Because this class only handles resolving commands, and nothing more than that, the application can attach whatever data it wants (`UserDataT`)
 +  so it can later perform its own processing (description; arg info; execution delegates, etc.)
 +
 +  I'd like to point out however, $(B only final words) are given user data as partial words aren't supposed to represent commands.
 +
 +  Finally, given the above point, if you tried to define "build release" and "build" at the same time, you'd fail an assert as "build" cannot be
 +  a partial word and a final word at the same time. This does kind of suck in some cases, but there are workarounds e.g. defining "build", then passing "release"/"debug"
 +  as arguments.
 +
 + Usage:
 +  Build up your tree by using `CommandResolver.define`.
 +
 +  Resolve commands via `CommandResolver.resolve` or `CommandResolver.resolveAndAdvance`.
 + ++/
@safe
final class CommandResolver(UserDataT)
{
    /// The `CommandNode` instatiation for this resolver.
    alias NodeT = CommandNode!UserDataT;

    private
    {
        CommandNode!UserDataT _rootNode;
        string[]              _sentences;
        NodeT[]               _finalWords;
    }

    this()
    {
        this._rootNode.type = CommandNodeType.root;
    }

    /++
     + Defines a command sentence.
     +
     + Description:
     +  A "sentence" consists of multiple "words". A "word" is a string of characters, each seperated by any amount of spaces.
     +
     +  For instance, `"build all libs"` contains the words `["build", "all", "libs"]`.
     +
     +  The last word within a sentence is known as the final word (`CommandNodeType.finalWord`), which is what defines the
     +  actual command associated with this sentence. The final word is the only word that has the `userDataForFinalNode` associated with it.
     +
     +  The rest of the words are known as partial words (`CommandNodeType.partialWord`) as they are only a partial part of a full sentence.
     +  (I hate all of this as well, don't worry).
     +
     +  So for example, if you wanted to define the command "build all libs" with some custom user data containing, for example, a description and
     +  an execute function, you could do something such as.
     +
     +  `myResolver.define("build all libs", MyUserData("Builds all Libraries", &buildAllLibsCommand))`
     +
     +  You can then later use `CommandResolver.resolve` or `CommandResolver.resolveAndAdvance`, using a user-provided string, to try and resolve
     +  to the final command.
     +
     + Params:
     +  commandSentence      = The sentence to define.
     +  userDataForFinalNode = The `UserDataT` to attach to the `CommandNode` for the sentence's final word.
     + ++/
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
            node.sentence = (isLastWord) ? commandSentence : null;

            if(isLastWord)
                this._finalWords ~= node;

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

        this._sentences ~= commandSentence;
    }
    
    /++
     + Attempts to resolve a range of words/a sentence into a `CommandNode`.
     +
     + Notes:
     +  The overload taking a `string` will split the string by spaces, the same way `CommandResolver.define` works.
     +
     + Description:
     +  There are three potential outcomes of this function.
     +
     +  1. The words provided fully match a command sentence. The value of `returnValue.value.type` will be `CommandNodeType.finalWord`.
     +  2. The words provided a partial match of a command sentence. The value of `returnValue.value.type` will be `CommandNodeType.partialWord`.
     +  3. Neither of the above. The value of `returnValue.success` will be `false`.
     +
     +  How you handle these outcomes, and which ones you handle, are entirely up to your application.
     +
     + Params:
     +  words = The words to resolve.
     +
     + Returns:
     +  A `CommandResolveResult`, specifying the result of the resolution.
     + ++/
    CommandResolveResult!UserDataT resolve(RangeOfStrings)(RangeOfStrings words)
    {
        return this._rootNode.byCommandSentence(words);
    }

    /// ditto.
    CommandResolveResult!UserDataT resolve(string sentence) pure
    {
        import std.algorithm : splitter, filter;
        return this.resolve(sentence.splitter(' ').filter!(w => w.length > 0));
    }

    /++
     + Peforms the same task as `CommandResolver.resolve`, except that it will also advance the given `parser` to the
     + next unparsed argument.
     +
     + Description:
     +  For example, you've defined `"set verbose"` as a command, and you pass in an `ArgPullParser(["set", "verbose", "true"])`.
     +
     +  This function will match with the `"set verbose"` sentence, and will advance the parser so that it will now be `ArgPullParser(["true"])`, ready
     +  for your application code to perform additional processing (e.g. arguments).
     +
     + Params:
     +  parser = The `ArgPullParser` to use and advance.
     +
     + Returns:
     +  Same thing as `CommandResolver.resolve`.
     + ++/
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
    
    /// Returns: The root `CommandNode`, for whatever you need it for.
    @property
    NodeT root()
    {
        return this._rootNode;
    }

    /++
     + Notes:
     +  While the returned array is mutable, the nodes stored in this array are *not* the same nodes stored in the actual search tree.
     +  This means that any changes made to this array will not be reflected by the results of `resolve` and `resolveAndAdvance`.
     +
     +  The reason this isn't marked `const` is because that'd mean that your user data would also be marked `const`, which, in D,
     +  can be *very* annoying and limiting. Doubly so since your intentions can't be determined due to the nature of user data. So behave with this.
     +
     + Returns:
     +  All of the final words currently defined.
     + ++/
    @property
    NodeT[] finalWords()
    {
        return this._finalWords;
    }
}
///
@("Main test for CommandResolver")
@safe
unittest
{
    import std.algorithm : map, equal;

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

    // Resolve 'toggle' and call its execute function.
    auto result = resolver.resolve("toggle");
    assert(result.success);
    assert(result.value.word == "toggle");
    assert(result.value.sentence == "toggle");
    assert(result.value.type == CommandNodeType.finalWord);
    assert(result.value.userData.execute !is null);
    result.value.userData.execute();
    assert(executeValue == true);

    // Resolve 'please' and confirm that it's only a partial match.
    result = resolver.resolve("please");
    assert(result.success);
    assert(result.value.word            == "please");
    assert(result.value.sentence        is null);
    assert(result.value.type            == CommandNodeType.partialWord);
    assert(result.value.children.length == 2);
    assert(result.value.userData        == UserData.init);
    
    // Resolve 'please toggle' and call its execute function.
    result = resolver.resolve("please toggle");
    assert(result.success);
    assert(result.value.word == "toggle");
    assert(result.value.sentence == "please toggle");
    assert(result.value.type == CommandNodeType.finalWord);
    result.value.userData.execute();
    assert(executeValue == false);

    // Resolve 'please tog' and call its execute function. (to test nodes with multiple children).
    result = resolver.resolve("please tog");
    assert(result.success);
    assert(result.value.word == "tog");
    assert(result.value.sentence == "please tog");
    assert(result.value.type == CommandNodeType.finalWord);
    result.value.userData.execute();
    assert(executeValue == true);

    // Resolve a few non-existing command sentences, and ensure that they were unsuccessful.
    assert(!resolver.resolve(null).success);
    assert(!resolver.resolve("toggle please").success);
    assert(!resolver.resolve("He she we, wombo.").success);

    // Test that final words are properly tracked.
    assert(resolver.finalWords.map!(w => w.word).equal(["toggle", "toggle", "tog"]));
    assert(resolver.root.finalWords.equal(resolver.finalWords));

    auto node = resolver.resolve("please").value;
    assert(node.finalWords().map!(w => w.word).equal(["toggle", "tog"]));
}

@("Test CommandResolver.resolveAndAdvance")
@safe
unittest
{
    // Resolution should stop once a non-Text argument is found "--c" in this case.
    // Also the parser should be advanced, where .front is the argument that wasn't part of the resolved command.
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

@("Test CommandResolver.resolve possible edge case")
@safe
unittest
{
    auto resolver = new CommandResolver!int();
    auto parser   = ArgPullParser(["set", "value", "true"]);
    
    resolver.define("set value", 0);

    auto result = resolver.resolveAndAdvance(parser);
    assert(result.success);
    assert(result.value.type == CommandNodeType.finalWord);
    assert(result.value.word == "value");
    assert(parser.front.value == "true");

    result = resolver.resolve("set verbose true");
    assert(!result.success);
}