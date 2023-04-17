function Import-MirthChannel { 
    <#
    .SYNOPSIS
        Imports a Mirth channel.

    .DESCRIPTION
        This function creates a new channel from the channel XML provided.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        $payLoad is a user XML object describing the channel to be added:



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

        # xml of the channel to be added
        [Parameter(ParameterSetName = "xmlProvided",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [xml]$payLoad,

        # path to the file containing the channel xml to import
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
        Write-Debug "Import-MirthChannel Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$channelXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A channel XML payLoad string is required!"
                return $null
            }
            else {
                Write-Debug "Loading channel XML from path $payLoadFilePath"
                [xml]$channelXML = Get-Content $payLoadFilePath
            }
        }
        else {
            Write-Debug "Import channel payload delivered via string parameter"
            $channelXML = $payLoad
        }

        Write-Debug ('Importing channel [' + $channelXML.channel.name + ']...')

        $uri = $serverUrl + '/api/channels'
        Write-Debug "POST to Mirth $uri "
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("accept", 'text/plain')
        $headers.Add("Content-Type", 'application/xml')
        try {
            $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method POST -Headers $headers -Body $channelXML.OuterXml
            Write-Debug "...done."

            if ($saveXML) { 
                Save-Content $r $outFile
            }
            # response is a plaintext string, XML was not an option
            Write-Verbose $r
            return $r

        }
        catch {
            Write-Error $_
        }

    } 
    END {
        Write-Debug "Import-MirthChannel Ending"
    }

}  # Import-MirthChannel