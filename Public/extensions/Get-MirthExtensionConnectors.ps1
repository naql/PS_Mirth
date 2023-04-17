function Get-MirthExtensionConnectors {
    [CmdletBinding()] 
    PARAM (
    
        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug 'Get-MirthExtensionConnectors Beginning'
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/extensions/connectors'
        Write-Debug "Invoking GET Mirth $uri "

        #$headers = $DEFAULT_HEADERS.clone()

        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -Headers $DEFAULT_HEADERS -WebSession $session
            Write-Debug "...done."

            if ($saveXML) { 
                Save-Content $r $outFile
            }
            Write-Verbose "$($r.OuterXml)"
            
            return $r
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug 'Get-MirthExtensionConnectors Ending' 
    }
}