function Convert-HashToXml {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Hash,
        [Parameter()]
        $Document
    )

    $Hash.Keys | Sort-Object | ForEach-Object {
        $Key = $_
        $Value = $Hash[$Key]
        if ($Value -is [hashtable]) {
            #Write-Debug "Converting hashtable $Key"
            $Value = Convert-HashToXml -Hash $Value
        }
        else {
            #Write-Debug "Converting $Key to string"
            $Value = $Value.ToString()
        }
        $Key = $Key.ToString()
        #Write-Debug "Adding $Key to XML"
        $NewElem = $Document.CreateElement($Key)
        $NewElem.InnerText = $Value
        $NewElem
    }
}