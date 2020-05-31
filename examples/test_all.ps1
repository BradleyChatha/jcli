# Used by CI to test that all examples compile and pass.
# I _could_ use JCLI itself, but then I'd have to worry about platform compatibility.

$TEST_CASES = @(
    @{ loc = "./00-basic-usage-default-command/";   params = "20";                  expected_status = 0      }
    @{ loc = "./00-basic-usage-default-command/";   params = "20 --reverse";        expected_status = 128    }

    @{ loc = "./01-named-sub-commands/";            params = "return 0";            expected_status = 0      }
    @{ loc = "./01-named-sub-commands/";            params = "r 128";               expected_status = 128    }

    @{ loc = "./02-shorthand-longhand-args/";       params = "return --code 0";     expected_status = 0      }
    @{ loc = "./02-shorthand-longhand-args/";       params = "r -c=128";            expected_status = 128    }

    @{ loc = "./03-inheritence-base-commands/";     params = "add 1 2";             expected_status = 3      }
    @{ loc = "./03-inheritence-base-commands/";     params = "add 1 2 --offset=7";  expected_status = 10     }

    @{ loc = "./04-custom-arg-binders/";            params = "./dub.sdl";           expected_status = 0      }
    @{ loc = "./04-custom-arg-binders/";            params = "./lalaland.txt";      expected_status = 1      } # Don't completely know why, but 1 is returned on error.
    
    @{ loc = "./05-dependency-injection/";          params = "dman";                expected_status = 0      }
    @{ loc = "./05-dependency-injection/";          params = "cman";                expected_status = 128    }

    @{ loc = "./06-configuration";                  params = "force exception";     contains_match  = "`$^"  } # Match nothing
    @{ loc = "./06-configuration";                  params = "set verbose true";    contains_match  = "`$^"  }
    @{ loc = "./06-configuration";                  params = "set name Bradley";    contains_match  = ".*"   } # Verbose logging should kick in
    @{ loc = "./06-configuration";                  params = "force exception";     contains_match  = ".*"   } # Ditto
    @{ loc = "./06-configuration";                  params = "greet";               contains_match  = "Brad" }
)

$AUX_DUB_PARAMS = ""
$AUX_DUB_PARAMS += "--compiler=ldc2" # For personal needs, since my dmd install is broken.

Remove-Item -Path "./06-configuration/config.json" -ErrorAction Ignore # So we don't keep previous state.

# Generic cd -> dub run -> examine status code
function Invoke-DubTest($options) 
{
    Write-Host Running $options.loc '|' $options.params '| Status:' $options.expected_status '| Match:' $options.contains_match

    Push-Location $options.loc
    $build_output = & dub build -b debug $AUX_DUB_PARAMS
    Write-Host $build_output
    $run_output = & ./test $options.params.Split(" ")
    Write-Host $run_output
    Pop-Location

    if($null -eq $run_output)
    {
        $run_output = "";
    }

    $run_output
    $LASTEXITCODE
}

# Run all tests
$failedTests = [System.Collections.ArrayList]@()
foreach ($test in $TEST_CASES) 
{
    $result     = Invoke-DubTest -options $test
    $statusCode = $result[-1] # Don't ask. Just... Powershell
    $output     = $result[-2]

    # Status code test
    if($null -ne $test.expected_status -and $statusCode -ne $test.expected_status) 
    {
        $test.actual_status = $statusCode
        $failedTests.Add($test)
    }

    # Output contains test
    if($null -ne $test.contains_match -and $output -notmatch $test.contains_match)
    {
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