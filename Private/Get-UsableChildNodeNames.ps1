function Get-UsableChildNodeNames {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Node
    )
    
    process {
        $Node | Where-Object { $_.Name -ne '#whitespace' } | Select-Object -ExpandProperty Name
    }
}