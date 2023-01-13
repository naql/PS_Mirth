function Set-PSConfig([hashtable]$Config) {
    foreach ($Key in $Config.Keys) {
        switch ($Key) {
            "DefaultHeaders" {
                $script:DEFAULT_HEADERS = $Config[$Key].Clone();
            }
            "ChannelAutocomplete" {
                $Value = $Config[$Key] -as [ChannelAutocompleteMode]
                if ($null -eq $Value) {
                    Write-Warning "Invalid value for option '$Key', defaulting to None"
                    $Value = [ChannelAutocompleteMode]::None
                }
                $script:ChannelAutocomplete = $Value
            }
            "MirthConnection" {
                $script:currentConnection = $Config[$Key]
            }
            "OutputFolder" {
                Set-OutputFolder $Config[$Key]
            }
            "SkipCertificateCheck" {
                $script:PSDefaultParameterValues = @{"Invoke-RestMethod:SkipCertificateCheck" = $Config[$Key] }
            }
            Default { Write-Warning "Unknown option '$Key', ignoring" }
        }
    }
}