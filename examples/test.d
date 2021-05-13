/+dub.sdl:
    name "test"
    dependency "jcli" path="../"
+/
module test;

import std, jaster.cli;

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

    testCase().inFolder         ("./05-dependency-injection/")
              .withParams       ("dman")
              .expectStatusToBe (0)
              .finish           (),
    testCase().inFolder         ("./05-dependency-injection/")
              .withParams       ("cman")
              .expectStatusToBe (128)
              .finish           (),

    testCase().inFolder             ("./06-configuration")
              .withParams           ("force exception")
              .expectOutputToMatch  ("$^")          // Match nothing
              .cleanup              ("config.json") // Otherwise subsequent runs of this test set won't work.
              .finish               (),
    testCase().inFolder             ("./06-configuration")
              .withParams           ("set verbose true")
              .expectOutputToMatch  ("$^")
              .finish               (),
    testCase().inFolder             ("./06-configuration")
              .withParams           ("set name Bradley")
              .expectOutputToMatch  (".*") // Verbose logging should kick in
              .finish               (), 
    testCase().inFolder             ("./06-configuration")
              .withParams           ("force exception")
              .expectOutputToMatch  (".*") // Ditto
              .finish               (),
    testCase().inFolder             ("./06-configuration")
              .withParams           ("greet")
              .expectOutputToMatch  ("Brad")
              .finish               (),

    // Can't use expectOutputToMatch for non-coloured text as it doesn't handle ANSI properly.
    testCase().inFolder             ("./07-text-buffer-table")
              .withParams           ("fixed")
              .expectStatusToBe     (0)
              .expectOutputToMatch  ("Age")
              .finish               (),
    testCase().inFolder             ("./07-text-buffer-table")
              .withParams           ("dynamic")
              .expectStatusToBe     (0)
              .expectOutputToMatch  ("Age")
              .finish               (),

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

    testCase().inFolder             ("./10-case-sensitive-args")
              .withParams           ("sensitive --abc 2")
              .expectStatusToBe     (0)
              .finish               (),
    testCase().inFolder             ("./10-case-sensitive-args")
              .withParams           ("sensitive --abC 2")
              .expectStatusToBe     (-1)
              .finish               (),
    testCase().inFolder             ("./10-case-sensitive-args")
              .withParams           ("insensitive --abc 2")
              .expectStatusToBe     (0)
              .finish               (),
    testCase().inFolder             ("./10-case-sensitive-args")
              .withParams           ("insensitive --ABC 2")
              .expectStatusToBe     (0)
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
        UserIO.logInfof("Running %s tests.", "ALL".ansi.fg(Ansi4BitColour.green));
        const anyFailures = runTestSet(TEST_CASES);

        return anyFailures ? -1 : 0;
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
        UserIO.logInfof("\n\nThe following tests %s:", "FAILED".ansi.fg(Ansi4BitColour.red));

    size_t failedCount;
    foreach(failed; results.filter!(r => !r.passed))
    {
        failedCount++;
        UserIO.logInfof("\t%s", failed.testCase.to!string.ansi.fg(Ansi4BitColour.cyan));

        foreach(reason; failed.failedReasons)
            UserIO.logErrorf("\t\t- %s", reason);
    }

    size_t passedCount = results.length - failedCount;
    UserIO.logInfof(
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

    failIf(results[0].statusCode != 0, "Build failed.");

    // When handling the status code, some terminals allow negative status codes, some don't, so we'll special case expecting
    // a -1 as expecting -1 or 255.
    if(testCase.expectedStatus.get(0) != -1)
        failIf(results[1].statusCode != testCase.expectedStatus.get(0), "Status code is wrong.");
    else
        failIf(results[1].statusCode != -1 && results[1].statusCode != 255, "Status code is wrong. (-1 special case)");

    if(!testCase.outputRegex.isNull)
        failIf(!results[1].output.match(testCase.outputRegex), "Output doesn't contain a match for the given regex.");

    if(testCase.allowedToFail)
    {
        if(!passed)
            UserIO.logWarningf("Test FAILED (ALLOWED).");
        passed = true;
    }

    if(!passed)
        UserIO.logErrorf("Test FAILED");
    else
        UserIO.logInfof("%s", "Test PASSED".ansi.fg(Ansi4BitColour.green));

    return TestResult(passed, reasons, testCase);
}

// [0] = build result, [1] = test result
Shell.Result[2] getBuildAndTestResults(TestCase testCase)
{
    const CATEGORY_COLOUR = Ansi4BitColour.magenta;
    const VALUE_COLOUR    = Ansi4BitColour.brightBlue;
    const RESULT_COLOUR   = Ansi4BitColour.yellow;

    UserIO.logInfof("");
    UserIO.logInfof("%s", "[Test Case]".ansi.fg(CATEGORY_COLOUR));
    UserIO.logInfof("%s: %s", "Folder".ansi.fg(CATEGORY_COLOUR),  testCase.folder.ansi.fg(VALUE_COLOUR));
    UserIO.logInfof("%s: %s", "Params".ansi.fg(CATEGORY_COLOUR),  testCase.params.ansi.fg(VALUE_COLOUR));
    UserIO.logInfof("%s: %s", "Status".ansi.fg(CATEGORY_COLOUR),  testCase.expectedStatus.get(0).to!string.ansi.fg(RESULT_COLOUR));
    UserIO.logInfof("%s: %s", "Regex ".ansi.fg(CATEGORY_COLOUR),  testCase.outputRegex.get(regex("N/A")).to!string.ansi.fg(RESULT_COLOUR));

    Shell.pushLocation(testCase.folder);
    scope(exit) Shell.popLocation();

    foreach(file; testCase.cleanupFiles.filter!(f => f.exists))
    {
        UserIO.logTracef("Cleanup: %s", file);
        remove(file);
    }

    const buildString   = "dub build --compiler=ldc2";
    const commandString = "\"./test\" " ~ testCase.params;
    const buildResult   = Shell.execute(buildString);
    const result        = Shell.execute(commandString);

    UserIO.logInfof("\n%s(status: %s):\n%s", "Build output".ansi.fg(CATEGORY_COLOUR), buildResult.statusCode.to!string.ansi.fg(RESULT_COLOUR), buildResult.output);
    UserIO.logInfof("%s(status: %s):\n%s",   "Test output".ansi.fg(CATEGORY_COLOUR),  result.statusCode.to!string.ansi.fg(RESULT_COLOUR),      result.output);

    return [buildResult, result];
}

void runCleanup(TestCase testCase)
{
    Shell.pushLocation(testCase.folder);
    scope(exit) Shell.popLocation();
    Shell.execute("dub clean");
}