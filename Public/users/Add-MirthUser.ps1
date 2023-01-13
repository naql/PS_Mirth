function Add-MirthUser { 

    <#
    .SYNOPSIS
        Adds a Mirth User. 

    .DESCRIPTION
        This function creates a new mirth user and then updates the password.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        $payLoad is a user XML object describing the user to be added:

            <user>
                <username>testUser4</username>
                <email>andy@datasprite.com</email>
                <firstName>Andrew</firstName>
                <lastName>Hart</lastName>
                <organization>DataSprite</organization>
                <description>This is a test user, added from PowerShell.</description>
                <phoneNumber>210-555-1234</phoneNumber>
            </user>

    .OUTPUTS
        Returns an XML object that is either a list of user elements or a single user element.

    .EXAMPLE
        $newUser = @"                
            <user>
                <username>myNewUserToo</username>
                <email>andy@datasprite.com</email>
                <firstName>Fred</firstName>
                <lastName>Flintstone</lastName>
                <organization>DataSprite</organization>
                <description>This is a test user, added from PowerShell.</description>
                <phoneNumber>210-724-2457</phoneNumber>
            </user>
        "@
        Connect-Mirth | Add-MirthUser -payLoad $newUser -newPassword topsecret

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of the channel to be added
        [Parameter(ParameterSetName = "xmlProvided",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$payLoad,

        # path to the file containing the channel xml to import
        [Parameter(ParameterSetName = "pathProvided",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$payloadFilePath,

        # The new password when performing the add-user or change-password commands, default is "changeit"
        [Parameter()]
        [securestring]$newPassword = (ConvertTo-SecureString -String "changeit" -AsPlainText),
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN {
        Write-Debug "Add-MirthUser Beginning..." 
    }
    PROCESS { 

        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth" 
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$userXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A user XML payLoad string is required!"
                return $null
            }
            else {
                Write-Debug "Loading user XML from path $payLoadFilePath"
                $userXML = Get-Content $payLoadFilePath  
            }
        }
        else {
            $userXML = [xml]$payLoad
        }
        $msg = "Adding user: " + $userXML.user.username + " assigned to " + $userXML.user.firstName + " " + $userXML.user.lastName
        Write-Debug $msg

        $uri = $serverUrl + '/api/users'
        Write-Debug "POST to Mirth $uri "
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Content-Type", "application/xml")
        try { 
            $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method POST -Headers $headers -Body $userXML.OuterXml
            Write-Debug "...done."

            if ($saveXML) { 
                Save-Content $r $outFile
            }
            Write-Verbose "$($r.OuterXml)"
            Set-MirthUserPassword -connection $connection -targetId $userXML.user.username -newPassword $newPassword
        }
        catch {
            Write-Error $_
        }

    } 
    END { 
        Write-Debug "Add-MirthUser Ending..."
    }

}  # Add-MirthUser
