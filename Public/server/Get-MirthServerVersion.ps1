function Get-MirthServerVersion { 

    <#
    .SYNOPSIS
        Gets the mirth server version. 

    .DESCRIPTION
        Returns a String containing the version to the Pipeline.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        Returns a string containing the version of the Mirth server, e.g., "3.6.2"

    .EXAMPLE
        Connect-Mirth | Get-MirthServerVersion  -saveXML

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.txt'
    ) 
    BEGIN {
        Write-Debug "Get-MirthServerVersion Beginning..."
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
 
        $uri = $serverUrl + '/api/server/version'
        Write-Debug "Invoking GET Mirth API server at: $uri "
        $headers = $DEFAULT_HEADERS.Clone();
        $headers.Add('Accept', 'text/plain');
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session -Headers $headers
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
        Write-Debug "Get-MirthServerVersion Ending..."
    }
}  # Get-MirthServerVersion