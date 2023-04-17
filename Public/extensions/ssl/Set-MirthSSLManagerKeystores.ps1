function Set-MirthSSLManagerKeystores { 
    <#
    .SYNOPSIS
        Given a truststore and keystore encoded as a Base64 string, upload them to 
        the Mirth server, replacing the SSL Manager keystores and assiging the specified password. 

    .DESCRIPTION
        If base64 encoded strings of the keystore and truststore JKS files are not provided, then 
        paths must be provided.  This function will read those JKS files in and base64 encode them.
        Then, it calls the Create-SSLMgrPropertiesPayload function to build the XML for the update.
        It then uses this XML to call the Set-MirthExtensionProperties for the "SSL Manager" 
        extension, updating the keystore, truststore, and password (stored in Mirth COnfiguration table.)

    .INPUTS
        The JKS keystore and truststore must be provided, either as base64 encode strings, or 
        as paths to the location of the JKS files in the filesystem.  These JKS keystores must be 
        encoded with the keystore password as specified in the $keyStorePass parameter.
        There MUST be NO private key password.

    .OUTPUTS

    .EXAMPLE
        Connect-Mirth | Update-MirthKeystores  -keyStorePath .\templates\default-keystore.jks -trustStorePath .\templates\default-truststore.jks  -keyStorePass changeit -saveXML

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # Base64 encoded string of a JKS file, used as SSL Manager keystore.
        [Parameter(ParameterSetName = "keystoreProvided")]
        [string]$keyStore = $null,
        
        # The path to the text file containing the public PEM
        [Parameter(ParameterSetName = "pathProvided")]
        [string]$keyStorePath,

        # Base64 encoded string of a JKS file, used as SSL Manager trustStore.
        [Parameter(ParameterSetName = "keystoreProvided")]
        [string]$trustStore = $null,
        
        # The path to the text file containing the private PEM
        [Parameter(ParameterSetName = "pathProvided")]
        [string]$trustStorePath,

        # keystore password.  This will be stored in the Mirth configuration table, category "SSL Manager", name "KeystorePass"
        [Parameter()]
        [string]$keyStorePass = "changeit",

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML
    )
    BEGIN { 
        Write-Debug "Set-MirthSSLManagerKeystores Beginning..."
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }  
        $payLoad = New-MirthSSLMgrPropertiesPayload -keyStore $keyStore -keyStorePath $keyStorePath -keyStorePass $keyStorePass -trustStore $trustStore -trustStorePath $trustStorePath -saveXML:$saveXML
        return Set-MirthExtensionProperties -connection $connection -targetId "SSL Manager" -payLoad $payLoad

    }
    END { 
        Write-Debug "Set-MirthSSLManagerKeystores Ending..."
    }

}  # Set-MirthSSLManagerKeystores
