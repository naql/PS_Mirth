function Set-MirthTaggedChannels {
    <#
    .SYNOPSIS
        Deletes, creates, or assigns an existing tag to a selected list of, or all, channels. 

    .DESCRIPTION
        A flexible command that can be used to tag channels en masse or by list of channel id.
        It can be used to create tags on the fly, to update, or to remove them.
        
        Updates or creates tags and assigns them to channels.  The function accepts either
        the id of an existing tag, or the name of an tag, which will be created if it does 
        not exist.  If the -remove switch is specified, the channel Tag is deleted.

    .INPUTS
        -connection  MirthConnection custom object is required. See Connect-Mirth.

        -tagId       the guid id of a channel tag, which must exist.

        -tagName    If the id is not provided, then the name of the existing tag, or the title of the new tag.

        -remove     A flag which indicates removal of the channel tag.

        -channelIds An optional array of strings for the channel ids tagged by this channel.
                    No effect if remove is set.

        -replaceChannels    if true, the existing channels assigned to the tag are replaced with the channelIds

    .OUTPUTS

        string      Returns the channelTag ID (whether udpated or newly created)

    .EXAMPLE
        Set-MirthTaggedChannels -tagName 'HALO-RR08' -alpha 255 -red 200 -green 0 -blue 255 -channelIds 0e06727d-55f7-4c91-a363-80521dc834b3 -replaceChannels

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # the channelTag id guid, if not provided one will be generated
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string]$tagId,

        # the property key name
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string]$tagName,

        # If no channelIds are specified, the channelTag is entirely removed from the server.
        [Parameter()]
        [switch]$remove,
        
        # an optional array of channelId guids
        # the channelTag id guid strings that the tag applies to when creating or updating a tag
        # if the remove switch is set, these channel ids will removed from the tags set of channelIds
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$channelIds,

        # If true, replaces the tag's existing channel assignments, 
        # otherwise, adds to them, ignored when the remove switch is set.
        [Parameter()]
        [switch]$replaceChannels,

        # the alpha value, 0-255
        # has no effect if the remove tag is specfiied
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [ValidateRange(0, 255)]
        [int]$alpha = 255,
   
        # the red value, 0-255
        # has no effect if the remove tag is specfiied
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [ValidateRange(0, 255)]
        [int]$red,
        
        # the green value,, 0-255
        # has no effect if the remove tag is specfiied
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [ValidateRange(0, 255)]
        [int]$green,

        # the blue value, 0-255
        # has no effect if the remove tag is specfiied
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [ValidateRange(0, 255)]
        [int]$blue,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )  
    BEGIN { 
        Write-Debug "Set-MirthTaggedChannels Beginning"
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }

        # if the list of channels is empty, then go and fetch a complete list of 
        # channel ids

        if ($channelIds.count -gt 0) { 
            # they provided some channel ids
            if ($remove) {
                Write-Debug "Removing $($channelIds.count) channels from this tag."
            }
            else {
                Write-Debug "Assigning $($channelIds.count) channels to this tag."
            }
        }
        else { 
            # go and get them all
            Write-Debug "Assigning tag to all existing channels"
            $channelIds = $(Get-MirthChannels ).list.channel.id
        }

        # First, fetch the current set of Mirth channel tags.

        $currentTagSet = Get-MirthChannelTags -connection $connection -saveXML:$saveXML
        [xml]$targetTag = $null
        $tagIdMap = @{}
        $tagNameMap = @{}
        Write-Debug "Building channelTag maps..."
        foreach ($channelTag in $currentTagSet.set.channelTag) { 
            $tmpTagId = $channelTag.id
            $tmpTagName = $channelTag.name
            Write-Debug "Tag Read: $tmpTagId - $tmpTagName"
            $tagIdMap.add($tmpTagId, $channelTag)
            $tagNameMap.add($tmpTagName, $channelTag)
        }
        # If a tagId was provided, see if it exists, else
        # if name provided, see if it exists.
        if (-not ([string]::IsNullOrEmpty($tagId) -or [string]::IsNullOrWhiteSpace($tagId))) {
            # tag id was specified, does id exist in current Tag set
            Write-Debug "Tag id was specified: $tagId"
            $foundTag = $tagIdMap[$tagId]
            if ($null -ne $foundTag) { 
                Write-Debug "Type of found target id $($foundTag.getType())"
                $newTag = New-Object -TypeName xml
                $newTag.AppendChild($newTag.ImportNode($foundTag, $true)) | Out-Null
                $targetTag = $newTag
            }
            else { 
                # The tag id does not exist, so they must be trying to add
                # ensure that the tagName parameter was also set
                Write-Debug "Adding tagId: $tagId"
                if ((-not $PSBoundParameters.containsKey("tagName")) -or ([string]::IsNullOrEmpty($tagName))) { 
                    Throw "A tagName must be provided to add a new tag!"
                }
            }            
        } 
        if ($null -eq $targetTag) {
            # a tag id was not provided, or it was not found
            # search by tag name
            Write-Debug "Searching for tag by name..."
            $foundTag = $tagNameMap["$tagName"]
            if ($null -ne $foundTag) { 
                Write-Debug "The channel tag was found by name."
                $newTag = New-Object -TypeName xml
                $newTag.AppendChild($newTag.ImportNode($foundTag, $true)) | Out-Null
                $targetTag = $newTag
            }
            
        }
        else { 
            # tag was found by id
            Write-Debug "Existing channel tag found by id."
            #check to see if we are updating the name?
        }
        # At this point, if we still don't have the current Tag
        # then, we must be creating it, unless remove switch
        if ($null -eq $targetTag) { 
            Write-Debug "No existing channelTag has been found."
            if ([string]::IsNullOrEmpty($tagId)) { 
                Write-Debug "No tag id was provided, generating new tag guid..."
                $tagId = $(New-Guid).toString()
                Write-Debug "New tag id = $tagId"
            }
            if (-not $remove) {
                Write-Debug "Creating new channel tag object"
                [xml]$targetTag = New-MirthChannelTagObject -tagId $tagId -tagName $tagName -channelIds $channelIds -alpha $alpha -red $red -green $green -blue $blue 
            }
        }
        else { 
            Write-Debug "Channel Tag already exists... updating it."
        }
        if ($remove -and ($null -eq $targetTag)) { 
            Write-Verbose "Channel Tag $tagId was not found to be removed."
            return $null
        }
        Write-Debug "Creating new tag set..."
        Write-Verbose "targetTag ID:   $($targetTag.channelTag.id)"
        Write-Verbose "targetTag Name: $($targetTag.channelTag.name)"

        [xml]$newTagSet = "<set />"
        # Write out a new set of tags skipping the tag if it is being 
        # removed, otherwise addit it at the end... 
        $found = $false
        foreach ($channelTag in $currentTagSet.set.channelTag) { 
            Write-Debug "Comparing $($channelTag.id) to $($targetTag.channelTag.id)"
            if ($channelTag.id -eq $targetTag.channelTag.id) { 
                Write-Debug "Match on tag id"
                if ((-not $remove) -or ($remove -and ($channelIds.Count -gt 0))) { 
                    $found = $true;
                    # add it to new set, possibly updating name and colors
                    Write-Debug "Updating channel Tag"
                    $targetTag.channelTag.name = $tagName
                    $targetTag.channelTag.backgroundColor.alpha = [string]$alpha
                    $targetTag.channelTag.backgroundColor.red = [string]$red
                    $targetTag.channelTag.backgroundColor.green = [string]$green 
                    $targetTag.channelTag.backgroundColor.blue = [string]$blue 
                    #  update the channel ids here...
                    [string[]]$mergedChannelIds = @()
                    if ($replaceChannels) { 
                        Write-Debug "Replacing existing tag channel assignments"
                        Write-Debug "There will be $($channelIds.count) channels assigned to this tag."
                        $mergedChannelIds = $channelIds
                    }
                    else { 
                        Write-Debug "Merging existing tag channel assignments"
                        [string[]] $currentChannels = $channeltag.channelIds.string
                        Write-Debug "There are $($currentChannels.count) channels currently assigned to this tag."
                        if ($remove) {
                            Write-Debug "Checking for removed channels..."
                            $remainingChannelIds = @()
                            foreach ($id in $currentChannels) {
                                Write-Debug "Checking [$id] against list: [$channelIds]"
                                if (-not ($channelIds -contains $id)) {
                                    $remainingChannelIds = $remainingChannelIds += $id
                                }
                                else { 
                                    Write-Debug "Omitting channel id $id from new list."
                                }
                            }
                            Write-Debug "After removing channels, the tag is assigned to $($remainingChannelIds.Count) channels."
                            $mergedChannelIds = $remainingChannelIds
                        }
                        else { 
                            Write-Debug "There are $($channelIds.count) channels to be merged to this tag."
                            $mergedChannelIds = $channelIds + $currentChannels | Sort-Object -Unique
                            Write-Debug "There are $($mergedChannelIds.count) merged channels assigned to this tag."
                        }

                    }
                    Write-Debug "Clearing all channel ids from tag..."
                    $channelIdsNode = $targetTag.SelectSingleNode(".//channelIds")
                    $channelIdsNode.RemoveAll() 

                    Write-Debug "Adding merged channel id nodes..."
                    Add-PSMirthStringNodes -parentNode $channelIdsNode -values $mergedChannelIds | Out-Null
                    Write-Debug "Tag update complete"

                    Write-Debug "Appending tag to set"
                    $newTagSet.DocumentElement.AppendChild($newTagSet.ImportNode($targetTag.channelTag, $true)) | Out-Null
                }
                else { 
                    Write-Debug "Omitting tag from new set"
                }
            }
            else {
                Write-Debug "Existing tag not a target, keeping in list."
                # existing tag not a match, keep in new set
                $newTagSet.DocumentElement.AppendChild($newTagSet.ImportNode($channelTag, $true)) | Out-Null
            }
        }  # foreach current channelTag...

        # we have now kept any tags not affected
        # if not remove, now we add the newly generated channelTag
        if ((-not $remove) -and (-not $found)) { 
            Write-Debug "Adding new channel tag to new tag set"
            $newTagSet.DocumentElement.AppendChild($newTagSet.ImportNode($targetTag.channelTag, $true)) | Out-Null
        } 
        Set-MirthChannelTags -payLoad $newTagSet.OuterXml | Out-Null
        return $targetTag.channelTag.id
    }
    END { 
        Write-Debug "Set-MirthTaggedChannels Ending"
    } 
}  #  Set-MirthTaggedChannels