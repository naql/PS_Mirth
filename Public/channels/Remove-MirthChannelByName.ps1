function Remove-MirthChannelByName { 
    <#
    .SYNOPSIS
        Removes one ore more channels with the name(s) specified by targetNames parameter

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetName Required, the name of the channel to be deleted.

    .OUTPUTS

    .EXAMPLE
        Remove-MirthChannels -targetName "My Channel Reader"  -saveXML
        
    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The required list of channel names to be removed
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetNames,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )  
    BEGIN {
        Write-Debug "Remove-MirthChannelByName Beginning" 
    }
    PROCESS {    
          
        # First, get the channels
        $channelSet = Get-MirthChannels -connection $connection  
        [string[]]$targetIds = @()
        foreach ($targetName in $targetNames) {
            $xpath = '//channel[name = "' + $targetName + '"]'  
            $channelFound = $channelSet.SelectSingleNode($xpath) 
            if ($null -ne $channelFound) { 
                # we found the channel
                Write-Debug "Adding channel id $($channelFound.id) to targetId list..."
                $targetIds += $channelFound.id
            }
            else { 
                Write-Warning "Skipping, the channel name was not found: $targetName"
            }
        }
        Write-Debug "There are now $($targetIds.count) channel ids in the list to remove"
        if ($targetIds.count -eq 0) { 
            Write-Warning "No channel with the target name was found to be deleted!"
            return $null
        }

        $r = Remove-MirthChannels -connection $connection -targetId $targetIds -saveXML:$saveXML

        if ($saveXML) { 
            #TODO what to save?
        }
        Write-Verbose "$($r.OuterXml)"
        return $r

    }
    END { 
        Write-Debug "Remove-MirthChannelByName Ending"
    }
}  # Remove-MirthChannelByName