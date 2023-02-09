function Get-MirthChannels { 
    <#
    .SYNOPSIS
        Gets a list of all channels, or multiple channels by ID

    .DESCRIPTION
        Return xml object describing a list of the requested channels.  Also fetches 
        server channel metadata and merges into the channel xml as a /channel/exportData
        element, just as if it were exported from the mirth gui.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all channel groups are returned.  Otherwise, only the channel groups with the 
        id values specified are returned.

    .OUTPUTS
        If -saveXML writes the list XML to Save-Get-MirthChannels-Output.xml
        If -exportChannels each channel is instead output in a separate file using the channel name.

        Returns an XML object that represents a list of channel objects:

        <list>
          <channel version="3.6.2">
            <id>e0e315bc-e064-4a6c-bc60-e26c2b4846b7</id>
            <nextMetaDataId>2</nextMetaDataId>
            <name>MyChannelReader</name>
            <description></description>
            <revision>1</revision>
            <sourceConnector version="3.6.2">
              <metaDataId>0</metaDataId>
              <name>sourceConnector</name>
              <properties class="com.mirth.connect.connectors.vm.VmReceiverProperties" version="3.6.2">
		        [...]
              </properties>
              <transformer version="3.6.2">
		        [...]
              </transformer>
              <filter version="3.6.2">
                <elements />
              </filter>
              <transportName>Channel Reader</transportName>
              <mode>SOURCE</mode>
              <enabled>true</enabled>
              <waitForPrevious>true</waitForPrevious>
            </sourceConnector>
            <destinationConnectors>
              <connector version="3.6.2">
                <metaDataId>1</metaDataId>
                <name>Destination 1</name>
                <properties class="com.mirth.connect.connectors.vm.VmDispatcherProperties" version="3.6.2">
			        [...]
                </properties>
                <transformer version="3.6.2">
			        [...]
                </transformer>
                <responseTransformer version="3.6.2">
			        [...]
                </responseTransformer>
                <filter version="3.6.2">
                  <elements />
                </filter>
                <transportName>Channel Writer</transportName>
                <mode>DESTINATION</mode>
                <enabled>true</enabled>
                <waitForPrevious>true</waitForPrevious>
              </connector>
            </destinationConnectors>
            <preprocessingScript>// Modify the message variable below to pre process data
        return message;</preprocessingScript>
            <postprocessingScript>// This script executes once after a message has been processed
        // Responses returned from here will be stored as "Postprocessor" in the response map
        return;</postprocessingScript>
            <deployScript>// This script executes once when the channel is deployed
        // You only have access to the globalMap and globalChannelMap here to persist data
        return;</deployScript>
            <undeployScript>// This script executes once when the channel is undeployed
        // You only have access to the globalMap and globalChannelMap here to persist data
        return;</undeployScript>
            <properties version="3.6.2">
              <clearGlobalChannelMap>true</clearGlobalChannelMap>
              <messageStorageMode>PRODUCTION</messageStorageMode>
              <encryptData>false</encryptData>
              <removeContentOnCompletion>false</removeContentOnCompletion>
              <removeOnlyFilteredOnCompletion>false</removeOnlyFilteredOnCompletion>
              <removeAttachmentsOnCompletion>false</removeAttachmentsOnCompletion>
              <initialState>STARTED</initialState>
              <storeAttachments>true</storeAttachments>
              <metaDataColumns>
                <metaDataColumn>
                  <name>SOURCE</name>
                  <type>STRING</type>
                  <mappingName>mirth_source</mappingName>
                </metaDataColumn>
                <metaDataColumn>
                  <name>TYPE</name>
                  <type>STRING</type>
                  <mappingName>mirth_type</mappingName>
                </metaDataColumn>
              </metaDataColumns>
              <attachmentProperties version="3.6.2">
                <type>None</type>
                <properties />
              </attachmentProperties>
              <resourceIds class="linked-hash-map">
                <entry>
                  <string>Default Resource</string>
                  <string>[Default Resource]</string>
                </entry>
              </resourceIds>
            </properties>
          </channel>
        </list>

        This is a very complex object which depends upon the channel configuration.
        Refer to the Mirth API for more information.

    .EXAMPLE
        Connect-Mirth | Get-MirthChannels 
        
    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the channelGroup to retrieve, empty for all
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetId,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Save each channel XML in a separate file using the channel name.
        # saveXML switch must also be on.
        [Parameter()]
        [switch]$exportChannels,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug 'Get-MirthChannels Beginning'
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }           
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/channels'
        if ([string]::IsNullOrEmpty($targetId) -or [string]::IsNullOrWhiteSpace($targetId)) {
            Write-Debug "Fetching all channels"
            $parameters = $null
        }
        else {
            $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
            foreach ($target in $targetId) {
                $parameters.Add('channelId', $target)
            }
            $uri = $uri + '?' + $parameters.toString()
        }

        Write-Debug "Invoking GET Mirth at $uri"
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session -Headers $DEFAULT_HEADERS
            Write-Debug "...done."
            # we have some result, so get the channel metadata map
            Write-Debug "Fetching Server channel metadata map"
            $channelMetaDataMap = Get-MirthServerChannelMetadata -connection $connection -asHashtable -saveXML:$saveXML
            Write-Debug "Channel Metadata map contains $($channelMetaDataMap.Count) entries..."

            $currentTagSet = Get-MirthChannelTags -connection $connection -saveXML:$saveXML -Raw
            $channelTagMap = @{}
            Write-Debug "Building channel to tag map..."
            foreach ($channelTag in $currentTagSet.set.channelTag) { 
                $channelIds = $channelTag.SelectNodes("channelIds/string")
                Write-Debug "There are $($channelIds.Count) channelIds for this tag [$($channelTag.name)]"
                foreach ($channelId in $channelIds) {
                    $key = $channelId.InnerText
                    Write-Debug "Key inserting into channelTagMap: $key"
                    if ($channelTagMap.containsKey($key)) {
                        $channelTagMap[$key] += $channelTag
                    }
                    else { 
                        $channelTagMap[$key] = @($channelTag)
                    }
                    Write-Debug "There are now $($channelTagMap[ $key].Count) tag entries for channelID  $key in the channelTagMap"
                }
            }
            Write-Debug "There are $($channelTagMap.count) total entries in the channelTagMap"

            # for each channel, we will merge in metadata and channelTags as if exported from gui
            foreach ($channel in $r.list.channel) {
                Write-Debug "Merging export metadata for $($channel.name)"
                $channelId = $channel.id
                $exportNode = $r.CreateElement('exportData')
                $exportNode = $channel.AppendChild($exportNode)
                Write-Debug "exportData node added"
                $metaDataNode = $r.CreateElement('metadata')
                $metaDataNode = $exportNode.AppendChild($metaDataNode)
                Write-Debug "metadata node added"
                $entry = $channelMetaDataMap[$($channel.id)]
                if ($null -ne $entry) {
                    # enabled
                    if ($null -ne $entry.enabled) {
                        Write-Debug "setting enabled"
                        $NewElem = $r.CreateElement('enabled')
                        $NewElem.InnerText = $entry.enabled
                        $null = $metaDataNode.AppendChild($NewElem)
                    }
                    # lastModified
                    if ($null -ne $entry.lastModified) {
                        Write-Debug "setting lastModified"
                        $NewElem = $r.CreateElement('lastModified')
                        #$NewElem.InnerText = $entry.lastModified
                        $NewElem = $metaDataNode.AppendChild($NewElem)
                        Convert-HashToXml -Hash $entry.lastModified -Document $r | ForEach-Object { $null = $NewElem.AppendChild($_) }
                    }
                    # pruningSettings
                    if ($null -ne $entry.pruningSettings) {
                        Write-Debug "setting pruningSettings"
                        $NewElem = $r.CreateElement('pruningSettings')
                        #$NewElem.InnerText = $entry.pruningSettings
                        $NewElem = $metaDataNode.AppendChild($NewElem)
                        Convert-HashToXml -Hash $entry.pruningSettings -Document $r | ForEach-Object { $null = $NewElem.AppendChild($_) } 
                    }
                }
                else { 
                    Write-Warning "No metadata was found!"
                }
                Write-Debug "All channel metadata processed"

                Write-Debug "Processing channelTags..."
                $channelTagArray = $channelTagMap[$channelId]
                if (($null -ne $channelTagArray) -and ($channelTagArray.Count -gt 0)) { 
                    Write-Debug "There are $($channelTagArray.Count) channelTags to be merged."
                    $channelTagsNode = $r.CreateElement('channelTags')
                    $channelTagsNode = $exportNode.AppendChild($channelTagsNode)
                    foreach ($channelTag in $channelTagArray) { 
                        Write-Debug "Importing and appending channelTag"
                        $channelIdNode = $r.ImportNode($channelTag, $true)
                        $channelTagsNode.AppendChild($channelIdNode) | Out-Null
                    }
                    Write-Debug "channel tag data processed"
                }
                else {
                    Write-Debug "There were no channelTags associated with this channel id."
                }
                
            }  # foreach channel in the list

            if ($saveXML) { 
                if ($exportChannels) {
                    # iterate through list, saving each channel using the name
                    foreach ($channel in $r.list.channel) {
                        Save-Content $channel ($channel.name + '.xml')
                    }
                }
                else {
                    Save-Content $r $outFile
                }
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
        }
        catch {
            Write-Error $_
        }     
    }
    END {
        Write-Debug 'Get-MirthChannels Ending' 
    }
}  # Get-MirthChannels