function Remove-MirthEvents {
    <#
    .SYNOPSIS
        Deletes all Mirth events.
    .DESCRIPTION
        If $Export is specified, the events will be exported into the application data directory on the server
        before being removed, and the full file paths will be returned. If not specified, there is no return value.
    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        #If true, messages will be exported into the application data directory on the server before being removed.
        [switch]
        $Export,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML
    )    
    BEGIN { 
        Write-Debug "Remove-MirthEvents Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"  
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        $uri = $serverUrl + '/api/events'

        if ($Export) {
            $uri = $uri + '?export=true'
        }

        Write-Debug "DELETE to Mirth $uri "
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add('accept', 'text/plain')

        try { 
            $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method DELETE -Headers $headers
            Write-Debug "...done."

            if ($saveXML) { 
                Save-Content $r $outFile
            }
            Write-Verbose $r
            
            return $r
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug "Remove-MirthEvents Ending"
    }
}