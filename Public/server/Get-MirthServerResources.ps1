function Get-MirthServerResources {
  [CmdletBinding()] 
  PARAM (
    # A MirthConnection is required. You can obtain one from Connect-Mirth.
    [Parameter(ValueFromPipeline = $True)]
    [MirthConnection]$connection = $currentConnection,

    [switch]
    $Raw,

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

    $uri = $serverUrl + '/api/server/resources'
    Write-Debug "Invoking GET Mirth at $uri"

    try { 
      $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session -Headers $DEFAULT_HEADERS

      if ($saveXML) { 
        Save-Content $r $outFile
      }
      Write-Verbose $r

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
  }
}