function Set-MirthLicenseManagerKey {
    [CmdletBinding()] 
    PARAM (
    
        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Key
    ) 
    BEGIN { 
        Write-Debug 'Set-MirthLicenseManagerKey Beginning'
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/extensions/licensemanager/key'
        Write-Debug "Invoking PUT Mirth $uri "

        $headers = $DEFAULT_HEADERS.clone()
        $headers.Add('Content-Type', 'text/plain')
        $headers.Add('accept', 'application/xml')

        try { 
            $r = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -WebSession $session -Body $Key

            Write-Debug "...done."
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug 'Set-MirthLicenseManagerKey Ending' 
    }
}