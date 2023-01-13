function Test-MirthUserLoggedIn { 
    <#
    .SYNOPSIS
        Tests the mirth user specified by the targetId and returns [bool] value
        indicating if the user is logged in or not.

    .DESCRIPTION
        Tests the user to see if logged in.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        A valid Mirth user id must be provided in the targetId parameter.

    .OUTPUTS
        [bool], TRUE if the user identified by targetId is logged in, otherwise false.

    .EXAMPLE
        Connect-Mirth | Test-MirthUserLoggedIn -targetId 1 

    .NOTES

    #>
    [OutputType([bool])] 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The user id to be tested (not the username)
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$targetId,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN {
        Write-Debug "Test-MirthUserLoggedIn Beginning" 
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/users/' + $targetId + "/loggedIn"
        Write-Debug "Invoking GET Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session 
            Write-Debug "...done."

            if ($saveXML) { 
                Save-Content $r $outFile
            }
            Write-Verbose "$($r.OuterXml)"
            
            return [System.Convert]::ToBoolean($r.boolean)
        }
        catch [System.Net.WebException] {
            # a 500 server error is thrown when you use a non-existent user id.
            Write-Error ("StatusCode: {0}" -f $_.Exception.Response.StatusCode.value__)
            Write-Error ("StatusDescription: {0}" -f $_.Exception.Response.StatusDescription)
            return $false
        }
        catch {
            Write-Error $_
            return $false
        }     
    }
    END {
        Write-Debug "Test-MirthUserLoggedIn Ending" 
    }
}  # Test-MirthUserLoggedIn