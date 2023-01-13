<#
curl -X GET "https://localhost:8443/api/system/stats" -H "accept: application/xml" -H "X-Requested-With: OpenAPI"


#>

function Get-MirthSystemStats {
    <#
    .SYNOPSIS
        Returns statistics for the underlying system. Returns an xml object to the Pipeline.

    .DESCRIPTION
        Returns statistics for the underlying system.

    .INPUTS
        A -connection  MirthConnection object is required. See Connect-Mirth.

    .OUTPUTS
        XML in the given format.

        <com.mirth.connect.model.SystemStats>
            <timestamp>
                <time>1673628573990</time>
                <timezone>America/Chicago</timezone>
            </timestamp>
            <cpuUsagePct>3.691752316394615E-5</cpuUsagePct>
            <allocatedMemoryBytes>239075328</allocatedMemoryBytes>
            <freeMemoryBytes>103990688</freeMemoryBytes>
            <maxMemoryBytes>239075328</maxMemoryBytes>
            <diskFreeBytes>80140439552</diskFreeBytes>
            <diskTotalBytes>1000202039296</diskTotalBytes>
        </com.mirth.connect.model.SystemStats>

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
    $uri = $serverUrl + '/api/system/stats'
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