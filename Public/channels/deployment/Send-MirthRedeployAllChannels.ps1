function Send-MirthRedeployAllChannels { 
    
    <#
    .SYNOPSIS
        Redeploys all mirth channels
        (note "Deploy" is approved in v6)

    .DESCRIPTION
        Redeploys all Mirth channels, optionally returning error response codes.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        If -saveXML writes the list XML to Save-Send-MirthRedeployAllChannels-Output.xml

    .EXAMPLE
        Send-MirthRedeployAllChannels -connection $connection -returnErrors
        
    .LINK
        Links to further documentation.

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
        Write-Debug "Send-MirthRedeployAllChannels Beginning"
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("accept", "application/xml")
        $headers.Add("Content-Type", "application/xml")

        $uri = $serverUrl + '/api/channels/_redeployAll'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('returnErrors', $returnErrors)
        $uri = $uri + '?' + $parameters.toString()

        Write-Debug "POST to Mirth $uri "
        try { 
            # using the returnErrors parameter set to true should cause channel deployment errors
            # to be returned, but I have been unable to access this.  That's why the attempt to use 
            # Invoke-WebRequest instead of Invoke-RestMethod and the weird error handling...  To be continued.
            #$r = Invoke-RestMethod -UseBasicParsing -Uri $uri -WebSession $session -Headers $headers -Method POST
            $r = Invoke-WebRequest -UseBasicParsing -Uri $uri -WebSession $session -Headers $headers -Method POST
            #Type of response object:Microsoft.PowerShell.Commands.WebResponseObject
            # Write-Debug "...done."
            # Write-Debug "Type of response object: $($r.getType())"
            # Write-Debug $r.BaseResponse
            # Write-Debug $r.StatusCode
            # Write-Debug $r.StatusDescription
            # Write-Debug $r.RawContent
            if ($saveXML) { 
                Save-Content $r.getType() $outFile
            }
            Write-Verbose "$r"
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
        Write-Debug "Send-MirthRedeployAllChannels Ending"
    }

}  # Send-MirthRedployAllChannels