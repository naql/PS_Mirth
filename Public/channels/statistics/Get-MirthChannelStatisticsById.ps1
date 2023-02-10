function Get-MirthChannelStatisticsById { 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection] $connection = $currentConnection,

        # The id of the chennel to interrogate, required
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $True, Position = 0)]
        [string]$ChannelId,

        # If true, return the raw xml response instead of a hashtable
        [switch] $Raw,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch] $saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string] $outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )         
    BEGIN { 
        Write-Debug "Get-MirthChannelStatisticsById Beginning"
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        $uri = $serverUrl + "/api/channels/$ChannelId/statistics"

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
                ConvertFrom-Xml $r.DocumentElement
            }
        }
        catch {
            Write-Error $_
        }        
    }
    END { 
        Write-Debug "Get-MirthChannelStatisticsById Ending"
    }
}