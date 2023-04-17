function Get-MirthSystemProperties { 
    <#
    .SYNOPSIS
        Gets the Mirth server java system properties, 
        and returns them as an XML object.

    .DESCRIPTION
        This command relies on a tool probe channel to obtain server-side
        information not normally available through the REST API.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        [xml] object representing the mirth.properties file in XML form.

        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd"[]>
        <properties>
        <comment>exported by probe channel</comment>
        <entry key="keystore.keypass">81uWxplDtB</entry>
        <entry key="password.minspecial">0</entry>
        [...]
        <entry key="http.host">0.0.0.0</entry>
        </properties>

    .EXAMPLE
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # If true, return the properties as a hashtable instead of an xml object for convenience
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
        Write-Debug "Get-MirthSystemProperties Beginning"
    }
    PROCESS { 

        # import the tool channel and deploy it
        Write-Debug "Invoking tool channel Probe_Java_System_Properties.xml"
        $toolPath = "./tools/Probe_Java_System_Properties.xml"
        [xml]$toolPayLoad = Invoke-PSMirthTool -connection $connection -toolPath $toolPath -saveXML:$saveXML
        if ($null -ne $toolPayLoad) {
            Write-Verbose $toolPayLoad.OuterXml
            if (-not $asHashtable) { 
                if ($saveXML) { 
                    Save-Content $toolPayLoad $outFile
                }
                return $toolPayLoad
            }
            else { 
                Write-Debug "Converting XML response to hashtable"
                $returnMap = @{};
                foreach ($entry in $toolPayLoad.properties.entry) { 
                    $key = $entry.Attributes[0].Value
                    $value = $entry.InnerText
                    Write-Debug ("Adding Key: $key with value: $value")
                    $returnMap[$key] = $value
                }
                if ($saveXML) {
                    [System.Collections.ArrayList]$Content = @()
                    $Content += "#  PS_Mirth fetched from $($connection.serverUrl) on $(Get-Date)"
                    $Content += $returnMap.GetEnumerator() | Sort-Object -Property name | ForEach-Object { "{0,-40} {1,1} {2}” -f $_.Key, "=", $_.Value }  
                    Save-Content $Content $outFile
                }
                return $returnMap
            }
        }
        else { 
            Throw "Mirth probe returned no results"
        }
    }
    END { 
        Write-Debug "Get-MirthSystemProperties Ending"
    }
} #  Get-MirthSystemProperties