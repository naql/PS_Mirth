function Get-MirthGlobalScripts { 
    <#
    .SYNOPSIS
        Gets the Mirth server global scripts.

    .DESCRIPTION
        Returns an XML object representing a map of global scripts.  
        The first string of each map entry is the name of the global script.
        The second string is the xml escaped javascript.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS

        [xml] object containing a map where each entry name value pair is
        a global script:  Deploy, Undeploy, Preprocessor, and Postprocessor

        <map>
	        <entry>
		        <string>Undeploy</string>
		        <string>// This script executes once for each deploy, undeploy, or redeploy task
        logger.info("=== GLOBAL UNDEPLOY SCRIPT EXECUTING ===");
        return;</string>
	        </entry>
	        <entry>
		        <string>Postprocessor</string>
		        <string>// This script executes once after a message has been processed
        logger.info("=== GLOBAL POSTPROCESSOR SCRIPT EXECUTING ===");
        return;</string>
	        </entry>
	        <entry>
		        <string>Deploy</string>
		        <string>// This script executes once for each deploy or redeploy task
        logger.info("=== GLOBAL DEPLOY SCRIPT EXECUTING ===");
        return;</string>
	        </entry>
	        <entry>
		        <string>Preprocessor</string>
		        <string>// Modify the message variable below to pre process data
        logger.info("=== GLOBAL PREPROCESSOR SCRIPT EXECUTING ===");
        return message;</string>
	        </entry>
        </map>

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

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Get-MirthGlobalScripts Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/server/globalScripts'
        Write-Debug "Invoking GET Mirth at $uri"
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Content-Type", "application/xml")
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session -Headers $headers
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
        Write-Debug "Get-MirthGlobalScripts Ending"
    }

}  #  Get-MirthGlobalScripts