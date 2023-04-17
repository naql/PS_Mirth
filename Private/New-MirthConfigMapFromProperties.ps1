function New-MirthConfigMapFromProperties { 
    <#
    .SYNOPSIS
        Create a new Mirth configurationMap XML object from either a hashtable passed in, or from a standard properties file
        in the file system.

    .DESCRIPTION

    .INPUTS
        $payLoad          - a [hashtable] of key/value pairs, or 
        $payLoadFilePath  - a fully qualified path to a standard properties file (with # comments preceding each property)

    .OUTPUTS
        [xml] object containing the xml mirthconfiguration map

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

    .EXAMPLE

    .LINK
        Links to further documentation.

    .NOTES
        This was created to provide input for the post to /api/extensions/ssl/all that I couldn't seem to get working.
    #> 
    [CmdletBinding()] 
    PARAM (

        # hashtable of property names and values, no comments
        [Parameter(ParameterSetName = "propertiesProvided",
            Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [hashtable]$payLoad,

        # path to file containing the properties file (including comments)
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
        Write-Debug "New-MirthConfigMapFromProperties Beginning"
    }
    PROCESS {
        [xml]$mapXML = [xml]"<map></map>"
        if (($payLoad -ne $null) -and ($payLoad -is [hashtable]) -and ($payLoad.Count -gt 0)) {
            Write-Debug "$msg = Properties hashtable provided in payLoad with $($payLoad.Count) entries"
            # Note:  We are losing comments here, because they are not represented in a vanilla hashtable
            foreach ($key in $payLoad.Keys) { 
                $newValue = $payLoad[$key]
                $entryXML = New-MirthConfigMapEntry -entryKey $key -entryValue $newValue -entryComment ""
                $mapXML.DocumentElement.AppendChild($mapXML.ImportNode($entryXML.entry, $true)) | Out-Null
            }
        }
        else { 
            # Verify the payLoadFilePath exists, load it
            if (Test-Path $payloadFilePath -PathType Leaf) {
                [string]$commentBuffer = ""
                Get-Content $payloadFilePath | ForEach-Object {
                    # comments are lines that begin with # character and must precede the property
                    # so, we will read building a comment string from any # lines, and create a 
                    # map entry when we encounter a property using whatever comment string has been 
                    # built so far, and then flushing it
                    [string]$line = $_
                    $line = $line.trim()
                    Write-Verbose "Read line: $_ "
                    [bool]$isComment = $line.StartsWith('#')
                    if ($isComment) {
                        #Write-Debug "Comment Found"
                        $commentBuffer += $line.substring(1)
                    }
                    else { 
                        # it should be a property
                        Write-Debug "Property Found"
                        $propLine = $line.Split('=')
                        $keyName = $propLine[0].trim()
                        $value = $propLine[1].trim()
                        Write-Debug "Key:     $keyName"
                        Write-Debug "Value:   $value"
                        Write-Debug "Comment: $commentBuffer"
                        $entryXML = New-MirthConfigMapEntry -entryKey $keyName -entryValue $value -entryComment $commentBuffer
                        $mapXML.DocumentElement.AppendChild($mapXML.ImportNode($entryXML.entry, $true)) | Out-Null

                        $commentBuffer = ''
                    }
                }
            }
            else { 
                $msg = "The properties file path provided was invalid: " + $payloadFilePath
                Write-Error $msg
                return
            }
        }
        if ($saveXML) {
            Save-Content $mapXML $outFile
        }
        Write-Verbose $mapXML.OuterXml
        return $mapXML
        <# Output a custom object with both $rValue and the server address
        return [pscustomobject] @{
            payLoad = $mapXML
        }#>
    }
    END { 
        Write-Debug "New-MirthConfigMapFromProperties Ending"
    }

}  # New-MirthConfigMapFromProperties