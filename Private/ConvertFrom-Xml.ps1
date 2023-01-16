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
        #Write-Debug "Data is string"
        $Data
    }
    elseif ($Data -is [array]) {
        #Write-Debug "Data is array"
        $Result = foreach ($Item in $Data) {
            ConvertFrom-Xml $Item @splat
        }
        $Result
    }
    elseif ($Data -is [System.Xml.XmlElement]) {
        #Write-Debug "Data is XML"

        if ($MapNames.Count -gt 0 -and $Data.LocalName -eq 'map') {
            #Write-Debug "MAP AWARE MATCHED 'map' with non-empty `$MapNames"

            if ($Data.entry.Count -gt 0) {
                #find a valid map name
                $ValidMapName = $MapNames | where { $null -ne $Data.entry[0].SelectSingleNode($_) }

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
            #Write-Debug "Found element $($Data.LocalName) in conversion list"
            #Write-Debug "`$ConvertAsList=$($ConvertAsList.GetEnumerator())"
            
            $ChildProperty = $ConvertAsList[$Data.LocalName]
            #Write-Debug "`$ChildProperty=$ChildProperty"
            
            $Children = $Data.$ChildProperty
            #Write-Debug "Iterating $($Children.GetEnumerator())"

            $ResultList = foreach ($Item in $Children) {
                ConvertFrom-Xml $Item @splat
            }
            $ResultList
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
        Write-Error "Unknown type: $($Data.GetType())"
        $Data
    }
}