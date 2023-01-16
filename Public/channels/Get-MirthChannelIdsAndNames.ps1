function Get-MirthChannelIdsAndNames {
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,
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
            
            if ($saveXML) { 
                Save-Content $r $outFile
            }

            if ($Raw) {
                $r
            }
            else {
                Write-Debug "Parsing response"
                
                #$channelIdsAndNames = Convert-XmlMapToHashtable $r.DocumentElement "entry" "string"
                
                $channelIdsAndNames = @{}
                #results are ordered ID then name
                foreach ($entry in $r.map.entry) {
                    $channelIdsAndNames.Add($entry.string[0], $entry.string[1])
                }
    
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