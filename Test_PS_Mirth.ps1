using namespace System.Management.Automation
#################################################################################################################################
#  deployMirth.ps1
#################################################################################################################################
param (
    [string]    $deployPath = "$pwd/deploy",  
    [string]    $server = 'localhost',  
    [string]    $port = '8443',
    [string]    $username = 'admin', 
    [securestring]    $password = (ConvertTo-SecureString -String 'admin' -AsPlainText),
    [switch]    $saveTranscript,
    [switch]    $verbose
)
$InformationPreference = 'Continue'
if ($verbose) { 
    $VerbosePreference = 'Continue'
}

Function Write-InformationColored {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object]$MessageData,
        [ConsoleColor]$ForegroundColor = $Host.UI.RawUI.ForegroundColor, # Make sure we use the current colours by default
        [ConsoleColor]$BackgroundColor = $Host.UI.RawUI.BackgroundColor,
        [Switch]$NoNewline
    )

    $msg = [HostInformationMessage]@{
        Message         = $MessageData
        ForegroundColor = $ForegroundColor
        BackgroundColor = $BackgroundColor
        NoNewline       = $NoNewline.IsPresent
    }

    Write-Information $msg
}

#######################################################################################################################################
Write-InformationColored -MessageData "Beginning PS_Mirth Test" -ForegroundColor Black -BackgroundColor DarkGreen 
Write-Verbose "Importing Module"
#Import-Module PS_Mirth -force
".\PS_Mirth.psd1" | Get-ChildItem | Import-Module -Force
$Version_PS_Mirth = (Get-Module -Name "PS_Mirth").Version
Write-InformationColored -MessageData "PS_Mirth Version: " -NoNewline
Write-InformationColored -MessageData "$($Version_PS_Mirth.Major).$($Version_PS_Mirth.Minor).$($Version_PS_Mirth.Build)"  -ForegroundColor Green   -BackgroundColor Black

$serverUrl = "https://" + $server + ":" + $port
Write-InformationColored -MessageData "Establishing Mirth connection to  " -ForegroundColor White -BackgroundColor Black -NoNewline
Write-InformationColored -MessageData $serverUrl  -ForegroundColor Green   -BackgroundColor Black 
$connection = Connect-Mirth -serverUrl $serverUrl -userName $username -userPass $password
if ($null -eq $connection) { 
    Write-InformationColored -MessageData "A connection to a running Mirth Server is required!"  -ForegroundColor Red   -BackgroundColor Black
    Write-InformationColored -MessageData "Unable to connect to server at $serverUrl" -ForegroundColor Red   -BackgroundColor Black
    Write-InformationColored -MessageData "Start or install a Mirth Connect service, or run the test script with -server -port -user -password options set correctly.`r`n"
    Exit
}

Write-InformationColored ""
Write-InformationColored -MessageData "Get-MirthChannelGroups " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $channelGroups = Get-MirthChannelGroups -connection $connection
    if ($null -ne $channelGroups) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$($channelGroups.OuterXml)"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}


Write-InformationColored ""
Write-InformationColored -MessageData "Get-MirthServerChannelMetadata " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $channelMetadata = Get-MirthServerChannelMetadata -connection $connection
    if ($null -ne $channelMetadata) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$($channelMetadata.OuterXml)"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}


Write-InformationColored -MessageData "Get-MirthChannels " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $channels = Get-MirthChannels -connection $connection
    if ($null -ne $channels) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$($channels.OuterXml)"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthChannelTags " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $channels = Get-MirthChannelTags -connection $connection
    if ($null -ne $channels) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthCodeTemplateLibraries " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $libraries = Get-MirthCodeTemplateLibraries -connection $connection
    if ($null -ne $libraries) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthConfigMap " -ForegroundColor White -BackgroundColor Black -NoNewline
try { 
    $serverConfigMap = Get-MirthConfigMap -connection $connection  
    if ($null -ne $serverConfigMap) {
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$($serverConfigMap.OuterXml)"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black  
    }
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthExtensionProperties " -ForegroundColor White -BackgroundColor Black -NoNewline
try { 
    $sslProperties = Get-MirthExtensionProperties -connection $connection  -targetId "SSL Manager"  -decode
    if ($null -ne $sslProperties) {
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$($sslProperties.OuterXml)"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black  
    }
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthGlobalScripts " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $serverGlobalScripts = Get-MirthGlobalScripts -connection $connection 
    if ($null -ne $serverGlobalScripts) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$($serverGlobalScripts.OuterXml)"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch {
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthKeyStoreBytes " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $keystoreBytes = Get-MirthKeyStoreBytes -connection $connection 
    if ($null -ne $keystoreBytes) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$($keystoreBytes.OuterXml)"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch {
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthKeyStoreCertificates " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $keystoreCerts = Get-MirthKeyStoreCertificates -connection $connection 
    if ($null -ne $keystoreCerts) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$($keystoreCerts.OuterXml)"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch {
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthLoggedUsers " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $loggedUsers = Get-MirthLoggedInUsers -connection $connection 
    if ($null -ne $loggedUsers) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$($loggedUsers.OuterXml)"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch {
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthServerAbout " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $serverAbout = Get-MirthServerAbout -connection $connection  
    if ($null -ne $serverAbout) {
        Write-Verbose "$($serverAbout.OuterXml)"
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
    }
    else { 
        Write-Verbose "serverAbout response is null!"
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch {
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black 
}

Write-InformationColored -MessageData "Get-MirthServerChannelMetaData " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $serverChannelMetaData = Get-MirthServerChannelMetaData -connection $connection 
    if ($null -ne $serverChannelMetaData) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$($serverChannelMetaData.OuterXml)"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthServerConfig " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $serverConfig = Get-MirthServerConfig  -connection $connection
    if ($null -ne $serverConfig) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$($serverConfig.OuterXml)"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthServerProperties " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $serverProperties = Get-MirthServerProperties  -connection $connection -asHashtable
    if ($null -ne $serverProperties) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$serverProperties"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthServerSettings " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $serverSettings = Get-MirthServerSettings -connection $connection 
    if ($null -ne $serverSettings) {
        Write-Verbose "$($serverSettings.OuterXml)"
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
    }
    else { 
        Write-Verbose "serverSettings response is null!"
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }  
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthServerTime " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $serverTime = Get-MirthServerTime  -connection $connection
    if ($null -ne $serverTime) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
        Write-Verbose "$($serverTime.OuterXml)"
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthServerVersion " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $serverVersion = Get-MirthServerVersion  -connection $connection 
    if ($null -ne $serverVersion) {
        Write-Verbose $serverVersion
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
    }
    else { 
        Write-Verbose "serverVersion response is null!"
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }  
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthUsers " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $mirthUsers = Get-MirthUsers  -connection $connection 
    if ($null -ne $mirthUsers) {
        Write-Verbose $mirthUsers
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
    }
    else { 
        Write-Verbose "$mirthUsers"
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }  
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}

Write-InformationColored -MessageData "Get-MirthChannelStatuses " -ForegroundColor White -BackgroundColor Black -NoNewline
try {
    $channelStatuses = Get-MirthChannelStatuses -connection $connection
    if ($null -ne $channelStatuses) { 
        Write-InformationColored -MessageData "OK" -ForegroundColor Green -BackgroundColor Black
    }
    else { 
        Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
    }
}
catch { 
    Write-Error $_
    Write-InformationColored -MessageData "FAIL" -ForegroundColor Red -BackgroundColor Black
}


Write-InformationColored ""
Write-InformationColored -MessageData "Ending PS_Mirth Test" -ForegroundColor Black -BackgroundColor DarkGreen 
Write-Verbose "end test script"