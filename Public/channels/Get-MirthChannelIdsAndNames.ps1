function Get-MirthChannelIdsAndNames {
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,
        [switch]
        $Raw
    )
    BEGIN {
        Write-Debug 'Get-MirthChannelIdsAndNames Beginning'
    }
    PROCESS {
        if ($null -eq $connection) {
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/channels/idsAndNames'
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Accept", "application/xml")
        
        Write-Debug "Invoking GET Mirth at $uri"
        try {
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session -Headers $headers
            Write-Debug "Parsing response"
            
            if ($Raw) {
                $r
            }
            else {
                $channelIdsAndNames = Convert-XmlMapToHashtable $r.DocumentElement "entry" "string"
    
                NotifyChannelMapCacheUpdate $channelIdsAndNames
    
                Write-Debug "...done."
    
                $channelIdsAndNames
            }
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug 'Get-MirthChannelIdsAndNames Ending' 
    }
}