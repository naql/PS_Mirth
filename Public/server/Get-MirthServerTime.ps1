function Get-MirthServerTime { 
    <#
    .SYNOPSIS
        Gets the Mirth server time.

    .DESCRIPTION
        Fetches the Mirth server time as a "gregorian-calendar" xml object.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        Returns xml containing server time and time zone:

        <gregorian-calendar>
            <time>1591908170092</time>
            <timezone>America/Chicago</timezone>
        </gregorian-calendar>

    .EXAMPLE
        connect-mirth | Get-MirthServerTime  -saveXML -outFile server-update-time.xml

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        [Parameter()]
        [switch]$Raw,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )     
    BEGIN { 
        Write-Debug "Get-MirthServerTime Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
 
        $uri = $serverUrl + '/api/server/time'
        $headers = $DEFAULT_HEADERS.Clone();
        $headers.Add("accept", "application/xml")
        $headers.Add("Content-Type", "application/xml")

        Write-Debug "Invoking GET Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -WebSession $session
            
            if ($saveXML) { 
                Save-Content $r $outFile
            }
            Write-Verbose "$($r.OuterXml)"
            
            if ($Raw) {
                $r
            }
            else {
                ConvertFrom-Xml $r.DocumentElement
            }
        }
        catch {
            Write-Error $_
        }
    }
    END { 
        Write-Debug "Get-MirthServerTime Ending"
    }
}  #  Get-MirthServerTime