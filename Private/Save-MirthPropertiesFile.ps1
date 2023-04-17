function Save-MirthPropertiesFile { 
    <#
    .SYNOPSIS
        Saves a property file containing the data from the Mirth XML Configuration Map
        passed in.  

    .DESCRIPTION
        By default the entries in the Mirth configuration map are sorted when output
        to the new properties file.  To suppress this use the -unsorted switch.

    .INPUTS
        $payLoad          - [xml] object containing the mirth xml configuration map

        <map>
            <entry>
                <string>ucp.db.url</string>
                <com.mirth.connect.util.ConfigurationProperty>
                <value>jdbc:oracle:thin:@sa-sandbox-db:1521:TMDSTMDG</value>
                <comment> The URL of the UCP  db.</comment>
                </com.mirth.connect.util.ConfigurationProperty>
            </entry>
            <entry>
                <string>ucp.pool.initial.size</string>
                <com.mirth.connect.util.ConfigurationProperty>
                <value>1</value>
                <comment> The initial size of the db connection pool.  (Defaults to 6 if not specified)</comment>
                </com.mirth.connect.util.ConfigurationProperty>
            </entry>
            [...]
        </map>

    .OUTPUTS
        Writes a properties file with the name assigned to the -outFile parameter.
        Outputs the text contents of the created property file to the pipeline on return.

    .EXAMPLE
        Connect-Mirth | Get-MirthConfigMap | Save-MirthPropertiesFile -outFile new.properties

    .LINK
        Links to further documentation.

    .NOTES
        TODO: Modify this to return text file stream and save to output folder only on -saveXML flag.
    #> 
    [CmdletBinding()] 
    PARAM (

        # xml document containing the mirth configuration map
        [Parameter(Mandatory = $True,
            ValueFromPipeline = $True)]
        [xml]$payLoad,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.properties',

        # A switch to suppress sorting of the created property file.
        [Parameter()]
        [switch]$unsorted
    ) 

    BEGIN { 
        Write-Debug "Save-MirthPropertiesFile Beginning"
    }
    PROCESS {
        if (($null -eq $payLoad ) -or ($payLoad -isnot [xml]) ) {
            Write-Error "payLoad is not XML document"
            return
        }

        $entries = $payLoad.map.entry;
        if ($unsorted) { 
            $outputEntries = $entries
        }
        else { 
            $outputEntries = $entries | Sort-Object { [string]$_.string }
        }
        [System.Collections.ArrayList]$Lines = @()
        foreach ($entry in $outputEntries) {
            #create a comment line
            $Lines += "#`t" + $entry.'com.mirth.connect.util.ConfigurationProperty'.comment
            $Lines += “{0,-40} {1,1} {2}” -f $entry.string, "=", $entry.'com.mirth.connect.util.ConfigurationProperty'.value
        }
        Save-Content $Lines $outFile
        # Return the properties as a hashtable
        ConvertFrom-StringData ($Lines | Out-String)
    }
    END { 
        Write-Debug "Save-MirthPropertiesFile Ending"
    }
}  # Save-MirthPropertiesFile