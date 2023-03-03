function Set-PSConfig([hashtable]$Config) {
    foreach ($Key in $Config.Keys) {
        switch ($Key) {
            "DefaultHeaders" {
                $script:DEFAULT_HEADERS = $Config[$Key].Clone();
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