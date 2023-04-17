function Set-MirthLicenseManagerValidationResponse {
    [CmdletBinding()] 
    PARAM (
    
        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ValidationResponse
    ) 
    BEGIN { 
        Write-Debug 'Set-MirthLicenseManagerValidationResponse Beginning'
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/extensions/licensemanager/validationResponse'
        Write-Debug "Invoking PUT Mirth $uri "

        $headers = $DEFAULT_HEADERS.clone()
        $headers.Add('Content-Type', 'text/plain')
        $headers.Add('accept', 'application/xml')

        try { 
            $r = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -WebSession $session -Body $ValidationResponse

            Write-Debug "...done."
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug 'Set-MirthLicenseManagerValidationResponse Ending' 
    }
}