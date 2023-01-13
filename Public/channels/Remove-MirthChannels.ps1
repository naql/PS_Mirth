function Remove-MirthChannels {
    <#
    .SYNOPSIS
        Removes channels with the ids specified by $targetId

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId   Required, the list of string channel IDs to be removed.

    .OUTPUTS

    .EXAMPLE
        Connect-Mirth | Remove-MirthChannels -targetId 21189e58-2f96-4d47-a0d5-d2879a86cee9,c98b1068-af68-41d9-9647-5ff719b21d67  -saveXML
        
    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The required id of the channelGroup to remove
        [Parameter(ParameterSetName = "selected",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetId,

        # if true, all channels will be removed
        [Parameter(ParameterSetName = "all",
            Mandatory = $True)]
        [switch]$removeAllChannels,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )  
    BEGIN {
        Write-Debug "Remove-MirthChannels Beginning" 
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }           
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        
        [string[]] $channelIdsToRemove = @()
        if ($removeAllChannels) { 
            Write-Debug "Removal of all channels is requested."
            [xml] $allChannelXml = Get-MirthChannels -connection $connection 
            $channelNodes = $allChannelXml.SelectNodes(".//channel")
            Write-Debug "There are $($channelNodes.Count) channels to be removed."
            if ($channelNodes.Count -gt 0) { 
                foreach ($channelNode in $channelNodes) { 
                    Write-Debug "Adding channel id [$($channelNode.id)] to removal list."
                    $channelIdsToRemove += $channelNode.id
                }
                Write-Debug "There are now $($channelNodes.Count) channel ids in the removal list."
            }
        }
        else { 
            Write-Debug "Removal of selected channels requested."
            $channelIdsToRemove = $targetId
        }

        $uri = $connection.serverUrl + '/api/channels'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        foreach ($id in $channelIdsToRemove) {
            $parameters.Add('channelId', $id)
        }
        $uri = $uri + '?' + $parameters.toString()

        Write-Debug "Invoking DELETE Mirth at $uri"
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method DELETE -WebSession $session

            if ($saveXML) { 
                Save-Content "Deleted Channels: $channelIdsToRemove" $outFile
            }
            Write-Verbose $r
            return $r
        }
        catch {
            Write-Error $_
        }      
    }
    END { 
        Write-Debug "Remove-MirthChannels Ending"
    }
}  # Remove-MirthChannels