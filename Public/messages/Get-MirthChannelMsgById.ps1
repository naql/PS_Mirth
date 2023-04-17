function Get-MirthChannelMsgById { 
    <#
    .SYNOPSIS
        Gets a message id from a channel, specified by id.

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        [xml] representation of a channel message;  the message itself is in 

    .EXAMPLE
        Get-MirthChannelMsgById -channelId ffe2e62c-5dd8-435e-a877-987d3f6c3d09 -messageId 8

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
        [string]  $channelId,

        # The message id to retrieve from the channel
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [long]  $messageId,

        # If true, return the raw xml response instead of a convenient object[]
        [switch] $Raw,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch] $saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string] $outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )         
    BEGIN { 
        Write-Debug "Get-MirthChannelMsgById Beginning"
    }
    PROCESS { 
        #GET /channels/{channelId}/messages/{messageId}
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        $uri = $serverUrl + "/api/channels/$channelId/messages/$messageId"

        Write-Debug "Invoking GET Mirth  $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."

            #a non-match returns an empty string,
            #so safety check before printing XML content
            if ($r -is [System.Xml.XmlDocument]) {
                Write-Verbose $r.innerXml
            }

            if ($saveXML) { 
                Save-Content $r $outFile
            }
            
            if ($Raw) {
                $r
            }
            else {
                ConvertFrom-Xml $r.DocumentElement -ConvertAsMap @{'connectorMessages' = $false }
            }
        }
        catch {
            Write-Error $_
        }        
    }
    END { 
        Write-Debug "Get-MirthChannelMsgById Ending"
    }
}  # Get-MirthChannelMsgById