/+dub.sdl:
    name "test"
    dependency "jcli" path="../"
+/
module test;

import std, jcli;

/++ DATA TYPES ++/
struct TestCase
{
    string                  folder;
    string                  params;
    string[]                cleanupFiles;
    Nullable!int            expectedStatus;
    Nullable!(Regex!char)   outputRegex;
    bool                    allowedToFail;
}

struct TestCaseBuilder
{
    TestCase testCase;

    TestCaseBuilder inFolder(string folder)
    {
        this.testCase.folder = folder;
        return this;
    }

    TestCaseBuilder withParams(string params)
    {
        this.testCase.params = params;
        return this;
    }

    TestCaseBuilder expectStatusToBe(int status)
    {
        this.testCase.expectedStatus = status;
        return this;
    }

    TestCaseBuilder expectOutputToMatch(string regexString)
    {
        this.testCase.outputRegex = regex(regexString);
        return this;
    }

    TestCaseBuilder cleanup(string fileName)
    {
        this.testCase.cleanupFiles ~= fileName;
        return this;
    }

    TestCaseBuilder allowToFail()
    {
        this.testCase.allowedToFail = true;
        return this;
    }

    TestCase finish()
    {
        return this.testCase;
    }
}
TestCaseBuilder testCase(){ return TestCaseBuilder(); }

struct TestResult
{
    bool     passed;
    string[] failedReasons;
    TestCase testCase;
}

/++ CONFIGURATION ++/
auto TEST_CASES = 
[
    testCase().inFolder         ("./00-basic-usage-default-command/")
              .withParams       ("20")
              .expectStatusToBe (0)
              .finish           (),
    testCase().inFolder         ("./00-basic-usage-default-command/")
              .withParams       ("20 --reverse")
              .expectStatusToBe (128)
              .finish           (),
    
    testCase().inFolder         ("./01-named-sub-commands/")
              .withParams       ("return 0")
              .expectStatusToBe (0)
              .finish           (),
    testCase().inFolder         ("./01-named-sub-commands/")
              .withParams       ("r 128")
              .expectStatusToBe (128)
              .finish           (),

    testCase().inFolder         ("./02-shorthand-longhand-args/")
              .withParams       ("return --code 0")
              .expectStatusToBe (0)
              .finish           (),
    testCase().inFolder         ("./02-shorthand-longhand-args/")
              .withParams       ("r -c=128")
              .expectStatusToBe (128)
              .finish           (),

    // Class inheritence is broken, but I don't really think I can fix it without compiler changes.
    testCase().inFolder         ("./03-inheritence-base-commands/")
              .withParams       ("add 1 2")
              .expectStatusToBe (3)
              .allowToFail      ()
              .finish           (),
    testCase().inFolder         ("./03-inheritence-base-commands/")
              .withParams       ("add 1 2 --offset=7")
              .expectStatusToBe (10)
              .allowToFail      ()
              .finish           (),

    testCase().inFolder         ("./04-custom-arg-binders/")
              .withParams       ("./dub.sdl")
              .expectStatusToBe (0)
              .finish           (),
    testCase().inFolder         ("./04-custom-arg-binders/")
              .withParams       ("./lalaland.txt")
              .expectStatusToBe (-1)
              .finish           (),

    testCase().inFolder         ("./05-built-in-binders/")
              .withParams       ("echo -b -i 2 -f 2.2 -s Hola -e red")
              .expectStatusToBe (0)
              .finish           (),

    testCase().inFolder             ("./08-arg-binder-validation")
              .withParams           ("20 69")
              .expectStatusToBe     (0)
              .finish               (),
    testCase().inFolder             ("./08-arg-binder-validation")
              .withParams           ("69 69")
              .expectStatusToBe     (-1)
              .expectOutputToMatch  ("Expected number to be even")
              .finish               (),
    testCase().inFolder             ("./08-arg-binder-validation")
              .withParams           ("20 20")
              .expectStatusToBe     (-1)
              .expectOutputToMatch  ("Expected number to be odd")
              .finish               (),

    testCase().inFolder             ("./09-raw-unparsed-arg-list")
              .withParams           ("echo -- Some args")
              .expectStatusToBe     (0)
              .expectOutputToMatch  (`Running command 'echo' with arguments \["Some", "args"\]`)
              .finish               (),
    testCase().inFolder             ("./09-raw-unparsed-arg-list")
              .withParams           ("noarg")
              .expectStatusToBe     (0)
              .expectOutputToMatch  (`Running command 'noarg' with arguments \[\]`)
              .finish               (),

    testCase().inFolder             ("./10-argument-options")
              .withParams           ("sensitive --abc 2")
              .expectStatusToBe     (0)
              .finish               (),
    testCase().inFolder             ("./10-argument-options")
              .withParams           ("sensitive --abC 2")
              .expectStatusToBe     (-1)
              .finish               (),
    testCase().inFolder             ("./10-argument-options")
              .withParams           ("insensitive --abc 2")
              .expectStatusToBe     (0)
              .finish               (),
    testCase().inFolder             ("./10-argument-options")
              .withParams           ("insensitive --ABC 2")
              .expectStatusToBe     (0)
              .finish               (),
    testCase().inFolder             ("./10-argument-options")
              .withParams           ("redefine --abc 2")
              .expectStatusToBe     (2)
              .finish               (),
    testCase().inFolder             ("./10-argument-options")
              .withParams           ("redefine --abc 2 --abc 1")
              .expectStatusToBe     (1)
              .finish               (),
    testCase().inFolder             ("./10-argument-options")
              .withParams           ("no-redefine --abc 2")
              .expectStatusToBe     (0)
              .finish               (),
    testCase().inFolder             ("./10-argument-options")
              .withParams           ("no-redefine --abc 2 --abc 1")
              .expectStatusToBe     (-1)
              .finish               (),
];
 
