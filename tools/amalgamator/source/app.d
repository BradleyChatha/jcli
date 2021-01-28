import std;

/++ CONFIGURATION ++/
const OUTPUT_FILE             = "./single-file/jcli.d";
const OUTPUT_FILE_MODULE_NAME = "jcli";

const MODULES_TO_REMOVE_FROM_IMPORTS = 
[
    regex("jaster.+"),
    regex("jcli"),
    regex("jioc.*")
];

const PACKAGES_TO_AMALGAMATE = 
[
    "", // Current dir
    "jioc"
];

/++ DATA TYPES ++/
enum ProcessResult
{
    ignored,
    handledOutputLine,
    handledScrapLine
}

struct Package
{
    string name;
    string[] sourceFilePaths;
    string licenseFileContents;
    size_t totalLengthOfFiles; // Includes licenseFileContents
}

/++ ENTRY POINT ++/
void main()
{
    // Ensure we're in JCLI's root, not this tool's root.
    while(!exists("LICENSE.md"))
        chdir("..");

    // Ensure output dir exists.
    mkdirRecurse(OUTPUT_FILE.dirName);

    // Load package info, stitch them together, then do additional processing so things compile.
    // While a lot of this could technically be done in a single pass instead of multiple, I just wanted to keep the code simple.
    auto output = appender!(char[]);
    auto info = loadAllPackageInfo();
    output.reserve(info.map!(i => i.totalLengthOfFiles).fold!((a, b) => a + b)(0UL) + (200 * info.length)); // The last part is just to give us some wiggle room before causing a reallocation.
    stitchPackages(info, output);

    auto stitched = output.data.idup;
    output.clear();
    postProcess(stitched, output);

    std.file.write(OUTPUT_FILE, output.data);
}

/++ INPUT FUNCTIONS ++/
Package[] loadAllPackageInfo()
{
    return PACKAGES_TO_AMALGAMATE.map!loadPackageInfo.array;
}

Package loadPackageInfo(string packageName)
{
    const result = executeShell("dub describe "~packageName);
    enforce(result.status == 0, "dub describe %s failed with status %s:%s\n".format(packageName, result.status, result.output));

    const json = parseJSON(result.output);

    Package pkg;
    pkg.name = (packageName.length == 0) ? "jcli" : packageName;

    const jsonPackage = json["packages"][0];
    const rootPath    = jsonPackage["path"].get!string;

    foreach(fileObj; jsonPackage["files"].array)
    {
        if(fileObj["role"].get!string != "source")
            continue;

        const path = buildPath(rootPath, fileObj["path"].get!string);
        pkg.sourceFilePaths ~= path;
        pkg.totalLengthOfFiles += File(path, "r").size;
    }

    const licensePath = buildPath(rootPath, "LICENSE.md");
    pkg.licenseFileContents = (licensePath.exists)
                              ? readText(licensePath)
                              : "Could not find LICENSE file";
    pkg.totalLengthOfFiles += pkg.licenseFileContents.length;

    return pkg;
}

/++ PROCESSING FUNCTIONS ++/
void stitchPackages(const Package[] packages, ref Appender!(char[]) output)
{
    // First, add an inline dub description, just for QoL needs.
    output.put("/*dub.sdl:\n");
    output.put("    name \"jcli\"\n");
    output.put("*/\n");

    // Second, add all licenses to the top of the file.
    foreach(pkg; packages)
    {
        output.put("/*");
        output.put(pkg.name);
        output.put(":\n");
        output.put(pkg.licenseFileContents);
        output.put('\n');
        output.put("*/\n");
    }

    // Third, add a few warnings.
    output.put(
`/*
    WARNING:
        It should go without saying that slapping a bunch of files together and hackily patching it to compile is very likely
        to cause unusual compiler errors during its early stages of support (i.e. this file).

        Please open an issue on Github if you run into any compiler errors that occur when using this file as opposed to using the
        non-amalgamated dub package of JCLI, as these will 99% of the time be a bug that needs addressing and fixing.

        Second, just report *any* behavioural differences (whether at runtime or compile time) between the amalgamated and non-amalgamated version of JCLI.

        Finally, if there's any improvements you can think of to make support for amalgamation better and more stable, please let me know!

    DEBUG_NOTE:
        If you compile this file via 'dmd ./jcli.d -H', then DMD will create a './jcli.di' file which gives a much more structured overview
        of how this code is viewed by the compiler.

        So for example, if you're getting errors such as "so and so is not defined", make dmd generate the .di file, do a search for the thing it says
        doesn't exist, and you might just find that it's somehow ended up under a "version(unittest)" statement, for example.

        Again, file an issue if something like this occurs.
*/`
    );
    output.put('\n');

    // Then add the definitive module statement.
    output.put("module ");
    output.put(OUTPUT_FILE_MODULE_NAME);
    output.put(";\n");

    // Then add in a version statement so some code and transform itself for the amalgamation.
    output.put("version = Amalgamation;");

    // Then add in each file.
    foreach(pkg; packages)
    {
        foreach(file; pkg.sourceFilePaths)
        {
            auto stream = File(file, "r");
            foreach(chunk; stream.byChunk(4096))
                output.put(cast(char[])chunk);
            output.put('\n');
        }
    }

    // Ensure we're a valid UTF8 file.
    validate(output.data);
}

