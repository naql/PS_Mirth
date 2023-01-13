function New-MirthConfigMapEntry {
    <#
    .SYNOPSIS
        Creates an XML object representing a Mirth configuration map entry.

    .DESCRIPTION

    .INPUTS
        $entryKey     - the property name
        $entryValue   - the property value
        $entryComment - comment describing the property or settings 

    .OUTPUTS
        [xml] object containing mirth configuration map entry 

    .EXAMPLE

    .LINK
        Links to further documentation.

    .NOTES
        
    #> 
    [CmdletBinding()] 
    PARAM (

        # the property key name
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$entryKey,
   
        # the property value
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$entryValue,
        
        # comment describing the property
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string]$entryComment = ""

    ) 
    BEGIN {
    }
    PROCESS {
        $entryXML = [xml]@"  
        <entry>
        <string>$entryKey</string>
            <com.mirth.connect.util.ConfigurationProperty>
                <value>$entryValue</value>
                <comment>$entryComment</comment>
            </com.mirth.connect.util.ConfigurationProperty>
        </entry>
"@
        return $entryXML
    }
    END {
    } 

}  # New-MirthConfigMapEntry