function Get-MirthEventById {
    [CmdletBinding()] 
    PARAM (
    
        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the event to retrieve.
        [Parameter(Mandatory, Position = 0)]
        [string]$Id,

        [switch]
        $Raw,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug 'Get-MirthDatabaseTaskById Beginning'
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + "/api/events/$Id"
        Write-Debug "Invoking GET Mirth $uri "

        #$headers = $DEFAULT_HEADERS.clone()

        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -Headers $DEFAULT_HEADERS -WebSession $session
            Write-Debug "...done."

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
        Write-Debug 'Get-MirthDatabaseTaskById Ending' 
    }
}