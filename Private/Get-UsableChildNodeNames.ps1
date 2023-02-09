function Get-UsableChildNodeNames {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Node
    )
    
    process {
        #there's a quirk where a node can contain a sub-node named "name",
        #and it overwrites the Name lookup, so use LocalName instead.
        $Node | Where-Object { $_.Name -ne '#whitespace' } | Select-Object -ExpandProperty LocalName
    }
}