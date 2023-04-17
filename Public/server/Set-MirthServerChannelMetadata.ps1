function Set-MirthServerChannelMetadata { 
    <#
    .SYNOPSIS
        Sets all server channel metadata from an XML payload string or file path.

    .DESCRIPTION
        Sends a map of channel id to metadata to the server to set all server channel metadata.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        This command expects input as an xml string or a path to a file containing the xml.
        $payLoad is xml describing the set of channel tags to be uploaded:

    .OUTPUTS

    .EXAMPLE

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of set of channelTags to be added
        [Parameter(ParameterSetName = "xmlProvided",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$payLoad,

        # path to file containing the xml for the payload
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
        Write-Debug "Set-MirthServerChannelMetadata Beginning"
    }
    PROCESS { 
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$payloadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A server channel metadata XML payLoad string is required!"
                return $null
            }
            else {
                Write-Debug "Loading server channel metadata from path $payLoadFilePath"
                [xml]$payloadXML = Get-Content $payLoadFilePath  
            }
        }
        else {
            $payloadXML = [xml]$payLoad
        }

        $uri = $serverUrl + '/api/server/channelMetadata'
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("accept", "application/xml")
        $headers.Add("Content-Type", "application/xml")

        Write-Debug "PUT to Mirth $uri "

        try {
            # Returns the response received from the server (we pass it on).
            #
            Invoke-RestMethod -WebSession $session -Uri $uri -Method PUT -Headers $headers -TimeoutSec 20 -Body $payloadXML.OuterXml
        }
        catch [System.Net.WebException] {
            throw $_
        }
    } 
    END { 
        Write-Debug "Set-MirthServerChannelMetadata Ending"
    }    
}  # Set-MirthServerChannelMetadata