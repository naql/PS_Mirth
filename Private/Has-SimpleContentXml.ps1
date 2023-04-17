function Has-SimpleContentXml {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Node
    )

    $Children = $Node.ChildNodes | where { $_.NodeType -eq [System.Xml.XmlNodeType]::Element }
    Write-Debug "Children of $($Node.Name): $($Children.Count)"
    
    if ($Children.Count -eq 0) {
        Write-Debug "No children, returning true"
        $true
    }
    else {
        if ($Children.Count -eq 1 -and $Children -is [array]) {
            Write-Debug "One child that's an array, returning true"
        }
        else {
            $UniqueChildNames = $Children | Select-Object -ExpandProperty Name -Unique
            Write-Debug "Unique child names: $($UniqueChildNames.Count)"
            
            return ($Children.Count -ne $UniqueChildNames.Count)
        }
    }
}