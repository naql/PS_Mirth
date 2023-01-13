function Convert-XmlMapToHashtable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]
        $Xml,
        [string]
        $OuterListName,
        [string]
        $InnerListName
    )

    Write-Debug "Convert-XmlMapToHashtable for '$($Xml.LocalName)' with `$OuterListName=$OuterListName' and `$InnerListName=$InnerListName"

    $channelIdsAndNames = @{}
    #results are ordered ID then name
    foreach ($Child in $Xml.$OuterListName) {
        #Write-Debug "Processing child $($Child.LocalName)"
        $Values = $Child.$InnerListName
        #Write-Debug "Pulled `$Values=$Values"
        $channelIdsAndNames.Add($Values[0], $Values[1])
    }
    $channelIdsAndNames
}