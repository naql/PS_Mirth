function Test-MirthFileReadWrite { 
    <#
    .SYNOPSIS
        Tests whether or not Mirth can read and/or write from a file folder path.

    .DESCRIPTION
        Returns an XML object the test result.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        $testPath   String containing directory path to be tested.

    .OUTPUTS
        [bool] $True if the folder passes the test, otherwise $False 

    .EXAMPLE
        $result = Test-MirthFileReadWrite -testPath D:/TEMP -mode R 
        if ($(Test-MirthFileReadWrite -testPath $path -mode RW )) { ... }

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter(Mandatory = $True)]
        [String]$testPath,

        # File mode to test: R = Read, W = Write, RW = Read/Write
        [Parameter()]
        [ValidateSet('R', 'W', 'RW')]        
        [String]$mode = "R"
    ) 
    BEGIN { 
        Write-Debug "Test-MirthFileReadWrite Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $channelId = "11111111-2222-3333-4444-555555555555"
        $channelName = "PS_MIRTH_TEST_FILE_" + $mode

        [xml] $testReadXML = @"
        <properties class="com.mirth.connect.connectors.file.FileReceiverProperties">
            <pluginProperties/>
            <pollConnectorProperties version="3.6.2" />
            <sourceConnectorProperties version="3.6.2" />
            <scheme>FILE</scheme>
            <host>$testPath</host>
            <timeout>10000</timeout>
        </properties>
"@
        [xml] $testWriteXML = @"
        <properties class="com.mirth.connect.connectors.file.FileDispatcherProperties">
            <pluginProperties />
            <destinationConnectorProperties/>
            <scheme>FILE</scheme>
            <host>$testPath</host>
            <timeout>10000</timeout>
        </properties>
"@
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('channelId', $channelId)
        $parameters.Add('channelName', $channelName)

        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Accept", "application/xml")
        $headers.Add("Content-Type", "application/xml")
      
        $result = $True
        try { 
            if ($mode.Contains('R')) {
                $uri = $serverUrl + '/api/connectors/file/_testRead'
                $uri = $uri + '?' + $parameters.toString()
                Write-Debug "Invoking POST Mirth API server at: $uri "
                $r = Invoke-RestMethod -Uri $uri -Headers $headers -Method POST -WebSession $session -Body $testReadXML.OuterXml
                [String] $testResult = $r.'com.mirth.connect.util.ConnectionTestResponse'.type
                Write-Verbose "READ Test:" 
                Write-Verbose "$($r.OuterXml)"
                $result = ($result -and ($testResult -eq "SUCCESS")) 
            }
            if ($mode.Contains('W')) {
                $uri = $serverUrl + '/api/connectors/file/_testWrite'
                $uri = $uri + '?' + $parameters.toString()
                Write-Debug "Invoking POST Mirth API server at: $uri "
                $r = Invoke-RestMethod -Uri $uri -Headers $headers -Method POST -WebSession $session -Body $testWriteXML.OuterXml
                [String] $testResult = $r.'com.mirth.connect.util.ConnectionTestResponse'.type
                Write-Verbose "Write Test:" 
                Write-Verbose "$($r.OuterXml)"
                $result = ($result -and ($testResult -eq "SUCCESS"))                 
            }
            return $result

        }
        catch {
            Write-Error $_
        }  
    }
    END {
        Write-Debug "Test-MirthFileRead Ending"
    } 
}  # Test-MirthFileRead
