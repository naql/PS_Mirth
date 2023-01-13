function Convert-XmlToHashtable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]
        $Xml,
        [hashtable]
        $ConvertAsList = @{}
    )

    Write-Debug "Convert-XmlToHashtable for $($Xml.LocalName)"

    if ($ConvertAsList.Keys -contains $Xml.LocalName) {
        Write-Debug "Found element in conversion list"

        Convert-XmlToList $Xml -ConvertAsList $ConvertAsList
    }
    else {
        $returnMap = @{}
        $PropNames = $Xml | Get-Member -Type Property | Select-Object -ExpandProperty Name
        foreach ($PropName in $PropNames) {
            $Value = $Xml.$PropName
            if ($Value -is [System.Xml.XmlElement]) {
                if ($Value.HasAttribute('class')) {
                    $returnMap[$PropName] = Convert-XmlByClassAttribute $Value
                }
                else {
                    $returnMap[$PropName] = Convert-XmlToHashtable $Value $ConvertAsList
                }
            }
            else {
                $returnMap[$PropName] = $Value
            }
        }
        $returnMap
    }
}