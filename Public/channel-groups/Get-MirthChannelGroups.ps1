function Get-MirthChannelGroups { 
    <#
    .SYNOPSIS
        Gets the Mirth Channel Groups 

    .DESCRIPTION
        Returns a list of one or more channelGroup objects:

        <list>
          <channelGroup version="3.6.2">
            <id>bb2c8399-d05b-443c-a77f-05b5484fdfe9</id>
            <name>Transport Sample Channels</name>
            <revision>1</revision>
            <lastModified>
              <time>1589682536845</time>
              <timezone>America/Chicago</timezone>
            </lastModified>
            <description>These are channels illustrating each of the basic Mirth transports.
        </description>
            <channels>
              <channel version="3.6.2">
                <id>e0e315bc-e064-4a6c-bc60-e26c2b4846b7</id>
                <revision>0</revision>
              </channel>
              <channel version="3.6.2">
                <id>014d299a-d972-4ae6-aa48-a2741f78390c</id>
                <revision>0</revision>
              </channel>
            </channels>
          </channelGroup>
        </list>

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all channel groups are returned.  Otherwise, only the channel groups with the 
        id values specified are returned.

    .OUTPUTS
        

    .EXAMPLE
        Connect-Mirth | Get-MirthChannelGroups 
        Connect-Mirth | Get-MirthChannelGroups -targetId bb2c8399-d05b-443c-a77f-05b5484fdfe9 
        Connect-Mirth | Get-MirthChannelGroups -targetId bb2c8399-d05b-443c-a77f-05b5484fdfe9,fdae2c23-8b01-48ac-9357-8da33082fe93

        # fetch a list of the current mirth channel group ids...
        $(Get-MirthChannelGroups ).list.channelGroup.id
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the channelGroup to retrieve, empty for all
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetId = @(),

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
        Write-Debug "Get-MirthChannelGroups Beginning..."
        #Write-Debug "targetId is: " $targetId     
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }  
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/channelgroups'
        if ([string]::IsNullOrEmpty($targetId) -or [string]::IsNullOrWhiteSpace($targetId)) {
            Write-Debug "Fetching all channel Groups"
            $parameters = $null
        }
        else {
            $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
            foreach ($target in $targetId) {
                $parameters.Add('channelGroupId', $target)
            }
            $uri = $uri + '?' + $parameters.toString()
        }
         
        Write-Debug "Invoking GET Mirth $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session 
            Write-Debug "...done."

            Write-Verbose "$($r.OuterXml)"
            
            if ($saveXML) { 
                Save-Content $r $outFile
            }
            
            if ($Raw) {
                $r
            }
            else {
                ConvertFrom-Xml $r.DocumentElement @{
                    'list'     = 'channelGroup'
                    'channels' = 'channel'
                }
            }
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug "Get-MirthChannelGroups Ending..." 
    }

}  # Get-MirthChannelGroups