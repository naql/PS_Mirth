function Get-MirthChannelMaxMsgId { 
    <#
    .SYNOPSIS
        Gets the maximum message id for the channel, specified by id.

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        [long] the maximum message number

    .EXAMPLE
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection] $connection = $currentConnection,

        # The id of the chennel to interrogate, required
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]  $targetId,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch] $saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string] $outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )         
    BEGIN { 
        Write-Debug "Get-MirthChannelMaxMsgId Beginning"
    }
    PROCESS { 
        #GET /channels/{channelId}/messages/maxMessageId
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        $uri = $serverUrl + "/api/channels/$targetId/messages/maxMessageId"

        Write-Debug "Invoking GET Mirth  $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."

            if ($saveXML) { 
                Save-Content $r $outFile
            }
            Write-Verbose $r.innerXml
            return [long]$r.long
                
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
        Write-Debug "Get-MirthChannelMaxMsgId Ending"
    }
}  # Get-MirthChannelMaxMsgId
