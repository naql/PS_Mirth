function Set-MirthCodeTemplateLibraries {
    <#
    .SYNOPSIS
        Replaces all code template libraries.

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        $payLoad 
        String containing the XML describing a list of code template library 
        xml objects, e.g.,

    .OUTPUTS

    .EXAMPLE
        #  The following command removes all code template libraries.
        Connect-Mirth | Update-MirthCodeTemplateLibraries -payLoad '<list></list>' -override  
        

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
        [string]$payLoad,

        # path to the file containing the channel xml to import
        [Parameter(ParameterSetName = "pathProvided",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$payloadFilePath,

        # If true, the code template library will be updated even if a different revision 
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
        Write-Debug "Set-MirthCodeTemplateLibraries Beginning"
    }
    PROCESS {
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$payLoadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A codetemplate library list XML payLoad string is required!"
                return $null
            }
            else {
                Write-Debug "Loading codetemplate library XML from path $payLoadFilePath"
                [xml]$payLoadXML = Get-Content $payLoadFilePath  
            }
        }
        else {
            Write-Debug "Creating XML payload from string: $payLoad"
            $payLoadXML = [xml]$payLoad
        }

        $codeTemplateNodes = $payLoadXML.SelectNodes(".//codeTemplates/codeTemplate")
        if ($codeTemplateNodes.Count -gt 0) { 
            Write-Debug "There are $($codeTemplateNodes.Count ) codeTemplate nodes to process..."
            foreach ($codeTemplate in $codeTemplateNodes) { 
                $r = Set-MirthCodeTemplate -connection $connection -payLoad $codeTemplate.OuterXml -override
                Write-Debug "Set-MirthCodeTemplate $($codeTemplate.id) response: $r.OuterXml"
            }
        }

        $uri = $serverUrl + '/api/codeTemplateLibraries'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('override', $override)
        $uri = $uri + '?' + $parameters.toString()
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Accept", "application/xml")
        $headers.Add("Content-Type", 'application/xml')
        Write-Debug "Invoking PUT Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -Method PUT -WebSession $session -Body $payLoadXML.OuterXml
            Write-Debug "...done."
            if ($saveXML) { 
                Save-Content $r $outFile
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
        }
        catch {
            Write-Error $_
        }  
    }
    END { 
        Write-Debug "Set-MirthCodeTemplateLibraries Ending"
    } 

}  # Set-MirthCodeTemplateLibraries
