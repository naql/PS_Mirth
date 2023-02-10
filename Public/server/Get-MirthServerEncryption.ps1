function Get-MirthServerEncryption {
  [CmdletBinding()] 
  PARAM (
    # A MirthConnection is required. You can obtain one from Connect-Mirth.
    [Parameter(ValueFromPipeline = $True)]
    [MirthConnection]$connection = $currentConnection,

    [Parameter()]
    [switch]$Raw,

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

    $uri = $serverUrl + '/api/server/encryption'
    Write-Debug "Invoking GET Mirth at $uri"
    try { 
      $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session

      if ($saveXML) { 
        Save-Content $r $outFile
      }
      Write-Verbose "$($r.OuterXml)"

      if ($Raw) { 
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
        ConvertFrom-Xml $r.DocumentElement
      }
    }
    catch {
      Write-Error $_
    }
  }
  END {
  }
}