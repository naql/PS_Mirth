function Connect-Mirth { 
    <#
    .SYNOPSIS
        Logs into a Mirth server and returns a MirthConnection object that can be used
        for subsequent calls.  

    .DESCRIPTION
        This function logs into the mirth server located at serverURL using the mirth 
        username adminUser and password, adminPass.  If these are not supplied, it will 
        default to "Https://localhost:8443", user "admin", and password "admin".  These 
        are the default Mirth settings for a new installation.

    .INPUTS

    .OUTPUTS
        If the login command is processed a [Microsoft.PowerShell.Commands.WebRequestSession] object representing 
        the session is returned.  Otherwise, the [xml] response from the Mirth server is returned.

    .EXAMPLE
        $session = Connect-Mirth -serverUrl https://localhost:5443 -adminUser myUser -adminPass myPass
        $session = Connect-Mirth -serverUrl va-nrg-t-gold.tmdsmsat.akiproj.com:8443 
        Connect-Mirth | Write-ServerConfig

    .LINK
        Links to further documentation.

    .NOTES
        [OutputType([Microsoft.PowerShell.Commands.WebRequestSession])]
    #> 
    [CmdletBinding()]
    PARAM (
        [Parameter()]
        [string]$serverUrl = "https://localhost:8443",
        [Parameter()]
        [string]$userName = "admin",
        [Parameter()]
        [securestring]$userPass = (ConvertTo-SecureString -String "admin" -AsPlainText)
    )
    BEGIN {
        Write-Debug "Connect-Mirth Beginning..."
    }
    PROCESS {
        Write-Debug "Logging into Mirth..."
        Write-Debug "serverUrl = $serverUrl"
        Write-Debug "userName = $userName"
        Write-Debug ("userPass = {0}" -f (ConvertFrom-SecureString $userPass -AsPlainText))
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Accept", "application/xml")
        $uri = $serverUrl + '/api/users/_login'
        $body = ("username={0}&password={1}" -f $userName, (ConvertFrom-SecureString $userPass -AsPlainText))
        try { 
            $r = Invoke-RestMethod -uri $uri -Headers $headers -Body $body -Method POST -SessionVariable session
            Write-Debug ("Response: {0}" -f $r.DocumentElement.status)

            $script:currentConnection = [MirthConnection]::new($session, $serverUrl, $userName, $userPass)

            if ($script:ChannelAutocomplete -eq [ChannelAutocompleteMode]::Cache) {
                Get-MirthChannelIdsAndNames
            }

            return $script:currentConnection
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug "Connect-Mirth Ending>..."
    }

}  # Connect-Mirth