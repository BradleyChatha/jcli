# Used by CI to test that all examples compile and pass.
# I _could_ use JCLI itself, but then I'd have to worry about platform compatibility.

$TEST_CASES = @(
    @{ loc = "./00-basic-usage/"; params = "20";           expected_status = 0  }
    @{ loc = "./00-basic-usage/"; params = "20 --reverse"; expected_status = -1 }
)

$AUX_DUB_PARAMS = ""
$AUX_DUB_PARAMS += "--compiler=ldc2" # For personal needs, since my dmd install is broken.

# Generic cd -> dub run -> examine status code
function Invoke-DubTest($options) 
{
    Write-Host Running $options.loc '|' $options.params '|' $options.expected_status 

    Push-Location $options.loc
    $build_output = & dub build $AUX_DUB_PARAMS
    Write-Host $build_output
    $run_output = & ./test $options.params.Split(" ")
    Write-Host $run_output
    Pop-Location
    $LASTEXITCODE
    return $options.expected_status -eq $LASTEXITCODE;
}

# Run all tests
$failedTests = [System.Collections.ArrayList]@()
foreach ($test in $TEST_CASES) 
{
    $result = Invoke-DubTest -options $test
    if(-not $result[-1]) # Don't ask. Just... Powershell
    {
        $test.actual_status = $result[-2]
        $failedTests.Add($test)
    }
}

# Output results, and set exit code.
$totalCount  = $TEST_CASES.Count
$failedCount = $failedTests.Count
$passedCount = $totalCount - $failedCount

Write-Host 'The following tests FAILED:'
Write-Host ($failedTests | Select-Object | Out-String)
Write-Host
Write-Host $totalCount total, $passedCount passed, $failedCount failed.

if($failedCount -ne 0)
{
    exit -1
}
else
{
    exit 0
}