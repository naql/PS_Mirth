function Set-MirthGlobalScripts { 
    <#
    .SYNOPSIS
        Replaces the Mirth global scripts. 

    .DESCRIPTION
        Replaces all global scripts, deploy, undeploy, preprocessor and postprocessor 

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        This command expects input in XML format, using the com.mirthy.connect.util.ConfigurationProperty 
        element to represent property values and description.

        $payLoad is xml describing a map containing string, string pairs, where the first string is the
        name of the global script and the second is the xml escaped javascript of the global script:

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

        # xml of the configuration map to be added
        [Parameter(ParameterSetName = "xmlProvided",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$payLoad,

        # path to file containing the xml of the configuation map
        [Parameter(ParameterSetName = "pathProvided",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$payloadFilePath,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )  
    BEGIN { 
        Write-Debug "Set-MirthGlobalScripts Beginning"
    }
    PROCESS {
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/server/globalScripts' 
        [xml]$payLoadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A configuration map XML payLoad string is required!"
                return $null
            }
            else {
                Write-Debug "Loading channel XML from path $payLoadFilePath"
                [xml]$payLoadXML = Get-Content $payLoadFilePath  
            }
        }
        else {
            Write-Debug "Creating XML payload from string: $payLoad"
            $payLoadXML = [xml]$payLoad
        }
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Accept", "application/xml")
        $headers.Add("Content-Type", "application/xml")

        Write-Debug "Invoking PUT Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -Method PUT -WebSession $session -Body $payLoadXML.OuterXml
            Write-Debug "...done."
            if ($saveXML) { 
                $Content = "Global Scripts Updated Successfully: $payLoad"
                Save-Content $Content $outFile
            }
            Write-Verbose "$($r.OuterXml)"

            return $r
        }
        catch {
            Write-Error $_
        }  
    }
    END {
        Write-Debug "Set-MirthGlobalScripts Ending" 
    }

}  #  Set-MirthGlobalScripts