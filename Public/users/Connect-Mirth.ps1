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
        $session = Connect-Mirth

        Connect using the defaults
    .EXAMPLE
        $session = Connect-Mirth -serverUrl https://localhost:5443

        Connect to the URL with default credentials
    .EXAMPLE
        $session = Connect-Mirth -serverUrl https://localhost:5443 -Credential $MyCredential
        
        Connect using all parameters
    .EXAMPLE
        Connect-Mirth | Write-ServerConfig
    
        Connect to the server using the defaults and write the server config
    .EXAMPLE
        $session = Connect-Mirth -ComputerName "testEnvMirth02" -Port 9000

        Connect to the server using the alternative ParameterSet
    .LINK
        Links to further documentation.

    .NOTES
        [OutputType([Microsoft.PowerShell.Commands.WebRequestSession])]
    #> 
    [CmdletBinding(DefaultParameterSetName = "Default")]
    PARAM (
        [Parameter(ParameterSetName = "Default")]
        [string]$serverUrl = "https://localhost:8443",
        [Parameter(Mandatory, ParameterSetName = "Split")]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,
        [Parameter(Mandatory, ParameterSetName = "Split")]
        [ValidateNotNull()]
        [int]$Port,
        [Parameter()]
        [pscredential]$Credential = $DEFAULT_CREDENTIAL
    )
    BEGIN {
        Write-Debug "Connect-Mirth Beginning..."
    }
    PROCESS {
        Write-Debug "Logging into Mirth..."
        
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("accept", "application/xml")

        if ($ComputerName) {
            #Write-Debug "Using computer name and port"
            $uri = "https://{0}:{1}/api/users/_login" -f $ComputerName, $Port
        }
        else {
            $uri = "{0}/api/users/_login" -f $serverUrl
        }

        Write-Debug "uri = $uri"
        Write-Debug "Credential = $Credential"

        $body = ("username={0}&password={1}" -f $Credential.UserName, $Credential.GetNetworkCredential().Password)
        try { 
            $r = Invoke-RestMethod -uri $uri -Headers $headers -Body $body -Method POST -SessionVariable session
            Write-Debug ("Response: {0}" -f $r.DocumentElement.status)

            $script:currentConnection = [MirthConnection]::new($session, $serverUrl, $Credential.UserName)

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