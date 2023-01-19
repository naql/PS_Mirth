function Set-MirthConfigMap {
    <#
    .SYNOPSIS
        Replaces the Mirth configuration map. 

    .DESCRIPTION
        Updates all entries in the configuration map. 

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        This command expects input in XML format, using the com.mirthy.connect.util.ConfigurationProperty 
        element to represent property values and description.

        $payLoad is xml describing the configuration map to be uploaded:

            <map>
              <entry>
                <string>file-inbound-folder</string>
                <com.mirth.connect.util.ConfigurationProperty>
                  <value>C:\FileReaderInput</value>
                  <comment>This is a descriptive comment describing the file-inbound-reader property.</comment>
                </com.mirth.connect.util.ConfigurationProperty>
              </entry>
              <entry>
                <string>db.url</string>
                <com.mirth.connect.util.ConfigurationProperty>
                  <value>jdbc:thin:@localhost:1521\dbname</value>
                  <comment>This is an example db url property.</comment>
                </com.mirth.connect.util.ConfigurationProperty>
              </entry>
            </map>

    .OUTPUTS

    .EXAMPLE
        $configMap = @"                

        "@
        Connect-Mirth | Add-MirthUser -payLoad $configMap 

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of the configuration map to be added
        [Parameter(ParameterSetName = "xmlProvided",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$payLoad,

        # path to file containing the xml of the configuation map
        [Parameter(ParameterSetName = "pathProvided",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$payloadFilePath,

        # If true, does not replace the current config map, merges with
        # the current settings, overwriting any that conflict
        [Parameter()]
        [switch]$merge,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )    
    BEGIN { 
        Write-Debug "Set-MirthConfigMap Beginning"
        
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/server/configurationMap'
        [xml]$payLoadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A configuration map XML payLoad string is required!"
                return $null
            }
            else {
                Write-Debug "Loading channel XML from path $payLoadFilePath"
                try {
                    [xml]$payLoadXML = Get-Content $payLoadFilePath  
                }
                catch {
                    throw $_
                }
            }
        }
        else {
            Write-Debug "Creating XML payload from string: $payLoad"
            $payLoadXML = [xml]$payLoad
        }

        $currentConfigMap = $null
        if ($merge) {
            Write-Debug "Merge flag set, fetching current config map..."
            $currentConfigMap = Get-MirthConfigMap -connection $connection
            $currentConfigMapNode = $currentConfigMap.SelectSingleNode("/map")
            $currentEntries = $currentConfigMap.SelectNodes(".//entry")
            $currCount = $currentEntries.Count
            Write-Debug "Current config map contains $currCount entries."
            $mergeEntries = $payLoadXML.SelectNodes(".//entry")
            $mergeCount = $mergeEntries.Count
            Write-Debug "There are $mergeCount entries to be merged."
            foreach ($newEntry in $mergeEntries) { 
                Write-Debug "Merging property $($newEntry.string)"
                $currentNode = $currentConfigMap.SelectSingleNode(".//entry[./string = '$($newEntry.string)']")
                if ($null -ne $currentNode) {
                    Write-Debug "Updating existing property..."
                    $oldValue = $null
                    $currValueNode = $currentNode.SelectSingleNode(".//com.mirth.connect.util.ConfigurationProperty/value")
                    if ($null -ne $currValueNode) { 
                        $oldValue = $currValueNode.InnerText
                    }
                    else { 
                        Write-Warning "Expected value node was not found!"
                    }
                    $oldComment = $null
                    $currCommentNode = $currentNode.SelectSingleNode(".//com.mirth.connect.util.ConfigurationProperty/comment")
                    if ($null -ne $currCommentNode) { 
                        $oldComment = $currCommentNode.InnerText
                    }
                    else { 
                        # we need to add a comment node
                        $configPropertyNode = $currentNode.SelectSingleNode(".//com.mirth.connect.util.ConfigurationProperty")
                        $currCommentNode = $currentConfigMap.CreateElement('comment')
                        $currCommentNode = $configPropertyNode.AppendChild($currCommentNode)
                    }                    

                    $newValue = $newEntry.'com.mirth.connect.util.ConfigurationProperty'.value
                    $newComment = $newEntry.'com.mirth.connect.util.ConfigurationProperty'.comment

                    Write-Debug "Updating old value [$oldValue] property to new value [$newValue]"
                    $currValueNode.set_InnerText($newValue)
                    
                    Write-Debug "Updating old comment [$oldComment] property to new value [$newComment]"
                    $currCommentNode.set_InnerText($newComment)
                }
                else { 
                    Write-Debug "Adding new merged property..."
                    $currentConfigMapNode.AppendChild($currentConfigMap.ImportNode($newEntry, $True)) | Out-Null
                }
            }  # for all new merged properties
            Write-Debug "Merge complete, replacing payload with merged map"
            $payLoadXML = $currentConfigMap
        }  # if merging

        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("accept", "application/xml")
        $headers.Add("Content-Type", "application/xml")

        Write-Debug "Invoking PUT Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -Method PUT -WebSession $session -Body $payLoadXML.OuterXml
            Write-Debug "...done."
            if ($saveXML) { 
                $Content = "Configuration Map Updated Successfully: $payLoad"
                Save-Content $Content $outFile
            }
            Write-Verbose "$($r.OuterXml)"

            return $r
        }
        catch {
            Write-Error $_
        }  
    }
    END {
        Write-Debug "Set-MirthConfigMap Ending"
    } 
}  #  Set-MirthConfigMap