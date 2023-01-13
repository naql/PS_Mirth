function Set-MirthUser {
    <#
    .SYNOPSIS
        Updates a Mirth user, specified by targetId (id only).

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        $payLoad 
        String containing the XML describing a user object, e.g.,
            <user>
              <id>13</id>
              <username>RenamedUser</username>
              <email>andy@datasprite.com</email>
              <firstName>Barney</firstName>
              <lastName>Rubble</lastName>
              <organization>DataSprite</organization>
              <description>User updated from PowerShell Mirth API</description>
              <phoneNumber>210-724-2457</phoneNumber>
            </user>

        Note that a user may be renamed, including the default admin user.
        Even though the id is supplied in the path, it must also be present 
        in the user payload.

    .OUTPUTS

    .EXAMPLE

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The user id to be updated, this must be the numeric id.
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$targetId,

        # xml of the user to be added
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$payLoad,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Set-MirthUser Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        if ([string]::IsNullOrEmpty($targetId)) { 
            Write-Error "A targetId is required!"
            return
        }

        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            Write-Error "A user XML payLoad string is required!"
            return
        }
        else {
            Write-Verbose "Creating payload from xml: $payLoad"
            $userXML = [xml]$payLoad
        }

        $msg = "Updating user: " + $userXML.user.username + " assigned to " + $userXML.user.firstName + " " + $userXML.user.lastName
        Write-Debug $msg

        $uri = $serverUrl + '/api/users/' + $targetId
        Write-Debug "PUT to Mirth $uri "
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Content-Type", "application/xml")
        try { 
            $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method PUT -Headers $headers -Body $userXML.OuterXml
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
        Write-Debug "Set-MirthUser Ending"
    }
 
}  # Set-MirthUser