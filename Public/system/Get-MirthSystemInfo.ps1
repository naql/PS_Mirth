<#
curl -X GET "https://localhost:8443/api/system/info" -H "accept: application/xml" -H "X-Requested-With: OpenAPI"
	
<com.mirth.connect.model.SystemInfo>
  <jvmVersion>1.8.0_351</jvmVersion>
  <osName>Windows 10</osName>
  <osVersion>10.0</osVersion>
  <osArchitecture>amd64</osArchitecture>
  <dbName>Apache Derby</dbName>
  <dbVersion>10.10.2.0 - (1582446)</dbVersion>
</com.mirth.connect.model.SystemInfo>
#>

function Get-MirthSystemInfo {
    <#
    .SYNOPSIS
        Returns information about the underlying system. Returns an xml object to the Pipeline.

    .DESCRIPTION
        Returns information about the underlying system.

    .INPUTS
        A -connection  MirthConnection object is required. See Connect-Mirth.

    .OUTPUTS
        XML in the given format.

        <com.mirth.connect.model.SystemInfo>
            <jvmVersion>1.8.0_351</jvmVersion>
            <osName>Windows 10</osName>
            <osVersion>10.0</osVersion>
            <osArchitecture>amd64</osArchitecture>
            <dbName>Apache Derby</dbName>
            <dbVersion>10.10.2.0 - (1582446)</dbVersion>
        </com.mirth.connect.model.SystemInfo>

        If the -asHashtable switch is specified, the response is a PowerShell hashtable.

    .EXAMPLE
        Connect-Mirth | Get-MirthConfigMap 
        Get-MirthConfigMap -asHashtable 

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # Switch, if true, returns hashtable response, otherwise XML
        [Parameter()]
        [switch]$asHashtable,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 

    if ($null -eq $connection) { 
        Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
    }          
    [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
    $serverUrl = $connection.serverUrl

    $headers = $DEFAULT_HEADERS.Clone()
    $headers.Add("accept", "application/xml")
    $uri = $serverUrl + '/api/system/info'
    Write-Debug "Invoking GET Mirth at $uri"
    try { 
        $r = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -WebSession $session

        if ($saveXML) { 
            Save-Content $r $outFile
        }
        Write-Verbose "$($r.OuterXml)"

        if (-not $asHashtable) { 
            $r
        }
        else { 
            Write-Debug "Converting XML response to hashtable"

            Convert-XmlToHashtable $r.DocumentElement
        }
    }
    catch {
        Write-Error $_
    }
}