/++ MAIN ++/
int main(string[] args)
{
    return (new CommandLineInterface!test()).parseAndExecute(args);
}

/++ COMMANDS ++/
@CommandDefault("Runs all test cases")
struct DefaultCommand
{
    int onExecute()
    {
        writefln("Running %s tests.", "ALL".ansi.fg(Ansi4BitColour.green));
        const anyfails = runTestSet(TEST_CASES);

        return anyfails ? -1 : 0;
    }
}

@Command("cleanup", "Runs the cleanup command for all test cases")
struct CleanupCommand
{
    void onExecute()
    {
        foreach(test; TEST_CASES)
            runCleanup(test);
    }
}

/++ FUNCS ++/
bool runTestSet(TestCase[] testSet)
{
    auto results = new TestResult[testSet.length];
    foreach(i, testCase; testSet)
        results[i] = testCase.runTest();

    if(results.any!(r => !r.passed))
        writefln("\n\nThe following tests %s:", "FAILED".ansi.fg(Ansi4BitColour.red));

    size_t failedCount;
    foreach(failed; results.filter!(r => !r.passed))
    {
        failedCount++;
        writefln("\t%s", failed.testCase.to!string.ansi.fg(Ansi4BitColour.cyan));

        foreach(reason; failed.failedReasons)
            writefln("\t\t- %s".ansi.fg(Ansi4BitColour.red).to!string, reason);
    }

    size_t passedCount = results.length - failedCount;
    writefln(
        "\n%s %s, %s %s, %s total tests",
        passedCount, "PASSED".ansi.fg(Ansi4BitColour.green),
        failedCount, "FAILED".ansi.fg(Ansi4BitColour.red),
        results.length
    );

    return (failedCount != 0);
}

TestResult runTest(TestCase testCase)
{
    const    results = getBuildAndTestResults(testCase);
    auto     passed  = true;
    string[] reasons;

    void failIf(bool condition, string reason)
    {
        if(!condition)
            return;

        passed   = false;
        reasons ~= reason;
    }

    failIf(results[0].status != 0, "Build failed.");

    // When handling the status code, some terminals allow negative status codes, some don't, so we'll special case expecting
    // a -1 as expecting -1 or 255.
    if(testCase.expectedStatus.get(0) != -1)
        failIf(results[1].status != testCase.expectedStatus.get(0), "Status code is wrong.");
    else
        failIf(results[1].status != -1 && results[1].status != 255, "Status code is wrong. (-1 special case)");

    if(!testCase.outputRegex.isNull)
        failIf(!results[1].output.matchFirst(testCase.outputRegex.get), "Output doesn't contain a match for the given regex.");

    if(testCase.allowedToFail)
    {
        if(!passed)
            writeln("Test FAILED (ALLOWED).".ansi.fg(Ansi4BitColour.yellow));
        passed = true;
    }

    if(!passed)
        writeln("Test FAILED".ansi.fg(Ansi4BitColour.red));
    else
        writefln("%s", "Test PASSED".ansi.fg(Ansi4BitColour.green));

    return TestResult(passed, reasons, testCase);
}

// [0] = build result, [1] = test result
auto getBuildAndTestResults(TestCase testCase)
{
    const CATEGORY_COLOUR = Ansi4BitColour.magenta;
    const VALUE_COLOUR    = Ansi4BitColour.brightBlue;
    const RESULT_COLOUR   = Ansi4BitColour.yellow;

    writefln("");
    writefln("%s", "[Test Case]".ansi.fg(CATEGORY_COLOUR));
    writefln("%s: %s", "Folder".ansi.fg(CATEGORY_COLOUR),  testCase.folder.ansi.fg(VALUE_COLOUR));
    writefln("%s: %s", "Params".ansi.fg(CATEGORY_COLOUR),  testCase.params.ansi.fg(VALUE_COLOUR));
    writefln("%s: %s", "Status".ansi.fg(CATEGORY_COLOUR),  testCase.expectedStatus.get(0).to!string.ansi.fg(RESULT_COLOUR));
    writefln("%s: %s", "Regex ".ansi.fg(CATEGORY_COLOUR),  testCase.outputRegex.get(regex("N/A")).to!string.ansi.fg(RESULT_COLOUR));

    auto cwd = getcwd();
    chdir(testCase.folder);
    scope(exit) chdir(cwd);

    foreach(file; testCase.cleanupFiles.filter!(f => f.exists))
    {
        writefln("Cleanup: %s".ansi.fg(Ansi4BitColour.brightBlack).to!string, file);
        remove(file);
    }

    const buildString   = "dub build --compiler=ldc2";
    const commandString = "\"./test\" " ~ testCase.params;
    const buildResult   = executeShell(buildString);
    const result        = executeShell(commandString);

    writefln("\n%s(status: %s):\n%s", "Build output".ansi.fg(CATEGORY_COLOUR), buildResult.status.to!string.ansi.fg(RESULT_COLOUR), buildResult.output);
    writefln("%s(status: %s):\n%s",   "Test output".ansi.fg(CATEGORY_COLOUR),  result.status.to!string.ansi.fg(RESULT_COLOUR),      result.output);

    return [buildResult, result];
}

void runCleanup(TestCase testCase)
{
    auto cwd = getcwd();
    chdir(testCase.folder);
    scope(exit) chdir(cwd);
    executeShell("dub clean");
}