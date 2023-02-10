function Get-MirthCodeTemplates { 
    <#
   .SYNOPSIS
       Gets Mirth Code Templates, either the targetIds specified, or all.

   .DESCRIPTION
       Returns a list of one or more code template objects:

   .INPUTS
       A -session  WebRequestSession object is required. See Connect-Mirth.
       -targetIds if omitted, then all libraries are returned.  Otherwise, only the libraries with the 
       id values specified are returned.

   .OUTPUTS

   .EXAMPLE

   .NOTES

   #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The ids of the code templates to retrieve, empty for all
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetIds,

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
        Write-Debug "Get-MirthCodeTemplates Beginning"
    }
    PROCESS { 

        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }  
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
       
        $uri = $serverUrl + '/api/codeTemplates'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        #    $parameters.Add('includeCodeTemplates', $includeCodeTemplates)

        if ([string]::IsNullOrEmpty($targetId) -or [string]::IsNullOrWhiteSpace($targetId)) {
            Write-Debug "Fetching all code templates"
        }
        else {
            foreach ($target in $targetIds) {
                $parameters.Add('codeTemplateId', $target)
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
                ConvertFrom-Xml $r.DocumentElement -ConvertAsList @('list')
            }
        }
        catch {
            Write-Error $_
        }
    }
    END { 
        Write-Debug "Get-MirthCodeTemplates Ending"
    }
}  # Get-MirthCodeTemplates
