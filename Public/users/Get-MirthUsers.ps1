function Get-MirthUsers {
    <#
    .SYNOPSIS
        Gets all Mirth users, or a specific mirth user by either id or username. 

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        Returns an XML object that is a list of user elements.

            <list>
              <user>
                <id>1</id>
                <username>admin</username>
                <email></email>
                <firstName></firstName>
                <lastName></lastName>
                <organization></organization>
                <description></description>
                <phoneNumber></phoneNumber>
                <lastLogin>
                  <time>1590301209113</time>
                  <timezone>America/Chicago</timezone>
                </lastLogin>
              </user>
                [...]
            </list>

    .EXAMPLE
        Connect-Mirth | Get-MirthUsers 
        Connect-Mirth | Get-MirthUsers -targetId 1 

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
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN {
        Write-Debug "Get-MirthUsers Beginning" 
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        $uri = $serverUrl + '/api/users'
        $singleUser = $False
        if (-NOT [string]::IsNullOrEmpty($targetId)) { 
            Write-Debug 'Getting user by target identifier'
            $singleUser = $True
            $uri = "$uri/$targetId"
        }
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Accept", "application/xml")

        Write-Debug "Invoking GET Mirth  $uri "
        try { 
            $r = Invoke-RestMethod -Headers $headers -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."

            if ($singleUser) { 
                #wrap in a list element for consistency
                Write-Debug "Wrapping single user in list for return"
                $userNode = $r.SelectSingleNode("/user")
                [Xml]$newXml = New-Object -TypeName xml
                $listNode = $newXml.CreateElement("list")
                $userNode = $listNode.OwnerDocument.ImportNode($userNode, $True)
                $listNode.AppendChild($userNode) | Out-Null  
                $newXml.AppendChild($listNode) | Out-Null

                $r = $newXml
            }

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
        Write-Debug "Get-MirthUsers Ending"
    }
}  # Get-MirthUsers