function Get-MirthCodeTemplateLibraries { 
    <#
    .SYNOPSIS
        Gets Mirth Code Template Libraries, either the targetIds specified, or all.

    .DESCRIPTION
        Returns a list of one or more code template library objects:



    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all libraries are returned.  Otherwise, only the libraries with the 
        id values specified are returned.

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

        # The id of the code template library to retrieve, empty for all
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetId,

        # If true, full code templates will be included inside each library.
        [parameter()]
        [switch]$includeCodeTemplates,

        # If true, return the raw xml response instead of a convenient object[]
        [switch] $Raw,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )    
    BEGIN { 
        Write-Debug "Get-MirthCodeTemplateLibraries Beginning"
    }
    PROCESS { 

        # TBD:  if we always sorted the contextType when exporting channels, libraries, etc, 
        # this would eliminate them always cluttering up the diff reports in Perforce

        # try this logic to sort the delegate contextType elements:
        #  /list/codeTemplateLibrary/codeTemplates/codeTemplate/contextSet/delegate/contextType

        # [xml]$xml = @"
        # <company>
        #     <stuff>
        #     </stuff>
        #     <machines>
        #         <machine>
        #             <name>ca</name>
        #             <b>123</b>
        #             <c>123</c>
        #         </machine>
        #         <machine>
        #             <name>ad</name>
        #             <b>234</b>
        #             <c>234</c>
        #         </machine>
        #         <machine>
        #             <name>be</name>
        #             <b>345</b>
        #             <c>345</c>
        #         </machine>
        #     </machines>
        #     <otherstuff>
        #     </otherstuff>
        # </company>
        # "@
        # [System.Xml.XmlNode]$orig = $xml.Company.Machines
        # $orig.Machine | sort Name -Descending |
        #   foreach { [void]$xml.company.machines.PrependChild($_) }
        # $xml.company.machines.machine


        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }  
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
        
        $uri = $serverUrl + '/api/codeTemplateLibraries'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('includeCodeTemplates', $includeCodeTemplates)

        if ([string]::IsNullOrEmpty($targetId) -or [string]::IsNullOrWhiteSpace($targetId)) {
            Write-Debug "Fetching all code template libraries"
        }
        else {
            foreach ($target in $targetId) {
                $parameters.Add('libraryId', $target)
            }
        }
        $uri = $uri + '?' + $parameters.toString()
        Write-Debug "Invoking GET Mirth $uri "
        try {
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session 
            Write-Debug "...done."

            Write-Verbose "$($r.OuterXml)"
            
            if ($saveXML) {
                Save-Content $r $outFile
            }
            
            if ($Raw) {
                $r
            }
            else {
                ConvertFrom-Xml $r.DocumentElement -ConvertAsList @('list', 'disabledChannelIds', 'enabledChannelIds', 'codeTemplates')
            }
        }
        catch {
            Write-Error $_
        }
    }
    END { 
        Write-Debug "Get-MirthCodeTemplateLibraries Ending"
    }
}