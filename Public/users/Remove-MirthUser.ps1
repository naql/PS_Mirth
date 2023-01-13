function Remove-MirthUser {
    <#
    .SYNOPSIS
        Deletes a Mirth user, specified by targetId (id only).

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        $targetId   The id of the user to delete.
                    Note, the default admin user, id = 1,  cannot be deleted.

    .OUTPUTS

    .EXAMPLE

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The user id to be deleted, this must be the numeric id.
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$targetId,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML
    )    
    BEGIN { 
        Write-Debug "Remove-MirthUser Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"  
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        if (-NOT [string]::IsNullOrEmpty($targetId)) { 
            Write-Debug 'Getting user by target identifier'
            $uri = "$uri/$targetId"
        }
        else { 
            Throw "A targetId is required!"
        }

        $msg = "Deleting user: " + $targetId
        Write-Debug $msg

        $uri = $serverUrl + '/api/users/' + $targetId
        Write-Debug "DELETE to Mirth $uri "
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Content-Type", "application/xml")
        try { 
            $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method DELETE -Headers $headers -Body $userXML.OuterXml
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
        Write-Debug "Remove-MirthUser Ending"
    }

}  # Remove-MirthUser
