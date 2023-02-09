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

Describe 'Get-UsableChildNodeNames' {
    It 'Given two child nodes, two names should be returned' {
        $test_input = ([xml]"<list><foo/><bar/></list>").DocumentElement
        $Names = Get-UsableChildNodeNames $test_input.ChildNodes
        $Names | Should -HaveCount 2
    }

    It 'Given a child node with sub-node "name", the LocalName should be returned' {
        #there's a quirk where a node can contain a sub-node named "name",
        #and it overwrites the Name lookup, so use LocalName instead.
        $test_input = ([xml](Get-Content .\Tests\Files\Get-UsableChildNodeNames.xml)).DocumentElement
        $Names = Get-UsableChildNodeNames $test_input.entry.ChildNodes
        $Names[0] | Should -Be 'string'
        $Names[1] | Should -Be 'connectorMetaData'
    }
}