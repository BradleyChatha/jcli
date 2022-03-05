module jcli.commandgraph.graph;

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

import jcli.core.udas : ParentCommand, Subcommands;

import std.traits;
import std.meta;

template escapedName(T)
{
    import std.conv : to;
    import std.path : baseName;
    import std.algorithm;
    import std.range;

    // The idea here is to minimize collisions between type symbols.
    enum location = __traits(getLocation, T);
    enum escapedName = baseName(location[0])
        .chain(fullyQualifiedName!T)
        .map!(ch => canFind([cast(dchar) '.', ' ', '!', '(', ')'], ch) ? '_' : ch)
        .chain(location[1].to!string)
        .to!string;
}

struct TypeGraphNode
{
    int typeIndex;
    
    /// Shows which field of the given command type points to the parent context.
    /// Is -1 if the related command does not have a member pointing to the parent context. 
    int fieldIndex;
}

/// Represents a command type graph with only one type.
template DegenerateCommandTypeGraph(CommandType)
{
    alias Types = AliasSeq!CommandType;
    immutable TypeGraphNode[][1] adjacencies = [[]];
    immutable int[] rootTypeIndices = [0];

    template getTypeIndexOf(T)
    {
        static assert(is(T == CommandType));
        enum int getTypeIndexOf = 0;
    }
}

/// Represents a command type graph where the information about the parent-child
/// relationships of commands are drawn from the children, via the @ParentCommand UDA.
template BottomUpCommandTypeGraph(_Types...)
{
    alias Node = TypeGraphNode;
    alias Types = _Types;

    // Mappings, rootTypeIndices, adjacencies
    mixin(getGraphMixinText());
    // pragma(msg, getGraphMixinText());

    template getTypeIndexOf(T)
    {
        mixin("alias getTypeIndexOf = Mappings!()." ~ escapedName!T ~ ";");
    }

    // Note:
    // I'm realying on the idea that name lookup in scopes is linear in time to
    // essentially have a fake compile time AA.
    // Normal AA's are not allowed to be used at compile time rn. 
    // (E.g. `immutable int[int] example = [1: 2]` does not compile).
    // TODO: refactor to return an info struct, like the top-down graph below.
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
                        {
                            // A command being a child of itself is not detected anywhere else, it's an edge case.
                            assert(*index != outerIndex, "`" ~ T.stringof ~ "` cannot be a parent of itself.");

                            childrenGraph[*index] ~= Node(cast(int) outerIndex, cast(int) fieldIndex);
                        }
                        else
                        {
                            assert(false, "`" ~ T.stringof ~ "` not found among types.");
                        }
                    }}
                }
            }
        }

        // TODO: is bit array worth it?
        bool [Types.length] isNotRootCache;
        foreach (parentIndex, children; childrenGraph)
        {
            foreach (childNode; children)
                isNotRootCache[childNode.typeIndex] = true;
        }

        size_t[] rootTypeIndices;
        foreach (index, isNotRoot; isNotRootCache)
        {
            if (!isNotRoot)
                rootTypeIndices ~= index;
        }

        checkNodeAcessibility(childrenGraph[], rootTypeIndices);

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
                visited[] = false;
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

        {
            ret ~= "template Mappings() {";
            foreach (key, index; typeToIndex)
                formattedWrite(ret, "enum int %s = %d;", key, index);
            ret ~= "}";
        }

        // TODO: return normally
        {
            formattedWrite(ret, "immutable int[] rootTypeIndices = %s;\n", rootTypeIndices);
        }
        {
            formattedWrite(ret, "immutable Node[][] adjacencies = %s;\n", childrenGraph);
        }

        // Extra info, not actually used
        static if (0)
        {
            formattedWrite(ret, "immutable bool[] isNodeRoot = %s;\n", isNotRootCache[].map!"!a");

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
}

