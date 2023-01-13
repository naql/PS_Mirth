function Convert-XmlByClassAttribute {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]
        $Xml
    )

    #Write-Debug "InnerConvertXmlByClass for $($Xml.LocalName)"
    
    $ClassAttr = $Xml.GetAttribute('class')
    
    $returnMap = @{}
    if ($ClassAttr -eq 'linked-hash-map') {
        $PropNames = $Xml.entry | Get-Member -Type Property | Select-Object -ExpandProperty Name
        $KeyProp = $PropNames[0]
        $ValueProp = $PropNames[1]
        foreach ($Entry in $Xml.entry) {
            $returnMap.Add($Entry.$KeyProp, $Entry.$ValueProp)
        }
    }
    else {
        throw "No implementation for '$ClassAttr'"
    }
    $returnMap
}