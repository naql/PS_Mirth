function Get-MirthChannelStatuses {
    <#
    .SYNOPSIS
        Gets the dashboard status of selected channels, or all channels

    .DESCRIPTION
        Return xml object describing a list of the requested channels.  Also fetches 
        server channel metadata and merges into the channel xml as a /channel/exportData
        element, just as if it were exported from the mirth gui.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then status for all channels are returned.  Otherwise, only the channels with the 
        id values specified are returned.

    .OUTPUTS

    .EXAMPLE
        
    .LINK
        Links to further documentation.

    .NOTES

    #>
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the channels to fetch status for, empty for all
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetId,

        [string] $filter,

        [switch] $includeUndeployed,

        # If true, return the raw xml response instead of a convenient object[]
        [switch] $Raw,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug 'Get-MirthChannelStatuses Beginning'
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }           
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/channels/statuses'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        if (-not([string]::IsNullOrEmpty($filter) -or [string]::IsNullOrWhiteSpace($filter))) {
            $parameters.Add('filter', $filter)
        }
        if ($includeUndeployed) { 
            $parameters.Add('includeUndeployed', 'true')
        }
        else {
            $parameters.Add('includeUndeployed', 'false')
        }
        if (-not([string]::IsNullOrEmpty($targetId) -or [string]::IsNullOrWhiteSpace($targetId))) {
            foreach ($target in $targetId) {
                $parameters.Add('channelId', $target)
            }
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
                        Save-Content $channel $channel.name + '.xml' 
                    }
                }
                else {
                    Save-Content $r $outFile
                }
            }
            Write-Verbose "$($r.OuterXml)"
            if ($Raw) {
                $r
            }
            else {
                ConvertFrom-Xml $r.DocumentElement @{
                    'list'               = 'dashboardStatus'
                    'statistics'         = 'entry'
                    'lifetimeStatistics' = 'entry'
                }
            }
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug 'Get-MirthChannelStatuses Ending' 
    }
}  # Get-MirthChannelStatuses