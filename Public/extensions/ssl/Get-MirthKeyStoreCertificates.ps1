function Get-MirthKeyStoreCertificates { 
    <#
    .SYNOPSIS
        Gets the Mirth KeyStore certificates 

    .DESCRIPTION
        Fetch mirth keystore and truststore

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        <com.mirth.connect.plugins.ssl.model.KeyStoreCertificates>
          <trustedCertificateMap>
            <entry>
              <string>default-client</string>
              <com.mirth.connect.plugins.ssl.model.KeyStoreEntry>
                <certificateChain>
                  <sun.security.x509.X509CertImpl resolves-to="java.security.cert.Certificate$CertificateRep">
                    <type>X.509</type>
                    <data>MIIC2DCCAcCgAwIBAgIEXsmT0zANBgkqhkiG9w0BAQsFADAuMRMwEQYDVQQLDApEYXRhU3ByaXRl
        MRcwFQYDVQQDDA5kZWZhdWx0LXNlcnZlcjAeFw0yMDA1MjMyMTIxMjNaFw0zMDA1MjMyMTIxMjNa
            [...]
        sC5hIr2jIgcvoJd6pS2QLhCMIYZYdc0h07IQyAxO1HcPllfW+eACA0P6zuULUxL5</data>
                  </sun.security.x509.X509CertImpl>
                </certificateChain>
              </com.mirth.connect.plugins.ssl.model.KeyStoreEntry>
            </entry>
          </trustedCertificateMap>
          <myCertificatesMap>
            <entry>
              <string>default-server</string>
              <com.mirth.connect.plugins.ssl.model.KeyStoreEntry>
                <certificateChain>
                  <sun.security.x509.X509CertImpl resolves-to="java.security.cert.Certificate$CertificateRep">
                    <type>X.509</type>
                    <data>MIIC2DCCAcCgAwIBAgIEXsmT0zANBgkqhkiG9w0BAQsFADAuMRMwEQYDVQQLDApEYXRhU3ByaXRl
        MRcwFQYDVQQDDA5kZWZhdWx0LXNlcnZlcjAeFw0yMDA1MjMyMTIxMjNaFw0zMDA1MjMyMTIxMjNa
            [...]
        sC5hIr2jIgcvoJd6pS2QLhCMIYZYdc0h07IQyAxO1HcPllfW+eACA0P6zuULUxL5</data>
                  </sun.security.x509.X509CertImpl>
                </certificateChain>
                <privateKey class="sun.security.rsa.RSAPrivateCrtKeyImpl" resolves-to="java.security.KeyRep">
                  <type>PRIVATE</type>
                  <algorithm>RSA</algorithm>
                  <format>PKCS#8</format>
                  <encoded>MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDNMKtyrE87UBxDYhzBWYqKxsmh
        jb0W70NX0S/Au+DH7twn/C3SvX1ExoAJaoWaxAKLgYF2zXuFhhyNPki83wwj2zdYOrYIVhwC+8GD
            [...]
        rcVfPVWUMpxw3vSUuOsf4f5IS3c=</encoded>
                </privateKey>
              </com.mirth.connect.plugins.ssl.model.KeyStoreEntry>
            </entry>
          </myCertificatesMap>
        </com.mirth.connect.plugins.ssl.model.KeyStoreCertificates>

    .EXAMPLE
        Connect-Mirth | Get-MirthKeyStoreCertificates 

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Get-MirthKeyStoreCertificates Beginning..."
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/extensions/ssl/all'
        Write-Debug "Invoking GET Mirth $uri "
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Content-Type", "application/xml")
        try { 
            $r = Invoke-RestMethod -WebSession $session -Uri $uri -Method GET -Headers $headers
            Write-Debug "...done."

            if ($saveXML) { 
                Save-Content $r $outFile
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
                
        }
        catch {
            Write-Error $_
        }     
    }
    END { 
        Write-Debug "Get-MirthKeyStoreCertificates Ending..."
    }
}  # Get-MirthKeyStoreCertificates
