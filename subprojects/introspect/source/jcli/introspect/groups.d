module jcli.introspect.groups;

/// Mark the member pointers of the command context struct 
/// to the parent command context struct with this.
/// That will make it join the command group.
/// The `onExecute` method will be called after the `onExecute` of that parent executes.
/// 
/// For now, when multiple such fields exist, the command  will be a child of both, 
/// and when the command is resolved, only the context pointer of 
/// the parent command that it was resolved through will be not-null.
enum ParentCommand;

// TODO: 
// Ways to specify children instead of the parent.
// Needs some changes in the graph code. Not hard.
//
// TODO: 
// Ways to parent all commands within a module.
// I bet this one can be really useful.
// Should also be pretty easy to implement.
//
// TODO:
// Discover commands through a parent command, by looking at its children.
// Should be very useful when you decide to go top-down
// and have more control over the command layout.
// I imagine it shouldn't be that hard?

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
        ~ location[1].to!string;
}

struct TypeGraphNode
{
    int typeIndex;
    
    /// Shows which field of the given command type points to the parent context.
    /// Is -1 if the related command does not have a member pointing to the parent context. 
    int fieldIndex;
}

template TypeGraph(Types...)
{
    alias Node = TypeGraphNode;

    // Note:
    // I'm realying on the idea that name lookup in scopes is linear in time to
    // essentially have a fake compile time AA.
    // Normal AA's are not allowed to be used at compile time rn. 
    // (E.g. `immutable int[int] example = [1: 2]` does not compile).
    private string getGraphMixinText()
    {
        size_t[string] typeToIndex;
        static foreach (index, Type; Types)
            typeToIndex[escapedName!Type] = index;
        Node[][Types.length] childrenGraph;

        foreach (outerIndex, Type; Types)
        {
            static foreach (fieldIndex, field; Type.tupleof)
            {
                static if (is(typeof(field) : T*, T))
                {
                    static if (hasUDA!(field, ParentCommand))
                    {{
                        const name = escapedName!T;
                        if (auto index = name in typeToIndex)
                            childrenGraph[*index] ~= Node(cast(int) outerIndex, cast(int) fieldIndex);
                        else
                            assert(false, name ~ " not found among types.");
                    }}
                }
            }
        }

        // TODO: is bit array worth it?
        bool[Types.length] isNotRootCache;
        foreach (parentIndex, children; childrenGraph)
        {
            foreach (childNode; children)
                isNotRootCache[childNode.typeIndex] = true;
        }

        {
            // Check for cicles in the graph.
            // Cicles will stifle the compiler (but I'm not sure).
            // TODO: use bit array?
            bool[Types.length] visited = false;

            bool isCyclic(size_t index)
            {
                if (visited[index])
                    return true;
                
                visited[index] = true;
                foreach (childNode; childrenGraph[index])
                {
                    if (isCyclic(childNode.typeIndex))
                        return true;
                }
                return false;
            }

            foreach (parentIndex, isNotRoot; isNotRootCache)
            {
                if (isNotRoot)
                    continue;
                if (isCyclic(parentIndex))
                {
                    // TODO: report more info here.
                    assert(false, "The command graph contains a cycle");
                }
            }
        }
		
        import std.array : appender;
        import std.format : formattedWrite;
        import std.algorithm : map;

        auto ret = appender!string;

        static if (0)
        {
            ret ~= "template Mappings() {";
            foreach (key, index; typeToIndex)
                formattedWrite(ret, "enum size_t %s = %d;", key, index);
            ret ~= "}";
        }

        {
            // auto rootTypes = appender!string;
            // rootTypes ~= "alias RootTypes = AliasSeq!(";

            auto rootTypeIndices = appender!string;
            rootTypeIndices ~= "immutable size_t[] rootTypeIndices = [";
            {
                size_t appendedCount = 0;
                foreach (nodeIndex, isNotRoot; isNotRootCache)
                {
                    if (isNotRoot)
                        continue;
                    if (appendedCount > 0)
                    {
                        rootTypeIndices ~= ", ";
                        // rootTypes ~= ", ";
                    }
                    appendedCount++;
                    
                    formattedWrite(rootTypeIndices, "%d", nodeIndex);
                    // formattedWrite(rootTypes, "Types[%d]", nodeIndex);
                }
            }
            rootTypeIndices ~= "];\n";

            ret ~= rootTypeIndices[];
            ret ~= "\n";

            // rootTypes ~= ");\n";
            // ret ~= rootTypes[];
            // ret ~= "\n";
        }
        {
            formattedWrite(ret, "immutable Node[][] Adjacencies = %s;\n", childrenGraph);
        }

        // Extra info, not actually used
        static if (0)
        {
            formattedWrite(ret, "immutable bool[] IsNodeRoot = %s;\n", isNotRootCache[].map!"!a");

            auto types = appender!string;
            auto fields = appender!string;

            foreach (parentIndex, ParentType; Types)
            {
                types ~= "alias " ~ escapedName!ParentType ~ " = AliasSeq!(";
                fields ~= "alias " ~ escapedName!ParentType ~ " = AliasSeq!(";

                foreach (typeIndexIndex, childNode; childrenGraph[parentIndex])
                {
                    if (typeIndexIndex > 0)
                    {
                        types ~= ", ";
                        fields ~= ", ";
                    }

                    formattedWrite(fields, "Types[%d].tupleof[%d]", 
                        childNode.typeIndex, childNode.fieldIndex);

                    formattedWrite(types, "Types[%d]", 
                        childNode.typeIndex);
                }

                types ~= ");\n";
                fields ~= ");\n";
            }

            ret ~= "\ntemplate Commands() {\n";
            ret ~= types[];
            ret ~= "\n}\n";

            ret ~= "\ntemplate Fields() {\n";
            ret ~= fields[];
            ret ~= "\n}\n";
        }
        
        return ret[];
    }

    // pragma(msg, getGraphMixinText());

    mixin(getGraphMixinText());

    // template getAdjacenciesOf(T)
    // {
    //     mixin("alias getAdjacenciessOf = Adjacencies[Mappings!()." ~ escapedName!T ~ "];");
    // }

    // template getChildTypes(T)
    // {
    //     mixin("alias getChildTypes = Commands!()." ~ escapedName!T ~ ";");
    // }

    // template getChildCommandFieldsOf(T)
    // {
    //     mixin("alias getChildCommandFieldsOf = Fields!()." ~ escapedName!T ~ ";");
    // }
}


