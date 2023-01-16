function Get-MirthConfigMap {
  <#
    .SYNOPSIS
        Gets the Mirth configuration map. Returns an xml object to the Pipeline.

    .DESCRIPTION
        Fetches the Mirth configuration map.

    .INPUTS
        A -connection  MirthConnection object is required. See Connect-Mirth.

    .OUTPUTS
        A map of entries with string key names and com.mirth.connect.util.ConfigurationProperty objects.

        <map>
          <entry>
            <string>file-inbound-folder</string>
            <com.mirth.connect.util.ConfigurationProperty>
              <value>C:\FileReaderInput</value>
              <comment>This is a comment describing the file-inbouind-reader property.</comment>
            </com.mirth.connect.util.ConfigurationProperty>
          </entry>
          <entry>
            <string>db.url</string>
            <com.mirth.connect.util.ConfigurationProperty>
              <value>jdbc:thin:@localhost:1521\dbname</value>
              <comment>This is a fake db url property.</comment>
            </com.mirth.connect.util.ConfigurationProperty>
          </entry>
        </map>
        <map>
          <entry>
            <string>file-inbound-folder</string>
            <com.mirth.connect.util.ConfigurationProperty>
              <value>C:\FileReaderInput</value>
              <comment>This is a comment describing the file-inbouind-reader property.</comment>
            </com.mirth.connect.util.ConfigurationProperty>
          </entry>
          <entry>
            <string>db.url</string>
            <com.mirth.connect.util.ConfigurationProperty>
              <value>jdbc:thin:@localhost:1521\dbname</value>
              <comment>This is a fake db url property.</comment>
            </com.mirth.connect.util.ConfigurationProperty>
          </entry>
        </map>

        If the -asHashtable switch is specified, the response is a PowerShell hashtable.

    .EXAMPLE
        Connect-Mirth | Get-MirthConfigMap 
        Get-MirthConfigMap -asHashtable 

    .NOTES

    #> 
  [CmdletBinding()] 
  PARAM (

    # A MirthConnection is required. You can obtain one from Connect-Mirth.
    [Parameter(ValueFromPipeline = $True)]
    [MirthConnection]$connection = $currentConnection,

    # Switch, if true, returns hashtable response, otherwise XML
    [Parameter()]
    [switch]$asHashtable,

    # Saves the response from the server as a file in the current location.
    [Parameter()]
    [switch]$saveXML,
        
    # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
    [Parameter()]
    [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
  ) 
  BEGIN { 
  }
  PROCESS { 
    if ($null -eq $connection) { 
      Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
    }          
    [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
    $serverUrl = $connection.serverUrl

    $uri = $serverUrl + '/api/server/configurationMap'
    Write-Debug "Invoking GET Mirth at $uri"
    try { 
      $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session

      if ($saveXML) { 
        Save-Content $r $outFile
      }
      Write-Verbose "$($r.OuterXml)"

      if (-not $asHashtable) { 
        return $r;
      }
      else { 
        Write-Debug "Converting XML response to hashtable"

        <#$returnMap = @{}
        foreach ($entry in $r.map.entry) { 
          $channelId = $entry.string
          $metaData = $entry.SelectSingleNode("com.mirth.connect.util.ConfigurationProperty").'value'
          $returnMap[$channelId] = $metaData
        }
        return $returnMap#>
        ConvertFrom-Xml $r.DocumentElement -MapNames @('com.mirth.connect.util.ConfigurationProperty/value')
      }
    }
    catch {
      Write-Error $_
    }
  }
  END {
  }
}  # Get-MirthConfigMap