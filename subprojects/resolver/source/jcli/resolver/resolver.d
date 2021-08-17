module jcli.resolver.resolver;

import std;

alias ResolveValueProvider = string[] delegate(string partialInput);

struct ResolveResult(alias UserDataT)
{
    enum Kind
    {
        full,
        partial
    }

    Kind kind;
    ResolveNode!UserDataT*[] fullMatchChain;
    ResolveNode!UserDataT*[] partialMatches;
    string[] valueOptions;
}

struct ResolveNode(alias UserDataT)
{
    char letter;
    bool isFullMatch;
    string fullMatchString;
    ResolveNode[] children;
    UserDataT userData;
    ResolveValueProvider valueProvider;
}

alias t = Resolver!int;

final class Resolver(alias UserDataT_)
{
    alias UserDataT = UserDataT_;

    static struct ArgInfo
    {
        string arg;
        ResolveValueProvider valueProvider;
    }

    private
    {
        ResolveNode!UserDataT _root;
    }

    @trusted nothrow
    void add(
        string[] command,
        UserDataT userData,
        ResolveValueProvider commandValueProvider
    )
    {
        ResolveNode!UserDataT* node = &this._root;
        bool _1;
        foreach(i, word; command)
        {
            foreach(ch; word)
                node = &this.nextByChar(*node, ch, true, _1);
            node.fullMatchString = word;
            node.isFullMatch = true;
            if(i+1 < command.length)
                node = &this.nextByChar(*node, ' ', true, _1);
        }

        node.valueProvider = commandValueProvider;
        node.userData = userData;
    }

    ResolveResult!UserDataT resolve(
        string[] command
    )
    {
        ResolveResult!UserDataT ret;

        ResolveNode!UserDataT* node = &this._root;
        bool found;
        foreach(i, word; command)
        {
            foreach(ch; word)
            {
                node = &this.nextByChar(*node, ch, false, found);
                if(!found)
                    break;
            }
            if(node.isFullMatch)
                ret.fullMatchChain ~= node;
            if(i+1 < command.length)
            {
                node = &this.nextByChar(*node, ' ', false, found);
                if(!found)
                    break;
            }
        }

        if(found && node.isFullMatch && node.userData != UserDataT.init)
        {
            ret.kind = ret.Kind.full;
            if(node.valueProvider)
                ret.valueOptions = node.valueProvider(null);
            return ret;
        }

        void addToPartial(ResolveNode!UserDataT* node)
        {
            foreach(ref child; node.children)
            {
                if(child.letter == ' ')
                    continue;
                if(child.isFullMatch)
                    ret.partialMatches ~= &child;
                addToPartial(&child);
            }
        }

        addToPartial(node);
        ret.kind = ret.Kind.partial;
        return ret;
    }

    @safe nothrow
    private ref NodeT nextByChar(NodeT)(ref NodeT parent, char ch, bool createIfNeeded, out bool found)
    {
        found = true;
        foreach(ref node; parent.children)
        {
            if(node.letter == ch)
                return node;
        }

        if(createIfNeeded)
        {
            parent.children ~= NodeT(ch);
            return parent.children[$-1];
        }
        else
        {
            found = false;
            static if(is(NodeT == ResolveNode!UserDataT))
                return this._root;
            else
            {
                static ResolveArgument _r;
                return _r;
            }
        }
    }
}

unittest
{
    auto r = new Resolver!int();
    r.add(["cloaca"], 20, null);
    auto re = r.resolve(["cloaca"]);

    assert(re.kind == re.Kind.full);
    assert(re.fullMatchChain.length == 1);
    assert(re.fullMatchChain[0].fullMatchString == "cloaca");
}

unittest
{
    auto r = new Resolver!int();
    r.add(["cloaca", "knuckles"], 20, null);
    auto re = r.resolve(["cloaca", "knuckles"]);

    assert(re.kind == re.Kind.full);
    assert(re.fullMatchChain.length == 2);
    assert(re.fullMatchChain[0].fullMatchString == "cloaca");
    assert(re.fullMatchChain[1].fullMatchString == "knuckles");
}

unittest
{
    auto r = new Resolver!int();
    r.add(["cloaca"], 20, null);
    auto re = r.resolve(["cloa"]);

    assert(re.kind == re.Kind.partial);
    assert(re.partialMatches.length == 1);
    assert(re.partialMatches[0].fullMatchString == "cloaca", re.partialMatches[0].fullMatchString);
}

unittest
{
    auto r = new Resolver!int();
    r.add(["nodders"], 20, null);
    auto re = r.resolve(["nop"]);

    assert(re.kind == re.Kind.partial, re.to!string);
    assert(re.partialMatches.length == 1);
    assert(re.partialMatches[0].fullMatchString == "nodders", re.partialMatches[0].fullMatchString);
}