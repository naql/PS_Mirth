function Convert-UnixTimeToDateTimeOffset {
    <#
    .SYNOPSIS
        Converts a Unix timestamp to a DateTimeOffset
    .DESCRIPTION
        Converts a Unix timestamp to a DateTimeOffset.
        Optionally, a timezone can be provided to convert the time to a specific timezone.
    .PARAMETER UnixTimeInMillis
        A numeric or string Unix timestamp in milliseconds
    .PARAMETER TimeZone
        The timezone to convert the time to. If not provided, the time will remain UTC.
    .EXAMPLE
        Convert-UnixTimeToDateTimeOffset "1673985402974" "America/Chicago"
    .EXAMPLE
        Convert-UnixTimeToDateTimeOffset $map.receivedDate.time $map.receivedDate.timezone -Verbose
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $UnixTimeInMillis,

        [Parameter()]
        [string]$TimeZone
    )

    $ParsedTime = [System.DateTimeOffset]::FromUnixTimeMilliseconds($UnixTimeInMillis)
    if ($PSBoundParameters.ContainsKey("TimeZone")) {
        $ParsedTimeZone = Get-TimeZone -Id $TimeZone
        $ParsedTime = $ParsedTime.AddHours($ParsedTimeZone.BaseUtcOffset.totalhours)
    }
    $ParsedTime
}