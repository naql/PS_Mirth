function ConvertFrom-Xml {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Data,
        [hashtable]
        $ConvertAsList = @{},
        [array]
        $MapNames = @()
    )

    $splat = @{
        ConvertAsList = $ConvertAsList
        MapNames      = $MapNames
    }
    #$PSBoundParameters.Remove("Data")
    #Write-Debug "ConvertFrom-Xml with $Data, `@PSBoundParameters=$($PSBoundParameters.GetEnumerator())"

    
    if ($Data -is [string]) {
        #Write-Debug "ConvertFrom-Xml with string $Data"
        $Data
    }
    elseif ($Data -is [array]) {
        #Write-Debug "ConvertFrom-Xml with array $Data"
        [array]$Result = $Data | ForEach-Object { ConvertFrom-Xml $_ @splat }
        $Result
    }
    elseif ($Data -is [System.Xml.XmlElement]) {
        #Write-Debug "ConvertFrom-Xml with XML $($Data.Name)"

        if ($MapNames.Count -gt 0 -and $Data.LocalName -eq 'map') {
            Write-Debug "MAP AWARE MATCHED 'map' with non-empty `$MapNames"

            if ($Data.entry.Count -gt 0) {
                #find a valid map name
                $ValidMapName = $MapNames | Where-Object { $null -ne $Data.entry[0].SelectSingleNode($_) }

                if ($null -ne $ValidMapName -and $ValidMapName.Count -eq 1) {
                    #Write-Debug "Using `$ValidMapName=$ValidMapName"
                    $ReturnMap = @{}
                    foreach ($Entry in $Data.entry) {
                        $Key = $Entry.string
                        #Write-Debug "`$Key=$Key"
                        $ValueNode = $Entry.SelectSingleNode($ValidMapName)
                        $Value = $ValueNode.'#text'
                        if ($null -eq $Value) {
                            $Value = ConvertFrom-Xml $ValueNode @splat
                        }
                        #Write-Debug "`$Value=$Value"
                        $ReturnMap[$Key] = $Value
                    }

                    if ($ReturnMap.Count -ne 0) {
                        #Write-Debug "special mapping worked, returning"
                        return $ReturnMap
                    }
                }
                else {
                    Write-Debug "None of the names given match this map - OR - more than one does"
                }
            }
        }
        
        if ($ConvertAsList.Keys -contains $Data.LocalName) {
            Write-Debug "Found element '$($Data.LocalName)' in conversion list"
            #Write-Debug "`$ConvertAsList=$($ConvertAsList.GetEnumerator())"
            
            $ChildProperty = $ConvertAsList[$Data.LocalName]
            #Write-Debug "`$ChildProperty=$ChildProperty"
            
            $Children = $Data.$ChildProperty
            #Write-Debug "Iterating $($Children.GetEnumerator())"

            [array]$ResultList = $Children | ForEach-Object { ConvertFrom-Xml $_ @splat }
            #Write-Debug "`$Data=$($Data.Name) has `$ResultList.GetType()=$($ResultList.GetType()) with Count=$($ResultList.Count)"
            
            #This is such a stupid bug to deal with: a 1-item array returns
            # its first value from this function, not the array itself!
            #So you can't just have: $ResultList
            if ($ResultList.Count -eq 1) {
                , $ResultList
            }
            else {
                $ResultList
            }
        }
        else {
            $Properties = Get-XmlProperties $Data
            #Write-Debug "`$Properties=$Properties"
            $ReturnMap = @{}
            foreach ($Property in $Properties) {
                $ReturnMap[$Property] = ConvertFrom-Xml $Data.$Property @splat
            }
            $ReturnMap
        }
    }
    else {
        Write-Error "Unknown type: $($Data.GetType()), returning as-is"
        $Data
    }
}