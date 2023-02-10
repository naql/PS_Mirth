function Remove-MirthChannelGroups { 
    <#
    .SYNOPSIS
        Removes channels with the ids specified by $targetId

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all channel groups are returned.  Otherwise, only the channel groups with the 
        id values specified are returned.

    .OUTPUTS

    .EXAMPLE
        Remove-MirthChannelGroups -targetId 21189e58-2f96-4d47-a0d5-d2879a86cee9,c98b1068-af68-41d9-9647-5ff719b21d67  -saveXML
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The ids of the channelGroup to remove, empty for all
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetIds = @(),
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Remove-MirthChannelGroups beginning"
    }
    PROCESS { 
        [xml]$payLoad = "<set />"
        [xml]$currentGroups = Get-MirthChannelGroups -saveXML:$saveXML
        $channelGroups = $currentGroups.list.channelGroup
        if ($targetIds.count -gt 0) { 
            foreach ($channelGroup in $channelGroups) {
                Write-Verbose "ChannelGroup id: $($channelGroup.id) name: $($channelGroup.name)" 
                if ($targetIds.contains($channelGroup.id)) { 
                    Write-Verbose "This channel is marked for removal, skipping..."
                }
                else { 
                    # add this channelGroup we are keeping to the set
                    $payLoad.DocumentElement.AppendChild($payLoad.ImportNode($channelGroup, $true))
                }
            }
            Set-MirthChannelGroups -payLoad $payLoad.OuterXml -removedChannelGroupIds $targetIds -override -saveXML:$saveXML 

        }
        else { 
            Write-Debug "All groups are to be deleted"
            $channelGroupIds = $currentGroups.list.channelGroup.id
            Write-Debug "There will be $($currentGroups.Count) channel groups deleted."
            Set-MirthChannelGroups -payLoad '<set />' -removedChannelGroupIds $channelGroupIds  -override -saveXML:$saveXML 
        }
        
    }
    END {
        Write-Debug "Remove-MirthChannelGroups ending"
    }
}  #  Remove-MirthChannelGroups
