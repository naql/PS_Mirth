function New-MirthSSLMgrPropertiesPayload { 
    <#
    .SYNOPSIS
        Given public and private PEM certificates from the pipeline, or from a file location, 
        generate an xml object that contains a com.mirth.connect.plugins.ssl.model.KeyStoreCertificates

    .DESCRIPTION

    .INPUTS

    .OUTPUTS
        A com.mirth.connect.plugins.ssl.model.KeyStoreCertificates XML object that contains the
        certificate pems and aliases as passed in.  This can then be passed to the Restore Keystore
        operation.

    .EXAMPLE
        Create-DefaultKeyStore -privCertPemPath .\templates\default-private-cert.pem -pubCertPemPath .\templates\default-public-cert.pem -saveXML

    .LINK
        Links to further documentation.

    .NOTES
        This was created to provide input for the post to /api/extensions/ssl/all that I couldn't seem to get working.
    #> 
    [CmdletBinding()] 
    PARAM (

        # The base64 encoded JKS keystore.
        [Parameter(ValueFromPipeline = $True)]
        [string]$keyStore = $null,
        
        # The path to the JKS keystore file
        [Parameter()]
        [string]$keyStorePath,

        # The base64 encoded JKS truststore.
        [Parameter(ValueFromPipeline = $True)]
        [string]$trustStore = $null,

        # The path to the text file containing the private PEM
        [Parameter()]
        [string]$trustStorePath,

        # The password to the keystore and truststore JKS files.
        [Parameter()]
        [string]$keyStorePass = "changeit",
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN {
        Write-Debug "New-MirthSSLMgrPropertiesPayload Beginning..."
    }
    PROCESS {

        if ([string]::IsNullOrEmpty($trustStore)) {
            if (Test-Path $trustStorePath -PathType Leaf) { 
                Write-Debug "Loading TrustStore from path $trustStorePath"
                $trustStore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($trustStorePath))
                #$trustStore = Get-Content $trustStorePath -Raw
            }
            else { 
                Write-Error "No TrustStore JKS provided and path " $trustStorePath " does not exist!"
                return;
            }
        }
        if ([string]::IsNullOrEmpty($keyStore)) {
            if (Test-Path $keyStorePath -PathType Leaf) { 
                Write-Debug "Loading KeyStore from path $keyStorePath"
                $keyStore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keyStorePath))
            }
            else { 
                Write-Error "No KeyStore JKS provided and path " $keyStorePath " does not exist!"
                return;
            }
        }

        $templateXML = 
        [xml]@"
<properties>
  <property name="KeyStore">$keyStore</property>
  <property name="KeyStorePassword">$keyStorePass</property>
  <property name="TrustStore">$trustStore</property>
  <property name="settings">&lt;com.mirth.connect.plugins.ssl.model.SSLManagerSettings&gt;
  &lt;validationLoginWarning&gt;true&lt;/validationLoginWarning&gt;
  &lt;expirationTimeUntil&gt;30d&lt;/expirationTimeUntil&gt;
&lt;/com.mirth.connect.plugins.ssl.model.SSLManagerSettings&gt;</property>
</properties>
"@

        if ($saveXML) { 
            Save-Content $templateXML $outFile
        }
        Write-Verbose $templateXML.OuterXml
        return $templateXML
    }
    END { 
        Write-Debug "New-MirthSSLMgrPropertiesPayload Ending..."
    }

}  # New-MirthSSLMgrPropertiesPayload