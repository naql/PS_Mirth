function Set-MirthChannelGroups { 
    <#
    .SYNOPSIS
        Adds or updates Mirth channel groups in bulk. 

    .DESCRIPTION
        Updates channel groups. 

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        This command expects input as an xml string.
        $payLoad is xml describing the channel groups to be uploaded:

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

        # array of string values containing channel group ids to remove
        # defaults to an empty array
        [Parameter()]
        [string[]]$removedChannelGroupIds = @(),      
        
        # If true, the code group will be updated even if a different revision 
        # exists on the server
        [Parameter()]
        [switch]$override,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )   
    BEGIN { 
        Write-Debug "Set-MirthChannelGroups Beginning"
    }
    PROCESS { 
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$payloadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A channel XML payLoad string is required!"
                return $null
            }
            else {
                Write-Debug "Loading channel XML from path $payLoadFilePath"
                [xml]$payloadXML = Get-Content $payLoadFilePath  
            }
        }
        else {
            $payloadXML = [xml]$payLoad
        }

        $msg = 'Importing channelGroup [' + $payloadXML.set.channelGroup.name + ']...'
        Write-Debug $msg

        [xml]$removeChannelGroupXml = "<set></set>";
        Add-PSMirthStringNodes -parentNode $($removeChannelGroupXml.SelectSingleNode("/set")) -values $removedChannelGroupIds | Out-Null

        Write-Debug "channel ids to be removed from group:"
        Write-Debug $removeChannelGroupXml.outerXml
        
        $uri = $serverUrl + '/api/channelgroups/_bulkUpdate'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('override', $override)
        $uri = $uri + '?' + $parameters.toString()
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Accept", "application/xml")  
        $headers.Add("Content-Type", "multipart/form-data; boundary=`"$boundary`"")

        Write-Debug "POST to Mirth $uri "

        $boundary = "--boundary--"
        $LF = "`n"
        $bodyLines = (
            "--$boundary",
            "Content-Disposition: form-data; name=`"channelGroups`"",
            "Content-Type: application/xml$LF",   
            $payloadXML.OuterXml,
            "$LF--$boundary",
            "Content-Disposition: form-data; name=`"removedChannelGroupIds`"",
            "Content-Type: application/xml$LF",  
            $removeChannelGroupXml.OuterXml,
            "--$boundary--$LF"
        ) -join $LF
        Write-Debug $bodyLines
        try {
            # Returns the response received from the server (we pass it on).
            #
            Invoke-RestMethod -WebSession $session -Uri $uri -Method Post -Headers $headers -TimeoutSec 20 -Body $bodyLines
        }
        catch [System.Net.WebException] {
            throw $_
        }
    } 
    END { 
        Write-Debug "Set-MirthChannelGroups Ending"
    }
}  #  Set-MirthChannelGroups
