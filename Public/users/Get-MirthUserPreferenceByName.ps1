function Get-MirthUserPreferenceByName {
    <#
    .SYNOPSIS
        Returns a specific user preference.
    .DESCRIPTION
        Note that if the specified Name is not found, then a blank response is returned.
    #>
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The unique ID of the user.
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$UserId,

        #The name of the user property to retrieve. Ex: firstlogin
        [Parameter(Mandatory, Position = 1)]
        [string]$Name,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Get-MirthUserPreferenceByName Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + "/api/users/$UserId/preferences/$Name"

        Write-Debug "GET to Mirth $uri "

        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("accept", "text/plain")
        
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
        Write-Debug "Get-MirthUserPreferenceByName Ending"
    }
}