function Get-MirthServerChannelMetadata { 
    <#
    .SYNOPSIS
        Gets all Mirth server channel metadata.

    .DESCRIPTION
        Return xml object describing channel metadata, enabled status, pruning settings, etc.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all channel groups are returned.  Otherwise, only the channel groups with the 
        id values specified are returned.

    .OUTPUTS
        Returns an XML object that represents all channel metadata

        <map>
            <entry>
                <string>cdfcb6b1-5fd4-4ef0-a700-68cacf6d0467</string>
                <com.mirth.connect.model.ChannelMetadata>
                    <enabled>true</enabled>                  
                    <lastModified>
                        <time>1592081530193</time>
                        <timezone>America/Chicago</timezone>
                    </lastModified>
                    <pruningSettings>
                        <pruneMetaDataDays>30</pruneMetaDataDays>
                        <pruneContentDays>15</pruneContentDays>
                        <archiveEnabled>true</archiveEnabled>
                    </pruningSettings>
                </com.mirth.connect.model.ChannelMetadata>
            </entry>
            ...
        </map>

    .EXAMPLE
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (
        # A mirth session is required. You can obtain one or pipe one in from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # If true, return a hashtable of the metadata, using the channel id as the key.
        [Parameter()]
        [switch]$asHashtable,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Get-MirthServerChannelMetadata Beginning"
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }        
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
        $uri = $serverUrl + '/api/server/channelMetadata'
        Write-Debug "Invoking GET Mirth at $uri"
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."

            if ($saveXML) {
                Save-Content $r $outFile
            }
            Write-Verbose "$($r.OuterXml)"
            if ($asHashtable) { 
                # construct a hashtable, channel id to metadata for return
                $returnMap = @{}
                foreach ($entry in $r.map.entry) { 
                    $channelId = $entry.string
                    $metaData = $entry."com.mirth.connect.model.ChannelMetadata"
                    $returnMap[$channelId] = ConvertFrom-Xml $metaData
                }
                return $returnMap
            }
            else { 
                return $r
            }
        }
        catch {
            Write-Error $_
        }
    }        
    END { 
        Write-Debug "Get-MirthServerChannelMetadata Ending"
    }
}  # Get-MirthServerChannelMetadata 
