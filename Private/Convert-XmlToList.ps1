function Convert-XmlToList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]
        $Xml,
        [hashtable]
        $ConvertAsList = @{}
    )

    Write-Debug "Convert-XmlToList for $($Xml.LocalName)"

    $ChildProperty = $ConvertAsList[$Xml.LocalName]
    $Children = $Xml.$ChildProperty

    foreach ($Item in $Children) {
        #Write-Debug "Converting $($Item.LocalName)"
        if ($Item -is [System.Xml.XmlElement]) {
            Convert-XmlToHashtable $Item $ConvertAsList
        }
        else {
            #Write-Debug "Item is $($Item.GetType())"
            $Item
        }
    }
}