unittest
{
    {
        static struct A {}
        static struct B { @ParentCommand A* a; }
        alias Graph = BottomUpCommandTypeGraph!(A, B);
        static assert(is(Graph.Types == AliasSeq!(A, B)));

        enum AIndex = Graph.getTypeIndexOf!A;
        static assert(AIndex == 0);
        
        enum BIndex = Graph.getTypeIndexOf!B;
        static assert(BIndex == 1);

        static assert(Graph.adjacencies[AIndex] == [TypeGraphNode(BIndex, 0)]);
        static assert(Graph.adjacencies[BIndex].length == 0);

        static assert(Graph.rootTypeIndices == [AIndex]);
    }

    // Cycle detection
    {
        static struct A { @ParentCommand A* a; }
        static assert(!__traits(compiles, BottomUpCommandTypeGraph!A));
    }

    template Cycle()
    {
        struct A0 { @ParentCommand B0* b; }
        struct B0 { @ParentCommand A0* a; }
        static assert(!__traits(compiles, BottomUpCommandTypeGraph!(A0, B0)));
    }

    alias a = Cycle!();
}



// Haven't tested this one, haven't used it either.
template AllCommandsOf(Modules...)
{
    template getCommands(alias Module)
    {
        template isCommand(string memberName)
        {
            import jcli.core;
            enum isCommand = hasUDA!(__traits(getMember, Module, memberName), Command)
                || hasUDA!(__traits(getMember, Module, memberName), CommandDefault);
        }
        alias commandNames = Filter!(isCommand, __traits(allMembers, Module));

        alias getMember(string memberName) = __traits(getMember, Module, memberName);
        alias getCommands = staticMap!(getMember, commandNames);
    }

    alias AllCommandsOf = staticMap!(getCommands, Modules);
}


/// Represents a command type graph where the information about the parent-child
/// relationships of commands are drawn from the parents, via the @Subcommands UDA.
template TopDownCommandTypeGraph(RootTypes...)
{
    alias Node = TypeGraphNode;
    private alias AllTypes = AllSubcommandsOf!RootTypes;

    private immutable graphData = getGraphData();

    // Types, Mappings
    mixin(graphData.mixinText);
    immutable Node[][] adjacencies = graphData.childrenGraph;
    immutable size_t[] rootTypeIndices = graphData.rootTypeIndices;

    template getTypeIndexOf(T)
    {
        mixin("alias getTypeIndexOf = Mappings!()." ~ escapedName!T ~ ";");
    }
    
    private auto getGraphData()
    {
        static struct Result
        {
            string mixinText;
            Node[][] childrenGraph;
            size_t[] rootTypeIndices;
        }

        // This thing could contain duplicates!
        // Which is why I'm doing all of the remapping below. 
        // It's still a bad idea to map to a command from two places, because then this array
        // will contain ALL of the subcommands of that type both times!

        size_t[string] typeToIndex;
        size_t[] actualTypeIndexToAllTypeIndex;

        static foreach (index, Type; AllTypes)
        {{
            if (escapedName!Type !in typeToIndex)
            {
                typeToIndex[escapedName!Type] = actualTypeIndexToAllTypeIndex.length;
                actualTypeIndexToAllTypeIndex ~= index;
            }
        }}

        size_t numTypes = actualTypeIndexToAllTypeIndex.length;
        Node[][] childrenGraph = new Node[][](numTypes);

        static foreach (index, ParentType; AllTypes)
        {{
            size_t actualTypeIndex = typeToIndex[escapedName!ParentType];

            if (actualTypeIndexToAllTypeIndex[actualTypeIndex] == index)
            {
                static foreach (Subcommand; SubcommandsOf!ParentType)
                {{
                    int fieldIndex = getIndexOfFieldWithParentPointerType!(ParentType, Subcommand);
                    size_t subcommandActualTypeIndex = typeToIndex[escapedName!Subcommand];
                    childrenGraph[actualTypeIndex] ~= Node(cast(int) subcommandActualTypeIndex, cast(int) fieldIndex);
                }}
            }
        }}

        size_t[] rootTypeIndices; // @suppress(dscanner.suspicious.label_var_same_name)
        foreach (RootType; RootTypes)
            rootTypeIndices ~= typeToIndex[escapedName!RootType];

        checkNodeAcessibility(childrenGraph[], rootTypeIndices);

        import std.array : appender;
        import std.format : formattedWrite;
        import std.algorithm : map;

        auto ret = appender!string;

        {
            ret ~= "template Mappings() {";
            foreach (key, index; typeToIndex)
                formattedWrite(ret, "enum int %s = %d;", key, index);
            ret ~= "}";
        }

        {
            ret ~= "\n";
            ret ~= "alias Types = AliasSeq!(";
            size_t appendedCount = 0;
            static foreach (index, Type; AllTypes)
            {{
                size_t actualIndex = typeToIndex[escapedName!Type];
                if (actualTypeIndexToAllTypeIndex[actualIndex] == index)
                {
                    if (appendedCount > 0)
                        ret ~= ",";
                    
                    assert(appendedCount == actualIndex);
                    appendedCount++;

                    formattedWrite(ret, "AllTypes[%d]", actualTypeIndexToAllTypeIndex[actualIndex]);
                }
            }}
            ret ~= ");";
            ret ~= "\n";
        }

        return Result(ret[], childrenGraph, rootTypeIndices);
    }
}

