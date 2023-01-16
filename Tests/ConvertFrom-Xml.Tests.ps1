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
        $test_input = ([xml]"<list class='map'><entry/></list>").DocumentElement
        $response = ConvertFrom-Xml -Data $test_input -Debug
        $response.Count | Should -Be 1
    }
    
    It 'Given a channel status xml, it should return a list' {
        $test_input = ([xml](Get-Content .\Tests\Files\Save-Get-MirthChannelStatuses-Output.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsList @{'list' = 'dashboardStatus'; 'statistics' = 'entry'; 'lifetimeStatistics' = 'entry' }
        $response.Count | Should -Be 11
    }

    It 'Given a channel message xml, it should return valid data' {
        $test_input = ([xml](Get-Content .\Tests\Files\Save-Get-MirthChannelMsgById-Output.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsList @{'connectorMessages' = 'entry' }
        $response.Count | Should -Be 6
        #TODO not sure why it's failing to see it as an array, sees a hashtable
        #$response.connectorMessages | Should -BeOfType array
        $response.connectorMessages.Count | Should -Be 2
        $response.connectorMessages[0].connectorMessage.receivedDate.Count | Should -Be 2
    }

    It 'Given a config map xml, it should return a valid list' {
        $test_input = ([xml](Get-Content .\Tests\Files\Save-Get-MirthConfigMap-Output.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -MapNames @('com.mirth.connect.util.ConfigurationProperty/value')
        $response.Count | Should -be 16
        $response.Values | Should -Not -BeNullOrEmpty
    }

    It 'Given a channel metadata xml, it should return valid data' {
        $test_input = ([xml](Get-Content .\Tests\Files\Save-Get-MirthServerChannelMetadata-Output.xml)).DocumentElement
        $response = ConvertFrom-Xml $test_input -MapNames @('com.mirth.connect.model.ChannelMetadata')
        $response.Count | Should -be 48
        $item = $response['8e2c2493-fc3a-4cce-af6a-b9e78962967c']
        $item | Should -BeOfType hashtable
        $item.enabled | Should -Be "true"
        $item.pruningSettings | Should -BeOfType hashtable
    }

    #this is currently a custom conversion
    <#It 'Given an extension properties xml, it should return valid data' {
        $test_input = ([xml](Get-Content ".\Tests\Files\Save-Get-MirthExtensionProperties-SSL Manager-Output.xml")).DocumentElement
        $response = ConvertFrom-Xml $test_input -ConvertAsList @{'properties' = 'property' }
        $response.Count | Should -be 4
    }#>
}