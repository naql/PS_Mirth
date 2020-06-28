

Write-Host "Beginning PS_Mirth Test"
Write-Host "Importing Module"
Import-Module PS_Mirth -force
Write-Host "Establishing default Mirth connection to LOCALHOST"
$connection = Connect-Mirth -verbose 
Write-Host "Get-MirthServerAbout"
try {
    $serverAbout = Get-MirthServerAbout -connection $connection   #-verbose
} catch { 
    Write-Error $_
}

Write-Host "Get-MirthServerSettings"
try {
    $serverSettings = Get-MirthServerSettings -connection $connection   #-verbose
} catch { 
    Write-Error $_
}
Write-Host "Get-MirthServerVersion"
try {
    $serverVersion = Get-MirthServerVersion  -connection $connection 
} catch { 
    Write-Error $_
}
Write-Host "Get-MirthServerTime"
try {
    $serverTime = Get-MirthServerTime  -connection $connection -verbose
} catch { 
    Write-Error $_
}
Write-Host "Get-MirthConfigMap"
try { 
    $serverConfigMap = Get-MirthConfigMap -connection $connection     #-verbose
} catch { 
    Write-Error $_
}
Write-Host "Get-MirthGlobalScripts"
try {
    $serverGlobalScripts = Get-MirthGlobalScripts -connection $connection #-verbose
} catch { 
    Write-Error $_
}
Write-Host "Get-MirthServerChannelMetaData"
try {
    $serverChannelMetaData = Get-MirthServerChannelMetaData -connection $connection  # -verbose
} catch { 
    Write-Error $_
}
Write-Host "Get-MirthChannelStatuses"
try {
    $channelStatuses = Get-MirthChannelStatuses -connection $connection
} catch { 
    Write-Error $_
}
