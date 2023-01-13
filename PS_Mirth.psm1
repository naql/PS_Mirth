#Get public and private function definition files.
$Classes = @( Get-ChildItem -Path $PSScriptRoot\Classes\*.ps1 -Recurse -ErrorAction SilentlyContinue )
$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue )

#Dot source the files
Foreach ($import in @($Classes + $Public + $Private)) {
    Try {
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import class/function $($import.fullname): $_"
    }
}

# Here I might...
# Read in or create an initial config file and variable
# Export Public functions ($Public.BaseName) for WIP modules
# Set variables visible to the module and its functions only

#default function parameters
$PSDefaultParameterValues = @{
    "Invoke-RestMethod:SkipCertificateCheck" = $true
}

#default API headers
$script:DEFAULT_HEADERS = @{
    "X-Requested-With" = "PS_Mirth"
}

# Dynamically Scoped/Globals

# Set this to 'Continue' to display output from Write-Debug statements, 
# or to 'SilentylyContinue' to suppress them.
#$DebugPreference = 'SilentlyContinue'

# This is where the -saveXML flag will cause files to be saved.  It 
# defaults to a subfolder in the current location.
[string]$script:DEFAULT_OUTPUT_FOLDER = Join-Path $pwd "PS_Mirth_Output"
[string]$script:SavePath = $DEFAULT_OUTPUT_FOLDER

[MirthConnection]$script:currentConnection = $null;

#Option to enable autocompletions of ChannelIds and ChannelNames for specific Mirth functions.
#Valid values are of type ChannelAutocompleteMode.
$script:ChannelAutocomplete = [ChannelAutocompleteMode]::None
$script:CachedChannelMapForAutocompletion = @{}

# aliases
Set-Alias cm Connect-Mirth
New-Alias -Name tmfrw -Value Test-MirthFileReadWrite

Export-ModuleMember -Function $Public.Basename