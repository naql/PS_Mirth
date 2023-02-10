function Add-MirthChannelGroups { 
    <#
    .SYNOPSIS
        Merge (add/updates) channelGroups. 

    .DESCRIPTION
        Merges a set of Mirth channelGroup objects into the currently existing set 
        of channelGroups.  The channelGroups being merged will replace any existing 
        channelGroup with the same ID.  Any channels in the merged channelGroups will 
        be removed from existing channelGroups.  Otherwise, it leaves the current 
        channelGroup set intact.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        This command expects input as an xml string.
        $payLoad is xml describing the set of channelGroup objects to be added.

    .OUTPUTS

    .EXAMPLE

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of the set of channelGroup objects
        [Parameter(ParameterSetName = "xmlProvided",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$payLoad,

        # path to file containing the xml of the channelGroup set
        [Parameter(ParameterSetName = "pathProvided",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$payloadFilePath,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )   
    BEGIN { 
        Write-Debug "Add-MirthChannelGroups Beginning"
    }
    PROCESS { 

        [xml]$payloadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A channelGroup XML payLoad string is required!"
                return $null
            }
            else {
                if (Test-Path -Path $payLoadFilePath) {
                    Write-Debug "Loading channelGroup XML from path $payLoadFilePath"
                    [xml]$payloadXML = Get-Content $payLoadFilePath  
                }
                else { 
                    Throw "The payloadFilePath specified is invalid!"
                }
            }
        }
        else {
            $payloadXML = [xml]$payLoad
        }
        # We need to get a list of channel ids referenced in the merged groups
        # these channels should be removed from any other existing groups they are referenced
        # to be contained in:  the merged groups take priority
        $refChannelIdList = @();
        $idNodes = $payLoadXML.SelectNodes("//channelGroup/channels/channel/id")
        foreach ($idNode in $idNodes) {
            Write-Debug "Adding channel id $($idNode.innerText) to list..."
            $refChannelIdList += $idNode.innerText
        }
        Write-Debug "There are $($refChannelIdList.Count) channels referenced in the new merged groups"
        foreach ($id in $refChannelIdList) { 
            Write-Debug "Channel ID: $id"
        }

        # Get the current list of channelGroups
        $currChannelGroups = Get-MirthChannelGroups -connection $connection
        [hashtable] $currChannelGroupMap = @{}
       
        foreach ($channelGroup in $currChannelGroups.list.channelGroup) { 
            $key = $channelGroup.id
            Write-Debug "Processing current channelGroup $key, $($channelGroup.name)"
            [Xml.XmlElement[]]$nodesToDelete = @()
            foreach ($channel in $channelGroup.channels.channel) {
                Write-Debug "examining channel id: $($channel.id)"
                if ($refChannelIdList -contains $($channel.id)) {
                    Write-Debug "This channel element needs to be deleted"
                    $nodesToDelete += $channel
                }
            }
            Write-Debug "There are $($nodesToDelete.Count) channel nodes to be deleted"
            foreach ($node in $nodesToDelete) { 
                Write-Debug "Deleting channel node from channelGroup"
                $channelGroup.channels.removeChild($node) | Out-Null
            }
            Write-Debug "Adding current channelGroup with id $key to current map..."
            $currChannelGroupMap[$key] = $channelGroup
        }
        Write-Debug "There are $($currChannelGroupMap.Keys.Count) channel groups currently."
        # add the payload list of groups to the current list of channelGroups
        foreach ($channelGroup in $payLoadXML.set.channelGroup) { 
            $currentGroupNode = $currChannelGroupMap[$channelGroup.id]
            if ($null -eq $currentGroupNode) { 
                Write-Debug "Inserting new channelGroup"
                $currChannelGroupMap[$channelGroup.id] = $channelGroup
            }
            else { 
                Write-Debug "Updating existing channelGroup"
                Write-Debug "Replacing $($currentGroupNode.OuterXml)"
                Write-Debug "With Node $($channelGroup.OuterXml)"
                $currChannelGroupMap[$channelGroup.id] = $channelGroup
            }
        }
        Write-Debug "After merge, there are $($currChannelGroupMap.Keys.Count) channel groups"
        [xml] $newGroupSet = "<set/>"
        $setNode = $newGroupSet.SelectSingleNode("/set")
        foreach ($key in $currChannelGroupMap.Keys) { 
            $channelGroup = $currChannelGroupMap[$key]
            Write-Debug "Inserting channelGroup id $key into return set"
            $setNode.AppendChild($newGroupSet.ImportNode($channelGroup, $true)) | Out-Null            
        }

        # Update the channelGroups with the new list
        $r = Set-MirthChannelGroups -connection $connection -payLoad $newGroupSet.OuterXml -override
        if ($saveXML) { 
            Save-Content $newGroupSet $outFile
        }
        Write-Verbose $newGroupSet.OuterXml
        return $r
    } 
    END { 
        Write-Debug "Add-MirthChannelGroups Ending"
    } 
}  # Add-MirthChannelGroups