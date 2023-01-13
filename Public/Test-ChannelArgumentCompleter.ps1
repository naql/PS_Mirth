function Test-ChannelArgumentCompleter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ArgumentCompleter({ ChannelIdArgumentCompleter @args })]
        $ChannelId,
        [Parameter(Mandatory)]
        [ArgumentCompleter({ ChannelNameArgumentCompleter @args })]
        $ChannelName
    )
    
    Write-Debug "Processing `$ChannelId=$ChannelId, `$ChannelName=$ChannelName"
}