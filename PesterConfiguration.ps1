New-PesterConfiguration @{
    Run = @{
        Path = './Tests'
        PassThru = $true
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    CodeCoverage = @{
        Enabled = $true
        Path = './OllamaOpenWebUIAPI/**/*.ps1'
        OutputFormat = 'JaCoCo'
        OutputPath = './Tests/coverage.xml'
    }
    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = './Tests/testresults.xml'
    }
}
