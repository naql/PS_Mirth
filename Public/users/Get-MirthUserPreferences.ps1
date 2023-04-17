function Get-MirthUserPreferences {
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The unique ID of the user.
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$UserId,

        # An optional set of property names to filter by.
        [Parameter(Position = 1)]
        [string[]]$Name,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Get-MirthUserPreferences Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + "/api/users/$UserId/preferences"

        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("accept", "application/xml")

        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('userId', $UserId)

        if ($PSBoundParameters.ContainsKey('Name')) {
            foreach ($value in $Name) {
                $parameters.Add('name', $value)
            }
        }
        
        $uri = $uri + '?' + $parameters.toString()

        Write-Debug "GET to Mirth $uri "
        
        try { 
            $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method GET -Headers $headers
            Write-Debug "...done."

            if ($saveXML) { 
                Save-Content $r $outFile
            }
            Write-Verbose "$($r.OuterXml)"
            
            return $r
        }
        catch {
            Write-Error $_
        }
    }
    END { 
        Write-Debug "Get-MirthUserPreferences Ending"
    }
}