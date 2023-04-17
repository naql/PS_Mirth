function Invoke-PSMirthTool { 
    <#
    .SYNOPSIS
        Deploys, invokes and fetches payloads from PS_Mirth "tool" channels.

    .DESCRIPTION
        This function loads in a "tool" channel.  It will import the channel to 
        the target mirth server, deploy it, send a message to it if necessary, 
        and fetch the resuling message content from the output destination 
        named "PS_OUTPUT". The type of payload, xml, JSON, etc, is determined 
        by the destination datatype.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        Object representing the resulting tool channel output.

    .EXAMPLE
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # required path to the tool to deploy
        [Parameter(Mandatory = $True)]
        [string]$toolPath,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )     
    BEGIN { 
        Write-Debug "Invoke-PSMirthTool Beginning"
    }
    PROCESS { 
        Write-Debug "Loading tool channel..."
        [xml]$tool = Get-Content $toolPath
        $toolName = $tool.channel.name
        $toolId = $tool.channel.id
        $toolTransportType = $tool.channel.sourceConnector.transportName
        Write-Debug "Tool:      $toolName"
        Write-Debug "Tool ID:   $toolId"
        Write-Debug "Type:      $toolTransportType"
        [string]$pollSetting = $tool.channel.sourceConnector.properties.pollConnectorProperties.pollOnStart
        $pollsOnStart = ($pollSetting.ToUpper() -eq "TRUE")
        if ($pollsOnStart) { 
            Write-Debug "The tool channel polls automatically on deployment"
        }
        else { 
            Write-Debug "The tool channel does NOT poll on deployment!"
            # we will add some logic to support this later
        }

        $returnValue = $null
        $result = Import-MirthChannel -connection $connection -payLoad $tool
        # call response is a plaintext string
        Write-Debug "Import Result: $result"
        Write-Debug "Deploying probe channel..."
        $result = Send-MirthDeployChannels -targetIds $toolId 
        Write-Debug "Deploy Result: $result"

        $maxMsgId = $null
        $attempts = 0
        while (($null -eq $maxMsgId) -and ($attempts -lt 3)) { 
            Write-Verbose "Looking for probe telemetry..." 
            $attempts++  
            $maxMsgId = Get-MirthChannelMaxMsgId -targetId $toolId 
            Write-Debug "Probe Channel Max Msg Id: $maxMsgId"
            if (-not $maxMsgId -gt 0) { 
                $maxMsgId = $null
                Write-Verbose "No probe telemetry available, pausing for 3 seconds to reattempt..."
                Start-Sleep -Seconds 3
            }
        }

        [xml]$channelMsg = $null
        if (-not $maxMsgId -gt 0) { 
            Write-Warning "No tool telemetry could be obtained"
        }
        else { 
            $attempts = 0
            while (($null -eq $channelMsg) -and ($attempts -lt 3)) { 
                Write-Verbose "Getting telemetry result..." 
                $attempts++  
                [xml]$channelMsg = Get-MirthChannelMsgById -connection $connection -channelId $toolId -messageId $maxMsgId -Raw
                if ($null -ne $channelMsg) {
                    $processedNode = $channelMsg.SelectSingleNode("/message/processed")
                    $result = $processedNode.InnerText.Trim()
                    if ($result -ne "true") { 
                        Write-Verbose "telemetry messages is not processed yet, pausing for 3 seconds to reattempt..."
                        $channelMsg = $null
                        Start-Sleep -Seconds 3
                    }
                }
            }
            if ($null -ne $channelMsg) {
                # We should now have a processed message, find our payload, look for destination 'PS_OUTPUT"
                $xpath = '/message/connectorMessages/entry/connectorMessage[connectorName = "PS_OUTPUT"]'
                $connectorMessageNode = $channelMsg.SelectSingleNode($xpath)
                if ($null -eq $connectorMessageNode) { 
                    Write-Error "Could not locate PS_OUTPUT destination of PSMirthTool channel: $toolName"
                    # return $null
                }     
                $dataType = $connectorMessageNode.encoded.dataType 
                Write-Debug "The tool output is of dataType: $dataType"
                if ($dataType -eq "XML") { 
                    [xml]$decoded = [System.Web.HttpUtility]::HtmlDecode($connectorMessageNode.encoded.content)
                    Set-Variable returnValue -Value ($decoded -as [Xml])
                }
                else { 
                    Write-Warning "Unimplemented PSMirthTool datatype"
                    $toolMessage = [System.Web.HttpUtility]::HtmlDecode($connectorMessageNode.encoded.content)
                    Set-Variable returnValue -Value ($toolMessage -as [String])                
                }
            }
            else { 
                # probe failed to process
                Write-Error "Tool probe channel $toolName failed to return telemetry."
            }
            
        }

        $result = Send-MirthUndeployChannels -connection $connection -targetIds $toolId 
        Write-Debug "Undeploy Result: $result"
        $result = Remove-MirthChannels -connection $connection -targetId $toolId 
        Write-Debug "Remove Result: $result" 

        return $returnValue
    }
    END { 
        Write-Debug "Invoke-PSMirthTool Ending"
    }
}  # Invoke-PSMirthTool