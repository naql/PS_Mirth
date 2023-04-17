function New-MirthKeyStoreCertificatesPayLoad { 
    <#
    .SYNOPSIS
        Given public and private PEM certificates from the pipeline, or from a file location, 
        generate an xml object that contains a com.mirth.connect.plugins.ssl.model.KeyStoreCertificates

    .DESCRIPTION

    .INPUTS

    .OUTPUTS
        [xml] object that contains a com.mirth.connect.plugins.ssl.model.KeyStoreCertificates XML object 
        populated with the certificate pems and aliases as passed in.  This can then be passed to the Restore 
        Keystore operation.

    .EXAMPLE
        Create-DefaultKeyStore -privCertPemPath .\templates\default-private-cert.pem -pubCertPemPath .\templates\default-public-cert.pem -saveXML

    .LINK
        Links to further documentation.

    .NOTES
        This was created to provide input for the post to /api/extensions/ssl/all that I couldn't seem to get working.
    #> 
    [CmdletBinding()] 
    PARAM (

        # The alias for the server default client public certificate.
        [Parameter()]
        [string]$defaultClientAlias = "default-client",

        # The base64 PEM for the server default client public certificate.
        [Parameter(ParameterSetName = "pemProvided",
            ValueFromPipeline = $True)]
        [string]$pubCertPem = $null,
        
        # The path to the text file containing the public PEM
        [Parameter(ParameterSetName = "filePaths")]
        [string]$pubCertPemPath,

        # The alias for the server default server private certificate.
        [Parameter()]
        [string]$defaultServerAlias = "default-server",

        # The base64 PEM for the server default server private certificate, unencrypted.
        [Parameter(ParameterSetName = "pemProvided",
            ValueFromPipeline = $True)]
        [string]$privCertPem = $null,

        # The path to the text file containing the private PEM
        [Parameter(ParameterSetName = "filePaths")]
        [string]$privCertPemPath,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'

    )
    BEGIN {
        Write-Debug "New-MirthKeyStoreCertificatesPayLoad Beginning..."
    }
    PROCESS {

        if ([string]::IsNullOrEmpty($pubCertPem)) {
            if (Test-Path $pubCertPemPath -PathType Leaf) { 
                Write-Debug "Loading Public Cert PEM from path " $pubCertPemPath
                $pubCertPem = Get-Content $pubCertPemPath -Raw
            }
            else { 
                Write-Error "No Public PEM provided and path " $pubCertPemPath " does not exist!"
                return;
            }
        }
        if ([string]::IsNullOrEmpty($privCertPem)) {
            if (Test-Path $privCertPemPath -PathType Leaf) { 
                Write-Debug "Loading Private Cert PEM from path " $privCertPemPath
                $privCertPem = Get-Content $privCertPemPath -Raw
            }
            else { 
                Write-Error "No Private PEM provided and path " $privCertPemPath " does not exist!"
                return;
            }
        }

        $templateXML = 
        [xml]@"
<com.mirth.connect.plugins.ssl.model.KeyStoreCertificates>
<trustedCertificateMap>
        <entry>
            <string>$defaultClientAlias</string>
            <com.mirth.connect.plugins.ssl.model.KeyStoreEntry>
                <certificateChain>
                    <sun.security.x509.X509CertImpl resolves-to='java.security.cert.Certificate$CertificateRep'>
                        <type>X.509</type>
                        <data>$pubCertPem</data>
                    </sun.security.x509.X509CertImpl>
                </certificateChain>
            </com.mirth.connect.plugins.ssl.model.KeyStoreEntry>
        </entry>
    </trustedCertificateMap>
    <myCertificatesMap>
        <entry>
            <string>$defaultServerAlias</string>
            <com.mirth.connect.plugins.ssl.model.KeyStoreEntry>
                <certificateChain>
                    <sun.security.x509.X509CertImpl resolves-to='java.security.cert.Certificate$CertificateRep'>
                        <type>X.509</type>
                        <data>$pubCertPem</data>
                    </sun.security.x509.X509CertImpl>
                </certificateChain>
                <privateKey class='sun.security.rsa.RSAPrivateCrtKeyImpl' resolves-to='java.security.KeyRep'>
                    <type>PRIVATE</type>
                    <algorithm>RSA</algorithm>
                    <format>PKCS#8</format>
                    <encoded>$privCertPem</encoded>
                </privateKey>
            </com.mirth.connect.plugins.ssl.model.KeyStoreEntry>
        </entry>
    </myCertificatesMap>
</com.mirth.connect.plugins.ssl.model.KeyStoreCertificates>
"@


        if ($saveXML) { 
            Save-Content $templateXML $outFile
        }
        Write-Verbose $templateXML.OuterXml

        return $templateXML
    }
    END { 
        Write-Debug "New-MirthKeyStoreCertificatesPayLoad Ending..."
    }

}  # New-MirthKeyStoreCertificatesPayLoad