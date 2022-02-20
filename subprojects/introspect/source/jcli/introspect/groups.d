module jcli.introspect.groups;

/// Mark the member pointers of the command context struct 
/// to the parent command context struct with this.
/// That will make it join the command group.
/// The `onExecute` method will be called after the `onExecute` of that parent executes.
/// 
/// For now, when multiple such fields exist, the command  will be a child of both, 
/// and when the command is resolved, only the context pointer of 
/// the parent command that it was resolved through will be not-null.
///
/// Multiple nested commands in the same function won't work correctly!
enum ParentCommand;

import std.traits;
import std.meta;

template escapedName(T)
{
    import std.string : replace;
    import std.conv : to;
    import std.path : baseName;

    // The idea here is to minimize collisions between type symbols.
    enum location = __traits(getLocation, T);
    enum escapedName = (baseName(location[0]) ~ fullyQualifiedName!T)
            .replace(".", "_")
            .replace(" ", "_")
            .replace("!", "_")
        ~ location[2].to!string;
}


private template Graph(Types...)
{
    // Note:
    // I'm realying on the idea that name lookup in scopes is linear in time to
    // essentially have a fake compile time AA.
    // Normal AA's are not allowed to be used at compile time rn. 
    // (E.g. `immutable int[int] example = [1: 2]` does not compile).
    mixin(
    (){
        size_t[string] typeToIndex;
        static foreach (index, Type; Types)
            typeToIndex[escapedName!Type] = index;

        static struct Node
        {
            size_t childIndex;
            size_t fieldIndex;
        }

        Node[][] childrenGraph;
        childrenGraph = new Node[][](Types.length);

        foreach (outerIndex, Type; Types)
        {
            static foreach (fieldIndex, field; Type.tupleof)
            {
                static if (is(typeof(field) : T*, T))
                {
                    static if (hasUDA!(field, ParentCommand))
                    {
                        childrenGraph[typeToIndex[escapedName!T]] ~= 
                            Node(outerIndex, fieldIndex);
                    }
                }
            }
        }
		
        import std.array;
        auto ret = appender!string;

        foreach (parentIndex, ParentType; Types)
        {
            ret ~= "alias " ~ escapedName!ParentType ~ " = AliasSeq!(";

            foreach (childIndexIndex, childNode; childrenGraph[parentIndex])
            {
                if (childIndexIndex > 0)
                    ret ~= ", ";
                import std.format : formattedWrite;
                formattedWrite(ret, "Types[%d].tupleof[%d]", 
                    childNode.childIndex, childNode.fieldIndex);
            }

            ret ~= ");";
        }
        
        return ret[];
    }());
}


/// ParentCommandFieldSymbols must be already filtered to have at least
/// one member marked with ParentCommand.
template getChildCommandFieldsOf(T, Types...)
{
    // It's a non-quadratic implementation that I came up with.
    alias G = Graph!Types;
    mixin("alias getChildCommandFieldsOf = G." ~ escapedName!T ~ ";");
 
    //
    // I'm keeping the old reflections for the sake of food for thought:
    //
    // This implementation is currently close to quadratic, when done for all commands
    // due to the limitations of metaprogramming in D.
    // In normal code, you would've done a lookup table by type for all commands,
    // which you cannot do at compile time in D.
    // alias ChildCommandFieldsOf = AliasSeq!();

    // If it really becomes a problem, this could offer a temporary solution.
    // But ideally, we need a lookup table.
    // alias RemainingCommandFieldSymbols = AliasSeq!();
    // alias CommandType = TCommand;

    // static foreach (field; parentCommandFieldSymbols)
    // {
    //     static if (is(typeof(field) : const(TCommand)*))
    //     {
    //         ChildCommandFieldsOf = AliasSeq!(ChildCommandFieldsOf, field);
    //     }
    //     // else
    //     // {
    //     //     RemainingCommandFieldSymbols = AliasSeq!(RemainingCommands, field);
    //     // }
    // }
}
unittest
{
    static struct A {}
    static struct B { @ParentCommand A* a; }
    static struct C { @ParentCommand B* b; }

    {
        alias Types = AliasSeq!(A, B, C);
        static assert(__traits(isSame, getChildCommandFieldsOf!(A, Types)[0], B.a));
        static assert(__traits(isSame, getChildCommandFieldsOf!(B, Types)[0], C.b));
        static assert(getChildCommandFieldsOf!(C, Types).length == 0);
    }
}

// template getParentCommandCandidateFieldSymbols(AllCommands)
// {
//     alias result = AliasSeq!();
//     static foreach (Command; AllCommands)
//     {
//         static foreach (field; Command.tupleof)
//         {
//             static if (hasUDA!(field, ParentCommand))
//             {
//                 static assert(is(typeof(field) : T*, T));
//                 result = AliasSeq!(result, field);
//             }
//         }
//     }
//     alias getParentCommandCandidateFieldSymbols = result;
// }   
// unittest
// {
//     static struct A
//     {
//         @ParentCommand int* i;
//         @ParentCommand int* j;
//     }
//     static assert(is(GetParentCommandCandidateFieldSymbols!A == AliasSeq!(A.i, A.j)));
// }