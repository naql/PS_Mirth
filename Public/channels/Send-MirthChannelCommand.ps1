function Send-MirthChannelCommand { 
    <#
    .SYNOPSIS
        Sends a command to one or more channels, optionally requesting error information.

    .DESCRIPTION
        This function accepts a string from a valid set of commands:
        * start
        * stop
        * halt
        * pause
        * resume
        It then calls the appropriate endpoint on the target server to execute that 
        command against the list of channels specified by the list of targetId strings, 
        each representing a mirth channel id uniquely identifying a channel on the server.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        If -saveXML writes the list XML to Save-Send-MirthChannelCommand-Output.xml

    .EXAMPLE
        Send-MirthChannelCommand -connection $connection -command stop -targetIds fa2cdec1-3abc-4186-95e3-9576d53b20e1 -returnErrors 
        Send-MirthChannelCommand -command start -targetIds 014d299a-d972-4ae6-aa48-a2741f78390c,fa2cdec1-3abc-4186-95e3-9576d53b20e1 
        Send-MirthChannelCommand -command pause 
        Send-MirthChannelCommand -command resume -saveXML 
        
    .LINK
        Links to further documentation.

    .NOTES
        When the returnErrors switch is set, if any of the channels fail to halt an 
        exception is thrown.  

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The array of the channel ids to undeploy, empty for all
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetIds,

        # The command to send to the target channels
        [Parameter(Mandatory = $True)]
        [ValidateSet('pause', 'resume', 'start', 'stop', 'halt')]  
        [string]$command,

        # If true, an error response code and the exception will be returned.
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
        Write-Debug "Send-MirthChannelCommand -command $command Beginning"
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Content-Type", "application/x-www-form-urlencoded");
        $headers.Add("Accept", "application/xml")

        $uri = $serverUrl + "/api/channels/_$command"
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('returnErrors', $returnErrors)
        $uri = $uri + '?' + $parameters.toString()

        $payloadBody = "";
        if ($targetIds.count -eq 0) { 
            Write-Debug "No target channel ids specified..."
            # get all channel IDs here
            # later we will add ways to filter
            Write-Debug "Fetching ALL channel ids in target server..."
            #TODO refactor to use Get-MirthChannelIdAndNames and remove this original function
            $targetIds = Get-MirthChannelIds -connection $connection
            Write-Debug "There are $($targetIds.Count) channels as target of $command command."
        }
        if ($targetIds.count -gt 0) { 
            Write-Debug "Attempting to $command $($targetIds.count) channels"
            for ($i = 0; $i -lt $targetIds.count; $i++) {
                $channelId = $targetIds[$i]
                if ($i -gt 0) {
                    $payloadBody += '&'
                }
                $payloadBody += "channelId=$channelId"
            }
            Write-Debug "Payload generated: $payloadBody"
        }

        Write-Debug "POST to Mirth $uri "
        try { 
            Invoke-RestMethod -UseBasicParsing -Uri $uri -WebSession $session -Headers $headers -Method POST -Body $payloadBody
            if ($saveXML) { 
                Save-Content "Channel command: $command successful for targets: $payloadBody" $outFile
            }
            Write-Debug "Channel Command [$command]: SUCCESS"
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
        Write-Debug "Send-MirthChannelCommand Ending"
    }          
}  # Send-MirthChannelCommand