function Get-MirthLoggedInUsers {
    <#
    .SYNOPSIS
        Gets the currently logged in Mirth users.

    .DESCRIPTION
        Returns a list of mirth users that are currently logged in.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all channel groups are returned.  Otherwise, only the channel groups with the 
        id values specified are returned.

    .OUTPUTS

        <list>
            <user>
                <id>1</id>
                <username>admin</username>
                <email />
                <firstName />
                <lastName />
                <organization />
                <description />
                <phoneNumber />
                <lastLogin>
                  <time>1590210339894</time>
                  <timezone>America/Chicago</timezone>
                </lastLogin>
          </user>
        </list>

    .EXAMPLE
        Connect-Mirth | Get-MirthLoggedUsers

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the channelGroup to retrieve, empty for all
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetId,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN {
        Write-Debug 'Get-MirthLoggedUsers Beginning'  
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }  
        [xml]$loggedUsers = '<list></list>' 
        $allUsers = Get-MirthUsers -connection $connection 
        foreach ($user in $allUsers.list.user) {
            $uTmp = $user.username
            Write-Debug "Checking user $uTmp" 
            if (Test-MirthUserLoggedIn -connection $connection -targetId $user.id) {
                Write-Verbose "$uTmp is logged in!"
                $loggedUsers.DocumentElement.AppendChild($loggedUsers.ImportNode($user, $true))
            }
        }
        if ($saveXML) { 
            Save-Content $loggedUsers $outFile
        }
        Write-Verbose $loggedUsers.OuterXml
        return $loggedUsers
    }
    END { 
        Write-Debug 'Get-MirthLoggedUsers Ending'
    }

}  # Get-MirthLoggedUsers