/// ParentCommandFieldSymbols must be already filtered to have at least
/// one member marked with ParentCommand.
// template getChildCommandFieldsOf(T, Types...)
// {
    // alias G = Graph!Types;
 
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
// }
// unittest
// {
//     static struct A {}
//     static struct B { @ParentCommand A* a; }
//     static struct C { @ParentCommand B* b; }

//     {
//         alias Types = AliasSeq!(A, B, C);
//         alias G = TypeGraph!Types;
//         static assert(__traits(isSame, G.getChildCommandFieldsOf!A[0], B.a));
//         static assert(__traits(isSame, G.getChildCommandFieldsOf!B[0], C.b));
//         static assert(G.getChildCommandFieldsOf!C.length == 0);
//     }
// }

// Haven't tested this one, haven't used it either.
template AllCommandsOf(Modules...)
{
    template getCommands(alias Module)
    {
        template isCommand(string memberName)
        {
            enum isCommand = hasUDA!(__traits(getMember, Module, memberName), Command)
                || hasUDA!(__traits(getMember, Module, memberName), CommandDefault);
        }
        alias commandNames = Filter!(isCommand, __traits(allMembers, Module));

        alias getMember(string memberName) = __traits(getMember, Module, memberName);
        alias getCommands = staticMap!(getMember, commandNames);
    }

    alias AllCommandsOf = staticMap!(getCommands, Modules);
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