unittest
{
    template Basic()
    {
        @(Subcommands!B)
        static struct A {}

        static struct B { A* a; }

        alias Graph = TopDownCommandTypeGraph!(A);
        static assert(is(Graph.Types == AliasSeq!(A, B)));

        enum AIndex = 0;
        static assert(AIndex == Graph.getTypeIndexOf!A);
        
        enum BIndex = 1;
        static assert(BIndex == Graph.getTypeIndexOf!B);

        enum node = TypeGraphNode(BIndex, 0);
        static assert(Graph.adjacencies[AIndex].length == 1);
        static assert(Graph.adjacencies[AIndex][0] == node);
        static assert(Graph.adjacencies[BIndex].length == 0);

        static assert(Graph.rootTypeIndices == [AIndex]);
    }

    // Cycle detection
    template ParentOfSelf()
    {
        @(Subcommands!A)
        static struct A { A* a; }
        static assert(!__traits(compiles, TopDownCommandTypeGraph!A));
    }

    template Cycle()
    {
        @(Subcommands!B)
        static struct A { B* b; }
        @(Subcommands!A)
        static struct B { A* a; }
        static assert(!__traits(compiles, TopDownCommandTypeGraph!(A, B)));
        static assert(!__traits(compiles, TopDownCommandTypeGraph!(A)));
        static assert(!__traits(compiles, TopDownCommandTypeGraph!(B)));
    }

    template NoField()
    {
        @(Subcommands!B)
        static struct A {}
        static struct B {}

        alias Graph = TopDownCommandTypeGraph!(A);
        enum AIndex = Graph.getTypeIndexOf!A;
        enum BIndex = Graph.getTypeIndexOf!B;
        
        enum node = TypeGraphNode(BIndex, -1);
        static assert(Graph.adjacencies[AIndex].length == 1);
        static assert(Graph.adjacencies[AIndex][0] == node);
    }

    template DuplicateParents()
    {
        @(Subcommands!C)
        static struct A {}
        @(Subcommands!C)
        static struct B {}
        static struct C {A* a; B* b;}

        alias Graph = TopDownCommandTypeGraph!(A, B);
        enum AIndex = Graph.getTypeIndexOf!A;
        enum BIndex = Graph.getTypeIndexOf!B;
        enum CIndex = Graph.getTypeIndexOf!C;
        static assert(Graph.Types.length == 3);
        
        enum nodeParentA = TypeGraphNode(CIndex, 0);
        enum nodeParentB = TypeGraphNode(CIndex, 1);
        
        static assert(Graph.adjacencies[AIndex].length == 1);
        static assert(Graph.adjacencies[AIndex][0] == nodeParentA);

        static assert(Graph.adjacencies[BIndex].length == 1);
        static assert(Graph.adjacencies[BIndex][0] == nodeParentB);

        static assert(Graph.adjacencies[CIndex].length == 0);
    }

    {
        alias _ = Basic!();
    }
    {
        alias _ = ParentOfSelf!();
    }
    {
        alias _ = Cycle!();
    }
    {
        alias _ = NoField!();
    }
    {
        alias _ = DuplicateParents!();
    }
}


