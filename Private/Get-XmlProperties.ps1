function Get-XmlProperties {
    [CmdletBinding()]
    param (
        [System.Xml.XmlElement]
        $Xml,
        [switch]
        $IncludeAttributes
    )
    
    $Properties = $Xml | Get-Member -Type Properties | Select-Object -ExpandProperty Name
    #Write-Debug "`$IncludeAttributes=$IncludeAttributes"
    if ($IncludeAttributes) {
        $Properties
    }
    else {
        $attrs = $Xml.Attributes.Name
        #Write-Debug "`$attrs=$attrs"

        $Properties | where { $attrs -notcontains $_ }
    }
}
