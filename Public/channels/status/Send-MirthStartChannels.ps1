function Send-MirthStartChannels { 
    <#
    .SYNOPSIS
        Starts a list of channels.

    .DESCRIPTION
        Sends a START signal to one or more channels, optionally requesting error information.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        If -saveXML writes the list XML to Save-Send-MirthStartChannels-Output.xml

    .EXAMPLE
        Send-MirthStartChannels -connection $connection -returnErrors -targetIds fa2cdec1-3abc-4186-95e3-9576d53b20e1
        Send-MirthStartChannels -targetIds 014d299a-d972-4ae6-aa48-a2741f78390c,fa2cdec1-3abc-4186-95e3-9576d53b20e1   
        
    .LINK
        Links to further documentation.

    .NOTES
        When the returnErrors switch is set, if any of the channels fail to start, an exception is thrown.  

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The array of the channel ids to undeploy, empty for all
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetIds,

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
        Write-Debug "Send-MirthStartChannels Beginning"
    }
    PROCESS { 

        return Send-MirthChannelCommand -connection $connection -targetIds $targetIds -command 'start' -returnErrors:$returnErrors -saveXML:$saveXML -outFile $outFile

    }
    END { 
        Write-Debug "Send-MirthStartChannels Ending"
    }          
}  # Send-MirthStartChannels