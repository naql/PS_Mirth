function ConvertFrom-Xml {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Data,
        [array]
        $ConvertAsList = @(),
        # first is element name, second is boolean whether its data value is simple content
        [hashtable]
        $ConvertAsMap = @{}
    )

    $splat = @{
        ConvertAsList = $ConvertAsList
        ConvertAsMap  = $ConvertAsMap
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

        <#enum MapParseType {
            None
            Regular
            Special
        }#>

        #$CurrentParseType = [MapParseType]::None
        <#
        $ConvertAsMap = $ConvertAsMap.Clone()
        #$ConvertAsMap.Add($Data.Name, $true)

        if ($Data.HasAttribute('class')) {
            switch ($Data.Attributes['class'].Value) {
                "map" {
                    Write-Debug "Found class='map' for $($Data.Name)"
                    $ConvertAsMap.Add($Data.Name, $true)
                }
                'java.util.Collections$UnmodifiableMap' {
                    Write-Debug "Found class='java.util.Collections/UnmodifiableMap' for $($Data.Name)"
                    # move down to the <m> element
                    $Data = $Data.m
                    $ConvertAsMap.Add($Data.Name, $true)
                }
                Default {}
            }
        }#>

        <#if($CurrentParseType -eq [MapParseType]::None -and $ConvertAsMap.Keys -contains $Data.LocalName) {
            $CurrentParseType = [MapParseType]::Regular
        }#>

        #check for class attribute with specific value
        if ($Data.HasAttribute('class') -and $Data.Attributes['class'].Value -eq 'java.util.Collections$UnmodifiableMap') {
            Write-Debug "Found class java.util.Collections/UnmodifiableMap"
            
            <#
            this type has the format:
            <content class="java.util.Collections$UnmodifiableMap">
                <m>
                    <entry>
                        <string>destinationSet</string>
                        <linked-hash-set>
                            <int>1</int>
                        </linked-hash-set>
                    </entry>
                </m>
            </content>

            so move down to the <m> element and add it to the local $ConvertAsMap marked as simple content
            #>
            $Data = $Data.m
            $ConvertAsMap = $ConvertAsMap.Clone()
            $ConvertAsMap.Add($Data.Name, $false)
        }

        #should we convert this element as a map?
        if ($ConvertAsMap.Keys -contains $Data.LocalName) {
            Write-Debug "Matched name '$($Data.LocalName)' within `$ConvertAsMap"

            #Determine the subelement to access
            $XmlProperty = Get-XmlProperties $Data
            #Write-Debug "Found `$XmlProperty=$XmlProperty"
            #access either the list or a single element via the property
            $SubElems = $Data.$XmlProperty
            #Write-Debug "`$SubElems=$($SubElems.Name)"
            if ($SubElems.Count -gt 1) {
                #Write-Debug "Count is greater than 1, so using the first element"
                $SubElem = $SubElems[0]
            }
            else {
                $SubElem = $SubElems
            }
            #Write-Debug "`$SubElem=$SubElem"

            if ($SubElem.ChildNodes.Count -gt 0) {
                Write-Debug "Continuing to process SubElement '$($SubElem.LocalName)' as a map as it contains entries"

                #pull the first child node's name as that's the key
                $MasterProperties = $SubElem.ChildNodes | Get-UsableChildNodeNames
                #Write-Debug "Found `$MasterProperties=$MasterProperties"
                $KeyProperty = $MasterProperties[0]
                $ValueProperty = $MasterProperties[1]

                #Write-Debug "`$KeyProperty=$KeyProperty, `$ValueProperty=$ValueProperty"

                $grouped = @{}
                #do we have two nodes with the same name?
                if ($KeyProperty -eq $ValueProperty) {
                    $SubElems | ForEach-Object {
                        $grouped[$_.$KeyProperty[0]] = $_.$KeyProperty[1]
                    }
                }
                else {
                    #group by the key property
                    $SubElems | ForEach-Object {
                        $grouped[$_.$KeyProperty] = $_.$ValueProperty
                    }
                }

                #$IsSimpleContent = $ConvertAsMap[$Data.LocalName] -eq $true

                #if not simple content
                if ($ConvertAsMap[$Data.LocalName] -eq $false) {
                    $grouped.Keys.Clone() | ForEach-Object {
                        $GroupKey = $_
                        $InnerData = $grouped[$GroupKey]
                        Write-Debug "Processing complex content `$GroupKey=$GroupKey, `$InnerData=$InnerData"
                        $grouped[$GroupKey] = ConvertFrom-Xml $InnerData @splat
                    }
                }

                <#$grouped.Keys.Clone() | ForEach-Object {
                    $GroupKey = $_
                    $InnerData = $grouped[$GroupKey]
                    Write-Debug "Processing `$GroupKey=$GroupKey, `$InnerData=$InnerData"
                    if ($IsSimpleContent) {
                        #$grouped[$GroupKey] = $InnerData.InnerText.Trim()
                        #$grouped[$GroupKey] = $InnerData.ChildNodes[0].InnerText
                        $InnerNodeName = $InnerData.ChildNodes | Get-UsableChildNodeNames
                        Write-Debug "Found `$InnerNodeName=$InnerNodeName"
                        $grouped[$GroupKey] = $InnerData.SelectSingleNode($InnerNodeName).InnerText
                    }
                    else {
                        $grouped[$GroupKey] = ConvertFrom-Xml $InnerData @splat
                    }
                }#>
                
                return $grouped
            }
        }
        
        #Should we convert this element as a list?
        if ($ConvertAsList -contains $Data.LocalName) {
            Write-Debug "Found element '$($Data.LocalName)' as list conversion"
            #Write-Debug "`$ConvertAsList=$($ConvertAsList.GetEnumerator())"

            #do this to avoid a null error given a childless node
            if ($Data.ChildNodes.Count -eq 0) {
                $ResultList = @{}
            }
            else {
                $ChildProperty = Get-XmlProperties $Data | Select-Object -First 1
                #$ChildProperty = $ConvertAsList[$Data.LocalName]
                #Write-Debug "`$ChildProperty=$ChildProperty"
                $Children = $Data.$ChildProperty
                #Write-Debug "Iterating $($Children.GetEnumerator())"

                [array]$ResultList = $Children | ForEach-Object { ConvertFrom-Xml $_ @splat }
                #Write-Debug "`$Data=$($Data.Name) has `$ResultList.GetType()=$($ResultList.GetType()) with Count=$($ResultList.Count)"
            }
            
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
        # we didn't match to treat as a list or a map, so just process the data as normal
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