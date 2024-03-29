function Get-PSConfig {
    @{
        "DefaultHeaders"       = $script:DEFAULT_HEADERS.Clone()
        "MirthConnection"      = $script:currentConnection
        "OutputFolder"         = $script:SavePath
        "SkipCertificateCheck" = $script:PSDefaultParameterValues["Invoke-RestMethod:SkipCertificateCheck"]
    }
}