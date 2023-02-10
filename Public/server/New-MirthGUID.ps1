function New-MirthGUID {
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
    Write-Debug "New-MirthGUID Beginning" 
  }
  PROCESS { 
    if ($null -eq $connection) { 
      Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
    }        
    [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
    $serverUrl = $connection.serverUrl

    $uri = $serverUrl + '/api/server/_generateGUID'
    Write-Debug "Invoking POST Mirth at $uri"

    $headers = $DEFAULT_HEADERS.Clone()
    $headers.Add('accept', 'text/plain')
    # THIS is REQUIRED ELSE YOU GET A 415 ERROR
    $headers.Add("Content-Type", "application/xml")

    try { 
      $r = Invoke-RestMethod -Uri $uri -Method POST -WebSession $session -Headers $headers
      
      Write-Debug "...done."

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
    Write-Debug "New-MirthGUID Ending" 
  } 
}