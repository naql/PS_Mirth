function Get-MirthServerAbout { 

    <#
    .SYNOPSIS
        Get an xml object summarizing mirth about properties.

    .DESCRIPTION
        Fetches an XML object that summarizes the Mirth server, the name, version, type of database, 
        number of channels, connectors and plugins installed.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        If the -asHashtable switch is set, a Powershell hashtable of the properties and values
        is returned.  Otherwise, it returns an XML object describing server properties.  
        This XML has the form:

        <map>
          <entry>
            <string>date</string>
            <string>November 16, 2018</string>
          </entry>
          <entry>
            <string>channelCount</string>
            <int>3</int>
          </entry>
          <entry>
            <string>database</string>
            <string>derby</string>
          </entry>
          <entry>
            <string>connectors</string>
            <map>
              <entry>
                <string>SMTP Sender</string>
                <string>3.6.2</string>
              </entry>
              <entry>
                <string>File Writer</string>
                <string>3.6.2</string>
              </entry>
                [...]
              <entry>
                <string>DICOM Sender</string>
                <string>3.6.2</string>
              </entry>
            </map>
          </entry>
          <entry>
            <string>plugins</string>
            <map>
              <entry>
                <string>Server Log</string>
                <string>3.6.2</string>
              </entry>
              <entry>
                <string>Text Viewer</string>
                <string>3.6.2</string>
              </entry>
                [...]
              <entry>
                <string>XSLT Transformer Step</string>
                <string>3.6.2</string>
              </entry>
            </map>
          </entry>
          <entry>
            <string>name</string>
            <string>LOCAL-TEST-MIRTH</string>
          </entry>
          <entry>
            <string>version</string>
            <string>3.6.2</string>
          </entry>
        </map>


    .EXAMPLE
        Connect-Mirth | Get-MirthServerAbout 

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # If true, return the about properties in a hashtable instead of xml object.
        [Parameter()]
        [switch]$asHashtable, 

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Get-MirthServerAbout Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
 
        $uri = $serverUrl + '/api/server/about'
        Write-Debug "Invoking GET Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session 
            Write-Debug "...done."

            if ($saveXML) {
                Save-Content $r $outFile
            }
            Write-Verbose "$($r.OuterXml)"
            if ($asHashtable) { 
                $returnMap = @{}

                foreach ($element in $r.map.entry) {
                    $String = @($element.string)
                    #Write-Debug ("Processing {0}" -f $String[0])

                    $PropNames = $element | Get-Member -Type Property | Select-Object -ExpandProperty Name

                    if ($String.Count -eq 2) {
                        #Write-Debug ("Found two strings: '{0}' and '{1}'" -f $String[0], $String[1])
                        $returnMap.Add($String[0], $String[1])
                    }
                    elseif ($PropNames -contains "int") {
                        #Write-Debug "Found int"
                        $returnMap.Add($String[0], $element.int)
                    }
                    elseif ($PropNames -contains "map") {
                        #Write-Debug "Found map"
                        $innerMap = @{}

                        foreach ($innerItem in $element.map.entry) {
                            $InnerString = $innerItem.string
                            #Write-Debug ("InnerString two strings: '{0}' and '{1}'" -f $InnerString[0], $InnerString[1])
                            $innerMap.Add($InnerString[0].Trim(), $InnerString[1].Trim())
                        }

                        $returnMap.Add($String[0], $innerMap)
                    }
                    else {
                        Write-Debug "Found unknown with properties: $PropNames, adding empty entry"
                        $returnMap.Add($String[0], "")
                    }
                }
                return $returnMap
            }
            else { 
                return $r
            }
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug "Get-MirthServerAbout Ending"
    }
}  # Get-MirthServerAbout