void postProcess(string stitched, ref Appender!(char[]) output)
{
    bool foundFirstModuleStatement = false;
    const processors = 
    [
        &postProcess_removeModuleStatements,              // Since this'll be under a single module, we need to remove all other module statements.
        &postProcess_removeBlacklistedImports,            // Since this'll be under a single module, all imports to now-non-existent modules must be removed.
        &postProcess_removeAttributesPreceedingUnittests, // Otherwise we'll be leaving behind stray @safes and @("dsadasd") which can cause errors.
        &postProcess_removeUnittests,                     // Some unittests rely on passing modules (as part of JCLI's functionality), so we'll just remove them entirely.
        &postProcess_disallowBlanketAttributes,           // e.g. We don't want a stray "version(unittest):" to mess up the entire thing.
    ];

    for(size_t i = 0; i < stitched.length; i++)
    {
        const iAtStart = i;
        
        // Read until new line or end.
        while(i < stitched.length && stitched[i] != '\n')
            i++;

        const line = stitched[iAtStart..i];
        const lineLeftTrimmed = line.strip(" \t", null);

        bool outputLine = true;
        foreach(processor; processors)
        {
            const result = processor(lineLeftTrimmed, foundFirstModuleStatement, output, i, iAtStart, stitched);
            if(result == ProcessResult.handledOutputLine)
                break;
            else if(result == ProcessResult.handledScrapLine)
            {
                outputLine = false;
                break;
            }
        }

        if(outputLine)
        {
            output.put(line);
            output.put('\n');
        }
    }
}

ProcessResult postProcess_removeModuleStatements(string lineLeftTrimmed, ref bool foundFirstModuleStatement, ref Appender!(char[]) output, ref size_t i, const size_t iAtStart, string stitched)
{
    if(!lineLeftTrimmed.startsWith("module"))
        return ProcessResult.ignored;

    if(!foundFirstModuleStatement)
    {
        foundFirstModuleStatement = true;
        return ProcessResult.ignored;
    }

    // Comment it out so it's not used, but it can still let me know where each file starts in the output.
    output.put("//[NO_MODULE_STATEMENTS_ALLOWED]");
    return ProcessResult.handledOutputLine;
}

ProcessResult postProcess_removeBlacklistedImports(string lineLeftTrimmed, ref bool _, ref Appender!(char[]) output, ref size_t i, const size_t iAtStart, string stitched)
{
    if(!lineLeftTrimmed.startsWith("import") && !lineLeftTrimmed.startsWith("public import"))
        return ProcessResult.ignored;

    bool lineHasMatch(string line)
    {
        return MODULES_TO_REMOVE_FROM_IMPORTS.map!(reg => matchFirst(line, reg)).any!(result => !result.empty);
    }
    // Case #1: Single line import we can easily handle
    if(lineLeftTrimmed.canFind(';'))
    {
        if(lineHasMatch(lineLeftTrimmed))
        {
            output.put("//[CONTAINS_BLACKLISTED_IMPORT]");
            return ProcessResult.handledOutputLine;
        }
        return ProcessResult.ignored;
    }

    // Case #2: Multi line import we need to do a bit of manual parsing with.
    auto line = lineLeftTrimmed;
    bool badImport = false;
    const oldI = i;
    while(true)
    {
        if(lineHasMatch(line))
            badImport = true;

        if(line.canFind(';'))
            break;

        // Read up to the next new line
        i++; // Skip current
        const start = i;
        while(i < stitched.length && stitched[i] != '\n')
            i++;

        line = stitched[start..i];
    }

    if(!badImport)
    {
        i = oldI;
        return ProcessResult.ignored;
    }

    output.put("/*[CONTAINS_BLACKLISTED_IMPORT]\n");
    output.put(stitched[oldI..i]);
    output.put('\n');
    output.put("*/");
    output.put('\n');

    return ProcessResult.handledScrapLine;
}

ProcessResult postProcess_removeAttributesPreceedingUnittests(string lineLeftTrimmed, ref bool _, ref Appender!(char[]) output, ref size_t i, const size_t iAtStart, string stitched)
{
    if(!lineLeftTrimmed.startsWith("@"))
        return ProcessResult.ignored;

    const oldI = i;
    while(i < stitched.length)
    {
        // Go to the next line.
        i++;
        const start = i;
        while(i < stitched.length && stitched[i] != '\n')
            i++;
    
        const line = stitched[start..i].strip(" \t");
        if(line.startsWith("@"))
            continue;

        if(line.startsWith("unittest"))
        {
            output.put("/*[NO_ATTRIBUTES_BEFORE_UNITTESTS]\n");
            output.put(stitched[iAtStart..start]);
            output.put("\n*/\n");
            i = start - 1;
            return ProcessResult.handledScrapLine;
        }

        break;
    }

    i = oldI;
    return ProcessResult.ignored;
}

ProcessResult postProcess_removeUnittests(string lineLeftTrimmed, ref bool _, ref Appender!(char[]) output, ref size_t i, const size_t iAtStart, string stitched)
{
    if(!lineLeftTrimmed.startsWith("unittest"))
        return ProcessResult.ignored;

    output.put("/*[NO_UNITTESTS_ALLOWED]\n");
    
    size_t bracketCount = 0;
    const oldI = i;
    while(i < stitched.length)
    {
        if(stitched[i] == '{')
            bracketCount++;
        else if(stitched[i] == '}')
        {
            bracketCount--;
            enforce(bracketCount != size_t.max, "Unbalanced brackets");
            if(bracketCount == 0)
            {
                output.put(stitched[iAtStart..++i]); // ++i to include the end bracket.
                output.put("\n*/\n");
                return ProcessResult.handledScrapLine;
            }
        }

        i++;
    }

    // Should technically never happen, but it's possible I guess.
    i = oldI;
    return ProcessResult.ignored;
}

ProcessResult postProcess_disallowBlanketAttributes(string lineLeftTrimmed, ref bool _, ref Appender!(char[]) output, ref size_t i, const size_t iAtStart, string stitched)
{
    enforce(
        !lineLeftTrimmed.startsWith("version(unittest):"), 
        "Blanket attributes not allowed: "~lineLeftTrimmed
    );
    return ProcessResult.ignored;
}