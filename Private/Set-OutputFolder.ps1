function Set-OutputFolder( $path ) {
    <#
    .SYNOPSIS
        Call to explicitly set the output folder for the PS_Mirth scripts when using the 
        -saveXML switch.  If called with no value, resets back to the default.

    .DESCRIPTION
        Set the output folder to be used by the PS_Mirth module when a CmdLet is requested
        to save an asset.  The default is the sub-folder /PS_Mirth_Output in the working folder.

    .INPUTS
        The path to set the PS_Mirth module output folder to.  Does not need to exist, 
        but must be a valid path.

    .OUTPUTS
        Returns the path.
        The folder is NOT created and will be lazily created on first output by the module.

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    $path = $path.Trim()
    if ([string]::IsNullOrEmpty($path)) {
        Write-Debug "Empty path provided, reverting to default"
        $script:SavePath = $DEFAULT_OUTPUT_FOLDER
    }
    elseif (!(Test-Path -Path $path -IsValid)) {
        Write-Error ("The path specified is not valid: {0}" -f $path)
    }
    else {
        $script:SavePath = $path
        Write-Debug "Current PS_Mirth output folder is: $script:SavePath"
    }
}