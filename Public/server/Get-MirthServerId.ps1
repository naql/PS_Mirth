function Get-MirthServerId {
  [CmdletBinding()] 
  PARAM (
    # A MirthConnection is required. You can obtain one from Connect-Mirth.
    [Parameter(ValueFromPipeline = $True)]
    [MirthConnection]$connection = $currentConnection,

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

    $uri = $serverUrl + '/api/server/id'
    Write-Debug "Invoking GET Mirth at $uri"

    $headers = $DEFAULT_HEADERS.Clone()
    $headers.Add('accept', 'text/plain')

    try { 
      $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session -Headers $headers

      if ($saveXML) { 
        Save-Content $r $outFile
      }
      Write-Verbose $r

      $r
    }
    catch {
      Write-Error $_
    }
  }
  END {
  }
}