function NotifyChannelMapCacheUpdate {
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable]$channelMap = @{}
    )

    if ($script:ChannelAutocomplete -eq [ChannelAutocompleteMode]::Cache) {
        $script:CachedChannelMapForAutocompletion = $channelMap.Clone()
    }
}
