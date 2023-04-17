function Set-MirthUserPassword {
    <#
    .SYNOPSIS
        Update Mirth user passwords

    .DESCRIPTION
        Updates the password for the mirth user specified by "targetId" to the 
        password specified by the parameter, newPassword, defaulting to "changeit"
        if none is provided.  It can perform this action for one user, by id or name,
        or for all users if no targetId is provided.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS

    .EXAMPLE
        Connect-Mirth | Set-MirthUserPassword -targetId admin -newPassword M1rth@dm1n!! 
        Connect-Mirth -userPass M1rth@dm1n!! | Set-MirthUserPassword -targetId admin -newPassword admin -saveXML

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The user id to be retrieved, this can be either the userName or the id
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string]$targetId,

        # The new password when performing the add-user or change-password commands, default is "changeit"
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [securestring]$newPassword = (ConvertTo-SecureString -String "changeit" -AsPlainText),
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN {
        Write-Debug "Set-MirthUserPassword Beginning" 
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $ulist = Get-MirthUsers -connection $connection -targetId $targetId -saveXML:$saveXML
        if ($null -ne $ulist) {
            $users = $ulist.SelectNodes("/list/user")
        }
        Write-Debug "There were $($users.Count) users retrieved for set password command"

        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Content-Type", "text/plain")

        foreach ($u in $users) {
            Write-Debug "Changing password user: $($u.id): $($u.username) assigned to $($u.lastName)"
                
            $uri = $serverUrl + '/api/users/' + $u.id + '/password'
            Write-Debug "PUT to Mirth at $uri"
            try { 
                $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method PUT -Headers $headers -Body (ConvertFrom-SecureString $newPassword -AsPlainText)
                Write-Debug "...Password set"
                if ($saveXML) { 
                    Save-Content "$targetId : $(ConvertFrom-SecureString $newPassword -AsPlainText)" $outFile
                }
                Write-Verbose $r
            }
            catch {
                Write-Error $_
            }
        }  # For each user selected
    } 
    END { 
        Write-Debug "Set-MirthUserPassword Ending" 
    }
}  # Set-MirthUserPassword
