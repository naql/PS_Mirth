function Get-MirthServerConfig {
    <#
    .SYNOPSIS
        Gets all the complete server configuration backup XML file for the specified server. 

    .DESCRIPTION
        Creates a single XML file backup of the entire mirth server configuration.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        Returns an XML object that represents a complete server backup of 
        channels, code templates, server settings, keystores, etc.

    .EXAMPLE
         Get-MirthServerConfig  -saveXML -outFile backup-local-dev.xml
         [xml]$backupXML = Get-MirthServerConfig -connection $connection 

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
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN {
        Write-Debug  "Get-MirthServerConfig Beginning..."
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/server/configuration'
        Write-Debug "Invoking GET Mirth $uri "
        # This backs up channels, code templates, everything, to a single xml file
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."

            if ($saveXML) { 
                Save-Content $r $outFile
            }
            Write-Verbose $r.innerXml
            return $r

        }
        catch {
            Write-Error $_
        }     
    }
    END { 
        Write-Debug "Get_MirthServerConfig Ending..."
    } 
}  # Get-MirthServerConfig