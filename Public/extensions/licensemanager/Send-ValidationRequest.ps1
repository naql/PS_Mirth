function Send-ValidationRequest {
    <#
    .SYNOPSIS
        Sends a validation request to the Connect License Server.
    .DESCRIPTION
        Sends a validation request to the Connect License Server and returns its JSON response.
    .LINK
        https://validate.connectlicenseserver.com/
    .LINK
        https://www.connectlicenseserver.com/v1/validateoffline
    #>
    [CmdletBinding()]
    param (
        # Connect's license key
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LicenseKey,
        # validation request generated from Get-MirthLicenseManagerValidationRequest
        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ValidationRequest,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.json"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.json'
    )

    #submission to https://validate.connectlicenseserver.com/
    #uses https://www.connectlicenseserver.com/v1/validateoffline
    $uri = 'https://www.connectlicenseserver.com/v1/validateoffline'

    Write-Debug "Invoking POST Mirth $uri "

    $headers = $DEFAULT_HEADERS.clone()
    #I haven't testing the removal of any of these headers which were present in the POST request from my browser
    $headers.Add('accept', '*/*')
    $headers.Add('Content-Type', 'application/json')
    $headers.Add('origin', 'https://validate.connectlicenseserver.com')
    $headers.Add('referer', 'https://validate.connectlicenseserver.com')

    $payloadJson = @{
        'key'               = $LicenseKey
        'validationRequest' = $ValidationRequest
    } | ConvertTo-Json

    try { 
        $r = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -WebSession $session -Body $payloadJson

        #expect JSON and 200 status
        <#
        "text": "{\"activated\":true,\"availableActivations\":null,\"validationResponse\":\"eyJREDACTEDJ9\"}"
        #>

        if ($saveXML) {
            Save-Content $r $outFile
        }

        Write-Debug "...done."

        return $r
    }
    catch {
        Write-Error $_
    }
}