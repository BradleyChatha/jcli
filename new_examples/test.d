// just making sure it compiles.

int main()
{
    import std.process : spawnShell, wait;
    import std.file : dirEntries, SpanMode, isDir;
    import std.stdio;

    int failCount = 0; 
    foreach (string folder; dirEntries(".", SpanMode.shallow))
    {
        if (!isDir(folder))
            continue;

        auto result = spawnShell(`dub build --root ` ~ folder).wait();
        if (result == 0)
        {
            writeln(folder, " success.");
        }
        else
        {
            writeln(folder, " fail.");
            failCount++;
        }
    }
    return failCount;
}