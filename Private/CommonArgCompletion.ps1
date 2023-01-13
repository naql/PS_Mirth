function CommonArgCompletion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Values,
        [Parameter(Mandatory)]
        $wordToComplete
    )

    $Values | Sort-Object | Where-Object {
        $_ -ilike "$wordToComplete*"
    } | ForEach-Object {
        #some names are multi-word, so wrap them in double-quotes for user convenience
        """$_"""
    }
}