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

Describe 'ConvertFrom-Xml' {
    It 'Given a default call, no attributes should be returned' {
        $test_input = ([xml]"<list class='map'><entry/></list>").DocumentElement
        $Properties = Get-XmlProperties $test_input
        $Properties.Count | Should -Be 1
    }
    
    It 'Given the switch IncludeAttributes, "class" should be returned' {
        $test_input = ([xml]"<list class='map'><entry/></list>").DocumentElement
        $Properties = Get-XmlProperties $test_input -IncludeAttributes
        $Properties.Count | Should -Be 2
    }
}