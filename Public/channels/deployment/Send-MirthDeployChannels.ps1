function Send-MirthDeployChannels {      
    <#
    .SYNOPSIS
        Sends mirth a signal to deploy selected channels.
        (note "Deploy" is approved in v6)

    .DESCRIPTION
        Deploys one or more channels on the target server.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -channelIds    a list of channel ids to be deployed, all if omitted.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        204 if successful, 500 if any of the channels fail to deploy

    .EXAMPLE
        
    .LINK

    .NOTES
        When the returnErrors switch is set, if any of the channels fail to deploy an 
        exception is thrown.  The response from the server *should* contain an xml 
        donkey DeployException that would tell us what channels failed and what the 
        error is, but I have been unable to obtain this response.  All the code sees
        is a ConnectionClosed error.

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the channels to undeploy, empty for all
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetIds,

        # If true, an error response code and exception will be returned.
        [Parameter()]
        [switch]$returnErrors,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Send-MirthDeployChannels Beginning"
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$payloadXML = "<set></set>"
        if ($targetIds.count -gt 0) { 
            # they provided some channel ids
            Write-Debug "Attempting to deploy $($targetIds.count) channels"
            Add-PSMirthStringNodes -parentNode $($payloadXML.SelectSingleNode("/set")) -values $targetIds | Out-Null
            Write-Debug "Payload generated: $($payloadXML.OuterXml)"
        }

        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("accept", "application/xml")
        $headers.Add("Content-Type", "application/xml")

        $uri = $serverUrl + '/api/channels/_deploy'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('returnErrors', $returnErrors)
        $uri = $uri + '?' + $parameters.toString()

        Write-Debug "POST to Mirth $uri "
        try { 
            $r = Invoke-RestMethod -UseBasicParsing -Uri $uri -WebSession $session -Headers $headers -Method POST -Body $payloadXML.OuterXml

            if ($saveXML) { 
                Save-Content $r $outFile
            }
            Write-Verbose "Deployed: $r"
            return $true
        }
        catch {
            $_.response
            $errorMessage = $_.Exception.Message
            if (Get-Member -InputObject $_.Exception -Name 'Response') {
                try {
                    $result = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($result)
                    $reader.BaseStream.Position = 0
                    $reader.DiscardBufferedData()
                    $responseBody = $reader.ReadToEnd();
                }
                catch {
                    Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage. Cannot get more information."
                }
            }
            Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage  Response body: $responseBody"
        }

    }
    END { 
        Write-Debug "Send-MirthDeployChannels Ending"

    }
}  # Send-MirthDeployChannels