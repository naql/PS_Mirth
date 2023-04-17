function Set-MirthLicenseManagerType {
    [CmdletBinding()] 
    PARAM (
    
        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        [switch]
        $Offline
    ) 
    BEGIN { 
        Write-Debug 'Set-MirthLicenseManagerType Beginning'
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/extensions/licensemanager/type'
        Write-Debug "Invoking PUT Mirth $uri "

        $headers = $DEFAULT_HEADERS.clone()
        $headers.Add('Content-Type', 'application/xml')
        $headers.Add('accept', 'application/xml')

        $payLoadXML = [xml]"<boolean>$($PSBoundParameters.ContainsKey("Offline"))</boolean>"

        try { 
            $r = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -WebSession $session -Body $payLoadXML

            Write-Debug "...done."
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug 'Set-MirthLicenseManagerType Ending' 
    }
}