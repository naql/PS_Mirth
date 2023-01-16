function Get-MirthChannelTags {
  <#
    .SYNOPSIS
        Gets the Mirth Channel Tags

    .DESCRIPTION
        Return xml object describing all channel tags defined and listing the channel ids that belong to them.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all channel groups are returned.  Otherwise, only the channel groups with the 
        id values specified are returned.

    .OUTPUTS
        Returns an XML object that represents a set of channelTag objects:

        <set>
          <channelTag>
            <id>c135989c-9e1c-45f3-9b7e-a31f5ff2ea45</id>
            <name>White Tag</name>
            <channelIds>
              <string>014d299a-d972-4ae6-aa48-a2741f78390c</string>
            </channelIds>
            <backgroundColor>
              <red>255</red>
              <green>255</green>
              <blue>255</blue>
              <alpha>255</alpha>
            </backgroundColor>
          </channelTag>
          <channelTag>
            <id>5a123c6b-aacd-4be5-8c21-a981ce94a95e</id>
            <name>Red Tag</name>
            <channelIds>
              <string>e0e315bc-e064-4a6c-bc60-e26c2b4846b7</string>
            </channelIds>
            <backgroundColor>
              <red>255</red>
              <green>0</green>
              <blue>0</blue>
              <alpha>255</alpha>
            </backgroundColor>
          </channelTag>
          <channelTag>
            <id>a18cdca9-e8d2-445f-b844-d1418e0acea8</id>
            <name>Blue Tag</name>
            <channelIds>
              <string>014d299a-d972-4ae6-aa48-a2741f78390c</string>
            </channelIds>
            <backgroundColor>
              <red>0</red>
              <green>102</green>
              <blue>255</blue>
              <alpha>255</alpha>
            </backgroundColor>
          </channelTag>
        </set>

    .EXAMPLE
        Get-MirthChannelTags -saveXML -outFile nrg-channel-tags.xml
        $channelGroups = Get-MirthChannelTags -connection $connection 
        
    .LINK

    .NOTES

    #> 
  [CmdletBinding()] 
  PARAM (

    
    # A mirth session is required. You can obtain one or pipe one in from Connect-Mirth.
    [Parameter(ValueFromPipeline = $True)]
    [MirthConnection]$connection = $currentConnection,

    # Saves the response from the server as a file in the current location.
    [Parameter()]
    [switch]$saveXML,

    [switch]
    $Raw,
        
    # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
    [Parameter()]
    [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
  ) 
  BEGIN {
    Write-Debug "Get-MirthChannelTags Beginning" 
  }
  PROCESS { 
    if ($null -eq $connection) { 
      Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
    }        
    [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
    $serverUrl = $connection.serverUrl

    $uri = $serverUrl + '/api/server/channelTags'
    Write-Debug "Invoking GET Mirth at $uri"
    try { 
      $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
      Write-Debug "...done."

      if ($saveXML) {
        Save-Content $r $outFile
      }
      Write-Verbose "$($r.OuterXml)"
            
      if ($Raw) {
        $r
      }
      else {
        ConvertFrom-Xml $r.DocumentElement @{'set' = 'channelTag'; 'channelIds' = 'string' }
      }
    }
    catch {
      Write-Error $_
    }
  }
  END { 
    Write-Debug "Get-MirthChannelTags Ending" 
  } 
}  #  Get-MirthChannelTags