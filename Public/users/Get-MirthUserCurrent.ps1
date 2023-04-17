function Get-MirthUserCurrent {
    <#
    .SYNOPSIS
        Returns the current logged in user.
    #>
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
        Write-Debug "Get-MirthUserCurrent Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + "/api/users/current"

        Write-Debug "GET to Mirth $uri "

        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("accept", "application/xml")
        
        try { 
            $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method GET -Headers $headers
            Write-Debug "...done."

            if ($saveXML) { 
                Save-Content $r $outFile
            }
            Write-Verbose "$($r.OuterXml)"
            
            if ($Raw) {
                $r
            }
            else {
                ConvertFrom-Xml $r.DocumentElement
            }
        }
        catch {
            Write-Error $_
        }
    }
    END { 
        Write-Debug "Get-MirthUserCurrent Ending"
    }
 
}