function Get-MirthChannels { 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The IDs of the channels to retrieve. If absent, all channels will be retrieved.
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$ChannelId,

        # If true, only channels with polling source connectors will be returned.
        [Parameter()]
        [boolean]$PollingOnly,

        #If true, code template libraries will be included in the channel.
        [boolean]$IncludeCodeTemplateLibraries,
   
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
        Write-Debug "$($MyInvocation.MyCommand.Name) Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }           
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/channels'

        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)

        if ($PSBoundParameters.ContainsKey('ChannelId')) {
            foreach ($value in $ChannelId) {
                $parameters.Add('channelId', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('PollingOnly')) {
            $parameters.Add('pollingOnly', $PollingOnly)
        }
        if ($PSBoundParameters.ContainsKey('IncludeCodeTemplateLibraries')) {
            $parameters.Add('includeCodeTemplateLibraries', $IncludeCodeTemplateLibraries)
        }

        $uri = $uri + '?' + $parameters.toString()

        Write-Debug "Invoking GET Mirth at $uri"
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session -Headers $DEFAULT_HEADERS
            
            Write-Debug "...done."

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
        Write-Debug "$($MyInvocation.MyCommand.Name) Ending"
    }
}