template SubcommandsOf(CommandType)
{
    alias _Subcommands = getUDAs!(CommandType, Subcommands);
    alias getTypes(Attr : Subcommands!(Types), Types...) = Types;
    alias SubcommandsOf = staticMap!(getTypes, _Subcommands);
}
unittest
{
    {
        static struct A {}
        static assert(is(SubcommandsOf!A == AliasSeq!()));
    }
    {
        static struct A {}
        @(Subcommands!A)
        static struct B {}
        static assert(is(SubcommandsOf!B == AliasSeq!A));
    }
    {
        static struct A1 {}
        static struct A2 {}
        static struct A3 {}

        @(Subcommands!(A1, A2))
        @(Subcommands!(A3))
        static struct B {}

        static assert(is(SubcommandsOf!(B) == AliasSeq!(A1, A2, A3)));
    }
}

template AllSubcommandsOf(CommandTypes...)
{
    static if (CommandTypes.length == 1)
    {
        alias AllSubcommandsOf = AliasSeq!(
            CommandTypes[0], staticMap!(.AllSubcommandsOf, SubcommandsOf!(CommandTypes[0])));
    }
    else static if (CommandTypes.length == 0)
    {
        alias AllSubcommandsOf = AliasSeq!();
    }
    else
    {
        alias AllSubcommandsOf = staticMap!(.AllSubcommandsOf, CommandTypes);
    }
}
unittest
{
    template Cycle()
    {
        @(Subcommands!B)
        static struct A {}
        @(Subcommands!A)
        static struct B {}
        static assert(!__traits(compiles, AllSubcommandsOf!A));
        static assert(!__traits(compiles, AllSubcommandsOf!B));
        static assert(!__traits(compiles, AllSubcommandsOf!(A, B)));
    }

    {
        static struct A {}
        static assert(is(AllSubcommandsOf!A == AliasSeq!(A)));
    }

    template SelfIncluded()
    {
        static struct A {}
        @(Subcommands!A)
        static struct B {}
        static assert(is(AllSubcommandsOf!B == AliasSeq!(B, A)));
    }

    {
        alias _ = Cycle!();
    }
    {
        alias _ = SelfIncluded!();
    }

}


private int getIndexOfFieldWithParentPointerType(ParentType, ChildType)()
{
    int result = -1;
    static foreach (SubcommandType; SubcommandsOf!ParentType)
    {
        static foreach (fieldIndex, field; SubcommandType.tupleof)
        {{
            static if (is(typeof(field) : T*, T))
            {
                // TODO: ParentCommand uda checks
                static if (is(T == ParentType))
                {
                    result = cast(int) fieldIndex;
                }
            }
        }}
    }
    return result;
}

unittest
{
    {
        static struct A {}
        static assert(is(AllSubcommandsOf!A == AliasSeq!(A)));
    }
    {
        static struct A {}
        static struct B {}
        static assert(is(AllSubcommandsOf!(A, B) == AliasSeq!(A, B)));
    }
    {
        static struct B {}
        static struct C {}

        @(Subcommands!(B, C))
        static struct A {}
        
        static assert(is(AllSubcommandsOf!(A) == AliasSeq!(A, B, C)));
    }
}


private void checkNodeAcessibility(TypeGraphNode[][] adjacencies, size_t[] rootTypeIndices)
{
    bool[] isAccessibleCache = new bool[adjacencies.length];

    void markChildrenAccessible(size_t index)
    {
        foreach (childNode; adjacencies[index])
        {
            if (isAccessibleCache[childNode.typeIndex])
                continue;
            isAccessibleCache[childNode.typeIndex] = true;
            markChildrenAccessible(childNode.typeIndex);
        }
    }

    foreach (parentIndex; rootTypeIndices)
    {
        isAccessibleCache[parentIndex] = true;
        markChildrenAccessible(parentIndex);
    }

    import std.algorithm : all;
    // TODO: better error here.
    assert(all(isAccessibleCache[]), "Some types were inaccessible.");
}
