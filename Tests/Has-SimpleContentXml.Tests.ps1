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

Describe 'Has-SimpleContentXml' {
    It 'Given content with no children, it should mark as simple content' {
        $test_input = ([xml]"<list></list>").DocumentElement
        $response = Has-SimpleContentXml $test_input -debug
        $response | Should -Be $true
    }

    It 'Given content with one child, it should not mark as simple content' {
        $test_input = ([xml]"<list><entry/></list>").DocumentElement
        $response = Has-SimpleContentXml $test_input -debug
        $response | Should -Be $false
    }

    It 'Given content with two children of the same name, it should mark as simple content' {
        $test_input = ([xml]"<list><entry/><entry/></list>").DocumentElement
        $response = Has-SimpleContentXml $test_input -debug
        $response | Should -Be $true
    }
}