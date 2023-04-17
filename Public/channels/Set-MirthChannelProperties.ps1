function Set-MirthChannelProperties { 
    <#
    .SYNOPSIS
        Sets channel properties for a list of channels, or all channels, deployed on the target server.

    .DESCRIPTION
        Only the parameters that are passed in are set.  The primary properties are 

        MessageStoreMode

        DEVELOPMENT - Content: All; Metadata: All; Durable Message Delivery On, 
        PRODUCTION  - Content: Raw,Encoded,Sent,Response,Maps; Metadata: All; Durable Message Delivery: On
        RAW         - Content: Raw; Metadata: All; Durable Message Delivery: Reprocess Only
        METADATA    - Content: (none); Metadata: All; Durable Message Delivery: Off
        DISABLED    - Content: (none); Metadata: (none); Durable Message Delivery: Off

        And there are performance/storage consequences for the mirth server in how these are 
        set.  Development offers the lowest performance with most data retained and highest storage requirements.
        Disabled offers the maximum performance, lowest amount of data retained, and lowest storage requirements.

        There are also trade-offs to be considered when reducing the data retained as regards troubleshooting.
        In QA/Development tiers it is usually necessary maintain data for development and validation.  In other
        environments it is only necessary when troubleshooting specific issues.  It may be better to keep channels
        running at higher performance levels and only enable DEVELOPMENT mode when it is necessary to troubleshoot 
        an issue.

    .INPUTS
        A -session              - WebRequestSession object is required. See Connect-Mirth.
        [string[]] $channelIds  - Optional list of channel ids, if omitted all channels are updated.
        Pass in only the properties you wish to set.

    .OUTPUTS

    .EXAMPLE
        Set-MirthChannelProperties -messageStorageMode PRODUCTION -clearGlobalChannelMap $True -pruneMetaDataDays 30 -pruneContentDays 15 -removeOnlyFilteredOnCompletion $True  

    .LINK

    .NOTES
        This command essentially fetches the list of channels specified, or all channels, and then 
        updates the specified channel properties, only if they were explicitly specified as parameters.

        There are many parameters.  Consider using splatting.

        It does NOT deploy the modified channels.  There may be consequences to deploying channels;  it may cause 
        unintended polls for channels that poll once on deployment.  Therefore, this command does not deploy.
        It is left up to the calling client code to know whether or not they should deploy the channels at this
        time.  The client code would need to call redeploy the affected channels.


    #> 
    [CmdletBinding()] 
    PARAM (
        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the channels to be set to the specified message storage mode, empty for all
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$channelIds,

        # If true, the channel is enabled and can be deployed
        [Parameter()]
        [bool] $enabled,  

        # The messages storage mode setting to be activated
        [Parameter()]
        [MirthMsgStorageMode] $messageStorageMode,

        # clear the global channel map on deployment if true
        [Parameter()]
        [bool] $clearGlobalChannelMap,

        # encrypt the data if true
        [Parameter()]
        [bool] $encryptData,

        # remove content on successful completion if true
        [Parameter()]
        [bool] $removeContentOnCompletion,

        # remove only filtered destinations on completion if true
        [Parameter()]
        [bool] $removeOnlyFilteredOnCompletion,

        # remove attachments on completion
        [Parameter()]
        [bool] $removeAttachmentsOnCompletion,

        # store attachments if true
        [Parameter()]
        [bool] $storeAttachments,

        # If set to a positive value, the number of days before pruning metadata.  If negative, store indefinitely.
        [Parameter()]
        [int] $pruneMetaDataDays,

        # If set to a positive value, the number of days before pruning content.  Cannot be greater than than pruneMetaDays. 
        # If negative, then store content until metadata is removed.
        [Parameter()]
        [ValidateScript({
                if ($PSBoundParameters.containsKey('pruneMetaDays')) {
                    # A pruneMetaDays parameter was provided along with pruneContentDays...
                    if ($_ -gt $pruneMetaDataDays) {
                        Throw "pruneContentDays ($_) cannot be greater than pruneMetaDays!"
                    }
                    else { 
                        $True
                    }
                }
                else {
                    # they only specified pruneContentDays, so we'll have to check it at time of update
                    $True
                }
            })]
        [int] $pruneContentDays,

        # Allow message archiving
        [Parameter()]
        [bool] $allowArchiving,        
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Set-MirthChannelProperties Beginning"
    }
    PROCESS { 
        [xml] $channelList = Get-MirthChannels -connection $connection -targetId $channelIds 
        $channelNodes = $channelList.SelectNodes("/list/channel")
        Write-Verbose "There are $($channelNodes.count) channels to be processed."
        foreach ($channelNode in $channelNodes) {
            Write-Verbose "Updating message properties for channel [$($channelNode.id)] $($channelNode.name)"
            if ($PSBoundParameters.containsKey('messageStorageMode')) {
                Write-Verbose "Updating messageStorageMode"
                $channelNode.properties.messageStorageMode = $messageStorageMode.toString()
            }
            if ($PSBoundParameters.containsKey('clearGlobalChannelMap')) {
                Write-Verbose "Updating clearGlobalChannelMap"
                $channelNode.properties.clearGlobalChannelMap = $clearGlobalChannelMap.ToString()
            }
            if ($PSBoundParameters.containsKey('encryptData')) {
                Write-Verbose "Updating encryptData"
                $channelNode.properties.encryptData = $encryptData.ToString()
            }
            if ($PSBoundParameters.containsKey('removeContentOnCompletion')) {
                Write-Verbose "Updating removeContentOnCompletion"
                $channelNode.properties.removeContentOnCompletion = $removeContentOnCompletion.ToString()
            }
            if ($PSBoundParameters.containsKey('removeOnlyFilteredOnCompletion')) {
                Write-Verbose "Updating removeOnlyFilteredOnCompletion"
                $channelNode.properties.removeOnlyFilteredOnCompletion = $removeOnlyFilteredOnCompletion.ToString()
            }
            if ($PSBoundParameters.containsKey('removeAttachmentsOnCompletion')) {
                Write-Verbose "Updating removeAttachmentsOnCompletion"
                $channelNode.properties.removeAttachmentsOnCompletion = $removeAttachmentsOnCompletion.ToString()
            }                          
            if ($PSBoundParameters.containsKey('storeAttachments')) {
                Write-Verbose "Updating storeAttachments"
                $channelNode.properties.storeAttachments = $storeAttachments.ToString()
            }
            if (($PSBoundParameters.containsKey('enabled')) -or
                ($PSBoundParameters.containsKey('pruneMetaDataDays')) -or 
                ($PSBoundParameters.containsKey('pruneContentDays')) -or
                ($PSBoundParameters.containsKey('allowArchiving'))) { 
                Write-Debug "Searching for pruningSettings node"
                [Xml.XmlElement] $psNode = $channelNode.SelectSingleNode("exportData/metadata/pruningSettings")
                if ($null -ne $psNode) {
                    Write-Debug "pruningSettings node found..."
                    if ($PSBoundParameters.containsKey('enabled')) {
                        Write-Verbose "Updating enabled"
                        $channelNode.exportData.metadata.enabled = $enabled.ToString()
                    }  
                    if ($PSBoundParameters.containsKey('pruneMetaDataDays')) {
                        Write-Verbose "Updating pruneMetaDataDays"
                        $pruneMetaDataDaysNode = $psNode.SelectSingleNode("pruneMetaDataDays")

                        if ($pruneMetaDataDays -lt 0) { 
                            # indefinite, remove the pruneMetaDataDays element, leaving nothing
                            # Write-Debug "Fetching pruneMetaDataDays node for deletion"
                            # $pruneMetaDataDaysNode = $psNode.SelectSingleNode("pruneMetaDataDays")
                            if ($null -ne $pruneMetaDataDaysNode) { 
                                Write-Debug "Removing pruneMetaDaysNode"
                                $psNode.removeChild($pruneMetaDataDaysNode) | Out-Null
                            }
                            else { 
                                Write-Debug "There is no pruneMetaDaysNode node to remove"
                            }  
                        }
                        else {
                            # updating
                            if (-not $PSBoundParameters.containsKey('pruneContentDays')) { 
                                # no validation has been performed
                                $pruneContentDays = $channelNode.exportData.metadata.pruningSettings.pruneContentDays
                                if ($null -ne $pruneContentDays) { 
                                    if ($pruneContentDays -gt $pruneMetaDataDays) { 
                                        Throw "pruneMetaDataData value specified [$($pruneMetaDataDays)] is less than current pruneContentDays [$($pruneContentDays)]! Increase or specify pruneContentDays parameter."
                                    }
                                }
                            }
                            if ($null -ne $pruneMetaDataDaysNode) { 
                                Write-Verbose "Updating pruneMetaDataDays node"
                                $channelNode.exportData.metadata.pruningSettings.pruneMetaDataDays = $pruneMetaDataDays.ToString()
                            }
                            else { 
                                # add pruneMetaDataDays here
                                $pruneMetaDataDaysNode = $channelList.CreateElement('pruneMetaDataDays')
                                $pruneMetaDataDaysNode.set_InnerText($pruneMetaDataDays.ToString())
                                $pruneMetaDataDaysNode = $psNode.AppendChild($pruneMetaDataDaysNode)
                            } 
                           
                        }
                    }
                    if ($PSBoundParameters.containsKey('pruneContentDays')) {
                        Write-Verbose "Updating pruneContentDays"
                        $pruneContentDaysNode = $psNode.SelectSingleNode("pruneContentDays")
                        if ($pruneContentDays -lt 0) { 
                            if ($null -ne $pruneContentDaysNode) { 
                                Write-Debug "Removing pruneContentDaysNode"
                                $psNode.removeChild($pruneContentDaysNode)  | Out-Null
                            }
                            else { 
                                Write-Debug "There is no pruneContentDaysNode node to remove"
                            }                 
                        }
                        else { 
                            # updating
                            if (-not $PSBoundParameters.containsKey('pruneMetaDataDays')) { 
                                # no validation has been performed
                                $pruneMetaDataDays = $channelNode.exportData.metadata.pruningSettings.pruneMetaDataDays
                                if ($null -ne $pruneContentDays) { 
                                    if ($pruneContentDays -gt $pruneMetaDataDays) { 
                                        Throw "pruneMetaDataData value specified [$($pruneMetaDataDays)] is less than current pruneContentDays [$($pruneContentDays)]! Increase or specify pruneContentDays parameter."
                                    }
                                }
                            }
                            if ($null -ne $pruneContentDaysNode) { 
                                Write-Debug "Updating existing pruneContentDays node"                
                                $channelNode.exportData.metadata.pruningSettings.pruneContentDays = $pruneContentDays.ToString()
                            }
                            else { 
                                # add a pruneContentDays node and update
                                $pruneContentDaysNode = $channelList.CreateElement('pruneContentDays')
                                $pruneContentDaysNode.set_InnerText($pruneContentDays.ToString())
                                $pruneContentDaysNode = $psNode.AppendChild($pruneContentDaysNode)                                
                            } 

                        }
                    }   
                    if ($PSBoundParameters.containsKey('allowArchiving')) {
                        Write-Verbose "Updating archiveEnabled"
                        $channelNode.exportData.metadata.pruningSettings.archiveEnabled = $allowArchiving.ToString()
                    }  
                }
                else { 
                    # If passed a channel xml which has not been merged with metadata,if so, we'll warn and skip
                    Write-Warn "The channel has no pruningSettings node, skipping."
                }
            }  # if an exportdata parameter was passed                                  
            Import-MirthChannel -connection $connection -payLoad $channelNode | Out-Null
        }  #  foreach $channelNode

    }
    END { 
        Write-Debug "Set-MirthChannelProperties Ending"
    }
}  # Set-MirthChannelProperties