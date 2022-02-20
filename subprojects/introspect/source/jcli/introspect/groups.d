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


template TypeGraph(Types...)
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

        Node[][Types.length] childrenGraph;

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

        // TODO: is bit array worth it?
        bool[Types.length] isNotRootCache;
        foreach (parentIndex, children; childrenGraph)
        {
            foreach (childNode; childrenGraph)
                isNotRootCache[childNode.childIndex] = true;
        }

        {
            // Check for cicles in the graph.
            // Cicles will stifle the compiler (but I'm not sure).
            // TODO: use bit array?
            bool[Types.length] visited = void;

            void isCyclic(size_t index)
            {
                if (visited[index])
                    return true;
                
                visited[index] = true;
                foreach (childNode; childrenGraph[index])
                {
                    if (isCyclic(childNode.childIndex))
                        return true;
                }
                return false;
            }

            foreach (parentIndex, isNotRoot; isNotRootCache)
            {
                if (isNotRoot)
                    continue;
                visited = 0;
                if (isCyclic(parentIndex))
                {
                    // TODO: report more info here.
                    assert(false, "The command graph contains a cycle");
                }
            }
        }
		
        import std.array;
        auto ret = appender!string;

        ret ~= "alias RootTypes = AliasSeq!(";
        {
            size_t appendedCount = 0;
            foreach (parentIndex, isNotRoot; isNotRootCache)
            {
                if (isNotRoot)
                    continue;
                if (appendedCount > 0)
                    ret ~= ", ";
                
                import std.format : formattedWrite;
                formattedWrite(ret, "Types[%d]", parentIndex);
            }
        }
        ret ~= ");";

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

    template getChildCommandFieldsOf(T)
    {
        mixin("alias getChildCommandFieldsOf = " ~ escapedName!T ~ ";");
    }

    alias Parent(alias f) = __traits(parent, f);
    
    // for now, just static map, but a different idea is to just store the info
    // (the type index and the field index) and then static map for both fields and types.
    alias getChildTypes(T) = staticMap!(Parent, getChildCommandFieldsOf!T);
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
unittest
{
    static struct A {}
    static struct B { @ParentCommand A* a; }
    static struct C { @ParentCommand B* b; }

    {
        alias Types = AliasSeq!(A, B, C);
        alias G = TypeGraph!Types;
        static assert(__traits(isSame, G.getChildCommandFieldsOf!(A, Types)[0], B.a));
        static assert(__traits(isSame, G.getChildCommandFieldsOf!(B, Types)[0], C.b));
        static assert(G.getChildCommandFieldsOf!(C, Types).length == 0);
    }
}

template AllCommandsOf(Modules...)
{
    // enum isCommand(string memberName) = hasUDA!(__traits(getMember, Module, memberName), Command)
    //     || hasUDA!(__traits(getMember, Module, memberName), CommandDefault);
    // alias AllCommandsOf = Filter!(isCommand, Modules);
    
    // TODO:
    // This is quadratic, I'm pretty sure.
    // You can do better with templates by splitting in half (there are functions in std.traits).
    static foreach (Module; Modules)
    {
        static foreach (memberName; __traits(allMembers, Module))
        {   
            static if (hasUDA!(__traits(getMember, Module, memberName), Command)
                || hasUDA!(__traits(getMember, Module, memberName), CommandDefault))
            {
                AllCommandsOf = AliasSeq!(AllCommandsOf, __traits(getMember, Module, memberName));
            }
        }
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