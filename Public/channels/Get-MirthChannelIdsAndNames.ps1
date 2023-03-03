function Get-MirthChannelIdsAndNames {
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,
        [switch]
        $Raw,
        # Reverse the hashtable, so the channel name is the key and the channel id is the value.
        [switch]
        $Reverse,
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
        $headers.Add("accept", "application/xml")
        
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

                #$KeyIndex, $ValueIndex = $Reverse ? 1, 0 : 0, 1

                #map as ID->name
                foreach ($entry in $r.map.entry) {
                    $channelIdsAndNames.Add($entry.string[0], $entry.string[1])
                }

                #remap as name->ID if $Reverse
                if ($Reverse) {
                    $ReverseMap = @{}
                    $channelIdsAndNames.GetEnumerator() | ForEach-Object {
                        $ReverseMap.Add($_.Value, $_.Key)
                    }
                    $ReverseMap
                }
                else {
                    $channelIdsAndNames
                }
    
                Write-Debug "...done."
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