function Set-MirthServerSettings { 
    <#
    .SYNOPSIS
        Sets the Mirth server settings.

    .DESCRIPTION
        Returns an XML object the Mirth server settings.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        
        [xml] object describing the server settings:

    .OUTPUTS
        <boolean>true<boolean> if successful, otherwise false

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

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/server/settings'
        [xml]$payLoadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A configuration map XML payLoad string is required!"
                return $null
            }
            else {
                Write-Debug "Loading channel XML from path $payLoadFilePath"
                [xml]$payLoadXML = Get-Content $payLoadFilePath  
            }
        }
        else {
            Write-Debug "Creating XML payload from string: $payLoad"
            $payLoadXML = [xml]$payLoad
        }
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Accept", "application/xml")
        $headers.Add("Content-Type", "application/xml")

        Write-Debug "Invoking PUT Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -Method PUT -WebSession $session -Body $payLoadXML.OuterXml
            Write-Debug "...done."
            if ($saveXML) { 
                $Content = "Server Settings Updated Successfully: $payLoad"
                Save-Content $Content $outFile
            }
            Write-Verbose "$($r.OuterXml)"

            return $r
        }
        catch {
            Write-Error $_
        }  
    }
    END {
    }

}  #  Set-MirthServerSettings
