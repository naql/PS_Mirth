function Get-OutputFolder () { 
    param(
        [switch] $create
    )
    if ($create -and !(Test-Path $script:SavePath -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $script:SavePath
    }
    return $script:SavePath
}