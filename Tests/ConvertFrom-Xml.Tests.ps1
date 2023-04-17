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
    It 'Given simple xml, it should return a single node' {
        $test_input = ([xml]"<list><entry/></list>").DocumentElement
        $response = ConvertFrom-Xml -Data $test_input
        $response | Should -HaveCount 1
    }

    It 'Given simple xml with a class attr, it should return a single node' {
        $test_input = ([xml]"<list class='map'><entry/></list>").DocumentElement
        $response = ConvertFrom-Xml -Data $test_input
        $response | Should -HaveCount 1
    }
    
    It 'Given a channel status xml, it should return multiple lists' {
        $test_input = ([xml](Get-Content .\Tests\Files\Save-Get-MirthChannelStatuses-Output.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsList @('list', 'statistics', 'lifetimeStatistics')
        $response -is [array] | Should -Be $true
        $response | Should -HaveCount 11
        $response[0].statistics -is [array] | Should -Be $true
        $response[0].lifetimeStatistics -is [array] | Should -Be $true
    }

    It 'Given a channel message xml, it should return data of the correct types' {
        $test_input = ([xml](Get-Content .\Tests\Files\Save-Get-MirthChannelMsgById-Output.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsMap @{'connectorMessages' = $false }
        $response.Count | Should -Be 6
        #TODO not sure why it's failing to see it as an array, sees a hashtable
        #$response.connectorMessages | Should -BeOfType array
        $response.connectorMessages.Count | Should -Be 2
        $response.connectorMessages['0'] -is [hashtable] | Should -Be $true
        $response.connectorMessages['0'].Count | Should -Be 23
        $response.connectorMessages['0'].receivedDate.Count | Should -Be 2
        $response.connectorMessages['0'].raw -is [hashtable] | Should -Be $true
    }

    #TODO implement this
    It 'Given a content map with matching child nodes, it should return valid data' {
        $test_input = ([xml](Get-Content .\Tests\Files\minimal-content-map-matching-node-names.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsMap @{'content' = $true }
        $response.Count | Should -Be 2
        $response.content.Count | Should -Be 2
    }

    It 'Given a config map xml, it should return a valid list' {
        $test_input = ([xml](Get-Content .\Tests\Files\Save-Get-MirthConfigMap-Output.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsMap @{'map' = $true }
        $response.Count | Should -be 16 -Because 'we expect -ConvertAsMap to return the deeper hashtable, not to give us a single-value hashtable'
        $response.Values | Should -Not -BeNullOrEmpty
    }

    It 'Given a channel metadata xml, it should return valid data' {
        $test_input = ([xml](Get-Content .\Tests\Files\Save-Get-MirthServerChannelMetadata-Output.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsMap @{'map' = $false }
        $response.Count | Should -be 48
        $item = $response['8e2c2493-fc3a-4cce-af6a-b9e78962967c']
        $item | Should -BeOfType hashtable
        $item.enabled | Should -Be "true"
        $item.pruningSettings -is [hashtable] | Should -Be $true
    }

    It 'Given a channel with multiple "message" entries, it should return an array of hashtables with an inner hashtable' {
        $test_input = ([xml](Get-Content .\Tests\Files\Get-MirthChannelMessages-Output-Multiple.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsList @('list') -ConvertAsMap @{ 'connectorMessages' = $false }
        $response | Should -HaveCount 2
        #not sure why it fails with -BeOfType array, using alternative
        $response -is [array] | Should -Be $true
        $response[0].connectorMessages -is [hashtable] | Should -Be $true
    }

    It 'Given a channel with a single "message" entry, it should return a valid hashtable with an inner hashtable' {
        $test_input = ([xml](Get-Content .\Tests\Files\Get-MirthChannelMessages-Output-Single.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsList @('list') -ConvertAsMap @{'connectorMessages' = $false }
        $response | Should -HaveCount 1
        #not sure why it fails with -BeOfType array, using alternative
        $response -is [array] | Should -be $true
        $response[0].connectorMessages -is [hashtable] | Should -Be $true
    }

    #TODO implement this
    It 'Given a channel with a <content class="map">, it should return "content" as hashtable without "entry"' -Skip {
        $test_input = ([xml](Get-Content .\Tests\Files\Get-MirthChannelMessages-Output-Multiple-WithContentIncluded.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsList @('list') -ConvertAsMap @{'connectorMessages' = $false; 'content' = $false }
        $response[0].ConnectorMessages['0'].responseMapContent.content.Count | Should -Be 1
        $response[0].ConnectorMessages['0'].responseMapContent.content.ContainsKey('entry') | Should -be $false
    }

    It 'Given minimal XML containing <content class="map">, it should return "content" as hashtable without "entry"' {
        $test_input = ([xml](Get-Content .\Tests\Files\minimal-content-map.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsMap @{'content' = $false }
        $response.content | Should -HaveCount 1
        $response.content.ContainsKey('entry') | Should -be $false
    }

    #this is currently a custom conversion
    <#It 'Given an extension properties xml, it should return valid data' {
        $test_input = ([xml](Get-Content ".\Tests\Files\Save-Get-MirthExtensionProperties-SSL Manager-Output.xml")).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsList @{'properties' = 'property' } -Debug
        $response.Count | Should -be 4
    }#>
}