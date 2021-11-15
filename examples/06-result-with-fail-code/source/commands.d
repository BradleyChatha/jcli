module commands;

import jcli;

enum ErrorCode : int
{
    badFormat = 100,
    tooLarge  = 101,
    tooSmall  = 102
}

@Binder
ResultOf!int toIntCustom(string str)
{
    import std.conv : to;

    try
    {
        const value = str.to!int;
        if(value <= 0)
            return fail!int("Input is too small", ErrorCode.tooSmall);
        else if(value > 2)
            return fail!int("Input is too big", ErrorCode.tooLarge);
        else
            return ok!int(value);
    }
    catch(Exception ex)
        return fail!int("Input was in a bad format", ErrorCode.badFormat);
}

@CommandDefault
struct DefaultCommand
{
    @ArgPositional
    int input;

    void onExecute()
    {
    }
}