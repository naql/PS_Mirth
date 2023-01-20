BeforeAll {
    $Private = @( Get-ChildItem -Path .\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue )

    #Dot source the files
    Foreach ($import in $Private) {
        Try {
            . $import.fullname
        }
        Catch {
            Write-Error -Message "Failed to import class/function $($import.fullname): $_"
        }
    }
}

Describe 'Convert-ToMirthDateString' {
    It 'Given valid input, it should not throw' {
        { Convert-ToMirthDateString "2022-12-25" } | Should -Not -Throw
        { Convert-ToMirthDateString (Get-Date) } | Should -Not -Throw
        { Convert-ToMirthDateString ([System.DateTimeOffset]::Now) } | Should -Not -Throw
    }

    It 'Given valid input, it should not contain a colon in the timezone offset' {
        $Value = Convert-ToMirthDateString "2022-12-25"
        $Value.LastIndexOf(":") | Should -BeLessThan 26
        $ExpectedRegex = "(?<year>(\d){4})-(?<month>(\d){2})-(?<day>(\d){2})T(?<hour>(\d){2}):(?<minute>(\d){2}):(?<second>(\d){2}).(?<milli>(\d){3})[+|-](?<offset>(\d){4})"
        $Value | Should -Match $ExpectedRegex
    }

    It 'Given invalid input, it should throw' {
        { Convert-ToMirthDateString "20x2-12-25" } | Should -Throw
        { Convert-ToMirthDateString @{} } | Should -Throw -Because "Unsupported type"
    }
}