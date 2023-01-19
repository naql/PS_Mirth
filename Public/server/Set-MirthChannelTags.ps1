function Set-MirthChannelTags { 
    <#
    .SYNOPSIS
        Adds or updates Mirth channel tags in bulk. 

    .DESCRIPTION
        Updates channel tags. 

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        This command expects input as an xml string or a path to a file containing the xml.
        $payLoad is xml describing the set of channel tags to be uploaded:

            <set>
                <channelTag>
                    <id>fcf80796-3547-4b6d-a06c-c62a379ea655</id>
                    <name>TEST</name>
                    <channelIds>
                        <string>de882379-b348-4855-9a84-4d83649aed08</string>
                    </channelIds>
                    <backgroundColor>
                        <red>255</red>
                        <green>0</green>
                        <blue>0</blue>
                        <alpha>255</alpha>
                    </backgroundColor>
                </channelTag>
                [...]]
                <channelTag>
                    <id>5a123c6b-aacd-4be5-8c21-a981ce94a95e</id>
                    <name>Red Tag</name>
                    <channelIds>
                        <string>014d299a-d972-4ae6-aa48-a2741f78390c</string>
                        <string>e0e315bc-e064-4a6c-bc60-e26c2b4846b7</string>
                    </channelIds>
                    <backgroundColor>
                        <red>255</red>
                        <green>0</green>
                        <blue>0</blue>
                        <alpha>255</alpha>
                    </backgroundColor>
                </channelTag>
            </set>        

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
        Write-Debug "Set-MirthChannelTags Beginning"
    }
    PROCESS { 
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$payloadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A channelTag set XML payLoad string is required!"
                return $null
            }
            else {
                Write-Debug "Loading channelTag XML from path $payLoadFilePath"
                [xml]$payloadXML = Get-Content $payLoadFilePath  
            }
        }
        else {
            $payloadXML = [xml]$payLoad
        }

        $msg = 'Importing channelTags [' + $payloadXML.set.channelTag.name + ']...'
        Write-Debug $msg
        
        $uri = $serverUrl + '/api/server/channelTags'
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
        Write-Debug "Set-MirthChannelTags Ending"
    }  
}  #  Set-MirthChannelTags