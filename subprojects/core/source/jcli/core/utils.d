module jcli.core.utils;

import std.traits : Unqual;

string toFlagsString(Flags)(Flags flags)
{
	import std.array;
	import std.bitmanip;

    alias ReadableFlags = Unqual!Flags;
    
    auto result = appender!string;
    bool isFirst = true;
 	foreach (bitIndex; flags.bitsSet)
    {
        Switch: switch (bitIndex)
        {
            default: assert(0);
            static foreach (memberName; __traits(allMembers, ReadableFlags))
            {
                static if (__traits(getMember, ReadableFlags, memberName).bitsSet.length == 1)
                {
                    case __traits(getMember, ReadableFlags, memberName).bitsSet.front:
                    {
                        if (!isFirst)
                            result ~= " | ";
                        else
                            isFirst = false;
                        result ~= ReadableFlags.stringof ~ "." ~ memberName;
                        break Switch;
                    }
                }
            }
        }
    }
    return result[];
}