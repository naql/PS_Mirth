function Disconnect-Mirth { 
    [CmdletBinding()]
    PARAM (
        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        $connection = $currentConnection
    )
    BEGIN {
        Write-Debug "Disconnect-Mirth Beginning..."
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth" 
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        Write-Debug "Disconnecting from Mirth..."
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("accept", "application/xml")
        $headers.Add("Content-Type", "application/xml")
        $uri = $serverUrl + '/api/users/_logout'

        Write-Debug "Invoking POST Mirth $uri"
        Write-Debug "`$headers=$($headers.GetEnumerator())"
        try { 
            Invoke-RestMethod -uri $uri -Headers $headers -Method Post -WebSession $session -StatusCodeVariable statusCode | Out-Null
            
            #expect statusCode=204
            Write-Debug "`$statusCode=$statusCode"

            #clear this feature's data as they've logged out
            NotifyChannelMapCacheUpdate @{}
            
            $script:currentConnection = $null
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug "Disconnect-Mirth Ending>..."
    }

}  # Disconnect-Mirth