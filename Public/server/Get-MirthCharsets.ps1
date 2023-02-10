function Get-MirthCharsets {
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
    Write-Debug "Get-MirthCharsets Beginning" 
  }
  PROCESS { 
    if ($null -eq $connection) { 
      Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
    }        
    [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
    $serverUrl = $connection.serverUrl

    $uri = $serverUrl + '/api/server/charsets'
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
        ConvertFrom-Xml $r.DocumentElement -ConvertAsList @('list')
      }
    }
    catch {
      Write-Error $_
    }
  }
  END { 
    Write-Debug "Get-MirthCharsets Ending" 
  } 
}