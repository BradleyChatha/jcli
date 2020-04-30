# Used by CI to test that all examples compile and pass.
# I _could_ use JCLI itself, but then I'd have to worry about platform compatibility.

$TEST_CASES = @(
    @{ loc = "./00-basic-usage-default-command/";   params = "20";                  expected_status = 0    }
    @{ loc = "./00-basic-usage-default-command/";   params = "20 --reverse";        expected_status = 128  }

    @{ loc = "./01-named-sub-commands/";            params = "return 0";            expected_status = 0   }
    @{ loc = "./01-named-sub-commands/";            params = "r 128";               expected_status = 128 }

    @{ loc = "./02-shorthand-longhand-args/";       params = "return --code 0";     expected_status = 0 }
    @{ loc = "./02-shorthand-longhand-args/";       params = "r -c=128";            expected_status = 128 }

    @{ loc = "./03-inheritence-base-commands/";     params = "add 1 2";             expected_status = 3 }
    @{ loc = "./03-inheritence-base-commands/";     params = "add 1 2 --offset=7";  expected_status = 10 }
)

$AUX_DUB_PARAMS = ""
#$AUX_DUB_PARAMS += "--compiler=ldc2" # For personal needs, since my dmd install is broken.

# Generic cd -> dub run -> examine status code
function Invoke-DubTest($options) 
{
    Write-Host Running $options.loc '|' $options.params '|' $options.expected_status 

    Push-Location $options.loc
    $build_output = & dub build -b debug $AUX_DUB_PARAMS
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