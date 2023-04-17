function Get-MirthChannelIds {
    <#
    .SYNOPSIS
        Gets an array of all channelIds in the target server.

    .DESCRIPTION
        Return array of string objects representing the list of channel ids in the target server.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS

    .EXAMPLE
        
    .LINK
        Links to further documentation.

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

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug 'Get-MirthChannelIds Beginning'
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }           

        [string[]] $channelIds = @()

        [xml] $allChannelXml = Get-MirthChannels -connection $connection 
        $channelNodes = $allChannelXml.SelectNodes(".//channel")
        Write-Debug "There are $($channelNodes.Count) channels to be considered."
        if ($channelNodes.Count -gt 0) { 
            foreach ($channelNode in $channelNodes) { 
                # TBD: add some filtering logic here?
                Write-Debug "Adding channel id [$($channelNode.id)] to list."
                $channelIds += $channelNode.id
            }
            Write-Debug "There are now $($channelNodes.Count) channel ids in the list."
        }
        if ($saveXML) { 
            Save-Content $channelIds $outFile
        }
        return $channelIds
    }
    END {
        Write-Debug 'Get-MirthChannelIds Ending' 
    }
}  # Get-MirthChannelIds
