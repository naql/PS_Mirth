﻿<############################################################################################>
# PS-Mirth v.1.1.2
<############################################################################################>
Add-Type -AssemblyName System.Web

$VERSION = @{
    MAJOR = 1
    MINOR = 1
    PATCH = 2
}


enum MirthMsgStorageMode {
    DISABLED = 1
    METADATA = 2
    RAW = 3
    PRODUCTION = 4
    DEVELOPMENT = 5
}

# The custom MirthConnection object is created and returned by Connect-Mirth.
# All of the other functions which make calls to the Mirth REST API will require one.
# (It is not mandatory because they are designed to work in an "interactive" manner.
#  When omitted, the dynamically scoped $currentConnection variable is used as the 
#  default.)
#
# New-Object -TypeName MirthConnection -ArgumentList $session, $serverUrl, $userName, $userPass
class MirthConnection {
    [ValidateNotNullOrEmpty()][Microsoft.PowerShell.Commands.WebRequestSession]$session
    [ValidateNotNullOrEmpty()][string]$serverUrl
    [ValidateNotNullOrEmpty()][string]$userName
    [ValidateNotNullOrEmpty()][string]$userPass

    MirthConnection($session, $serverUrl, $userName, $userPass ) {
       $this.session   = $session
       $this.serverUrl = $serverUrl
       $this.userName  = $userName
       $this.userPass  = $userPass
    }
    
    [String] ToString()  {
        return "MirthConnection" + ":" + $this.serverUrl + ":" + $this.userName + ":" + $this.userPass
    }
}

# [UNDER CONSTRUCTION]
# This class is instended to serve as a container for server metadata.  It is intended to 
# be used as a basis for server-to-server comparisons.
class MirthServerSummary { 
    
    [string]$serverUrl
    [string]$id
    [string]$serverName

}


# Dynamically Scoped/Globals

# Set this to 'Continue' to display output from Write-Debug statements, 
# or to 'SilentylyContinue' to suppress them.
$DebugPreference = 'SilentlyContinue'

# This is where the -saveXML flag will cause files to be saved.  It 
# defaults to a subfolder in the current location.  Call Set-Mirth
[string]$savePath = Join-Path -Path $pwd -ChildPath "/PS_Mirth_Output/" 
Write-Verbose "Current PS_Mirth output folder is: $savePath"

[MirthConnection]$currentConnection = $null;


<############################################################################################>
<#       PS-Mirth Functions                                                                 #>
<############################################################################################>

function Get-PSMirthVersion { 
    return $VERSION
}

function Set-PSMirthDebug( [bool]$debug ) {
    <#
    .SYNOPSIS
        Call to set the module $DebugPreference 
    #> 
    if ($debug) { 
        $Script:DebugPreference = 'Continue'
        Write-Debug ("Debug On")
    } else { 
        $Script:DebugPreference = 'SilentlyContinue'
        Write-Debug ("Debug Off") # won't be seen
    }
}
function Set-PSMirthOutputFolder( $path ) {
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
        Returns the path, normalized with a backslash at the end.
        The folder is NOT created and will be lazily created on first output by the module.

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    $path = $path.Trim()
    if ([string]::IsNullOrEmpty($path)) {
        $savePath = Join-Path -Path $pwd -ChildPath "/PS_Mirth_Output/"
    }
    if (!(Test-Path -Path $path -IsValid)) {
        Write-Error "The path specified is not valid!"
        return $null
    }
    
    $script:savePath = PathAddBackslash($path)
    Write-Debug "Current PS_Mirth output folder is: $savePath"
    return $script:savePath
    
}

function PathAddBackslash($path) {
    $separator1 = [IO.Path]::DirectorySeparatorChar
    $separator2 = [System.IO.Path]::AltDirectorySeparatorChar 

    $path = $path.TrimEnd()
    if ($path.EndsWith($separator1) -or $path.EndsWith($separator2)) {
        return $path;
    }
    if ($path.Contains($separator2)) {
        return $path + $separator2;
    }
    return $path + $separator1;
}

function Get-PSMirthOutputFolder () { 
    param(
        [switch] $create
    )
    if ($create -and !(Test-Path $savePath -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $savePath
    }
    return $script:savePath
}

function Get-PSMirthConnection { 
    Write-Debug "Get-PSMirthConnection"
    return $script:currentConnection
}

function Set-PSMirthConnection( $connection ) { 
    Write-Debug "Set-PSMirthConnection"
    $script:currentConnection = $connection
}

<############################################################################################>
<#        Utility Functions                                                                 #>
<#                                                                                          #>
<#   General utilities and functions that create needed XML objects.                        #>
<#                                                                                          #>
<############################################################################################>

function global:Convert-XmlElementToDoc { 
   <#
    .SYNOPSIS
        Convert an Xml.XmlElement to an XmlDocument, with the element as the root
    .DESCRIPTION

    .INPUTS
        An Xml.XmlElement node
    .OUTPUTS
        An Xml Document with the element node as the root
    #> 
    [CmdletBinding()] 
    PARAM (
        # The alias for the server default client public certificate.
        [Parameter(Mandatory=$True)]
        [Xml.XmlElement]$element
    )
    $xml = New-Object -TypeName xml
    $xml.AppendChild($xml.ImportNode($element, $true)) | Out-Null 
    return $xml
}  # Convert-XmlElementToDoc

function global:New-MirthKeyStoreCertificatesPayLoad { 
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
        [Parameter(ParameterSetName="pemProvided",
                   ValueFromPipeline=$True)]
        [string]$pubCertPem = $null,
        
        # The path to the text file containing the public PEM
        [Parameter(ParameterSetName="filePaths")]
        [string]$pubCertPemPath,

        # The alias for the server default server private certificate.
        [Parameter()]
        [string]$defaultServerAlias = "default-server",

        # The base64 PEM for the server default server private certificate, unencrypted.
        [Parameter(ParameterSetName="pemProvided",
                   ValueFromPipeline=$True)]
        [string]$privCertPem = $null,

        # The path to the text file containing the private PEM
        [Parameter(ParameterSetName="filePaths")]
        [string]$privCertPemPath,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

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
            } else { 
              Write-Error "No Public PEM provided and path " $pubCertPemPath " does not exist!"
              return;
            }
        }
        if ([string]::IsNullOrEmpty($privCertPem)) {
            if (Test-Path $privCertPemPath -PathType Leaf) { 
                Write-Debug "Loading Private Cert PEM from path " $privCertPemPath
                $privCertPem = Get-Content $privCertPemPath -Raw
            } else { 
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
            [string]$o = Get-PSMirthOutputFolder -create
            $o = Join-Path $o $outFile     
            $templateXML.save($o)
        }
        Write-Verbose $templateXML.OuterXml

        return $templateXML
    }
    END { 
        Write-Debug "New-MirthKeyStoreCertificatesPayLoad Ending..."
    }

}  # New-MirthKeyStoreCertificatesPayLoad

function global:New-MirthSSLMgrPropertiesPayload { 
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
        [Parameter(ValueFromPipeline=$True)]
        [string]$keyStore = $null,
        
        # The path to the JKS keystore file
        [Parameter()]
        [string]$keyStorePath,

        # The base64 encoded JKS truststore.
        [Parameter(ValueFromPipeline=$True)]
        [string]$trustStore = $null,

        # The path to the text file containing the private PEM
        [Parameter()]
        [string]$trustStorePath,

        # The password to the keystore and truststore JKS files.
        [Parameter()]
        [string]$keyStorePass = "changeit",
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

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
            } else { 
              Write-Error "No TrustStore JKS provided and path " $trustStorePath " does not exist!"
              return;
            }
        }
        if ([string]::IsNullOrEmpty($keyStore)) {
            if (Test-Path $keyStorePath -PathType Leaf) { 
                Write-Debug "Loading KeyStore from path $keyStorePath"
                $keyStore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keyStorePath))
            } else { 
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
            [string]$o = Get-PSMirthOutputFolder -create
            $o = Join-Path $o $outFile    
            $templateXML.save($o)
        }
        Write-Verbose $templateXML.OuterXml
        return $templateXML
    }
    END { 
        Write-Debug "New-MirthSSLMgrPropertiesPayload Ending..."
    }

}  # New-MirthSSLMgrPropertiesPayload

function global:New-MirthChannelTagObject {
       <#
    .SYNOPSIS
        Creates an XML object representing a Mirth channel tag.

    .DESCRIPTION
        Given some parameter inputs, create a Mirth Channel Tag XML object.

    .INPUTS  
        The tag name is the only required parameter.  You can optionally specify
        the tag id, tag colors (ARGB), and list of channel ids to be tagged
        wit this tag.

    .OUTPUTS
        [xml] object describing a channelTag

          <channelTag>
            <id>a18cdca9-e8d2-445f-b844-d1418e0acea8</id>
            <name>Blue Tag</name>
            <channelIds>
                <string>014d299a-d972-4ae6-aa48-a2741f78390c</string>
            </channelIds>
            <backgroundColor>
                <red>0</red>
                <green>102</green>
                <blue>255</blue>
                <alpha>255</alpha>
            </backgroundColor>
        </channelTag>  

    .EXAMPLE
        $tagXML = New-MirthChannelTagObject -tagName 'HALO-RR08'

    .LINK
        See Mirth User Manual documentation regarding channel "tags".

    .NOTES
        
    #> 
    [CmdletBinding()] 
    PARAM (

        # the channelTag id guid, if not provided one will be generated
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string]$tagId = $(New-Guid).toString(),

        # the property key name
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$tagName,

        # the alpha value, 0-255, defaults to 255
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [ValidateRange(0,255)]
        [int]$alpha = 255,
   
        # the red value, 0-255, defaults to 0
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [ValidateRange(0,255)]
        [int]$red = 0,
        
        # the green value,, 0-255, defaults to 0
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [ValidateRange(0,255)]
        [int]$green = 0,

        # the blue value, 0-255, defaults to 0
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [ValidateRange(0,255)]
        [int]$blue = 0,

        # an optional array of channelId guids
        # the channelTag id guid strings that the tag applies to
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$channelIds

    ) 
    BEGIN {
        Write-Debug "New-MirthChannelTagObject Beginning"
    }
    PROCESS {

        Write-Debug ("Alpha: $alpha  Red: $red  Green: $green  Blue: $blue")
        $objectXML = [xml]@"  
        <channelTag>
        <id>$tagId</id>
        <name>$tagName</name>
        <channelIds>
        </channelIds>
        <backgroundColor>
          <red>$red</red>
          <green>$green</green>
          <blue>$blue</blue>
          <alpha>$alpha</alpha>
        </backgroundColor>
      </channelTag>
"@
        # If any channel ids were added, we need to add them to the channelIds element as <string /> values...
        Add-PSMirthStringNodes -parentNode $($objectXML.SelectSingleNode("/channelTag/channelIds")) -values $channelIds | Out-Null
        Write-Verbose "XML Object: $($objectXML.OuterXml)"
        return $objectXML
    }
    END { 
        Write-Debug "New-MirthChannelTagObject Ending"
    }

}  # New-MirthChannelTagObject

function global:New-MirthConfigMapEntry {
    <#
    .SYNOPSIS
        Creates an XML object representing a Mirth configuration map entry.

    .DESCRIPTION

    .INPUTS
        $entryKey     - the property name
        $entryValue   - the property value
        $entryComment - comment describing the property or settings 

    .OUTPUTS
        [xml] object containing mirth configuration map entry 

    .EXAMPLE

    .LINK
        Links to further documentation.

    .NOTES
        
    #> 
    [CmdletBinding()] 
    PARAM (

        # the property key name
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$entryKey,
   
        # the property value
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$entryValue,
        
        # comment describing the property
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string]$entryComment = ""

    ) 
    BEGIN {
    }
    PROCESS {
        $entryXML = [xml]@"  
        <entry>
        <string>$entryKey</string>
            <com.mirth.connect.util.ConfigurationProperty>
                <value>$entryValue</value>
                <comment>$entryComment</comment>
            </com.mirth.connect.util.ConfigurationProperty>
        </entry>
"@
        return $entryXML
    }
    END {
    } 

}  # New-MirthConfigMapEntry

function global:New-MirthConfigMapFromProperties { 
    <#
    .SYNOPSIS
        Create a new Mirth configurationMap XML object from either a hashtable passed in, or from a standard properties file
        in the file system.

    .DESCRIPTION

    .INPUTS
        $payLoad          - a [hashtable] of key/value pairs, or 
        $payLoadFilePath  - a fully qualified path to a standard properties file (with # comments preceding each property)

    .OUTPUTS
        [xml] object containing the xml mirthconfiguration map

        <map>
            <entry>
                <string>ucp.db.url</string>
                <com.mirth.connect.util.ConfigurationProperty>
                <value>jdbc:oracle:thin:@sa-sandbox-db:1521:TMDSTMDG</value>
                <comment> The URL of the UCP  db.</comment>
                </com.mirth.connect.util.ConfigurationProperty>
            </entry>
            <entry>
                <string>ucp.pool.initial.size</string>
                <com.mirth.connect.util.ConfigurationProperty>
                <value>1</value>
                <comment> The initial size of the db connection pool.  (Defaults to 6 if not specified)</comment>
                </com.mirth.connect.util.ConfigurationProperty>
            </entry>
            [...]
        </map>

    .EXAMPLE

    .LINK
        Links to further documentation.

    .NOTES
        This was created to provide input for the post to /api/extensions/ssl/all that I couldn't seem to get working.
    #> 
    [CmdletBinding()] 
    PARAM (

        # hashtable of property names and values, no comments
        [Parameter(ParameterSetName="propertiesProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [hashtable]$payLoad,

        # path to file containing the properties file (including comments)
        [Parameter(ParameterSetName="pathProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payloadFilePath,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 

    BEGIN { 
        Write-Debug "New-MirthConfigMapFromProperties Beginning"
    }
    PROCESS {
    [xml]$mapXML = [xml]"<map></map>"
        if (($payLoad -ne $null) -and ($payLoad -is [hashtable]) -and ($payLoad.Count -gt 0)) {
            Write-Debug "$msg = Properties hashtable provided in payLoad with $($payLoad.Count) entries"
            # Note:  We are losing comments here, because they are not represented in a vanilla hashtable
            foreach ($key in $payLoad.Keys) { 
                $newValue = $payLoad[$key]
                $entryXML = New-MirthConfigMapEntry -entryKey $key -entryValue $newValue -entryComment ""
                $mapXML.DocumentElement.AppendChild($mapXML.ImportNode($entryXML.entry, $true)) | Out-Null
            }
        } else { 
            # Verify the payLoadFilePath exists, load it
            if (Test-Path $payloadFilePath -PathType Leaf) {
                [string]$commentBuffer = ""
                Get-Content $payloadFilePath | ForEach-Object {
                  # comments are lines that begin with # character and must precede the property
                  # so, we will read building a comment string from any # lines, and create a 
                  # map entry when we encounter a property using whatever comment string has been 
                  # built so far, and then flushing it
                  [string]$line = $_
                  $line = $line.trim()
                  Write-Verbose "Read line: $_ "
                  [bool]$isComment = $line.StartsWith('#')
                  if ($isComment) {
                    #Write-Debug "Comment Found"
                    $commentBuffer += $line.substring(1)
                  } else { 
                    # it should be a property
                    Write-Debug "Property Found"
                    $propLine = $line.Split('=')
                    $keyName  = $propLine[0].trim()
                    $value    = $propLine[1].trim()
                    Write-Debug "Key:     $keyName"
                    Write-Debug "Value:   $value"
                    Write-Debug "Comment: $commentBuffer"
                    $entryXML = New-MirthConfigMapEntry -entryKey $keyName -entryValue $value -entryComment $commentBuffer
                    $mapXML.DocumentElement.AppendChild($mapXML.ImportNode($entryXML.entry, $true)) | Out-Null

                    $commentBuffer = ''
                  }
                }
            } else { 
                $msg = "The properties file path provided was invalid: " + $payloadFilePath
                Write-Error $msg
                return
            }
        }
        if ($saveXML) { 
            [string]$o = Get-PSMirthOutputFolder -create
            $o = Join-Path $o $outFile 
            $mapXML.save($o)
        }
        Write-Verbose $mapXML.OuterXml
        return $mapXML
        <# Output a custom object with both $rValue and the server address
        return [pscustomobject] @{
            payLoad = $mapXML
        }#>
    }
    END { 
        Write-Debug "New-MirthConfigMapFromProperties Ending"
    }

}  # New-MirthConfigMapFromProperties

function global:Save-MirthPropertiesFile { 
    <#
    .SYNOPSIS
        Saves a property file containing the data from the Mirth XML Configuration Map
        passed in.  

    .DESCRIPTION
        By default the entries in the Mirth configuration map are sorted when output
        to the new properties file.  To suppress this use the -unsorted switch.

    .INPUTS
        $payLoad          - [xml] object containing the mirth xml configuration map

        <map>
            <entry>
                <string>ucp.db.url</string>
                <com.mirth.connect.util.ConfigurationProperty>
                <value>jdbc:oracle:thin:@sa-sandbox-db:1521:TMDSTMDG</value>
                <comment> The URL of the UCP  db.</comment>
                </com.mirth.connect.util.ConfigurationProperty>
            </entry>
            <entry>
                <string>ucp.pool.initial.size</string>
                <com.mirth.connect.util.ConfigurationProperty>
                <value>1</value>
                <comment> The initial size of the db connection pool.  (Defaults to 6 if not specified)</comment>
                </com.mirth.connect.util.ConfigurationProperty>
            </entry>
            [...]
        </map>

    .OUTPUTS
        Writes a properties file with the name assigned to the -outFile parameter.
        Outputs the text contents of the created property file to the pipeline on return.

    .EXAMPLE
        Connect-Mirth | Get-MirthConfigMap | Save-MirthPropertiesFile -outFile new.properties

    .LINK
        Links to further documentation.

    .NOTES
        TODO: Modify this to return text file stream and save to output folder only on -saveXML flag.
    #> 
    [CmdletBinding()] 
    PARAM (

        # xml document containing the mirth configuration map
        [Parameter(Mandatory=$True,
                   ValueFromPipeline=$True)]
        [xml]$payLoad,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.properties',

        # A switch to suppress sorting of the created property file.
        [Parameter()]
        [switch]$unsorted = $false
    ) 

    BEGIN { 
        Write-Debug "Save-MirthPropertiesFile Beginning"
    }
    PROCESS {
        [string]$outPath = Get-PSMirthOutputFolder -create
        $targetPath = Join-Path $outPath $outFile 
        if (($null -ne $payLoad ) -and ($payLoad -is [xml]) ) {
            if (Test-Path -Path $targetPath) {
                Clear-Content -Path $targetPath 
            } else { 
                New-Item -Name $outFile -ItemType File -Path $outPath  | Out-Null
            }
            $entries = $payLoad.map.entry;
            if ($unsorted) { 
                $outputEntries = $entries
            } else { 
                $outputEntries = $entries | Sort-Object { [string]$_.string }
            }
            foreach ($entry in $outputEntries) {
                $line = "#`t" + $entry.'com.mirth.connect.util.ConfigurationProperty'.comment
                Add-Content -Path $targetPath -value $line
                $line = “{0,-40} {1,1} {2}” -f $entry.string, "=", $entry.'com.mirth.connect.util.ConfigurationProperty'.value
                Add-Content -Path $targetPath -value $line
            }
            Get-Content -path $targetPath | Write-Verbose  
            # Return the properties as a hashtable
            [hashtable]$returnMap = ConvertFrom-StringData (Get-Content $targetPath | Out-String)
            return $returnMap

        } else { 
            Write-Error "payLoad is not XML document"
            return
        }
    }
    END { 
        Write-Debug "Save-MirthPropertiesFile Ending"
    }
}  # Save-MirthPropertiesFile

function global:Add-PSMirthStringNodes { 
    <#
    .SYNOPSIS
        Given an XMLElement parent node and an array of strings, will add all 
        of the array values as <string>value</string> child nodes  

    .DESCRIPTION
        This is a utility function called by other functions when 
        preparing payloads.

    .INPUTS
        $payLoad          - [xml] object containing the mirth xml configuration map

    .OUTPUTS

    .EXAMPLE

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

        # The XMLElement to which the nodes are to be added
        [Parameter()]
        [xml.XMLElement] $parentNode,
        
        # An array of String values, each of which should be added as a <string>value</string>
        # child to the parent node passed in.
        [Parameter()]
        [string[]] $values
    ) 
    BEGIN { 
        Write-Debug "Add-PSMirthStringNodes Beginning"
    }
    Process { 
        if ($null -eq $parentNode) { 
            Throw 'parentNode must not be a null object'
        }
        Write-Debug "The parent node is of type: $($parentNode.getType())"
        $xmlDoc = $parentNode.OwnerDocument

        Write-Debug "Adding string nodes to parent $($parentNode.localName)..."
        foreach ($value in $values) {
            Write-Debug "Adding child string $value"
            $e = $xmlDoc.CreateElement("string")
            $e.set_InnerText($value) | Out-Null
            $parentNode.AppendChild($e) | Out-Null
        }
        Write-Debug "$($values.count) string child elements added"
        return $parentNode    
    }
    END { 
        Write-Debug "Add-PSMirthStringNodes Ending"
    }
}  # Add-PSMirthStringNodes

function global:Invoke-PSMirthTool { 
    <#
    .SYNOPSIS
        Deploys, invokes and fetches payloads from PS_Mirth "tool" channels.

    .DESCRIPTION
        This function loads in a "tool" channel.  It will import the channel to 
        the target mirth server, deploy it, send a message to it if necessary, 
        and fetch the resuling message content from the output destination 
        named "PS_OUTPUT". The type of payload, xml, JSON, etc, is determined 
        by the destination datatype.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        Object representing the resulting tool channel output.

    .EXAMPLE
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # required path to the tool to deploy
        [Parameter(Mandatory=$True)]
        [string]$toolPath,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )     
    BEGIN { 
        Write-Debug "Invoke-PSMirthTool Beginning"
    }
    PROCESS { 
        Write-Debug "Loading tool channel..."
        [xml]$tool = Get-Content $toolPath
        $toolName  = $tool.channel.name
        $toolId = $tool.channel.id
        $toolTransportType = $tool.channel.sourceConnector.transportName
        Write-Debug "Tool:      $toolName"
        Write-Debug "Tool ID:   $toolId"
        Write-Debug "Type:      $toolTransportType"
        [string]$pollSetting = $tool.channel.sourceConnector.properties.pollConnectorProperties.pollOnStart
        $pollsOnStart = ($pollSetting.ToUpper() -eq "TRUE")
        if ($pollsOnStart) { 
            Write-Debug "The tool channel polls automatically on deployment"
        } else { 
            Write-Debug "The tool channel does NOT poll on deployment!"
            # we will add some logic to support this later
        }

        $returnValue = $null
        $result = Import-MirthChannel -connection $connection -payLoad $tool.OuterXml 
        Write-Debug "Import Result: $($result.OuterXml)"
        Write-Debug "Deploying probe channel..."
        $result = Send-MirthDeployChannels -targetIds $toolId 
        Write-Debug "Deploy Result: $result"

        $maxMsgId = $null
        $attempts = 0
        while (($null -eq $maxMsgId) -and ($attempts -lt 3)) { 
            Write-Verbose "Looking for probe telemetry..." 
            $attempts++  
            $maxMsgId = Get-MirthChannelMaxMsgId -targetId $toolId 
            Write-Debug "Probe Channel Max Msg Id: $maxMsgId"
            if (-not $maxMsgId -gt 0) { 
                $maxMsgId = $null
                Write-Verbose "No probe telemetry available, pausing for 3 seconds to reattempt..."
                Start-Sleep -Seconds 3
            }
        }

        [xml]$channelMsg = $null
        if (-not $maxMsgId -gt 0) { 
            Write-Warning "No tool telemetry could be obtained"
        } else { 
            $attempts = 0
            while (($null -eq $channelMsg) -and ($attempts -lt 3)) { 
                Write-Verbose "Getting telemetry result..." 
                $attempts++  
                [xml]$channelMsg = Get-MirthChannelMsgById -connection $connection -channelId $toolId -messageId $maxMsgId 
                if ($null -ne $channelMsg) {
                    $processedNode = $channelMsg.SelectSingleNode("/message/processed")
                    $result = $processedNode.InnerText.Trim()
                    if ($result -ne "true") { 
                        Write-Verbose "telemetry messages is not processed yet, pausing for 3 seconds to reattempt..."
                        $channelMsg = $null
                        Start-Sleep -Seconds 3
                    }
                }
            }
            if ($null -ne $channelMsg) {
                # We should now have a processed message, find our payload, look for destination 'PS_OUTPUT"
                $xpath = '/message/connectorMessages/entry/connectorMessage[connectorName = "PS_OUTPUT"]'
                $connectorMessageNode = $channelMsg.SelectSingleNode($xpath)
                if ($null -eq $connectorMessageNode) { 
                    Write-Error "Could not locate PS_OUTPUT destination of PSMirthTool channel: $toolName"
                    # return $null
                }     
                $dataType = $connectorMessageNode.encoded.dataType 
                Write-Debug "The tool output is of dataType: $dataType"
                if ($dataType -eq "XML") { 
                    [xml]$decoded = [System.Web.HttpUtility]::HtmlDecode($connectorMessageNode.encoded.content)
                    Set-Variable returnValue -Value ($decoded -as [Xml])
                } else { 
                    Write-Warning "Unimplemented PSMirthTool datatype"
                    $toolMessage = [System.Web.HttpUtility]::HtmlDecode($connectorMessageNode.encoded.content)
                    Set-Variable returnValue -Value ($toolMessage -as [String])                
                }
            } else { 
                # probe failed to process
                Write-Error "Tool probe channel $toolName failed to return telemetry."
            }
            
        }

        $result = Send-MirthUndeployChannels -connection $connection -targetIds $toolId 
        Write-Debug "Undeploy Result: $result"
        $result = Remove-MirthChannels -connection $connection -targetId $toolId 
        Write-Debug "Remove Result: $result" 

        return $returnValue
    }
    END { 
        Write-Debug "Invoke-PSMirthTool Ending"
    }
}  # Invoke-PSMirthTool


<############################################################################################>
<#       Server Functions                                                                    #>
<############################################################################################>

function global:Get-MirthServerAbout { 

    <#
    .SYNOPSIS
        Get an xml object summarizing mirth about properties.

    .DESCRIPTION
        Fetches an XML object that summarizes the Mirth erver, the name, version, type of database, 
        number of channels, connectors and plugins installed.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        If the -asHashtable switch is set, a Powershell hashtable of the properties and values
        is returned.  Otherwise, it returns an XML object describing server properties.  
        This XML has the form:

        <map>
          <entry>
            <string>date</string>
            <string>November 16, 2018</string>
          </entry>
          <entry>
            <string>channelCount</string>
            <int>3</int>
          </entry>
          <entry>
            <string>database</string>
            <string>derby</string>
          </entry>
          <entry>
            <string>connectors</string>
            <map>
              <entry>
                <string>SMTP Sender</string>
                <string>3.6.2</string>
              </entry>
              <entry>
                <string>File Writer</string>
                <string>3.6.2</string>
              </entry>
                [...]
              <entry>
                <string>DICOM Sender</string>
                <string>3.6.2</string>
              </entry>
            </map>
          </entry>
          <entry>
            <string>plugins</string>
            <map>
              <entry>
                <string>Server Log</string>
                <string>3.6.2</string>
              </entry>
              <entry>
                <string>Text Viewer</string>
                <string>3.6.2</string>
              </entry>
                [...]
              <entry>
                <string>XSLT Transformer Step</string>
                <string>3.6.2</string>
              </entry>
            </map>
          </entry>
          <entry>
            <string>name</string>
            <string>LOCAL-TEST-MIRTH</string>
          </entry>
          <entry>
            <string>version</string>
            <string>3.6.2</string>
          </entry>
        </map>


    .EXAMPLE
        Connect-Mirth | Get-MirthServerAbout 

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
         [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # If true, return the about properties in a hashtable instead of xml object.
        [Parameter()]
        [switch]$asHashtable = $false, 

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Get-MirthServerAbout Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
 
        $uri = $serverUrl + '/api/server/about'
        Write-Debug "Invoking GET Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session 
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"
            if ($asHashtable) { 
                $returnMap = @{}
                foreach ($entry in $r.map.entry) { 
                    $node = $entry.FirstChild
                    while ($node.NodeType -eq "Whitespace") { 
                        $node = $node.NextSibling
                    }
                    $key = $node.InnerText 
                    $valueNode = $node.NextSibling
                    while ($valueNode.NodeType -eq "Whitespace") { 
                        $valueNode = $valueNode.NextSibling
                    }
                    $value = $valueNode.InnerText 
                    $returnMap[$key] = $value
                }
                return $returnMap
            } else { 
                return $r
            }
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug "Get-MirthServerAbout Ending"
    }
}  # Get-MirthServerAbout

function global:Get-MirthServerConfig {
    <#
    .SYNOPSIS
        Gets all the complete server configuration backup XML file for the specified server. 

    .DESCRIPTION
        Creates a single XML file backup of the entire mirth server configuration.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        Returns an XML object that represents a complete server backup of 
        channels, code templates, server settings, keystores, etc.

    .EXAMPLE
         Get-MirthServerConfig  -saveXML -outFile backup-local-dev.xml
         [xml]$backupXML = Get-MirthServerConfig -connection $connection 

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN {
        Write-Debug  "Get-MirthServerConfig Beginning..."
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/server/configuration'
        Write-Debug "Invoking GET Mirth $uri "
        # This backs up channels, code templates, everything, to a single xml file
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose $r.innerXml
            return $r

        }
        catch {
            Write-Error $_
        }     
    }
    END { 
        Write-Debug "Get_MirthServerConfig Ending..."
    } 
}  # Get-MirthServerConfig

function global:Get-MirthServerVersion { 

    <#
    .SYNOPSIS
        Gets the mirth server version. 

    .DESCRIPTION
        Returns a String containing the version to the Pipeline.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        Returns a string containing the version of the Mirth server, e.g., "3.6.2"

    .EXAMPLE
        Connect-Mirth | Get-MirthServerVersion  -saveXML

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.txt'
    ) 
    BEGIN {
        Write-Debug "Get-MirthServerVersion Beginning..." 
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
 
        $uri = $serverUrl + '/api/server/version'
        Write-Debug "Invoking GET Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session -Headers @{'Accept' = 'text/plain'; 'X-My-Header' = 'DataSprite'}
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                Write-Debug "Saving Output to $o" 
                Set-Content -Path $o -Value $r      
                Write-Debug "Done!" 
            }
            Write-Verbose $r
            return $r
        }
        catch {
            Write-Error $_
        }
    }
    END { 
        Write-Debug "Get-MirthServerVersion Ending..."
    }
}  # Get-MirthServerVersion

function global:Get-MirthServerTime { 
    <#
    .SYNOPSIS
        Gets the Mirth server time.

    .DESCRIPTION
        Fetches the Mirth server time as a "gregorian-calendar" xml object.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        Returns xml containing server time and time zone:

        <gregorian-calendar>
            <time>1591908170092</time>
            <timezone>America/Chicago</timezone>
        </gregorian-calendar>

    .EXAMPLE
        connect-mirth | Get-MirthServerTime  -saveXML -outFile server-update-time.xml

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )     
    BEGIN { 
        Write-Debug "Get-MirthServerTime Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
 
        $uri = $serverUrl + '/api/server/time'
        $headers = @{}
        $headers.Add("Accept","application/xml")

        Write-Debug "Invoking GET Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -WebSession $session  -ContentType 'application/xml' 
            
            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                Set-Content -Path $o -Value $r.OuterXml      
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
        }
        catch {
            Write-Error $_
        }
    }
    END { 
        Write-Debug "Get-MirthServerTime Ending"
    }
}  #  Get-MirthServerTime

function global:Get-MirthChannelGroups { 
    <#
    .SYNOPSIS
        Gets the Mirth Channel Groups 

    .DESCRIPTION
        Returns a list of one or more channelGroup objects:

        <list>
          <channelGroup version="3.6.2">
            <id>bb2c8399-d05b-443c-a77f-05b5484fdfe9</id>
            <name>Transport Sample Channels</name>
            <revision>1</revision>
            <lastModified>
              <time>1589682536845</time>
              <timezone>America/Chicago</timezone>
            </lastModified>
            <description>These are channels illustrating each of the basic Mirth transports.
        </description>
            <channels>
              <channel version="3.6.2">
                <id>e0e315bc-e064-4a6c-bc60-e26c2b4846b7</id>
                <revision>0</revision>
              </channel>
              <channel version="3.6.2">
                <id>014d299a-d972-4ae6-aa48-a2741f78390c</id>
                <revision>0</revision>
              </channel>
            </channels>
          </channelGroup>
        </list>

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all channel groups are returned.  Otherwise, only the channel groups with the 
        id values specified are returned.

    .OUTPUTS
        

    .EXAMPLE
        Connect-Mirth | Get-MirthChannelGroups 
        Connect-Mirth | Get-MirthChannelGroups -targetId bb2c8399-d05b-443c-a77f-05b5484fdfe9 
        Connect-Mirth | Get-MirthChannelGroups -targetId bb2c8399-d05b-443c-a77f-05b5484fdfe9,fdae2c23-8b01-48ac-9357-8da33082fe93

        # fetch a list of the current mirth channel group ids...
        $(Get-MirthChannelGroups ).list.channelGroup.id
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the channelGroup to retrieve, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetId = @(),
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Get-MirthChannelGroups Beginning..."
        #Write-Debug "targetId is: " $targetId     
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }  
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/channelgroups'
        if ([string]::IsNullOrEmpty($targetId) -or [string]::IsNullOrWhiteSpace($targetId)) {
            Write-Debug "Fetching all channel Groups"
            $parameters = $null
        } else {
            $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
            foreach ($target in $targetId) {
                $parameters.Add('channelGroupId', $target)
            }
            $uri = $uri + '?' + $parameters.toString()
        }
         
        Write-Debug "Invoking GET Mirth $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session 
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"
            return $r;
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug "Get-MirthChannelGroups Ending..." 
    }

}  # Get-MirthChannelGroups

function global:Set-MirthChannelGroups { 
    <#
    .SYNOPSIS
        Adds or updates Mirth channel groups in bulk. 

    .DESCRIPTION
        Updates channel groups. 

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        This command expects input as an xml string.
        $payLoad is xml describing the channel groups to be uploaded:

    .OUTPUTS

    .EXAMPLE

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of the configuration map to be added
        [Parameter(ParameterSetName="xmlProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payLoad,

        # path to file containing the xml of the configuation map
        [Parameter(ParameterSetName="pathProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payloadFilePath,

        # array of string values containing channel group ids to remove
        # defaults to an empty array
        [Parameter()]
        [string[]]$removedChannelGroupIds = @(),      
        
        # If true, the code group will be updated even if a different revision 
        # exists on the server
        [Parameter()]
        [switch]$override = $false,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )   
    BEGIN { 
        Write-Debug "Set-MirthChannelGroups Beginning"
    }
    PROCESS { 
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$payloadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A channel XML payLoad string is required!"
                return $null
            } else {
                Write-Debug "Loading channel XML from path $payLoadFilePath"
                [xml]$payloadXML = Get-Content $payLoadFilePath  
            }
        } else {
            $payloadXML = [xml]$payLoad
        }

        $msg = 'Importing channelGroup [' + $payloadXML.set.channelGroup.name + ']...'
        Write-Debug $msg

        [xml]$removeChannelGroupXml = "<set></set>";
        Add-PSMirthStringNodes -parentNode $($removeChannelGroupXml.SelectSingleNode("/set")) -values $removedChannelGroupIds | Out-Null

        Write-Debug "channel ids to be removed from group:"
        Write-Debug $removeChannelGroupXml.outerXml
        
        $uri = $serverUrl + '/api/channelgroups/_bulkUpdate'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('override', $override)
        $uri = $uri + '?' + $parameters.toString()
        $headers = @{}
        $headers.Add("Accept","application/xml")  

        Write-Debug "POST to Mirth $uri "

        $boundary = "--boundary--"
        $LF = "`n"
        $bodyLines = (
            "--$boundary",
            "Content-Disposition: form-data; name=`"channelGroups`"",
            "Content-Type: application/xml$LF",   
            $payloadXML.OuterXml,
            "$LF--$boundary",
            "Content-Disposition: form-data; name=`"removedChannelGroupIds`"",
            "Content-Type: application/xml$LF",  
            $removeChannelGroupXml.OuterXml,
            "--$boundary--$LF"
            ) -join $LF
        Write-Debug $bodyLines
        try {
            # Returns the response gotten from the server (we pass it on).
            #
            Invoke-RestMethod -WebSession $session -Uri $uri -Method Post -ContentType "multipart/form-data; boundary=`"$boundary`"" -TimeoutSec 20 -Body $bodyLines
        }
        catch [System.Net.WebException] {
            throw $_
        }
    } 
    END { 
        Write-Debug "Set-MirthChannelGroups Ending"
    }
}  #  Set-MirthChannelGroups

function global:Remove-MirthChannelGroups { 
    <#
    .SYNOPSIS
        Removes channels with the ids specified by $targetId

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all channel groups are returned.  Otherwise, only the channel groups with the 
        id values specified are returned.

    .OUTPUTS

    .EXAMPLE
        Remove-MirthChannelGroups -targetId 21189e58-2f96-4d47-a0d5-d2879a86cee9,c98b1068-af68-41d9-9647-5ff719b21d67  -saveXML
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The ids of the channelGroup to remove, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetIds = @(),
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Remove-MirthChannelGroups beginning"
    }
    PROCESS { 
        [xml]$payLoad = "<set />"
        [xml]$currentGroups = Get-MirthChannelGroups -saveXML:$saveXML
        $channelGroups = $currentGroups.list.channelGroup
        if ($targetIds.count -gt 0) { 
            foreach ($channelGroup in $channelGroups) {
                Write-Verbose "ChannelGroup id: $($channelGroup.id) name: $($channelGroup.name)" 
                if ($targetIds.contains($channelGroup.id)) { 
                    Write-Verbose "This channel is marked for removal, skipping..."
                } else { 
                    # add this channelGroup we are keeping to the set
                    $payLoad.DocumentElement.AppendChild($payLoad.ImportNode($channelGroup,$true))
                }
            }
            Set-MirthChannelGroups -payLoad $payLoad.OuterXml -removedChannelGroupIds $targetIds -override -saveXML:$saveXML 

        } else { 
            Write-Debug "All groups are to be deleted"
            $channelGroupIds = $currentGroups.list.channelGroup.id
            Write-Debug "There will be $($currentGroups.Count) channel groups deleted."
            Set-MirthChannelGroups -payLoad '<set />' -removedChannelGroupIds $channelGroupIds  -override -saveXML:$saveXML 
        }
        
    }
    END {
        Write-Debug "Remove-MirthChannelGroups ending"
    }
}  #  Remove-MirthChannelGroups

function global:Add-MirthChannelGroups { 
    <#
    .SYNOPSIS
        Merge (add/updates) channelGroups. 

    .DESCRIPTION
        Merges a set of Mirth channelGroup objects into the currently existing set 
        of channelGroups.  The channelGroups being merged will replace any existing 
        channelGroup with the same ID.  Any channels in the merged channelGroups will 
        be removed from existing channelGroups.  Otherwise, it leaves the current 
        channelGroup set intact.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        This command expects input as an xml string.
        $payLoad is xml describing the set of channelGroup objects to be added.

    .OUTPUTS

    .EXAMPLE

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of the set of channelGroup objects
        [Parameter(ParameterSetName="xmlProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payLoad,

        # path to file containing the xml of the channelGroup set
        [Parameter(ParameterSetName="pathProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payloadFilePath,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )   
    BEGIN { 
        Write-Debug "Add-MirthChannelGroups Beginning"
    }
    PROCESS { 

        [xml]$payloadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A channelGroup XML payLoad string is required!"
                return $null
            } else {
                if (Test-Path -Path $payLoadFilePath) {
                    Write-Debug "Loading channelGroup XML from path $payLoadFilePath"
                    [xml]$payloadXML = Get-Content $payLoadFilePath  
                } else { 
                    Throw "The payloadFilePath specified is invalid!"
                }
            }
        } else {
            $payloadXML = [xml]$payLoad
        }
        # We need to get a list of channel ids referenced in the merged groups
        # these channels should be removed from any other existing groups they are referenced
        # to be contained in:  the merged groups take priority
        $refChannelIdList = @();
        $idNodes = $payLoadXML.SelectNodes("//channelGroup/channels/channel/id")
        foreach ($idNode in $idNodes) {
            Write-Debug "Adding channel id $($idNode.innerText) to list..."
            $refChannelIdList  += $idNode.innerText
        }
        Write-Debug "There are $($refChannelIdList.Count) channels referenced in the new merged groups"
        foreach ($id in $refChannelIdList) { 
            Write-Debug "Channel ID: $id"
        }

        # Get the current list of channelGroups
        $currChannelGroups = Get-MirthChannelGroups -connection $connection
        [hashtable] $currChannelGroupMap = @{}
       
        foreach ($channelGroup in $currChannelGroups.list.channelGroup) { 
            $key    = $channelGroup.id
            Write-Debug "Processing current channelGroup $key, $($channelGroup.name)"
            [Xml.XmlElement[]]$nodesToDelete = @()
            foreach ($channel in $channelGroup.channels.channel) {
                Write-Debug "examining channel id: $($channel.id)"
                if ($refChannelIdList -contains $($channel.id)) {
                    Write-Debug "This channel element needs to be deleted"
                    $nodesToDelete += $channel
                }
            }
            Write-Debug "There are $($nodesToDelete.Count) channel nodes to be deleted"
            foreach ($node in $nodesToDelete) { 
                Write-Debug "Deleting channel node from channelGroup"
                $channelGroup.channels.removeChild($node) | Out-Null
            }
            Write-Debug "Adding current channelGroup with id $key to current map..."
            $currChannelGroupMap[$key] = $channelGroup
        }
        Write-Debug "There are $($currChannelGroupMap.Keys.Count) channel groups currently."
        # add the payload list of groups to the current list of channelGroups
        foreach ($channelGroup in $payLoadXML.set.channelGroup) { 
            $currentGroupNode = $currChannelGroupMap[$channelGroup.id]
            if ($null -eq $currentGroupNode) { 
                Write-Debug "Inserting new channelGroup"
                $currChannelGroupMap[$channelGroup.id] = $channelGroup
            } else { 
                Write-Debug "Updating existing channelGroup"
                Write-Debug "Replacing $($currentGroupNode.OuterXml)"
                Write-Debug "With Node $($channelGroup.OuterXml)"
                $currChannelGroupMap[$channelGroup.id] = $channelGroup
            }
        }
        Write-Debug "After merge, there are $($currChannelGroupMap.Keys.Count) channel groups"
        [xml] $newGroupSet = "<set/>"
        $setNode = $newGroupSet.SelectSingleNode("/set")
        foreach ($key in $currChannelGroupMap.Keys) { 
            $channelGroup = $currChannelGroupMap[$key]
            Write-Debug "Inserting channelGroup id $key into return set"
            $setNode.AppendChild($newGroupSet.ImportNode($channelGroup, $true)) | Out-Null            
        }

        # Update the channelGroups with the new list
        $r = Set-MirthChannelGroups -connection $connection -payLoad $newGroupSet.OuterXml -override
        if ($saveXML) { 
            [string]$o = Get-PSMirthOutputFolder -create
            $o = Join-Path $o $outFile 
            Write-Verbose "Saving merged channelGroups to $o"
            Set-Content $o $newGroupSet.OuterXml
        }
        Write-Verbose $newGroupSet.OuterXml
        return $r
    } 
    END { 
        Write-Debug "Add-MirthChannelGroups Ending"
    } 
}  # Add-MirthChannelGroups

function global:Get-MirthServerChannelMetadata { 
    <#
    .SYNOPSIS
        Gets all Mirth server channel metadata.

    .DESCRIPTION
        Return xml object describing channel metadata, enabled status, pruning settings, etc.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all channel groups are returned.  Otherwise, only the channel groups with the 
        id values specified are returned.

    .OUTPUTS
        Returns an XML object that represents all channel metadata

        <map>
            <entry>
                <string>cdfcb6b1-5fd4-4ef0-a700-68cacf6d0467</string>
                <com.mirth.connect.model.ChannelMetadata>
                    <enabled>true</enabled>                  
                    <lastModified>
                        <time>1592081530193</time>
                        <timezone>America/Chicago</timezone>
                    </lastModified>
                    <pruningSettings>
                        <pruneMetaDataDays>30</pruneMetaDataDays>
                        <pruneContentDays>15</pruneContentDays>
                        <archiveEnabled>true</archiveEnabled>
                    </pruningSettings>
                </com.mirth.connect.model.ChannelMetadata>
            </entry>
            ...
        </map>

    .EXAMPLE
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (
        # A mirth session is required. You can obtain one or pipe one in from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # If true, return a hashtable of the metadata, using the channel id as the key.
        [Parameter()]
        [switch]$asHashtable = $false,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Get-MirthServerChannelMetadata Beginning"
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }        
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
        $uri = $serverUrl + '/api/server/channelMetadata'
        Write-Debug "Invoking GET Mirth at $uri"
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"
            if ($asHashtable) { 
                # construct a hashtable, channel id to metadata for return
                $returnMap = @{}
                foreach ($entry in $r.map.entry) { 
                    $channelId = $entry.string
                    $metaData  = $entry.SelectSingleNode("com.mirth.connect.model.ChannelMetadata")
                    $returnMap[$channelId] = $metaData
                }
                return $returnMap
            } else { 
                return $r
            }
        }
        catch {
            Write-Error $_
        }
    }        
    END { 
        Write-Debug "Get-MirthServerChannelMetadata Ending"
    }
}  # Get-MirthServerChannelMetadata 

function global:Set-MirthServerChannelMetadata { 
    <#
    .SYNOPSIS
        Sets all server channel metadata from an XML payload string or file path.

    .DESCRIPTION
        Sends a map of channel id to metadata to the server to set all server channel metadata.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        This command expects input as an xml string or a path to a file containing the xml.
        $payLoad is xml describing the set of channel tags to be uploaded:

    .OUTPUTS

    .EXAMPLE

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of set of channelTags to be added
        [Parameter(ParameterSetName="xmlProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payLoad,

        # path to file containing the xml for the payload
        [Parameter(ParameterSetName="pathProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payloadFilePath,     

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )   
    BEGIN { 
        Write-Debug "Set-MirthServerChannelMetadata Beginning"
    }
    PROCESS { 
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$payloadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A server channel metadata XML payLoad string is required!"
                return $null
            } else {
                Write-Debug "Loading server channel metadata from path $payLoadFilePath"
                [xml]$payloadXML = Get-Content $payLoadFilePath  
            }
        } else {
            $payloadXML = [xml]$payLoad
        }

        $uri = $serverUrl + '/api/server/channelMetadata'
        $headers = @{}
        $headers.Add("Accept","application/xml")  

        Write-Debug "PUT to Mirth $uri "

        try {
            # Returns the response gotten from the server (we pass it on).
            #
            Invoke-RestMethod -WebSession $session -Uri $uri -Method PUT  -ContentType 'application/xml'  -TimeoutSec 20 -Body $payloadXML.OuterXml
        }
        catch [System.Net.WebException] {
            throw $_
        }
    } 
    END { 
        Write-Debug "Set-MirthServerChannelMetadata Ending"
    }    
}  # Set-MirthServerChannelMetadata 

function global:Get-MirthChannelTags {
    <#
    .SYNOPSIS
        Gets the Mirth Channel Tags

    .DESCRIPTION
        Return xml object describing all channel tags defined and listing the channel ids that belong to them.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all channel groups are returned.  Otherwise, only the channel groups with the 
        id values specified are returned.

    .OUTPUTS
        Returns an XML object that represents a set of channelTag objects:

        <set>
          <channelTag>
            <id>c135989c-9e1c-45f3-9b7e-a31f5ff2ea45</id>
            <name>White Tag</name>
            <channelIds>
              <string>014d299a-d972-4ae6-aa48-a2741f78390c</string>
            </channelIds>
            <backgroundColor>
              <red>255</red>
              <green>255</green>
              <blue>255</blue>
              <alpha>255</alpha>
            </backgroundColor>
          </channelTag>
          <channelTag>
            <id>5a123c6b-aacd-4be5-8c21-a981ce94a95e</id>
            <name>Red Tag</name>
            <channelIds>
              <string>e0e315bc-e064-4a6c-bc60-e26c2b4846b7</string>
            </channelIds>
            <backgroundColor>
              <red>255</red>
              <green>0</green>
              <blue>0</blue>
              <alpha>255</alpha>
            </backgroundColor>
          </channelTag>
          <channelTag>
            <id>a18cdca9-e8d2-445f-b844-d1418e0acea8</id>
            <name>Blue Tag</name>
            <channelIds>
              <string>014d299a-d972-4ae6-aa48-a2741f78390c</string>
            </channelIds>
            <backgroundColor>
              <red>0</red>
              <green>102</green>
              <blue>255</blue>
              <alpha>255</alpha>
            </backgroundColor>
          </channelTag>
        </set>

    .EXAMPLE
        Get-MirthChannelTags -saveXML -outFile nrg-channel-tags.xml
        $channelGroups = Get-MirthChannelTags -connection $connection 
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

    
        # A mirth session is required. You can obtain one or pipe one in from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN {
        Write-Debug "Get-MirthChannelTags Beginning" 
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }        
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/server/channelTags'
        Write-Debug "Invoking GET Mirth at $uri"
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
        }
        catch {
            Write-Error $_
        }
    }
    END { 
        Write-Debug "Get-MirthChannelTags Ending" 
    } 
}  #  Get-MirthChannelTags

function global:Set-MirthChannelTags { 
    <#
    .SYNOPSIS
        Adds or updates Mirth channel tags in bulk. 

    .DESCRIPTION
        Updates channel tags. 

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        This command expects input as an xml string or a path to a file containing the xml.
        $payLoad is xml describing the set of channel tags to be uploaded:

            <set>
                <channelTag>
                    <id>fcf80796-3547-4b6d-a06c-c62a379ea655</id>
                    <name>TEST</name>
                    <channelIds>
                        <string>de882379-b348-4855-9a84-4d83649aed08</string>
                    </channelIds>
                    <backgroundColor>
                        <red>255</red>
                        <green>0</green>
                        <blue>0</blue>
                        <alpha>255</alpha>
                    </backgroundColor>
                </channelTag>
                [...]]
                <channelTag>
                    <id>5a123c6b-aacd-4be5-8c21-a981ce94a95e</id>
                    <name>Red Tag</name>
                    <channelIds>
                        <string>014d299a-d972-4ae6-aa48-a2741f78390c</string>
                        <string>e0e315bc-e064-4a6c-bc60-e26c2b4846b7</string>
                    </channelIds>
                    <backgroundColor>
                        <red>255</red>
                        <green>0</green>
                        <blue>0</blue>
                        <alpha>255</alpha>
                    </backgroundColor>
                </channelTag>
            </set>        

    .OUTPUTS

    .EXAMPLE

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of set of channelTags to be added
        [Parameter(ParameterSetName="xmlProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payLoad,

        # path to file containing the xml for the payload
        [Parameter(ParameterSetName="pathProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payloadFilePath,     

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )   
    BEGIN { 
        Write-Debug "Set-MirthChannelTags Beginning"
    }
    PROCESS { 
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$payloadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A channelTag set XML payLoad string is required!"
                return $null
            } else {
                Write-Debug "Loading channelTag XML from path $payLoadFilePath"
                [xml]$payloadXML = Get-Content $payLoadFilePath  
            }
        } else {
            $payloadXML = [xml]$payLoad
        }

        $msg = 'Importing channelTags [' + $payloadXML.set.channelTag.name + ']...'
        Write-Debug $msg
        
        $uri = $serverUrl + '/api/server/channelTags'
        $headers = @{}
        $headers.Add("Accept","application/xml")  

        Write-Debug "PUT to Mirth $uri "

        try {
            # Returns the response gotten from the server (we pass it on).
            #
            Invoke-RestMethod -WebSession $session -Uri $uri -Method PUT  -ContentType 'application/xml'  -TimeoutSec 20 -Body $payloadXML.OuterXml
        }
        catch [System.Net.WebException] {
            throw $_
        }
    } 
    END { 
        Write-Debug "Set-MirthChannelTags Ending"
    }  
}  #  Set-MirthChannelTags

function global:Set-MirthTaggedChannels {
    <#
    .SYNOPSIS
        Deletes, creates, or assigns an existing tag to a selected list of, or all, channels. 

    .DESCRIPTION
        A flexible command that can be used to tag channels en masse or by list of channel id.
        It can be used to create tags on the fly, to update, or to remove them.
        
        Updates or creates tags and assigns them to channels.  The function accepts either
        the id of an existing tag, or the name of an tag, which will be created if it does 
        not exist.  If the -remove switch is specified, the channel Tag is deleted.

    .INPUTS
        -connection  MirthConnection custom object is required. See Connect-Mirth.

        -tagId       the guid id of a channel tag, which must exist.

        -tagName    If the id is not provided, then the name of the existing tag, or the title of the new tag.

        -remove     A flag which indicates removal of the channel tag.

        -channelIds An optional array of strings for the channel ids tagged by this channel.
                    No effect if remove is set.

        -replaceChannels    if true, the existing channels assigned to the tag are replaced with the channelIds

    .OUTPUTS

        string      Returns the channelTag ID (whether udpated or newly created)

    .EXAMPLE
        Set-MirthTaggedChannels -tagName 'HALO-RR08' -alpha 255 -red 200 -green 0 -blue 255 -channelIds 0e06727d-55f7-4c91-a363-80521dc834b3 -replaceChannels

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # the channelTag id guid, if not provided one will be generated
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string]$tagId,

        # the property key name
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string]$tagName,

        # If no channelIds are specified, the channelTag is entirely removed from the server.
        [Parameter()]
        [switch]$remove = $false,
        
        # an optional array of channelId guids
        # the channelTag id guid strings that the tag applies to when creating or updating a tag
        # if the remove switch is set, these channel ids will removed from the tags set of channelIds
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$channelIds,

        # If true, replaces the tag's existing channel assignments, 
        # otherwise, adds to them, ignored when the remove switch is set.
        [Parameter()]
        [switch]$replaceChannels = $false,

        # the alpha value, 0-255
        # has no effect if the remove tag is specfiied
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [ValidateRange(0,255)]
        [int]$alpha = 255,
   
        # the red value, 0-255
        # has no effect if the remove tag is specfiied
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [AllowNull()]
        [ValidateRange(0,255)]
        [int]$red,
        
        # the green value,, 0-255
        # has no effect if the remove tag is specfiied
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [AllowNull()]
        [ValidateRange(0,255)]
        [int]$green,

        # the blue value, 0-255
        # has no effect if the remove tag is specfiied
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [AllowNull()]
        [ValidateRange(0,255)]
        [int]$blue,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )  
    BEGIN { 
        Write-Debug "Set-MirthTaggedChannels Beginning"
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }

        # if the list of channels is empty, then go and fetch a complete list of 
        # channel ids

        if ($channelIds.count -gt 0) { 
            # they provided some channel ids
            if ($remove) {
                Write-Debug "Removing $($channelIds.count) channels from this tag."
            } else {
                Write-Debug "Assigning $($channelIds.count) channels to this tag."
            }
        } else { 
            # go and get them all
            Write-Debug "Assigning tag to all existing channels"
            $channelIds = $(Get-MirthChannels ).list.channel.id
        }

        # First, fetch the current set of Mirth channel tags.

        $currentTagSet = Get-MirthChannelTags -connection $connection -saveXML:$saveXML
        [xml]$targetTag = $null
        $tagIdMap = @{}
        $tagNameMap = @{}
        Write-Debug "Building channelTag maps..."
        foreach ($channelTag in $currentTagSet.set.channelTag) { 
            $tmpTagId = $channelTag.id
            $tmpTagName = $channelTag.name
            Write-Debug "Tag Read: $tmpTagId - $tmpTagName"
            $tagIdMap.add($tmpTagId,$channelTag)
            $tagNameMap.add($tmpTagName,$channelTag)
        }
        # If a tagId was provided, see if it exists, else
        # if name provided, see if it exists.
        if (-not ([string]::IsNullOrEmpty($tagId) -or [string]::IsNullOrWhiteSpace($tagId))) {
            # tag id was specified, does id exist in current Tag set
            Write-Debug "Tag id was specified: $tagId"
            $foundTag = $tagIdMap[$tagId]
            if ($null -ne $foundTag) { 
                Write-Debug "Type of found target id $($foundTag.getType())"
                $newTag = New-Object -TypeName xml
                $newTag.AppendChild($newTag.ImportNode($foundTag, $true)) | Out-Null
                $targetTag = $newTag
            } else { 
                # The tag id does not exist, so they must be trying to add
                # ensure that the tagName parameter was also set
                Write-Debug "Adding tagId: $tagId"
                if ((-not $PSBoundParameters.containsKey("tagName")) -or ([string]::IsNullOrEmpty($tagName))) { 
                    Throw "A tagName must be provided to add a new tag!"
                }
            }            
        } 
        if ($null -eq $targetTag) {
            # a tag id was not provided, or it was not found
            # search by tag name
            Write-Debug "Searching for tag by name..."
            $foundTag = $tagNameMap["$tagName"]
            if ($null -ne $foundTag) { 
                Write-Debug "The channel tag was found by name."
                $newTag = New-Object -TypeName xml
                $newTag.AppendChild($newTag.ImportNode($foundTag, $true)) | Out-Null
                $targetTag = $newTag
            }
            
        } else { 
            # tag was found by id
            Write-Debug "Existing channel tag found by id."
            #check to see if we are updating the name?
        }
        # At this point, if we still don't have the current Tag
        # then, we must be creating it, unless remove switch
        if ($null -eq $targetTag) { 
            Write-Debug "No existing channelTag has been found."
            if ([string]::IsNullOrEmpty($tagId)) { 
                Write-Debug "No tag id was provided, generating new tag guid..."
                $tagId = $(New-Guid).toString()
                Write-Debug "New tag id = $tagId"
            }
            if (-not $remove) {
                Write-Debug "Creating new channel tag object"
                [xml]$targetTag = New-MirthChannelTagObject -tagId $tagId -tagName $tagName -channelIds $channelIds -alpha $alpha -red $red -green $green -blue $blue 
            }
        } else { 
            Write-Debug "Channel Tag already exists... updating it."
        }
        if ($remove -and ($null -eq $targetTag)) { 
            Write-Verbose "Channel Tag $tagId was not found to be removed."
            return $null
        }
        Write-Debug "Creating new tag set..."
        Write-Verbose "targetTag ID:   $($targetTag.channelTag.id)"
        Write-Verbose "targetTag Name: $($targetTag.channelTag.name)"

        [xml]$newTagSet = "<set />"
        # Write out a new set of tags skipping the tag if it is being 
        # removed, otherwise addit it at the end... 
        $found = $false
        foreach ($channelTag in $currentTagSet.set.channelTag) { 
            Write-Debug "Comparing $($channelTag.id) to $($targetTag.channelTag.id)"
            if ($channelTag.id -eq $targetTag.channelTag.id) { 
                Write-Debug "Match on tag id"
                if ((-not $remove) -or ($remove -and ($channelIds.Count -gt 0))) { 
                    $found = $true;
                    # add it to new set, possibly updating name and colors
                    Write-Debug "Updating channel Tag"
                    $targetTag.channelTag.name = $tagName
                    $targetTag.channelTag.backgroundColor.alpha = [string]$alpha
                    $targetTag.channelTag.backgroundColor.red   = [string]$red
                    $targetTag.channelTag.backgroundColor.green = [string]$green 
                    $targetTag.channelTag.backgroundColor.blue  = [string]$blue 
                    #  update the channel ids here...
                    [string[]]$mergedChannelIds = @()
                    if ($replaceChannels) { 
                        Write-Debug "Replacing existing tag channel assignments"
                        Write-Debug "There will be $($channelIds.count) channels assigned to this tag."
                        $mergedChannelIds = $channelIds
                    } else { 
                        Write-Debug "Merging existing tag channel assignments"
                        [string[]] $currentChannels = $channeltag.channelIds.string
                        Write-Debug "There are $($currentChannels.count) channels currently assigned to this tag."
                        if ($remove) {
                            Write-Debug "Checking for removed channels..."
                            $remainingChannelIds = @()
                            foreach ($id in $currentChannels) {
                                Write-Debug "Checking [$id] against list: [$channelIds]"
                                if (-not ($channelIds -contains $id)) {
                                    $remainingChannelIds = $remainingChannelIds += $id
                                } else { 
                                    Write-Debug "Omitting channel id $id from new list."
                                }
                            }
                            Write-Debug "After removing channels, the tag is assigned to $($remainingChannelIds.Count) channels."
                            $mergedChannelIds = $remainingChannelIds
                        } else { 
                            Write-Debug "There are $($channelIds.count) channels to be merged to this tag."
                            $mergedChannelIds = $channelIds + $currentChannels | Sort-Object -Unique
                            Write-Debug "There are $($mergedChannelIds.count) merged channels assigned to this tag."
                        }

                    }
                    Write-Debug "Clearing all channel ids from tag..."
                    $channelIdsNode = $targetTag.SelectSingleNode(".//channelIds")
                    $channelIdsNode.RemoveAll() 

                    Write-Debug "Adding merged channel id nodes..."
                    Add-PSMirthStringNodes -parentNode $channelIdsNode -values $mergedChannelIds | Out-Null
                    Write-Debug "Tag update complete"

                    Write-Debug "Appending tag to set"
                    $newTagSet.DocumentElement.AppendChild($newTagSet.ImportNode($targetTag.channelTag,$true)) | Out-Null
                } else { 
                    Write-Debug "Omitting tag from new set"
                }
            } else {
                Write-Debug "Existing tag not a target, keeping in list."
                # existing tag not a match, keep in new set
                $newTagSet.DocumentElement.AppendChild($newTagSet.ImportNode($channelTag,$true)) | Out-Null
            }
        }  # foreach current channelTag...

        # we have now kept any tags not affected
        # if not remove, now we add the newly generated channelTag
        if ((-not $remove) -and (-not $found)) { 
            Write-Debug "Adding new channel tag to new tag set"
            $newTagSet.DocumentElement.AppendChild($newTagSet.ImportNode($targetTag.channelTag,$true)) | Out-Null
        } 
        Set-MirthChannelTags -payLoad $newTagSet.OuterXml | Out-Null
        return $targetTag.channelTag.id
    }
    END { 
        Write-Debug "Set-MirthTaggedChannels Ending"
    } 
}  #  Set-MirthTaggedChannels

function global:Get-MirthConfigMap {
    <#
    .SYNOPSIS
        Gets the Mirth configuration map. Returns an xml object to the Pipeline.

    .DESCRIPTION
        Fetches the Mirth configuration map.

    .INPUTS
        A -connection  MirthConnection object is required. See Connect-Mirth.

    .OUTPUTS
        A map of entries with string key names and com.mirth.connect.util.ConfigurationProperty objects.

        <map>
          <entry>
            <string>file-inbound-folder</string>
            <com.mirth.connect.util.ConfigurationProperty>
              <value>C:\FileReaderInput</value>
              <comment>This is a comment describing the file-inbouind-reader property.</comment>
            </com.mirth.connect.util.ConfigurationProperty>
          </entry>
          <entry>
            <string>db.url</string>
            <com.mirth.connect.util.ConfigurationProperty>
              <value>jdbc:thin:@localhost:1521\dbname</value>
              <comment>This is a fake db url property.</comment>
            </com.mirth.connect.util.ConfigurationProperty>
          </entry>
        </map>
        <map>
          <entry>
            <string>file-inbound-folder</string>
            <com.mirth.connect.util.ConfigurationProperty>
              <value>C:\FileReaderInput</value>
              <comment>This is a comment describing the file-inbouind-reader property.</comment>
            </com.mirth.connect.util.ConfigurationProperty>
          </entry>
          <entry>
            <string>db.url</string>
            <com.mirth.connect.util.ConfigurationProperty>
              <value>jdbc:thin:@localhost:1521\dbname</value>
              <comment>This is a fake db url property.</comment>
            </com.mirth.connect.util.ConfigurationProperty>
          </entry>
        </map>

        If the -asHashtable switch is specified, the response is a PowerShell hashtable.

    .EXAMPLE
        Connect-Mirth | Get-MirthConfigMap 
        Get-MIrthConfigMap -asHashtable 

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # Switch, if true, returns hashtable response, otherwise XML
        [Parameter()]
        [switch]$asHashtable,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/server/configurationMap'
        Write-Debug "Invoking GET Mirth at $uri"
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"

            if (-not $asHashtable) { 
                return $r;
            } else { 
                Write-Debug "Converting XML response to hashtable"
                $returnMap = @{};
                $entries = $r.map.entry | Sort-Object { [string]$_.string }
                Write-Debug "There are $($entries.count) sorted entries to be placed into the hashtable..."
                foreach ($entry in $entries) { 
                    $key = $entry.'string'
                    $value = $entry.'com.mirth.connect.util.ConfigurationProperty'.'value'
                    Write-Debug ("Adding Key: $key with value: $value")
                    $returnMap[$key] = $value
                }         
                return $returnMap
            }
        } catch {
            Write-Error $_
        }
    }
    END {
    }
}  # Get-MirthConfigMap

function global:Set-MirthConfigMap {
    <#
    .SYNOPSIS
        Replaces the Mirth configuration map. 

    .DESCRIPTION
        Updates all entries in the configuration map. 

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        This command expects input in XML format, using the com.mirthy.connect.util.ConfigurationProperty 
        element to represent property values and description.

        $payLoad is xml describing the configuration map to be uploaded:

            <map>
              <entry>
                <string>file-inbound-folder</string>
                <com.mirth.connect.util.ConfigurationProperty>
                  <value>C:\FileReaderInput</value>
                  <comment>This is a descriptive comment describing the file-inbound-reader property.</comment>
                </com.mirth.connect.util.ConfigurationProperty>
              </entry>
              <entry>
                <string>db.url</string>
                <com.mirth.connect.util.ConfigurationProperty>
                  <value>jdbc:thin:@localhost:1521\dbname</value>
                  <comment>This is an example db url property.</comment>
                </com.mirth.connect.util.ConfigurationProperty>
              </entry>
            </map>

    .OUTPUTS

    .EXAMPLE
        $configMap = @"                

        "@
        Connect-Mirth | Add-MirthUser -payLoad $configMap 

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of the configuration map to be added
        [Parameter(ParameterSetName="xmlProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payLoad,

        # path to file containing the xml of the configuation map
        [Parameter(ParameterSetName="pathProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payloadFilePath,

        # If true, does not replace the current config map, merges with
        # the current settings, overwriting any that conflict
        [Parameter()]
        [switch]$merge = $false,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )    
    BEGIN { 
        Write-Debug "Set-MirthConfigMap Beginning"
        
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/server/configurationMap'
        [xml]$payLoadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A configuration map XML payLoad string is required!"
                return $null
            } else {
                Write-Debug "Loading channel XML from path $payLoadFilePath"
                try {
                    [xml]$payLoadXML = Get-Content $payLoadFilePath  
                } catch {
                    throw $_
                }
            }
        } else {
            Write-Debug "Creating XML payload from string: $payLoad"
            $payLoadXML = [xml]$payLoad
        }

        $currentConfigMap = $null
        if ($merge) {
            Write-Debug "Merge flag set, fetching current config map..."
            $currentConfigMap = Get-MirthConfigMap -connection $connection
            $currentConfigMapNode = $currentConfigMap.SelectSingleNode("/map")
            $currentEntries = $currentConfigMap.SelectNodes(".//entry")
            $currCount = $currentEntries.Count
            Write-Debug "Current config map contains $currCount entries."
            $mergeEntries = $payLoadXML.SelectNodes(".//entry")
            $mergeCount = $mergeEntries.Count
            Write-Debug "There are $mergeCount entries to be merged."
            foreach ($newEntry in $mergeEntries) { 
                Write-Debug "Merging property $($newEntry.string)"
                $currentNode = $currentConfigMap.SelectSingleNode(".//entry[./string = '$($newEntry.string)']")
                if ($null -ne $currentNode) {
                    Write-Debug "Updating existing property..."
                    $oldValue = $null
                    $currValueNode = $currentNode.SelectSingleNode(".//com.mirth.connect.util.ConfigurationProperty/value")
                    if ($null -ne $currValueNode) { 
                        $oldValue = $currValueNode.InnerText
                    } else { 
                        Write-Warning "Expected value node was not found!"
                    }
                    $oldComment = $null
                    $currCommentNode = $currentNode.SelectSingleNode(".//com.mirth.connect.util.ConfigurationProperty/comment")
                    if ($null -ne $currCommentNode) { 
                        $oldComment = $currCommentNode.InnerText
                    } else { 
                        # we need to add a comment node
                        $configPropertyNode = $currentNode.SelectSingleNode(".//com.mirth.connect.util.ConfigurationProperty")
                        $currCommentNode = $currentConfigMap.CreateElement('comment')
                        $currCommentNode = $configPropertyNode.AppendChild($currCommentNode)
                    }                    

                    $newValue = $newEntry.'com.mirth.connect.util.ConfigurationProperty'.value
                    $newComment = $newEntry.'com.mirth.connect.util.ConfigurationProperty'.comment

                    Write-Debug "Updating old value [$oldValue] property to new value [$newValue]"
                    $currValueNode.set_InnerText($newValue)
                    
                    Write-Debug "Updating old comment [$oldComment] property to new value [$newComment]"
                    $currCommentNode.set_InnerText($newComment)
                } else { 
                    Write-Debug "Adding new merged property..."
                    $currentConfigMapNode.AppendChild($currentConfigMap.ImportNode($newEntry, $True)) | Out-Null
                }
            }  # for all new merged properties
            Write-Debug "Merge complete, replacing payload with merged map"
            $payLoadXML = $currentConfigMap
        }  # if merging

        $headers = @{}
        $headers.Add("Accept","application/xml")

        Write-Debug "Invoking PUT Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -ContentType 'application/xml' -Method PUT -WebSession $session -Body $payLoadXML.OuterXml
            Write-Debug "...done."
            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $output = "Configuration Map Updated Successfully: $payLoad"
                Set-Content -Path $o -Value $output   
            }
            Write-Verbose "$($r.OuterXml)"

            return $r
        }
        catch {
            Write-Error $_
        }  
    }
    END {
        Write-Debug "Set-MirthConfigMap Ending"
    } 
}  #  Set-MirthConfigMap

function global:Get-MirthExtensionProperties { 
    <#
    .SYNOPSIS
        Get the properties for a Mirth Extension, identified by name.

    .DESCRIPTION
        Returns an XML object describing the properties of the extension 
        identified by targetId.

    .INPUTS
        -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId The name of the extension to get the properties for.

    .OUTPUTS
        [xml], 

        <properties>
            <property name="KeyStore">
            /u3+7QAAAAIAAAABAAAAAQAEdGVzdAAAAXIlmNosAAAFADCCBPwwDgYKKwYBBAEqAhEBAQUABIIE&#xd;
            6PSUqo9CFNaayZxCmMeR6ThcKafQrrkaPDY6VOHZskDTDMbZFtuAoZ6JWO7soavfvCrJw4RWzn96&#xd;
                [...]
            4ENsek9dTjmjzfc233OfjSyQgylaIRdbhJBBN7t5zRfMrj/5IBnlAYMYqClYT9aTqrs1suYRrEyX&#xd;
            fhkQEX+Ccf+nypUQa6CZUS+m8+B+3afWp9N1oEWimnJ6To24OLxyW/xf2l/xBn5lWNfTZdB+9FGm&#xd;
            qVbijeiKupsPFC+U6qGWw9iCml8IOXJB3TnzMtLYPsMl5NNHIoUyQpuUsHL0YInO1OMKf4TO+Urr&#xd;
            x7uaUr3+CRvy3l03uEJ1CG79EqjQWgZt6Pfg+pJVsMXdgA==&#xd;
          </property>
            <property name="KeyStorePassword">4403a343-5c9d-4b1e-9cb9-f495e4e56586</property>
            <property name="TrustStore">
            /u3+7QAAAAIAAAAAIouZUIjaIVohN/fTqy/BgnB2Uis=&#xd;
          </property>
            <property name="settings">
            &lt;com.mirth.connect.plugins.ssl.model.SSLManagerSettings&gt;
              &lt;validationLoginWarning&gt;true&lt;/validationLoginWarning&gt;
              &lt;expirationTimeUntil&gt;30d&lt;/expirationTimeUntil&gt;
          &lt;/com.mirth.connect.plugins.ssl.model.SSLManagerSettings&gt;</property>
        </properties>

    .EXAMPLE
        Connect-Mirth | Get-MirthExtensionProperties -targetId "User Authorization" -decode
        Connect-Mirth | Get-MirthExtensionProperties -targetId "SSL Manager"  -decode

    .LINK
        Links to further documentation.

    .NOTES

    #>
    [OutputType([xml])] 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The name of the extension that we want to fetch the properties of
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$targetId,

        # Switch to decode html encoded data
        [Parameter()]
        [switch]$decode = $false,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-' + $targetId + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Get-MirthExtensionProperties Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
        
        $targetId = [uri]::EscapeDataString($targetId)
        $uri = $serverUrl + '/api/extensions/' + $targetId + "/properties"
        Write-Debug "Invoking GET Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session  -ContentType 'application/xml'
            Write-Debug "...done."
            if ($decode) {
                Write-Debug "Decoding XML escaped data..." 
                $decoded = [System.Web.HttpUtility]::HtmlDecode($r.OuterXml)
                $r = [xml]$decoded
            }

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"

            return $r
        }
        catch {
            Write-Error $_
        }    
    }
    END { 
        Write-Debug "Get-MirthExtensionProperties Ending"
    }
}  #  Get-MirthExtensionProperties

function global:Set-MirthExtensionProperties { 
    <#
    .SYNOPSIS
        Set the properties for a Mirth Extension, identified by name.

    .DESCRIPTION
        

    .INPUTS
        -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId The name of the extension to get the properties for.

    .OUTPUTS
        [xml], 

    .EXAMPLE
        $payLoad = @"
        <properties>
          <property name="KeyStore">/u3+7QAAAAIAAAABAAAAAQAEdGVzdAAAAXIlmNosAAAFADCCBPwwDgYKKwYBBAEqAhEBAQUABIIE
        6PSUqo9CFNaayZxCmMeR6ThcKafQrrkaPDY6VOHZskDTDMbZFtuAoZ6JWO7soavfvCrJw4RWzn96
            [...]
        4ENsek9dTjmjzfc233OfjSyQgylaIRdbhJBBN7t5zRfMrj/5IBnlAYMYqClYT9aTqrs1suYRrEyX
        fhkQEX+Ccf+nypUQa6CZUS+m8+B+3afWp9N1oEWimnJ6To24OLxyW/xf2l/xBn5lWNfTZdB+9FGm
        qVbijeiKupsPFC+U6qGWw9iCml8IOXJB3TnzMtLYPsMl5NNHIoUyQpuUsHL0YInO1OMKf4TO+Urr
        x7uaUr3+CRvy3l03uEJ1CG79EqjQWgZt6Pfg+pJVsMXdgA==</property>
          <property name="KeyStorePassword">changeit</property>
          <property name="TrustStore">/u3+7QAAAAIAAAAAIouZUIjaIVohN/fTqy/BgnB2Uis=
        </property>
          <property name="settings">&lt;com.mirth.connect.plugins.ssl.model.SSLManagerSettings&gt;
          &lt;validationLoginWarning&gt;true&lt;/validationLoginWarning&gt;
          &lt;expirationTimeUntil&gt;30d&lt;/expirationTimeUntil&gt;
        &lt;/com.mirth.connect.plugins.ssl.model.SSLManagerSettings&gt;</property>
        </properties>
        "@
        Connect-Mirth | Set-MirthExtensionProperties -targetId "SSL Manager" -payLoad $payLoad 

    .LINK
        Links to further documentation.

    .NOTES

    #>
    [OutputType([xml])] 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The name of the extension that we want to fetch the properties of
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$targetId,

        
        # xml of the properties to be added
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [xml]$payLoad,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-' + $targetId + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Set-MirthExtensionProperties Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
         
        $headers = @{}
        $headers.Add("Accept","application/xml")
        $targetId = [uri]::EscapeDataString($targetId)
        $uri = $serverUrl + '/api/extensions/' + $targetId + "/properties"
        Write-Debug "Invoking PUT Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -ContentType 'application/xml' -Method PUT -WebSession $session -Body $payLoad.OuterXml
            Write-Debug "...done."
            if ($decode) { 
                $decoded = [System.Web.HttpUtility]::HtmlDecode($r.OuterXml)
                $r = [xml]$decoded
            }
            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"

            return $r
        }
        catch {
            Write-Error $_
        }    
    }
    END { 
        Write-Debug "Set-MirthExtensionProperties Ending"
    }
}  #  Set-MirthExtensionProperties

function global:Get-MirthGlobalScripts { 
    <#
    .SYNOPSIS
        Gets the Mirth server global scripts.

    .DESCRIPTION
        Returns an XML object representing a map of global scripts.  
        The first string of each map entry is the name of the global script.
        The second string is the xml escaped javascript.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS

        [xml] object containing a map where each entry name value pair is
        a global script:  Deploy, Undeploy, Preprocessor, and Postprocessor

        <map>
	        <entry>
		        <string>Undeploy</string>
		        <string>// This script executes once for each deploy, undeploy, or redeploy task
        logger.info("=== GLOBAL UNDEPLOY SCRIPT EXECUTING ===");
        return;</string>
	        </entry>
	        <entry>
		        <string>Postprocessor</string>
		        <string>// This script executes once after a message has been processed
        logger.info("=== GLOBAL POSTPROCESSOR SCRIPT EXECUTING ===");
        return;</string>
	        </entry>
	        <entry>
		        <string>Deploy</string>
		        <string>// This script executes once for each deploy or redeploy task
        logger.info("=== GLOBAL DEPLOY SCRIPT EXECUTING ===");
        return;</string>
	        </entry>
	        <entry>
		        <string>Preprocessor</string>
		        <string>// Modify the message variable below to pre process data
        logger.info("=== GLOBAL PREPROCESSOR SCRIPT EXECUTING ===");
        return message;</string>
	        </entry>
        </map>

    .EXAMPLE
        
    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Get-MirthGlobalScripts Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/server/globalScripts'
        Write-Debug "Invoking GET Mirth at $uri"
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session -ContentType 'application/xml' 
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug "Get-MirthGlobalScripts Ending"
    }

}  #  Get-MirthGlobalScripts

function global:Set-MirthGlobalScripts { 
    <#
    .SYNOPSIS
        Replaces the Mirth global scripts. 

    .DESCRIPTION
        Replaces all global scripts, deploy, undeploy, preprocessor and postprocessor 

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        This command expects input in XML format, using the com.mirthy.connect.util.ConfigurationProperty 
        element to represent property values and description.

        $payLoad is xml describing a map containing string, string pairs, where the first string is the
        name of the global script and the second is the xml escaped javascript of the global script:

        <map>
	        <entry>
		        <string>Undeploy</string>
		        <string>// This script executes once for each deploy, undeploy, or redeploy task
        logger.info("=== GLOBAL UNDEPLOY SCRIPT EXECUTING ===");
        return;</string>
	        </entry>
	        <entry>
		        <string>Postprocessor</string>
		        <string>// This script executes once after a message has been processed
        logger.info("=== GLOBAL POSTPROCESSOR SCRIPT EXECUTING ===");
        return;</string>
	        </entry>
	        <entry>
		        <string>Deploy</string>
		        <string>// This script executes once for each deploy or redeploy task
        logger.info("=== GLOBAL DEPLOY SCRIPT EXECUTING ===");
        return;</string>
	        </entry>
	        <entry>
		        <string>Preprocessor</string>
		        <string>// Modify the message variable below to pre process data
        logger.info("=== GLOBAL PREPROCESSOR SCRIPT EXECUTING ===");
        return message;</string>
	        </entry>
        </map>



    .OUTPUTS

    .EXAMPLE

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of the configuration map to be added
        [Parameter(ParameterSetName="xmlProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payLoad,

        # path to file containing the xml of the configuation map
        [Parameter(ParameterSetName="pathProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payloadFilePath,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )  
    BEGIN { 
        Write-Debug "Set-MirthGlobalScripts Beginning"
    }
    PROCESS {
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/server/globalScripts' 
        [xml]$payLoadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A configuration map XML payLoad string is required!"
                return $null
            } else {
                Write-Debug "Loading channel XML from path $payLoadFilePath"
                [xml]$payLoadXML = Get-Content $payLoadFilePath  
            }
        } else {
            Write-Debug "Creating XML payload from string: $payLoad"
            $payLoadXML = [xml]$payLoad
        }
        $headers = @{}
        $headers.Add("Accept","application/xml")

        Write-Debug "Invoking PUT Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -ContentType 'application/xml' -Method PUT -WebSession $session -Body $payLoadXML.OuterXml
            Write-Debug "...done."
            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile  
                $output = "Global Scripts Updated Successfully: $payLoad"
                Set-Content -Path $o -Value $output   
            }
            Write-Verbose "$($r.OuterXml)"

            return $r
        }
        catch {
            Write-Error $_
        }  
    }
    END {
        Write-Debug "Set-MirthGlobalScripts Ending" 
    }

}  #  Set-MirthGlobalScripts

function global:Get-MirthServerSettings { 
    <#
    .SYNOPSIS
        Gets the Mirth server settings.

    .DESCRIPTION
        Returns an XML object the Mirth server settings.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS

        [xml] object describing the server settings:

        <serverSettings>
          <serverName>LOCAL-TEST-MIRTH</serverName>
          <clearGlobalMap>true</clearGlobalMap>
          <queueBufferSize>1000</queueBufferSize>
          <defaultMetaDataColumns>
            <metaDataColumn>
              <name>SOURCE</name>
              <type>STRING</type>
              <mappingName>mirth_source</mappingName>
            </metaDataColumn>
            <metaDataColumn>
              <name>TYPE</name>
              <type>STRING</type>
              <mappingName>mirth_type</mappingName>
            </metaDataColumn>
          </defaultMetaDataColumns>
          <smtpHost>mail.datasprite.com</smtpHost>
          <smtpPort>587</smtpPort>
          <smtpTimeout>5000</smtpTimeout>
          <smtpFrom>admin@datasprite.com</smtpFrom>
          <smtpSecure>tls</smtpSecure>
          <smtpAuth>true</smtpAuth>
          <smtpUsername>admin@datasprite.com</smtpUsername>
          <smtpPassword>turn1pgr8vy</smtpPassword>
        </serverSettings>


    .EXAMPLE
        Connect-Mirth | Get-MirthServerSettings -saveXML
        
    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN {
        Write-Debug "Get-MirthServerSettings Beginning" 

    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
 
        $uri = $serverUrl + '/api/server/settings'
        Write-Debug "Invoking GET Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session 
            Write-Debug "...done."
            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
        }
        catch {
            Write-Error $_
        }     
    }
    END { 
        Write-Debug "Get-MirthServerSettings Ending" 
    }

}  #  Get-MirthServerSettings

function global:Set-MirthServerSettings { 
    <#
    .SYNOPSIS
        Sets the Mirth server settings.

    .DESCRIPTION
        Returns an XML object the Mirth server settings.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        
        [xml] object describing the server settings:

    .OUTPUTS
        <boolean>true<boolean> if successful, otherwise false

    .EXAMPLE
        
    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of the configuration map to be added
        [Parameter(ParameterSetName="xmlProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payLoad,

        # path to file containing the xml of the configuation map
        [Parameter(ParameterSetName="pathProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payloadFilePath,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/server/settings'
        [xml]$payLoadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A configuration map XML payLoad string is required!"
                return $null
            } else {
                Write-Debug "Loading channel XML from path $payLoadFilePath"
                [xml]$payLoadXML = Get-Content $payLoadFilePath  
            }
        } else {
            Write-Debug "Creating XML payload from string: $payLoad"
            $payLoadXML = [xml]$payLoad
        }
        $headers = @{}
        $headers.Add("Accept","application/xml")

        Write-Debug "Invoking PUT Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -ContentType 'application/xml' -Method PUT -WebSession $session -Body $payLoadXML.OuterXml
            Write-Debug "...done."
            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $output = "Server Settings Updated Successfully: $payLoad"
                Set-Content -Path $o -Value $output   
            }
             Write-Verbose "$($r.OuterXml)"

            return $r
        }
        catch {
            Write-Error $_
        }  
    }
    END {
    }

}  #  Set-MirthServerSettings

function global:Get-MirthSystemProperties { 
    <#
    .SYNOPSIS
        Gets the Mirth server java system properties, 
        and returns them as an XML object.

    .DESCRIPTION
        This command relies on a tool probe channel to obtain server-side
        information not normally available through the REST API.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        [xml] object representing the mirth.properties file in XML form.

        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd"[]>
        <properties>
        <comment>exported by probe channel</comment>
        <entry key="keystore.keypass">81uWxplDtB</entry>
        <entry key="password.minspecial">0</entry>
        [...]
        <entry key="http.host">0.0.0.0</entry>
        </properties>

    .EXAMPLE
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # If true, return the properties as a hashtable instead of an xml object for convenience
        [Parameter()]
        [switch]$asHashtable = $false,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )     
    BEGIN { 
        Write-Debug "Get-MirthSystemProperties Beginning"
    }
    PROCESS { 

        # import the tool channel and deploy it
        Write-Debug "Invoking tool channel Probe_Java_System_Properties.xml"
        $toolPath = "$PSSCriptRoot/tools/Probe_Java_System_Properties.xml"
        [xml]$toolPayLoad = Invoke-PSMirthTool -connection $connection -toolPath $toolPath -saveXML:$saveXML
        if ($null -ne $toolPayLoad) {
            Write-Verbose $toolPayLoad.OuterXml
            if (-not $asHashtable) { 
                if ($saveXML) { 
                    [string]$outPath = Get-PSMirthOutputFolder -create
                    $outPath = Join-Path $outPath $outFile 
                    Write-Debug "Saving to $outPath"    
                    $toolPayLoad.save($outPath)
                }
                return $toolPayLoad
            } else { 
                Write-Debug "Converting XML response to hashtable"
                $returnMap = @{};
                if ($saveXML) {
                    [string]$outPath = Get-PSMirthOutputFolder -create
                    $outPath = Join-Path $outPath $outFile 
                    if (Test-Path -Path $outPath) {
                        Clear-Content -path $outPath 
                        $line = "#  PS_Mirth fetched from $($connection.serverUrl) on $(Get-Date)"
                        Add-Content -Path $outPath -value $line
                    }
                } 
                foreach ($entry in $toolPayLoad.properties.entry) { 
                    $key = $entry.Attributes[0].Value
                    $value = $entry.InnerText
                    Write-Debug ("Adding Key: $key with value: $value")
                    $returnMap[$key] = $value
                } 
                Write-Debug "Sorting by key for output..."
                $sorted = $returnMap.GetEnumerator() | Sort-Object -Property name 
                if ($saveXML) {
                    [string]$outPath = Get-PSMirthOutputFolder -create
                    $outPath = Join-Path $outPath $outFile 
                    Write-Debug "Saving hash map to $outPath"
                    foreach ($property in $sorted) { 
                        $key    = $property.Name
                        $value  = $property.Value
                        $line = “{0,-40} {1,1} {2}” -f $key, "=", $value
                        Add-Content -Path $outPath -value $line
                    }  
                }         
                return $returnMap
            }
        } else { 
            Throw "Mirth probe returned no results"
        }
    }
    END { 
        Write-Debug "Get-MirthSystemProperties Ending"
    }
} #  Get-MirthSystemProperties 


function global:Get-MirthServerProperties { 
    <#
    .SYNOPSIS
        Gets the Mirth server configuration property file, 
        located in the Mirth install folder at conf/mirth.properties, 
        and returns it as an XML object.

    .DESCRIPTION
        This command relies on a tool probe channel to obtain server-side
        information not normally available through the REST API.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        [xml] object representing the mirth.properties file in XML form.

        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd"[]>
        <properties>
        <comment>exported by probe channel</comment>
        <entry key="keystore.keypass">81uWxplDtB</entry>
        <entry key="password.minspecial">0</entry>
        [...]
        <entry key="http.host">0.0.0.0</entry>
        </properties>

    .EXAMPLE
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # If true, return the properties as a hashtable instead of an xml object for convenience
        [Parameter()]
        [switch]$asHashtable = $false,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )     
    BEGIN { 
        Write-Debug "Get-MirthServerProperties Beginning"
    }
    PROCESS { 
        # import the tool channel and deploy it
        Write-Debug "Invoking tool channel Probe_Mirth_Properties.xml"
        $toolPath = "$PSSCriptRoot/tools/Probe_Mirth_Properties.xml"
        [xml]$toolPayLoad = Invoke-PSMirthTool -connection $connection -toolPath $toolPath -saveXML:$saveXML
        if ($null -ne $toolPayLoad) {
            Write-Verbose $toolPayLoad.OuterXml
            if (-not $asHashtable) { 
                if ($saveXML) { 
                    [string]$outPath = Get-PSMirthOutputFolder -create
                    $outPath = Join-Path $outPath $outFile 
                    Write-Debug "Saving to $outPath"    
                    $toolPayLoad.save($outPath)
                }
                return $toolPayLoad
            } else { 
                Write-Debug "Converting XML response to hashtable"
                $returnMap = @{};
                if ($saveXML) {
                    [string]$outPath = Get-PSMirthOutputFolder -create
                    $outPath = Join-Path $outPath $outFile 
                    if (Test-Path -Path $outPath) {
                        Clear-Content -path $outPath 
                        $line = "#  PS_Mirth fetched from $($connection.serverUrl) on $(Get-Date)"
                        Add-Content -Path $outPath -value $line
                    }
                } 
                foreach ($entry in $toolPayLoad.properties.entry) { 
                    $key = $entry.Attributes[0].Value
                    $value = $entry.InnerText
                    Write-Debug ("Adding Key: $key with value: $value")
                    $returnMap[$key] = $value
                } 
                Write-Debug "Sorting by key for output..."
                $sorted = $returnMap.GetEnumerator() | Sort-Object -Property name 
                if ($saveXML) {
                    [string]$outPath = Get-PSMirthOutputFolder -create
                    $outPath = Join-Path $outPath $outFile 
                    Write-Debug "Saving hash map to $outPath"
                    foreach ($property in $sorted) { 
                        $key    = $property.Name
                        $value  = $property.Value
                        $line = “{0,-40} {1,1} {2}” -f $key, "=", $value
                        Add-Content -Path $outPath -value $line
                    }  
                }         
                return $returnMap
            }
        } else { 
            Throw "Mirth properties probe returned no results"
        }
    }
    END { 
        Write-Debug "Get-MirthServerProperties Ending"
    }
} #  Get-MirthServerProperties 

function global:Test-MirthFileReadWrite { 
   <#
    .SYNOPSIS
        Tests whether or not Mirth can read and/or write from a file folder path.

    .DESCRIPTION
        Returns an XML object the test result.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        $testPath   String containing directory path to be tested.

    .OUTPUTS
        [bool] $True if the folder passes the test, otherwise $False 

    .EXAMPLE
        $result = Test-MirthFileReadWrite -testPath D:/TEMP -mode R 
        if ($(Test-MirthFileReadWrite -testPath $path -mode RW )) { ... }

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter(Mandatory=$True)]
        [String]$testPath,

        # File mode to test: R = Read, W = Write, RW = Read/Write
        [Parameter()]
        [ValidateSet('R','W','RW')]        
        [String]$mode   = "R"
    ) 
    BEGIN { 
        Write-Debug "Test-MirthFileReadWrite Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $channelId = "11111111-2222-3333-4444-555555555555"
        $channelName = "PS_MIRTH_TEST_FILE_" + $mode

        [xml] $testReadXML = @"
        <properties class="com.mirth.connect.connectors.file.FileReceiverProperties">
            <pluginProperties/>
            <pollConnectorProperties version="3.6.2" />
            <sourceConnectorProperties version="3.6.2" />
            <scheme>FILE</scheme>
            <host>$testPath</host>
            <timeout>10000</timeout>
        </properties>
"@
        [xml] $testWriteXML = @"
        <properties class="com.mirth.connect.connectors.file.FileDispatcherProperties">
            <pluginProperties />
            <destinationConnectorProperties/>
            <scheme>FILE</scheme>
            <host>$testPath</host>
            <timeout>10000</timeout>
        </properties>
"@
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('channelId', $channelId)
        $parameters.Add('channelName', $channelName)

        $headers = @{}
        $headers.Add("Accept","application/xml")
      
        $result = $True
        try { 
            if ($mode.Contains('R')) {
                $uri = $serverUrl + '/api/connectors/file/_testRead'
                $uri = $uri + '?' + $parameters.toString()
                Write-Debug "Invoking POST Mirth API server at: $uri "
                $r = Invoke-RestMethod -Uri $uri -Headers $headers -ContentType 'application/xml' -Method POST -WebSession $session -Body $testReadXML.OuterXml
                [String] $testResult = $r.'com.mirth.connect.util.ConnectionTestResponse'.type
                Write-Verbose "READ Test:" 
                Write-Verbose "$($r.OuterXml)"
                $result = ($result -and ($testResult -eq "SUCCESS")) 
            }
            if ($mode.Contains('W')) {
                $uri = $serverUrl + '/api/connectors/file/_testWrite'
                $uri = $uri + '?' + $parameters.toString()
                Write-Debug "Invoking POST Mirth API server at: $uri "
                $r = Invoke-RestMethod -Uri $uri -Headers $headers -ContentType 'application/xml' -Method POST -WebSession $session -Body $testWriteXML.OuterXml
                [String] $testResult = $r.'com.mirth.connect.util.ConnectionTestResponse'.type
                Write-Verbose "Write Test:" 
                Write-Verbose "$($r.OuterXml)"
                $result = ($result -and ($testResult -eq "SUCCESS"))                 
            }
            return $result

        }
        catch {
            Write-Error $_
        }  
    }
    END {
        Write-Debug "Test-MirthFileRead Ending"
    } 
}  # Test-MirthFileRead
New-Alias -Name tmfrw -Value Test-MirthFileReadWrite

<############################################################################################>
<#        Channel Functions                                                                 #>
<############################################################################################>

function global:Get-MirthChannelIds {
    <#
    .SYNOPSIS
        Gets an array of all channelIds in the target server.

    .DESCRIPTION
        Return array of string objects representing the list of channel ids in the target server.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS

    .EXAMPLE
        
    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug 'Get-MirthChannelIds Beginning'
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }           

        [string[]] $channelIds = @()

        [xml] $allChannelXml = Get-MirthChannels -connection $connection 
        $channelNodes = $allChannelXml.SelectNodes(".//channel")
        Write-Debug "There are $($channelNodes.Count) channels to considered."
        if ($channelNodes.Count -gt 0) { 
            foreach ($channelNode in $channelNodes) { 
                # TBD: add some filtering logic here?
                Write-Debug "Adding channel id [$($channelNode.id)] to list."
                $channelIds += $channelNode.id
            }
            Write-Debug "There are now $($channelNodes.Count) channel ids in the list."
        }
        if ($saveXML) { 
            [string]$outPath = Get-PSMirthOutputFolder -create
            $outPath = Join-Path $outPath $outFile 
            Write-Debug "Saving channel id list at: $outPath"
            Clear-Content -path $outPath -ErrorAction SilentlyContinue | Out-Null
            foreach ($id in $channelIds) {
                Add-Content -Path $outPath -value $id
            }
        }
        return $channelIds
    }
    END {
        Write-Debug 'Get-MirthChannelIds Ending' 
    }
}  # Get-MirthChannelIds
        
function global:Get-MirthChannelStatuses {
    <#
    .SYNOPSIS
        Gets the dashboard status of selected channels, or all channels

    .DESCRIPTION
        Return xml object describing a list of the requested channels.  Also fetches 
        server channel metadata and merges into the channel xml as a /channel/exportData
        element, just as if it were exported from the mirth gui.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then status for all channels are returned.  Otherwise, only the channels with the 
        id values specified are returned.

    .OUTPUTS

    .EXAMPLE
        
    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the channels to fetch status for, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetId,

        [string] $filter,

        [switch] $includeUndeployed,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug 'Get-MirthChannelStatuses Beginning'
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }           
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/channels/statuses'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        if (-not([string]::IsNullOrEmpty($filter) -or [string]::IsNullOrWhiteSpace($filter))) {
            $parameters.Add('filter', $filter)
        }
        if ($includeUndeployed) { 
            $parameters.Add('includeUndeployed','true')
        } else {
            $parameters.Add('includeUndeployed','false')
        }
        if (-not([string]::IsNullOrEmpty($targetId) -or [string]::IsNullOrWhiteSpace($targetId))) {
            foreach ($target in $targetId) {
                $parameters.Add('channelId', $target)
            }
        } 
        $uri = $uri + '?' + $parameters.toString()

        Write-Debug "Invoking GET Mirth at $uri"
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."
            if ($saveXML) { 
                if ($exportChannels) {
                    # iterate through list, saving each channel using the name
                    foreach ($channel in $r.list.channel) {
                        $exportFileName = Get-PSMirthOutputFolder -create
                        $exportFileName = $exportFileName + $channel.name + '.xml' 
                        $msg = "Exporting channel '$exportFileName'"
                        Write-Debug $msg
                        Set-Content $exportFileName $channel.OuterXml
                    }
                } else {
                    [string]$o = Get-PSMirthOutputFolder -create
                    $o = Join-Path $o $outFile   
                    $r.save($o)
                }
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
        }
        catch {
            Write-Error $_
        }     
    }
    END {
        Write-Debug 'Get-MirthChannelStatuses Ending' 
    }
}  # Get-MirthChannelStatuses
function global:Set-MirthChannelProperties { 
    <#
    .SYNOPSIS
        Sets channel properties for a list of channels, or all channels, deployed on the target server.

    .DESCRIPTION
        Only the parameters that are passed in are set.  The primary properties are 

        MessageStoreMode

        DEVELOPMENT - Content: All; Metadata: All; Durable Message Delivery On, 
        PRODUCTION  - Content: Raw,Encoded,Sent,Response,Maps; Metadata: All; Durable Message Delivery: On
        RAW         - Content: Raw; Metadata: All; Durable Message Delivery: Reprocess Only
        METADATA    - Content: (none); Metadata: All; Durable Message Delivery: Off
        DISABLED    - Content: (none); Metadata: (none); Durable Message Delivery: Off

        And there are performance/storage consequences for the mirth server in how these are 
        set.  Development offers the lowest performance with most data retained and highest storage requirements.
        Disabled offers the maximum performance, lowest amount of data retained, and lowest storage requirements.

        There are also trade-offs to be considered when reducing the data retained as regards troubleshooting.
        In QA/Development tiers it is usually necessary maintain data for development and validation.  In other
        environments it is only necessary when troubleshooting specific issues.  It may be better to keep channels
        running at higher performance levels and only enable DEVELOPMENT mode when it is necessary to troubleshoot 
        an issue.

    .INPUTS
        A -session              - WebRequestSession object is required. See Connect-Mirth.
        [string[]] $channelIds  - Optional list of channel ids, if omitted all channels are updated.
        Pass in only the properties you wish to set.

    .OUTPUTS

    .EXAMPLE
        Set-MirthChannelProperties  -messageStorageMode PRODUCTION -clearGlobalChannelMap $True -pruneMetaDataDays 30 -pruneContentDays 15  -removeOnlyFilteredOnCompletion $True  

    .LINK

    .NOTES
        This command essentially fetches the list of channels specified, or all channels, and then 
        updates the specified channel properties, only if they were explicitly specified as parameters.

        There are many parameters.  Consider using splatting.

        It does NOT deploy the modified channels.  There may be consequences to deploying channels;  it may cause 
        unintended polls for channels that poll once on deployment.  Therefore, this command does not deploy.
        It is left up to the calling client code to know whether or not they should deploy the channels at this
        time.  The client code would need to call redeploy the affected channels.


    #> 
    [CmdletBinding()] 
    PARAM (
         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the channels to be set to the specified message storage mode, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$channelIds,

        # If true, the channel is enabled and can be deployed
        [Parameter()]
        [bool] $enabled,  

        # The messages storage mode setting to be activated
        [Parameter()]
        [MirthMsgStorageMode] $messageStorageMode,

        # clear the global channel map on deployment if true
        [Parameter()]
        [bool] $clearGlobalChannelMap,

        # encrypt the data if true
        [Parameter()]
        [bool] $encryptData,

        # remove content on successful completion if true
        [Parameter()]
        [bool] $removeContentOnCompletion,

        # remove only filtered destinations on completion if true
        [Parameter()]
        [bool] $removeOnlyFilteredOnCompletion,

        # remove attachments on completion
        [Parameter()]
        [bool] $removeAttachmentsOnCompletion,

        # store attachments if true
        [Parameter()]
        [bool] $storeAttachments,

        # If set to a positive value, the number of days before pruning metadata.  If negative, store indefinitely.
        [Parameter()]
        [int] $pruneMetaDataDays,

        # If set to a positive value, the number of days before pruning content.  Cannot be greater than than pruneMetaDays. 
        # If negative, then store content until metadata is removed.
        [Parameter()]
        [ValidateScript({
            if ($PSBoundParameters.containsKey('pruneMetaDays')) {
                # A pruneMetaDays parameter was provided along with pruneContentDays...
                if ($_ -gt $pruneMetaDataDays) {
                    Throw "pruneContentDays ($_) cannot be greater than pruneMetaDays!"
                }
                else { 
                    $True
                }
            } else {
                # they only specified pruneContentDays, so we'll have to check it at time of update
                $True
            }
        })]
        [int] $pruneContentDays,

        # Allow message archiving
        [Parameter()]
        [bool] $allowArchiving,        
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Set-MirthChannelProperties Beginning"
    }
    PROCESS { 
        [xml] $channelList = Get-MirthChannels -connection $connection -targetId $channelIds 
        $channelNodes = $channelList.SelectNodes("/list/channel")
        Write-Verbose "There are $($channelNodes.count) channels to be processed."
        foreach ($channelNode in $channelNodes) {
            Write-Verbose "Updating message properties for channel [$($channelNode.id)] $($channelNode.name)"
            if ($PSBoundParameters.containsKey('messageStorageMode')) {
                Write-Verbose "Updating messageStorageMode"
                $channelNode.properties.messageStorageMode = $messageStorageMode.toString()
            }
            if ($PSBoundParameters.containsKey('clearGlobalChannelMap')) {
                Write-Verbose "Updating clearGlobalChannelMap"
                $channelNode.properties.clearGlobalChannelMap = $clearGlobalChannelMap.ToString()
            }
            if ($PSBoundParameters.containsKey('encryptData')) {
                Write-Verbose "Updating encryptData"
                $channelNode.properties.encryptData = $encryptData.ToString()
            }
            if ($PSBoundParameters.containsKey('removeContentOnCompletion')) {
                Write-Verbose "Updating removeContentOnCompletion"
                $channelNode.properties.removeContentOnCompletion = $removeContentOnCompletion.ToString()
            }
            if ($PSBoundParameters.containsKey('removeOnlyFilteredOnCompletion')) {
                Write-Verbose "Updating removeOnlyFilteredOnCompletion"
                $channelNode.properties.removeOnlyFilteredOnCompletion = $removeOnlyFilteredOnCompletion.ToString()
            }
            if ($PSBoundParameters.containsKey('removeAttachmentsOnCompletion')) {
                Write-Verbose "Updating removeAttachmentsOnCompletion"
                $channelNode.properties.removeAttachmentsOnCompletion = $removeAttachmentsOnCompletion.ToString()
            }                          
            if ($PSBoundParameters.containsKey('storeAttachments')) {
                Write-Verbose "Updating storeAttachments"
                $channelNode.properties.storeAttachments = $storeAttachments.ToString()
            }
            if (($PSBoundParameters.containsKey('enabled')) -or
                ($PSBoundParameters.containsKey('pruneMetaDataDays'))  -or 
                ($PSBoundParameters.containsKey('pruneContentDays'))  -or
                ($PSBoundParameters.containsKey('allowArchiving'))) { 
                Write-Debug "Searching for pruningSettings node"
                [Xml.XmlElement] $psNode = $channelNode.SelectSingleNode("exportData/metadata/pruningSettings")
                if ($null -ne $psNode) {
                    Write-Debug "pruningSettings node found..."
                    if ($PSBoundParameters.containsKey('enabled')) {
                        Write-Verbose "Updating enabled"
                        $channelNode.exportData.metadata.enabled = $enabled.ToString()
                    }  
                    if ($PSBoundParameters.containsKey('pruneMetaDataDays')) {
                        Write-Verbose "Updating pruneMetaDataDays"
                        $pruneMetaDataDaysNode = $psNode.SelectSingleNode("pruneMetaDataDays")

                        if ($pruneMetaDataDays -lt 0) { 
                            # indefinite, remove the pruneMetaDataDays element, leaving nothing
                            # Write-Debug "Fetching pruneMetaDataDays node for deletion"
                            # $pruneMetaDataDaysNode = $psNode.SelectSingleNode("pruneMetaDataDays")
                            if ($null -ne $pruneMetaDataDaysNode) { 
                                Write-Debug "Removing pruneMetaDaysNode"
                                $psNode.removeChild($pruneMetaDataDaysNode) | Out-Null
                            } else { 
                                Write-Debug "There is no pruneMetaDaysNode node to remove"
                            }  
                        } else {
                            # updating
                            if (-not $PSBoundParameters.containsKey('pruneContentDays')) { 
                                # no validation has been performed
                                $pruneContentDays = $channelNode.exportData.metadata.pruningSettings.pruneContentDays
                                if ($null -ne $pruneContentDays) { 
                                    if ($pruneContentDays -gt $pruneMetaDataDays) { 
                                        Throw "pruneMetaDataData value specified [$($pruneMetaDataDays)] is less than current pruneContentDays [$($pruneContentDays)]! Increase or specify pruneContentDays parameter."
                                    }
                                }
                            }
                            if ($null -ne $pruneMetaDataDaysNode) { 
                                Write-Verbose "Updating pruneMetaDataDays node"
                                $channelNode.exportData.metadata.pruningSettings.pruneMetaDataDays = $pruneMetaDataDays.ToString()
                            } else { 
                                # add pruneMetaDataDays here
                                $pruneMetaDataDaysNode = $channelList.CreateElement('pruneMetaDataDays')
                                $pruneMetaDataDaysNode.set_InnerText($pruneMetaDataDays.ToString())
                                $pruneMetaDataDaysNode = $psNode.AppendChild($pruneMetaDataDaysNode)
                            } 
                           
                        }
                    }
                    if ($PSBoundParameters.containsKey('pruneContentDays')) {
                        Write-Verbose "Updating pruneContentDays"
                        $pruneContentDaysNode = $psNode.SelectSingleNode("pruneContentDays")
                        if ($pruneContentDays -lt 0) { 
                            if ($null -ne $pruneContentDaysNode) { 
                                Write-Debug "Removing pruneContentDaysNode"
                                $psNode.removeChild($pruneContentDaysNode)  | Out-Null
                            } else { 
                                Write-Debug "There is no pruneContentDaysNode node to remove"
                            }                 
                        } else { 
                            # updating
                            if (-not $PSBoundParameters.containsKey('pruneMetaDataDays')) { 
                                # no validation has been performed
                                $pruneMetaDataDays = $channelNode.exportData.metadata.pruningSettings.pruneMetaDataDays
                                if ($null -ne $pruneContentDays) { 
                                    if ($pruneContentDays -gt $pruneMetaDataDays) { 
                                        Throw "pruneMetaDataData value specified [$($pruneMetaDataDays)] is less than current pruneContentDays [$($pruneContentDays)]! Increase or specify pruneContentDays parameter."
                                    }
                                }
                            }
                            if ($null -ne $pruneContentDaysNode) { 
                                Write-Debug "Updating existing pruneContentDays node"                
                                $channelNode.exportData.metadata.pruningSettings.pruneContentDays = $pruneContentDays.ToString()
                            } else { 
                                # add a pruneContentDays node and update
                                $pruneContentDaysNode = $channelList.CreateElement('pruneContentDays')
                                $pruneContentDaysNode.set_InnerText($pruneContentDays.ToString())
                                $pruneContentDaysNode = $psNode.AppendChild($pruneContentDaysNode)                                
                            } 

                        }
                    }   
                    if ($PSBoundParameters.containsKey('allowArchiving')) {
                        Write-Verbose "Updating archiveEnabled"
                        $channelNode.exportData.metadata.pruningSettings.archiveEnabled = $allowArchiving.ToString()
                    }  
                } else { 
                    # If passed a channel xml which has not been merged with metadata,if so, we'll warn and skip
                    Write-Warn "The channel has no pruningSettings node, skipping."
                }
            }  # if an exportdata parameter was passed                                  
            Import-MirthChannel -connection $connection -payLoad $channelNode.OuterXml | Out-Null
        }  #  foreach $channelNode

    }
    END { 
        Write-Debug "Set-MirthChannelProperties Ending"
    }
}  # Set-MirthChannelProperties

function global:Get-MirthChannelMsgById { 
    <#
    .SYNOPSIS
        Gets a message id from a channel, specified by id.

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        [xml] representation of a channel message;  the message itself is in 

    .EXAMPLE
        Get-MirthChannelMsgById -channelId  ffe2e62c-5dd8-435e-a877-987d3f6c3d09 -messageId 8

    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection] $connection = $currentConnection,

        # The id of the chennel to interrogate, required
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]  $channelId,

        # The message id to retrieve from the channel
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [long]  $messageId,        

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch] $saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string] $outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )         
    BEGIN { 
        Write-Debug "Get-MirthChannelMsgById Beginning"
    }
    PROCESS { 
        #GET /channels/{channelId}/messages/maxMessageId
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        $uri = $serverUrl + "/api/channels/$channelId/messages/$messageId"

        Write-Debug "Invoking GET Mirth  $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                #$o = $o + $outFile
                $o = Join-Path $o $outFile 
                Write-Debug "Saving Output to $o"
                $r.save($o)     
                Write-Debug "Done!" 
            }
            Write-Verbose $r.innerXml
            return $r
                
        }
        catch {
            Write-Error $_
        }        
    }
    END { 
        Write-Debug "Get-MirthChannelMsgById Ending"
    }
}  # Get-MirthChannelMsgById

function global:Get-MirthChannelMaxMsgId { 
    <#
    .SYNOPSIS
        Gets the maximum message id for the channel, specified by id.

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        [long] the maximum message number

    .EXAMPLE
        
    .LINK

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection] $connection = $currentConnection,

        # The id of the chennel to interrogate, required
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]  $targetId,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch] $saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string] $outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )         
    BEGIN { 
        Write-Debug "Get-MirthChannelMaxMsgId Beginning"
    }
    PROCESS { 
        #GET /channels/{channelId}/messages/maxMessageId
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        $uri = $serverUrl + "/api/channels/$targetId/messages/maxMessageId"

        Write-Debug "Invoking GET Mirth  $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                #$o = $o + $outFile
                $o = Join-Path $o $outFile 
                Write-Debug "Saving Output to $o"
                $r.save($o)     
                Write-Debug "Done!" 
            }
            Write-Verbose $r.innerXml
            return [long]$r.long
                
        }
        catch {
            $_.response
        $errorMessage = $_.Exception.Message
            if (Get-Member -InputObject $_.Exception -Name 'Response') {
                try {
                    $result = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($result)
                    $reader.BaseStream.Position = 0
                    $reader.DiscardBufferedData()
                    $responseBody = $reader.ReadToEnd();
                } catch {
                    Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage. Cannot get more information."
                }
            }
            Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage  Response body: $responseBody"
        }        
    }
    END { 
        Write-Debug "Get-MirthChannelMaxMsgId Ending"
    }
}  # Get-MirthChannelMaxMsgId

function global:Send-MirthStartChannels { 
    <#
    .SYNOPSIS
        Starts a list of channels.

    .DESCRIPTION
        Sends a START signal to one or more channels, optionally requesting error information.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        If -saveXML writes the list XML to Save-Send-MirthStartChannels-Output.xml

    .EXAMPLE
        Send-MirthStartChannels -connection $connection -returnErrors -targetIds fa2cdec1-3abc-4186-95e3-9576d53b20e1
        Send-MirthStartChannels -targetIds 014d299a-d972-4ae6-aa48-a2741f78390c,fa2cdec1-3abc-4186-95e3-9576d53b20e1   
        
    .LINK
        Links to further documentation.

    .NOTES
        When the returnErrors switch is set, if any of the channels fail to start, an exception is thrown.  

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The array of the channel ids to undeploy, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetIds,

        # If true, an error response code and the exception will be returned.
        [Parameter()]
        [switch]$returnErrors = $false,        
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'

    )
    BEGIN { 
        Write-Debug "Send-MirthStartChannels Beginning"
    }
    PROCESS { 

        return Send-MirthChannelCommand -connection $connection -targetIds $targetIds -command 'start' -returnErrors:$returnErrors -saveXML:$saveXML -outFile $outFile

    }
    END { 
        Write-Debug "Send-MirthStartChannels Ending"
    }          
}  # Send-MirthStartChannels

function global:Send-MirthStopChannels { 
    <#
    .SYNOPSIS
        Stops a list of channels.

    .DESCRIPTION
        Sends a STOP signal to one or more channels, optionally requesting error information.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        If -saveXML writes the list XML to Save-Send-MirthStopChannels-Output.xml

    .EXAMPLE
        Send-MirthStopChannels -connection $connection -returnErrors -targetIds fa2cdec1-3abc-4186-95e3-9576d53b20e1
        Send-MirthStopChannels -targetIds 014d299a-d972-4ae6-aa48-a2741f78390c,fa2cdec1-3abc-4186-95e3-9576d53b20e1  
        
    .LINK
        Links to further documentation.

    .NOTES
        When the returnErrors switch is set, if any of the channels fail to stop an 
        exception is thrown.  

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The array of the channel ids to undeploy, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetIds,

        # If true, an error response code and the exception will be returned.
        [Parameter()]
        [switch]$returnErrors = $false,        
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Send-MirthStopChannels Beginning"
    }
    PROCESS { 

        return Send-MirthChannelCommand -connection $connection -targetIds $targetIds -command 'stop' -returnErrors:$returnErrors -saveXML:$saveXML -outFile $outFile

    }
    END { 
        Write-Debug "Send-MirthStopChannels Ending"
    }          
}  # Send-MirthStopChannels
function global:Send-MirthHaltChannels { 
    <#
    .SYNOPSIS
        Halts a list of channels.

    .DESCRIPTION
        Sends a HALT signal to one or more channels, optionally requesting error information.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        If -saveXML writes the list XML to Save-Send-MirthHaltChannels-Output.xml

    .EXAMPLE
        Send-MirthHaltChannels -connection $connection -returnErrors -targetIds fa2cdec1-3abc-4186-95e3-9576d53b20e1
        Send-MirthHaltChannels -targetIds 014d299a-d972-4ae6-aa48-a2741f78390c,fa2cdec1-3abc-4186-95e3-9576d53b20e1  
        
    .LINK
        Links to further documentation.

    .NOTES
        When the returnErrors switch is set, if any of the channels fail to halt an 
        exception is thrown.  

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The array of the channel ids to undeploy, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetIds,

        # If true, an error response code and the exception will be returned.
        [Parameter()]
        [switch]$returnErrors = $false,        
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Send-MirthHaltChannels Beginning"
    }
    PROCESS { 

        return Send-MirthChannelCommand -connection $connection -targetIds $targetIds -command 'halt' -returnErrors:$returnErrors -saveXML:$saveXML -outFile $outFile

    }
    END { 
        Write-Debug "Send-MirthHaltChannels Ending"
    }          
}  # Send-MirthHaltChannels

function global:Send-MirthPauseChannels { 
    <#
    .SYNOPSIS
        Pauses a list of channels.

    .DESCRIPTION
        Sends a PAUSE signal to one or more channels, optionally requesting error information.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        If -saveXML writes the list XML to Save-Send-MirthHaltChannels-Output.xml

    .EXAMPLE
        Send-MirthPauseChannels -connection $connection -returnErrors -targetIds fa2cdec1-3abc-4186-95e3-9576d53b20e1
        Send-MirthPauseChannels -targetIds 014d299a-d972-4ae6-aa48-a2741f78390c,fa2cdec1-3abc-4186-95e3-9576d53b20e1  
        
    .LINK
        Links to further documentation.

    .NOTES
        When the returnErrors switch is set, if any of the channels fail to halt an 
        exception is thrown.  

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The array of the channel ids to undeploy, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetIds,

        # If true, an error response code and the exception will be returned.
        [Parameter()]
        [switch]$returnErrors = $false,        
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Send-MirthPauseChannels Beginning"
    }
    PROCESS { 

        return Send-MirthChannelCommand -connection $connection -targetIds $targetIds -command 'pause' -returnErrors:$returnErrors -saveXML:$saveXML -outFile $outFile

    }
    END { 
        Write-Debug "Send-MirthPauseChannels Ending"
    }          
}  # Send-MirthPauseChannels

function global:Send-MirthResumeChannels { 
    <#
    .SYNOPSIS
        Resumes a list of channels.

    .DESCRIPTION
        Sends a RESUME signal to one or more channels, optionally requesting error information.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        If -saveXML writes the list XML to Save-Send-MirthHaltChannels-Output.xml

    .EXAMPLE
        Send-MirthResumeChannels -connection $connection -returnErrors -targetIds fa2cdec1-3abc-4186-95e3-9576d53b20e1
        Send-MirthResumeChannels -targetIds 014d299a-d972-4ae6-aa48-a2741f78390c,fa2cdec1-3abc-4186-95e3-9576d53b20e1  
        
    .LINK
        Links to further documentation.

    .NOTES
        When the returnErrors switch is set, if any of the channels fail to halt an 
        exception is thrown.  

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The array of the channel ids to undeploy, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetIds,

        # If true, an error response code and the exception will be returned.
        [Parameter()]
        [switch]$returnErrors = $false,        
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Send-MirthResumeChannels Beginning"
    }
    PROCESS { 

        return Send-MirthChannelCommand -connection $connection -targetIds $targetIds -command 'resume' -returnErrors:$returnErrors -saveXML:$saveXML -outFile $outFile

    }
    END { 
        Write-Debug "Send-MirthResumeChannels Ending"
    }          
}  # Send-MirthResumeChannels

function global:Send-MirthChannelCommand { 
    <#
    .SYNOPSIS
        Sends a command to one or more channels, optionally requesting error information.

    .DESCRIPTION
        This function accepts a string from a valid set of commands:
        * start
        * stop
        * halt
        * pause
        * resume
        It then calls the appropriate endpoint on the target server to execute that 
        command against the list of channels specified by the list of targetId strings, 
        each representing a mirth channel id uniquely identifying a channel on the server.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        If -saveXML writes the list XML to Save-Send-MirthChannelCommand-Output.xml

    .EXAMPLE
        Send-MirthChannelCommand -connection $connection -command stop -targetIds fa2cdec1-3abc-4186-95e3-9576d53b20e1 -returnErrors 
        Send-MirthChannelCommand -command start -targetIds 014d299a-d972-4ae6-aa48-a2741f78390c,fa2cdec1-3abc-4186-95e3-9576d53b20e1 
        Send-MirthChannelCommand -command pause 
        Send-MirthChannelCommand -command resume -saveXML 
        
    .LINK
        Links to further documentation.

    .NOTES
        When the returnErrors switch is set, if any of the channels fail to halt an 
        exception is thrown.  

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The array of the channel ids to undeploy, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetIds,

        # The command to send to the target channels
        [Parameter(Mandatory=$True)]
        [ValidateSet('pause','resume','start','stop','halt')]  
        [string]$command,

        # If true, an error response code and the exception will be returned.
        [Parameter()]
        [switch]$returnErrors = $false,        
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Send-MirthChannelCommand -command $command Beginning"
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $headers = @{}
        $headers.Add("Content-Type","application/x-www-form-urlencoded");
        $headers.Add("Accept","application/xml")

        $uri = $serverUrl + "/api/channels/_$command"
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('returnErrors', $returnErrors)
        $uri = $uri + '?' + $parameters.toString()

        $payloadBody = "";
        if ($targetIds.count -eq 0){ 
            Write-Debug "No target channel ids specified..."
            # get all channel IDs here
            # later we will add ways to filter
            Write-Debug "Fetching ALL channel ids in target server..."
            $targetIds = Get-MirthChannelIds -connection $connection
            Write-Debug "There are $($targetIds.Count) channels as target of $command command."
        }
        if ($targetIds.count -gt 0) { 
            Write-Debug "Attempting to $command $($targetIds.count) channels"
            for($i=0; $i -lt $targetIds.count; $i++) {
                $channelId = $targetIds[$i]
                if ($i -gt 0) {
                    $payloadBody += '&'
                }
                $payloadBody += "channelId=$channelId"
            }
            Write-Debug "Payload generated: $payloadBody"
        }

        Write-Debug "POST to Mirth $uri "
        try { 
            $r = Invoke-RestMethod -UseBasicParsing -Uri $uri -WebSession $session -Headers $headers -Method POST -Body $payloadBody
            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $line = "Channel command: $command successful for targets: "
                Set-Content $o -Value $line 
                Add-Content $o $payloadBody
            }
            Write-Verbose "Channel Command [$command]: SUCCESS"
            return $true
        } catch {
            $_.response
        $errorMessage = $_.Exception.Message
            if (Get-Member -InputObject $_.Exception -Name 'Response') {
                try {
                    $result = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($result)
                    $reader.BaseStream.Position = 0
                    $reader.DiscardBufferedData()
                    $responseBody = $reader.ReadToEnd();
                } catch {
                    Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage. Cannot get more information."
                }
            }
            Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage  Response body: $responseBody"
        }

    }
    END { 
        Write-Debug "Send-MirthChannelCommand Ending"
    }          
}  # Send-MirthChannelCommand



function global:Send-MirthDeployChannels {      
    <#
    .SYNOPSIS
        Sends mirth a signal to deploy selected channels.
        (note "Deploy" is approved in v6)

    .DESCRIPTION
        Deploys one or more channels on the target server.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -channelIds    a list of channel ids to be deployed, all if omitted.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        204 if successful, 500 if any of the channels fail to deploy

    .EXAMPLE
        
    .LINK

    .NOTES
        When the returnErrors switch is set, if any of the channels fail to deploy an 
        exception is thrown.  The response from the server *should* contain an xml 
        donkey DeployException that would tell us what channels failed and what the 
        error is, but I have been unable to obtain this response.  All the code sees
        is a ConnectionClosed error.

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the channels to undeploy, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetIds,

        # If true, an error response code and exception will be returned.
        [Parameter()]
        [switch]$returnErrors = $false,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Send-MirthDeployChannels Beginning"
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$payloadXML = "<set></set>"
        if ($targetIds.count -gt 0) { 
            # they provided some channel ids
            Write-Debug "Attempting to deploy $($targetIds.count) channels"
            Add-PSMirthStringNodes -parentNode $($payloadXML.SelectSingleNode("/set")) -values $targetIds | Out-Null
            Write-Debug "Payload generated: $($payloadXML.OuterXml)"
        }

        $headers = @{}
        $headers.Add("Accept","application/xml")

        $uri = $serverUrl + '/api/channels/_deploy'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('returnErrors', $returnErrors)
        $uri = $uri + '?' + $parameters.toString()

        Write-Debug "POST to Mirth $uri "
        try { 
            $r = Invoke-RestMethod -UseBasicParsing -Uri $uri -WebSession $session -Headers $headers -Method POST -ContentType 'application/xml' -Body $payloadXML.OuterXml

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                Write-Debug "Saving Output to $o"
                Set-Content $o -Value $r  
            }
            Write-Verbose -Message "Deployed: $r"
            return $true
        } catch {
            $_.response
        $errorMessage = $_.Exception.Message
            if (Get-Member -InputObject $_.Exception -Name 'Response') {
                try {
                    $result = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($result)
                    $reader.BaseStream.Position = 0
                    $reader.DiscardBufferedData()
                    $responseBody = $reader.ReadToEnd();
                } catch {
                    Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage. Cannot get more information."
                }
            }
            Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage  Response body: $responseBody"
        }

    }
    END { 
        Write-Debug "Send-MirthDeployChannels Ending"

    }
}  # Send-MirthDeployChannels

function global:Send-MirthRedeployAllChannels { 
    
    <#
    .SYNOPSIS
        Redeploys all mirth channels
        (note "Deploy" is approved in v6)

    .DESCRIPTION
        Redeploys all Mirth channels, optionally returning error response codes.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        If -saveXML writes the list XML to Save-Send-MirthRedeployAllChannels-Output.xml

    .EXAMPLE
        Send-MirthRedeployAllChannels -connection $connection -returnErrors
        
    .LINK
        Links to further documentation.

    .NOTES
        When the returnErrors switch is set, if any of the channels fail to deploy an 
        exception is thrown.  The response from the server *should* contain an xml 
        donkey DeployException that would tell us what channels failed and what the 
        error is, but I have been unable to obtain this response.  All the code sees
        is a ConnectionClosed error.

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # If true, an error response code and exception will be returned.
        [Parameter()]
        [switch]$returnErrors = $false,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Send-MirthRedeployAllChannels Beginning"
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $headers = @{}
        $headers.Add("Accept","application/xml")

        $uri = $serverUrl + '/api/channels/_redeployAll'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('returnErrors', $returnErrors)
        $uri = $uri + '?' + $parameters.toString()

        Write-Debug "POST to Mirth $uri "
        try { 
            # using the returnErrors parameter set to true should cause channel deployment errors
            # to be returned, but I have been unable to access this.  That's why the attempt to use 
            # Invoke-WebRequest instead of Invoke-RestMethod and the weird error handling...  To be continued.
            #$r = Invoke-RestMethod -UseBasicParsing -Uri $uri -WebSession $session -Headers $headers -Method POST -ContentType 'application/xml' 
            $r = Invoke-WebRequest -UseBasicParsing -Uri $uri -WebSession $session -Headers $headers -Method POST -ContentType 'application/xml' 
            #Type of response object:Microsoft.PowerShell.Commands.WebResponseObject
            # Write-Debug "...done."
            # Write-Debug "Type of response object: $($r.getType())"
            # Write-Debug $r.BaseResponse
            # Write-Debug $r.StatusCode
            # Write-Debug $r.StatusDescription
            # Write-Debug $r.RawContent
            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                Set-Content $o -Value $r.getType()   
            }
            Write-Verbose "$r"
            return $true
        } catch {
            $_.response
            $errorMessage = $_.Exception.Message
            if (Get-Member -InputObject $_.Exception -Name 'Response') {
                try {
                    $result = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($result)
                    $reader.BaseStream.Position = 0
                    $reader.DiscardBufferedData()
                    $responseBody = $reader.ReadToEnd();
                } catch {
                    Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage. Cannot get more information."
                }
            }
            Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage  Response body: $responseBody"
        }
    }
    END { 
        Write-Debug "Send-MirthRedeployAllChannels Ending"
    }

}  # Send-MirthRedployAllChannels

function global:Send-MirthUndeployChannels { 
    <#
    .SYNOPSIS
        Undeploys all channels, or a list of channels.

    .DESCRIPTION
        Undeploys Mirth channels, optionally returning error information.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -returnErrors  switch, if true error response code and exception will be returned.  
        
    .OUTPUTS
        If -saveXML writes the list XML to Save-Send-MirthRedeployAllChannels-Output.xml

    .EXAMPLE
        Send-MirthUndeployChannels -connection $connection -returnErrors
        
    .LINK
        Links to further documentation.

    .NOTES
        When the returnErrors switch is set, if any of the channels fail to deploy an 
        exception is thrown.  The response from the server *should* contain an xml 
        donkey DeployException that would tell us what channels failed and what the 
        error is, but I have been unable to obtain this response.  All the code sees
        is a ConnectionClosed error.

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The array of the channel ids to undeploy, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetIds,

        # If true, an error response code and the exception will be returned.
        [Parameter()]
        [switch]$returnErrors = $false,        
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Send-MirthUndeployChannels Beginning"
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $headers = @{}
        $headers.Add("Accept","application/xml")

        $uri = $serverUrl + '/api/channels/_undeploy'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('returnErrors', $returnErrors)
        $uri = $uri + '?' + $parameters.toString()

        [xml]$payloadXML = "<set></set>";
        if ($targetIds.count -gt 0) { 
            # they provided some channel ids
            Write-Debug "Attempting to deploy $($targetIds.count) channels"
            Add-PSMirthStringNodes -parentNode $($payloadXML.SelectSingleNode("/set")) -values $targetIds | Out-Null
            Write-Debug "Payload generated: $($payloadXML.OuterXml)"
        }

        Write-Debug "POST to Mirth $uri "
        try { 
            $r = Invoke-RestMethod -UseBasicParsing -Uri $uri -WebSession $session -Headers $headers -Method POST -ContentType 'application/xml' -Body $payLoadXML.OuterXml

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                Set-Content $o -Value $r 
            }
            Write-Verbose "Undeployed: $r"
            return $true
        } catch {
            $_.response
        $errorMessage = $_.Exception.Message
            if (Get-Member -InputObject $_.Exception -Name 'Response') {
                try {
                    $result = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($result)
                    $reader.BaseStream.Position = 0
                    $reader.DiscardBufferedData()
                    $responseBody = $reader.ReadToEnd();
                } catch {
                    Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage. Cannot get more information."
                }
            }
            Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage  Response body: $responseBody"
        }

    }
    END { 
        Write-Debug "Send-MirthUndeployChannels Ending"
    }          
}  # Send-MirthUndeployChannels

function global:Get-MirthChannels { 
    <#
    .SYNOPSIS
        Gets a list of all channels, or multiple channels by ID

    .DESCRIPTION
        Return xml object describing a list of the requested channels.  Also fetches 
        server channel metadata and merges into the channel xml as a /channel/exportData
        element, just as if it were exported from the mirth gui.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all channel groups are returned.  Otherwise, only the channel groups with the 
        id values specified are returned.

    .OUTPUTS
        If -saveXML writes the list XML to Save-Get-MirthChannels-Output.xml
        If -exportChannels each channel is instead output in a separate file using the channel name.

        Returns an XML object that represents a list of channel objects:

        <list>
          <channel version="3.6.2">
            <id>e0e315bc-e064-4a6c-bc60-e26c2b4846b7</id>
            <nextMetaDataId>2</nextMetaDataId>
            <name>MyChannelReader</name>
            <description></description>
            <revision>1</revision>
            <sourceConnector version="3.6.2">
              <metaDataId>0</metaDataId>
              <name>sourceConnector</name>
              <properties class="com.mirth.connect.connectors.vm.VmReceiverProperties" version="3.6.2">
		        [...]
              </properties>
              <transformer version="3.6.2">
		        [...]
              </transformer>
              <filter version="3.6.2">
                <elements />
              </filter>
              <transportName>Channel Reader</transportName>
              <mode>SOURCE</mode>
              <enabled>true</enabled>
              <waitForPrevious>true</waitForPrevious>
            </sourceConnector>
            <destinationConnectors>
              <connector version="3.6.2">
                <metaDataId>1</metaDataId>
                <name>Destination 1</name>
                <properties class="com.mirth.connect.connectors.vm.VmDispatcherProperties" version="3.6.2">
			        [...]
                </properties>
                <transformer version="3.6.2">
			        [...]
                </transformer>
                <responseTransformer version="3.6.2">
			        [...]
                </responseTransformer>
                <filter version="3.6.2">
                  <elements />
                </filter>
                <transportName>Channel Writer</transportName>
                <mode>DESTINATION</mode>
                <enabled>true</enabled>
                <waitForPrevious>true</waitForPrevious>
              </connector>
            </destinationConnectors>
            <preprocessingScript>// Modify the message variable below to pre process data
        return message;</preprocessingScript>
            <postprocessingScript>// This script executes once after a message has been processed
        // Responses returned from here will be stored as "Postprocessor" in the response map
        return;</postprocessingScript>
            <deployScript>// This script executes once when the channel is deployed
        // You only have access to the globalMap and globalChannelMap here to persist data
        return;</deployScript>
            <undeployScript>// This script executes once when the channel is undeployed
        // You only have access to the globalMap and globalChannelMap here to persist data
        return;</undeployScript>
            <properties version="3.6.2">
              <clearGlobalChannelMap>true</clearGlobalChannelMap>
              <messageStorageMode>PRODUCTION</messageStorageMode>
              <encryptData>false</encryptData>
              <removeContentOnCompletion>false</removeContentOnCompletion>
              <removeOnlyFilteredOnCompletion>false</removeOnlyFilteredOnCompletion>
              <removeAttachmentsOnCompletion>false</removeAttachmentsOnCompletion>
              <initialState>STARTED</initialState>
              <storeAttachments>true</storeAttachments>
              <metaDataColumns>
                <metaDataColumn>
                  <name>SOURCE</name>
                  <type>STRING</type>
                  <mappingName>mirth_source</mappingName>
                </metaDataColumn>
                <metaDataColumn>
                  <name>TYPE</name>
                  <type>STRING</type>
                  <mappingName>mirth_type</mappingName>
                </metaDataColumn>
              </metaDataColumns>
              <attachmentProperties version="3.6.2">
                <type>None</type>
                <properties />
              </attachmentProperties>
              <resourceIds class="linked-hash-map">
                <entry>
                  <string>Default Resource</string>
                  <string>[Default Resource]</string>
                </entry>
              </resourceIds>
            </properties>
          </channel>
        </list>

        This is a very complex object which depends upon the channel configuration.
        Refer to the Mirth API for more information.

    .EXAMPLE
        Connect-Mirth | Get-MirthChannels 
        
    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the channelGroup to retrieve, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetId,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Save each channel XML in a separate file using the channel name.
        # saveXML switch must also be on.
        [Parameter()]
        [switch]$exportChannels = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug 'Get-MirthChannels Beginning'
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }           
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/channels'
        if ([string]::IsNullOrEmpty($targetId) -or [string]::IsNullOrWhiteSpace($targetId)) {
            Write-Debug "Fetching all channels"
            $parameters = $null
        } else {
            $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
            foreach ($target in $targetId) {
                $parameters.Add('channelId', $target)
            }
            $uri = $uri + '?' + $parameters.toString()
        }

        Write-Debug "Invoking GET Mirth at $uri"
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."
            # we have some result, so get the channel metadata map
            Write-Debug "Fetching Server channel metadata map"
            $channelMetaDataMap = Get-MirthServerChannelMetadata -connection $connection -asHashtable -saveXML:$saveXML
            Write-Debug "Channel Metadata map contains $($channelMetaDataMap.Count) entries..."

            $currentTagSet = Get-MirthChannelTags -connection $connection -saveXML:$saveXML
            $channelTagMap = @{}
            Write-Debug "Building channel to tag map..."
            foreach ($channelTag in $currentTagSet.set.channelTag) { 
                $channelIds = $channelTag.SelectNodes("channelIds/string")
                Write-Debug "There are $($channelIds.Count) channelIds for this tag [$($channelTag.name)]"
                foreach ($channelId in $channelIds) {
                    $key = $channelId.InnerText
                    Write-Debug "Key inserting into channelTagMap: $key"
                    if ($channelTagMap.containsKey($key)) {
                        $channelTagMap[$key] += $channelTag
                    } else { 
                        $channelTagMap[$key] = @($channelTag)
                    }
                    Write-Debug "There are now $($channelTagMap[ $key].Count) tag entries for channelID  $key in the channelTagMap"
                }
            }
            Write-Debug "There are $($channelTagMap.count) total entries in the channelTagMap"

            # for each channel, we will merge in metadata and channelTags as if exported from gui
            foreach ($channel in $r.list.channel) {
                Write-Debug "Merging export metadata for $($channel.name)"
                $channelId = $channel.id
                $exportNode = $r.CreateElement('exportData')
                $exportNode = $channel.AppendChild($exportNode)
                Write-Debug "exportData node added"
                $metaDataNode = $r.CreateElement('metadata')
                $metaDataNode = $exportNode.AppendChild($metaDataNode)
                Write-Debug "metadata node added"
                $entry = $channelMetaDataMap[$($channel.id)]
                if ($null -ne $entry) {
                    # enabled
                    Write-Debug "setting enabled"
                    try { 
                        $enabledNode = $entry.SelectSingleNode("enabled")
                        $enabledNode = $r.ImportNode($enabledNode,$true) 
                        $enabledNode = $metaDataNode.AppendChild($enabledNode)
                    } catch { 
                        Write-Error $_
                    }
                    # lastModified
                    Write-Debug "setting lastModified"
                    try {
                        $lastModifiedNode = $entry.SelectSingleNode("lastModified")
                        $lastModifiedNode = $r.ImportNode($lastModifiedNode,$true) 
                        $lastModifiedNode = $metaDataNode.AppendChild($lastModifiedNode)
                    } catch { 
                        Write-Error $_
                    }                        
                    # pruningSettings
                    Write-Debug "setting pruningSettings"
                    try { 
                        $pruningSettingsNode = $entry.SelectSingleNode("pruningSettings")
                        $pruningSettingsNode = $r.ImportNode($pruningSettingsNode,$true) 
                        $pruningSettingsNode = $metaDataNode.AppendChild($pruningSettingsNode)
                    } catch { 
                        Write-Error $_
                    }                        
                } else { 
                    Write-Warning "No metadata was found!"
                }
                Write-Debug "All channel metadata processed"

                Write-Debug "Processing channelTags..."
                $channelTagArray = $channelTagMap[$channelId]
                if (($null -ne $channelTagArray) -and ($channelTagArray.Count -gt 0)) { 
                    Write-Debug "There are $($channelTagArray.Count) channelTags to be merged."
                    $channelTagsNode = $r.CreateElement('channelTags')
                    $channelTagsNode = $exportNode.AppendChild($channelTagsNode)
                    foreach ($channelTag in $channelTagArray) { 
                        Write-Debug "Importing and appending channelTag"
                        $channelIdNode = $r.ImportNode($channelTag,$true)
                        $channelTagsNode.AppendChild($channelIdNode) | Out-Null
                    }
                    Write-Debug "channel tag data processed"
                } else { 
                    Write-Debug "There were no channelTags associated with this channel id."
                }
                
            }  # foreach channel in the list

            if ($saveXML) { 
                if ($exportChannels) {
                    # iterate through list, saving each channel using the name
                    foreach ($channel in $r.list.channel) {
                        $exportFileName = Get-PSMirthOutputFolder -create
                        $exportFileName = $exportFileName + $channel.name + '.xml' 
                        $msg = "Exporting channel '$exportFileName'"
                        Write-Debug $msg
                        Set-Content $exportFileName $channel.OuterXml
                    }
                } else {
                    [string]$o = Get-PSMirthOutputFolder -create
                    $o = Join-Path $o $outFile   
                    $r.save($o)
                }
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
        }
        catch {
            Write-Error $_
        }     
    }
    END {
        Write-Debug 'Get-MirthChannels Ending' 
    }
}  # Get-MirthChannels

function global:Remove-MirthChannels {
    <#
    .SYNOPSIS
        Removes channels with the ids specified by $targetId

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId   Required, the list of string channel IDs to be removed.

    .OUTPUTS

    .EXAMPLE
        Connect-Mirth | Remove-MirthChannels -targetId 21189e58-2f96-4d47-a0d5-d2879a86cee9,c98b1068-af68-41d9-9647-5ff719b21d67  -saveXML
        
    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The required id of the channelGroup to remove
        [Parameter(ParameterSetName="selected",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetId,

        # if true, all channels will be removed
        [Parameter(ParameterSetName="all",
                   Mandatory=$True)]
        [switch]$removeAllChannels = $false,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )  
    BEGIN {
        Write-Debug "Remove-MirthChannels Beginning" 
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }           
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        
        [string[]] $channelIdsToRemove = @()
        if ($removeAllChannels) { 
            Write-Debug "Removal of all channels is requested."
            [xml] $allChannelXml = Get-MirthChannels -connection $connection 
            $channelNodes = $allChannelXml.SelectNodes(".//channel")
            Write-Debug "There are $($channelNodes.Count) channels to be removed."
            if ($channelNodes.Count -gt 0) { 
                foreach ($channelNode in $channelNodes) { 
                    Write-Debug "Adding channel id [$($channelNode.id)] to removal list."
                    $channelIdsToRemove += $channelNode.id
                }
                Write-Debug "There are now $($channelNodes.Count) channel ids in the removal list."
            }
        } else { 
            Write-Debug "Removal of selected channels requested."
            $channelIdsToRemove = $targetId
        }

        $uri = $connection.serverUrl + '/api/channels'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        foreach ($id in $channelIdsToRemove) {
            $parameters.Add('channelId', $id)
        }
        $uri = $uri + '?' + $parameters.toString()

        Write-Debug "Invoking DELETE Mirth at $uri"
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method DELETE -WebSession $session

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile      
                Set-Content -Path $o -Value "Deleted Channels: $id" 
            }
            Write-Verbose $r
            return $r
        }
        catch {
            Write-Error $_
        }      
    }
    END { 
        Write-Debug "Remove-MirthChannels Ending"
    }
}  # Remove-MirthChannels

function global:Remove-MirthChannelByName { 
   <#
    .SYNOPSIS
        Removes one ore more channels with the name(s) specified by targetNames parameter

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetName Required, the name of the channel to be deleted.

    .OUTPUTS

    .EXAMPLE
        Remove-MirthChannels -targetName "My Channel Reader"  -saveXML
        
    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The required list of channel names to be removed
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetNames,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )  
    BEGIN {
        Write-Debug "Remove-MirthChannelByName Beginning" 
    }
    PROCESS {    
          
        # First, get the channels
        $channelSet = Get-MirthChannels -connection $connection  
        [string[]]$targetIds = @()
        foreach ($targetName in $targetNames) {
            $xpath = '//channel[name = "' + $targetName + '"]'  
            $channelFound = $channelSet.SelectSingleNode($xpath) 
            if ($null -ne $channelFound) { 
                # we found the channel
                Write-Debug "Adding channel id $($channelFound.id) to targetId list..."
                $targetIds += $channelFound.id
            } else { 
                Write-Warning "Skipping, the channel name was not found: $targetName"
            }
        }
        Write-Debug "There are now $($targetIds.count) channel ids in the list to remove"
        if ($targetIds.count -eq 0) { 
            Write-Warning "No channel with the target name was found to be deleted!"
            return $null
        }

        $r = Remove-MirthChannels -connection $connection -targetId $targetIds -saveXML:$saveXML

        if ($saveXML) { 
            [string]$o = Get-PSMirthOutputFolder -create
            $o = Join-Path $o $outFile    
        }
        Write-Verbose "$($r.OuterXml)"
        return $r

    }
    END { 
        Write-Debug "Remove-MirthChannelByName Ending"
    }
}  # Remove-MirthChannelByName

function global:Import-MirthChannel { 
    <#
    .SYNOPSIS
        Imports a Mirth channel.

    .DESCRIPTION
        This function creates a new channel from the channel XML provided.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        $payLoad is a user XML object describing the channel to be added:



    .OUTPUTS


    .EXAMPLE

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of the channel to be added
        [Parameter(ParameterSetName="xmlProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payLoad,

        # path to the file containing the channel xml to import
        [Parameter(ParameterSetName="pathProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payloadFilePath,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Import-MirthChannel Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$channelXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A channel XML payLoad string is required!"
                return $null
            } else {
                Write-Debug "Loading channel XML from path $payLoadFilePath"
                [xml]$channelXML = Get-Content $payLoadFilePath  
            }
        } else {
            Write-Debug "Import channel payload delivered via string parameter"
            $channelXML = [xml]$payLoad
        }

        $msg = 'Importing channel [' + $channelXML.channel.name + ']...'
        Write-Debug $msg

        $uri = $serverUrl + '/api/channels'
        Write-Debug "POST to Mirth $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method POST -ContentType 'application/xml' -Body $channelXML.OuterXml
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                Write-Debug "Saving Output to $o"
                $r.save($o)     
                Write-Debug "Done!" 
            }
            Write-Verbose "$($r.OuterXml)"
            return $r

        }
        catch {
            Write-Error $_
        }

    } 
    END {
        Write-Debug "Import-MirthChannel Ending"
    }

}  # Import-MirthChannel

function global:Send-MirthMessage { 
    BEGIN { 
        Write-Debug "Send-MirthMessage Beginning"
    }
    PROCESS { 
        # POST /channels/{channelId}/messages
        #
        #  body, body string - raw message data to process
        #  destinationMetaDataId, query parameter, array of integer, destinations to send msg to
        #  sourceMapEntry, query parameter, array of string, key=value pairs injected into sourceMap
        #  overwrite, query parameter, boolean, if true and original message id given, this message will overwrite existing
        #  imported, query parameter, boolean, if true marks this messag as imported, if overwriting statistics not decremented
        #  originalMessageId, query parameter, long, the original message id this msg is associated with


    }
    END { 
        Write-Debug "Send-MirthMessage Ending"
    }
}  #  Send-MirthMessage [UNDER CONSTRUCTION]


<############################################################################################>
<#        Code Template Functions                                                           #>
<############################################################################################>

function global:Get-MirthCodeTemplates { 
    <#
   .SYNOPSIS
       Gets Mirth Code Templates, either the targetIds specified, or all.

   .DESCRIPTION
       Returns a list of one or more code template objects:

   .INPUTS
       A -session  WebRequestSession object is required. See Connect-Mirth.
       -targetIds if omitted, then all libraries are returned.  Otherwise, only the libraries with the 
       id values specified are returned.

   .OUTPUTS

   .EXAMPLE

   .NOTES

   #> 
   [CmdletBinding()] 
   PARAM (

        # A MirthConnection is required. You can obtain one from Connect-Mirth.
       [Parameter(ValueFromPipeline=$True)]
       [MirthConnection]$connection = $currentConnection,

       # The ids of the code templates to retrieve, empty for all
       [Parameter(ValueFromPipelineByPropertyName=$True)]
       [string[]]$targetIds,
  
       # Saves the response from the server as a file in the current location.
       [Parameter()]
       [switch]$saveXML = $false,
       
       # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
       [Parameter()]
       [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
   )    
   BEGIN { 
       Write-Debug "Get-MirthCodeTemplates Beginning"
   }
   PROCESS { 

       if ($null -eq $connection) { 
           Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
       }  
       [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
       $serverUrl = $connection.serverUrl
       
       $uri = $serverUrl + '/api/codeTemplates'
       $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    #    $parameters.Add('includeCodeTemplates', $includeCodeTemplates)

       if ([string]::IsNullOrEmpty($targetId) -or [string]::IsNullOrWhiteSpace($targetId)) {
           Write-Debug "Fetching all code templates"
       } else {
           foreach ($target in $targetIds) {
               $parameters.Add('codeTemplateId', $target)
           }
       }
       $uri = $uri + '?' + $parameters.toString()
       Write-Debug "Invoking GET Mirth $uri "
       try { 
           $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session 
           Write-Debug "...done."

           if ($saveXML) { 
               [string]$o = Get-PSMirthOutputFolder -create
               $o = Join-Path $o $outFile 
               $r.save($o)
           }
           Write-Verbose "$($r.OuterXml)"
           return $r;
       }
       catch {
           Write-Error $_
       }
   }
   END { 
       Write-Debug "Get-MirthCodeTemplates Ending"
   }
}  # Get-MirthCodeTemplates

function global:Set-MirthCodeTemplate {
    <#
    .SYNOPSIS
        Updates a code template.

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        $payLoad 
        String containing the XML describing a codeTemplate object

    .OUTPUTS

    .EXAMPLE  

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of the channel to be added
        [Parameter(ParameterSetName="xmlProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payLoad,

        # path to the file containing the channel xml to import
        [Parameter(ParameterSetName="pathProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payloadFilePath,

        # If true, the code template will be updated even if a different revision 
        # exists on the server
        [Parameter()]
        [switch]$override = $false,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )    
    BEGIN { 
        Write-Debug "Set-MirthCodeTemplate Beginning"
    }
    PROCESS {
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$payLoadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A channel XML payLoad string is required!"
                return $null
            } else {
                Write-Debug "Loading channel XML from path $payLoadFilePath"
                [xml]$payLoadXML = Get-Content $payLoadFilePath  
            }
        } else {
            Write-Debug "Creating XML payload from string: $payLoad"
            $payLoadXML = [xml]$payLoad
        }
        $newCodeTemplateId = $payLoadXML.codeTemplate.id 
        Write-Debug "The code template id to be set is [$newCodeTemplateId]"

        $uri = $serverUrl + '/api/codeTemplates/' + $newCodeTemplateId
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('override', $override)
        $uri = $uri + '?' + $parameters.toString()
        $headers = @{}
        $headers.Add("Accept","application/xml")
        Write-Debug "Invoking PUT Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -ContentType 'application/xml' -Method PUT -WebSession $session -Body $payLoadXML.OuterXml
            Write-Debug "...done."
            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
        }
        catch {
            Write-Error $_
        }  
    }
    END { 
        Write-Debug "Set-MirthCodeTemplate Ending"
    } 

}  # Set-MirthCodeTemplate

function global:Remove-MirthCodeTemplates  { 
    <#
    .SYNOPSIS
        Removes all Mirth code templates, or a list of them specified by id.

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        $targetId   The id of the user to delete.
                    Note, the default admin user, id = 1,  cannot be deleted.

    .OUTPUTS

    .EXAMPLE

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # Array of code template ids to be removed
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetIds,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
                
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )    
    BEGIN { 
        Write-Debug "Remove-MirthCodeTemplates Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth!"  
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        if (-NOT [string]::IsNullOrEmpty($targetIds)) { 
            Write-Debug "Removal of list of $($targetIds.Count) code template ids is requested."
            
        } else { 
            $allCodeTemplates = Get-MirthCodeTemplates -connection $connection 
            if ($null -ne $allCodeTemplates) { 
                $targetIds = $allCodeTemplates.list.codeTemplate.id
                Write-Debug "There are $($targetIds.Count) code templates to be removed."
            } else { 
                Write-Warning "Unable to fetch list of code templates."
                $targetIds = @()
            }
        }

        foreach ($targetId in $targetIds) {
            
            $uri = $serverUrl + '/api/codeTemplates/' + $targetId
            $msg = "Deleting code template: " + $targetId
            Write-Debug $msg

            Write-Debug "DELETE to Mirth $uri "
            try { 
                $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method DELETE -ContentType 'application/xml' -Body $userXML.OuterXml

                if ($saveXML) { 
                    [string]$o = Get-PSMirthOutputFolder -create
                    $o = Join-Path $o $outFile 
                    Write-Debug "Saving Output to $o"
                    Set-Content $o -Value $r
                    #$r.save($o)     
                }
                Write-Verbose "$($r.OuterXml)"
            }
            catch {
                Write-Error $_
            }
        }
        return 
    }
    END { 
        Write-Debug "Remove-MirthCodeTemplates Ending"
    }
}  # Remove-MirthCodeTemplates

function global:Get-MirthCodeTemplateLibraries { 
     <#
    .SYNOPSIS
        Gets Mirth Code Template Libraries, either the targetIds specified, or all.

    .DESCRIPTION
        Returns a list of one or more code template library objects:



    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all libraries are returned.  Otherwise, only the libraries with the 
        id values specified are returned.

    .OUTPUTS

    .EXAMPLE
        
    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the code template library to retrieve, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetId,

        # If true, full code templates will be included inside each library.
        [parameter()]
        [switch]$includeCodeTemplates = $false,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )    
    BEGIN { 
        Write-Debug "Get-MirthCodeTemplateLibraries Beginning"
    }
    PROCESS { 

        # TBD:  if we always sorted the contextType when exporting channels, lbiraries, etc, 
        # this would eliminate them always cluttering up the diff reports in Perforce

        # try this logic to sort the delegate contextType elements:
        #  /list/codeTemplateLibrary/codeTemplates/codeTemplate/contextSet/delegate/contextType

        # [xml]$xml = @"
        # <company>
        #     <stuff>
        #     </stuff>
        #     <machines>
        #         <machine>
        #             <name>ca</name>
        #             <b>123</b>
        #             <c>123</c>
        #         </machine>
        #         <machine>
        #             <name>ad</name>
        #             <b>234</b>
        #             <c>234</c>
        #         </machine>
        #         <machine>
        #             <name>be</name>
        #             <b>345</b>
        #             <c>345</c>
        #         </machine>
        #     </machines>
        #     <otherstuff>
        #     </otherstuff>
        # </company>
        # "@
        # [System.Xml.XmlNode]$orig = $xml.Company.Machines
        # $orig.Machine | sort Name  -Descending |
        #   foreach { [void]$xml.company.machines.PrependChild($_) }
        # $xml.company.machines.machine


        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }  
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
        
        $uri = $serverUrl + '/api/codeTemplateLibraries'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('includeCodeTemplates', $includeCodeTemplates)

        if ([string]::IsNullOrEmpty($targetId) -or [string]::IsNullOrWhiteSpace($targetId)) {
            Write-Debug "Fetching all code template libraries"
        } else {
            foreach ($target in $targetId) {
                $parameters.Add('libraryId', $target)
            }
        }
        $uri = $uri + '?' + $parameters.toString()
        Write-Debug "Invoking GET Mirth $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session 
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"
            return $r;
        }
        catch {
            Write-Error $_
        }
    }
    END { 
        Write-Debug "Get-MirthCodeTemplateLibraries Ending"
    }
}  # Get-MirthCodeTemplateLibraries

function global:Set-MirthCodeTemplateLibraries {
    <#
    .SYNOPSIS
        Replaces all code template libraries.

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        $payLoad 
        String containing the XML describing a list of code template library 
        xml objects, e.g.,

    .OUTPUTS

    .EXAMPLE
        #  The following command removes all code template libraries.
        Connect-Mirth | Update-MirthCodeTemplateLibraries -payLoad '<list></list>' -override  
        

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of the channel to be added
        [Parameter(ParameterSetName="xmlProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payLoad,

        # path to the file containing the channel xml to import
        [Parameter(ParameterSetName="pathProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payloadFilePath,

        # If true, the code template library will be updated even if a different revision 
        # exists on the server
        [Parameter()]
        [switch]$override = $false,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )    
    BEGIN { 
        Write-Debug "Set-MirthCodeTemplateLibraries Beginning"
    }
    PROCESS {
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$payLoadXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A codetemplate library list XML payLoad string is required!"
                return $null
            } else {
                Write-Debug "Loading codetemplate library XML from path $payLoadFilePath"
                [xml]$payLoadXML = Get-Content $payLoadFilePath  
            }
        } else {
            Write-Debug "Creating XML payload from string: $payLoad"
            $payLoadXML = [xml]$payLoad
        }

        $codeTemplateNodes = $payLoadXML.SelectNodes(".//codeTemplates/codeTemplate")
        if ($codeTemplateNodes.Count -gt 0) { 
            Write-Debug "There are $($codeTemplateNodes.Count ) codeTemplate nodes to process..."
            foreach ($codeTemplate in $codeTemplateNodes) { 
                $r = Set-MirthCodeTemplate -connection $connection -payLoad $codeTemplate.OuterXml -override
                Write-Debug "Set-MirthCodeTemplate $($codeTemplate.id) response: $r.OuterXml"
            }
        }

        $uri = $serverUrl + '/api/codeTemplateLibraries'
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $parameters.Add('override', $override)
        $uri = $uri + '?' + $parameters.toString()
        $headers = @{}
        $headers.Add("Accept","application/xml")
        Write-Debug "Invoking PUT Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -ContentType 'application/xml' -Method PUT -WebSession $session -Body $payLoadXML.OuterXml
            Write-Debug "...done."
            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
        }
        catch {
            Write-Error $_
        }  
    }
    END { 
        Write-Debug "Set-MirthCodeTemplateLibraries Ending"
    } 

}  # Set-MirthCodeTemplateLibraries

<############################################################################################>
<#        SSL Manager Functions                                                             #>
<############################################################################################>

function global:Set-MirthSSLManagerKeystores { 
    <#
    .SYNOPSIS
        Given a truststore and keystore encoded as a Base64 string, upload them to 
        the Mirth server, replacing the SSL Manager keystores and assignign the specified password. 

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
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # Base64 encoded string of a JKS file, used as SSL Manager keystore.
        [Parameter(ParameterSetName="keystoreProvided")]
        [string]$keyStore = $null,
        
        # The path to the text file containing the public PEM
        [Parameter(ParameterSetName="pathProvided")]
        [string]$keyStorePath,

        # Base64 encoded string of a JKS file, used as SSL Manager trustStore.
        [Parameter(ParameterSetName="keystoreProvided")]
        [string]$trustStore = $null,
        
        # The path to the text file containing the private PEM
        [Parameter(ParameterSetName="pathProvided")]
        [string]$trustStorePath,

        # keystore password.  This will be stored in the Mirth configuration table, category "SSL Manager", name "KeystorePass"
        [Parameter()]
        [string]$keyStorePass = "changeit",

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false
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

function global:Get-MirthKeyStoreCertificates { 
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
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
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
        try { 
            $r = Invoke-RestMethod -WebSession $session -Uri $uri -Method GET -ContentType 'application/xml' 
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
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

function global:Get-MirthKeyStoreBytes { 
    <#
    .SYNOPSIS
        Gets the Mirth KeyStore/TrustStore Bytes 

    .DESCRIPTION
        Fetch Byte array of mirth keystore and truststore

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        

    .EXAMPLE
        

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN { 
        Write-Debug "Get-MirthKeyStoreBytes Beginning..."
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        $uri = $serverUrl + '/api/extensions/ssl/allStoreBytes'
        Write-Debug "Invoking GET Mirth $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                $r.save($o)
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
                
        }
        catch {
            Write-Error $_
        }
    }
    END { 
        Write-Debug "Get-MirthKeyStoreBytes Ending..."
    }
}  # Get-MirthKeyStoreBytes

<############################################################################################>
<#        User Functions                                                                    #>
<############################################################################################>

function global:Connect-Mirth { 
    <#
    .SYNOPSIS
        Logs into a Mirth server and returns a MirthConnection object that can be used
        for subsequent calls.  

    .DESCRIPTION
        This function logs into the mirth server located at serverURL using the mirth 
        username adminUser and password, adminPass.  If these are not supplied, it will 
        default to "Https://localhost:8443", user "admin", and password "admin".  These 
        are the default Mirth settings for a new installation.

    .INPUTS

    .OUTPUTS
        If the login command is processed a [Microsoft.PowerShell.Commands.WebRequestSession] object representing 
        the session is returned.  Otherwise, the [xml] response from the Mirth server is returned.

    .EXAMPLE
        $session = Connect-Mirth -serverUrl https://localhost:5443 -adminUser myUser -adminPass myPass
        $session = Connect-Mirth -serverUrl va-nrg-t-gold.tmdsmsat.akiproj.com:8443 
        Connect-Mirth | Write-ServerConfig

    .LINK
        Links to further documentation.

    .NOTES
        [OutputType([Microsoft.PowerShell.Commands.WebRequestSession])]
    #> 
    [OutputType([MirthConnection])] 
    [CmdletBinding()]
    PARAM (
        [Parameter()]
        [string]$serverUrl = "https://localhost:8443",
        [Parameter()]
        [string]$userName = "admin",
        [Parameter()]
        [string]$userPass = "admin"
    )
    BEGIN {
        Write-Debug "Connect-Mirth Beginning..." 
        Write-Debug "Initializing SSL session attributes to ignore self-signed certs, trust all cert policy...."
    # Force the script to ignore Mirth's self-signed certificate
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    
    # and to use TLS1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    PROCESS {
        Write-Debug "Logging into Mirth..."
        Write-Debug "serverUrl = $serverUrl"
        Write-Debug "userName = $userName"
        Write-Debug "userPass = $userPass" 
        $headers = @{}
        $headers.Add("Accept","application/xml")
        $uri = $serverUrl + '/api/users/_login?username=' + $userName + '&password=' + $userPass
        try { 
            $r = Invoke-RestMethod -uri $uri  -Headers $headers -Method POST -SessionVariable session
            $msg = "Response: " + $r.'com.mirth.connect.model.LoginStatus'.status
            Write-Debug $msg

            $connection = [MirthConnection]::new($session,$serverUrl,$userName,$userPass)
            Set-PSMirthConnection($connection);

            return $connection

        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug "Connect-Mirth Ending>..."
    }

}  # Connect-Mirth

function global:Set-MirthUserPassword {
    <#
    .SYNOPSIS
        Update Mirth user passwords

    .DESCRIPTION
        Updates the password for the mirth user specified by "targetId" to the 
        password specified by the parameter, newPassword, defaulting to "changeit"
        if none is provided.  It can perform this action for one user, by id or name,
        or for all users if no targetId is provided.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS

    .EXAMPLE
        Connect-Mirth | Set-MirthUserPassword -targetId admin -newPassword M1rth@dm1n!! 
        Connect-Mirth -userPass M1rth@dm1n!! | Set-MirthUserPassword -targetId admin -newPassword admin -saveXML

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The user id to be retrieved, this can be either the userName or the id
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string]$targetId,

        # The new password when performing the add-user or change-password commands, default is "changeit"
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string]$newPassword = "changeit",
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN {
        Write-Debug "Set-MirthUserPassword Beginning" 
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $ulist = Get-MirthUsers -connection $connection -targetId $targetId -saveXML:$saveXML
        if ($null -ne $ulist) {
            $users = $ulist.SelectNodes("/list/user")
        }
        Write-Debug "There were $($users.Count) users retrieved for set password command"

        foreach ($u in $users) {
            Write-Debug "Changing password user: $($u.id): $($u.username) assigned to $($u.lastName)"
                
            $uri = $serverUrl + '/api/users/' + $u.id + '/password'
            Write-Debug "PUT to Mirth at $uri"
            try { 
                $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method PUT -ContentType 'text/plain' -Body $newPassword
                Write-Debug "...Password set"
                if ($saveXML) { 
                    [string]$o = Get-PSMirthOutputFolder -create
                    $o = Join-Path $o $outFile 
                    Set-Content -Path $o -Value "$targetId : $newPassword" 
                }
                Write-Verbose $r
            }
            catch {
                Write-Error $_
            }
        }  # For each user selected
    } 
    END { 
        Write-Debug "Set-MirthUserPassword Ending" 
    }
}  # Set-MirthUserPassword

function global:Test-MirthUserLogged { 
    <#
    .SYNOPSIS
        Tests the mirth user specified by the targetId and returns [bool] value
        indicating if the user is logged in or not.

    .DESCRIPTION
        Tests the user to see if logged in.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        A valid Mirth user id must be provided in the targetId parameter.

    .OUTPUTS
        [bool], TRUE if the user identified by targetId is logged in, otherwise false.

    .EXAMPLE
        Connect-Mirth | Test-MirthUserLogged -targetId 1 

    .NOTES

    #>
    [OutputType([bool])] 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The user id to be tested (not the username)
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$targetId,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN {
        Write-Debug "Test-MirthUserLogged Beginning" 
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        $uri = $serverUrl + '/api/users/' + $targetId + "/loggedIn"
        Write-Debug "Invoking GET Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session 
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                Set-Content -Path $o -Value $r.OuterXml
            }
            Write-Verbose "$($r.OuterXml)"
            $loggedIn = [System.Convert]::ToBoolean($r.boolean)

            return $loggedIn
        }
        catch [System.Net.WebException] {
            # a 500 server error is thrown when you use a non-existent user id.
            $msg = "StatusCode:" + $_.Exception.Response.StatusCode.value__ 
            Write-Error $msg
            $msg = "StatusDescription:" + $_.Exception.Response.StatusDescription
            Write-Error $msg
            return $false
        }
        catch {
            Write-Error $_
            return $false

        }     
    }
    END {
        Write-Debug "Test-MirthUserLogged Ending" 
    }
}  # Test-MirthUserLogged

function global:Get-MirthLoggedUsers {
    <#
    .SYNOPSIS
        Gets the currently logged in Mirth users.

    .DESCRIPTION
        Returns a list of mirth users that are currently logged in.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        -targetId if omitted, then all channel groups are returned.  Otherwise, only the channel groups with the 
        id values specified are returned.

    .OUTPUTS

        <list>
            <user>
                <id>1</id>
                <username>admin</username>
                <email />
                <firstName />
                <lastName />
                <organization />
                <description />
                <phoneNumber />
                <lastLogin>
                  <time>1590210339894</time>
                  <timezone>America/Chicago</timezone>
                </lastLogin>
          </user>
        </list>

    .EXAMPLE
        Connect-Mirth | Get-MirthLoggedUsers

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The id of the channelGroup to retrieve, empty for all
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$targetId,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,

        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    ) 
    BEGIN {
        Write-Debug 'Get-MirthLoggedUsers Beginning'  
    }
    PROCESS { 
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }  
        [xml]$loggedUsers = '<list></list>' 
        $allUsers = Get-MirthUsers -connection $connection 
        foreach($user in $allUsers.list.user) {
            $uTmp = $user.username
            Write-Debug "Checking user $uTmp" 
            if (Test-MirthUserLogged -connection $connection -targetId $user.id ) {
                Write-Verbose "$uTmp is logged in!"
                $loggedUsers.DocumentElement.AppendChild($loggedUsers.ImportNode($user,$true))
            }
        }
        if ($saveXML) { 
            [string]$o = Get-PSMirthOutputFolder -create
            $o = Join-Path $o $outFile 
            Write-Debug "Saving Output to $o"
            $loggedUsers.save($o)     
            Write-Debug "Done!" 
        }
        Write-Verbose $loggedUsers.OuterXml
        return $loggedUsers
    }
    END { 
        Write-Debug 'Get-MirthLoggedUsers Ending'
    }

}  # Get-MirthLoggedUsers

function global:Get-MirthUsers {
    <#
    .SYNOPSIS
        Gets all Mirth users, or a specific mirth user by either id or username. 

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        Returns an XML object that is a list of user elements.

            <list>
              <user>
                <id>1</id>
                <username>admin</username>
                <email></email>
                <firstName></firstName>
                <lastName></lastName>
                <organization></organization>
                <description></description>
                <phoneNumber></phoneNumber>
                <lastLogin>
                  <time>1590301209113</time>
                  <timezone>America/Chicago</timezone>
                </lastLogin>
              </user>
                [...]
            </list>

    .EXAMPLE
        Connect-Mirth | Get-MirthUsers 
        Connect-Mirth | Get-MirthUsers -targetId 1 

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The user id to be retrieved, this can be either the userName or the id
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string]$targetId,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN {
        Write-Debug "Get-MirthUsers Beginning" 
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        $uri = $serverUrl + '/api/users'
        $singleUser = $False
        if (-NOT [string]::IsNullOrEmpty($targetId)) { 
            Write-Debug 'Getting user by target identifier'
            $singleUser = $True
            $uri = "$uri/$targetId"
        }
        $headers = @{}
        $headers.Add("Accept","application/xml")

        Write-Debug "Invoking GET Mirth  $uri "
        try { 
            $r = Invoke-RestMethod -Headers $headers -Uri $uri -Method GET -WebSession $session
            Write-Debug "...done."

            if ($singleUser) { 
                #wrap in a list element for consistency
                Write-Debug "Wrapping single user in list for return"
                $userNode = $r.SelectSingleNode("/user")
                [Xml]$newXml = New-Object -TypeName xml
                $listNode = $newXml.CreateElement("list")
                $userNode = $listNode.OwnerDocument.ImportNode($userNode,$True)
                $listNode.AppendChild($userNode) | Out-Null  
                $newXml.AppendChild($listNode) | Out-Null

                $r = $newXml
            }

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                #$o = $o + $outFile
                $o = Join-Path $o $outFile 
                $r.save($o)     
                Write-Debug "Output saved to $o"
            }
            Write-Verbose "$($r.OuterXml)"
            return $r   
        }
        catch {
            Write-Error $_
        }
    }
    END { 
        Write-Debug "Get-MirthUsers Ending"
    }
}  # Get-MirthUsers

function global:Set-MirthUser {
    <#
    .SYNOPSIS
        Updates a Mirth user, specified by targetId (id only).

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        $payLoad 
        String containing the XML describing a user object, e.g.,
            <user>
              <id>13</id>
              <username>RenamedUser</username>
              <email>andy@datasprite.com</email>
              <firstName>Barney</firstName>
              <lastName>Rubble</lastName>
              <organization>DataSprite</organization>
              <description>User updated from PowerShell Mirth API</description>
              <phoneNumber>210-724-2457</phoneNumber>
            </user>

        Note that a user may be renamed, including the default admin user.
        Even though the id is supplied in the path, it must also be present 
        in the user payload.

    .OUTPUTS

    .EXAMPLE

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The user id to be updated, this must be the numeric id.
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$targetId,

        # xml of the user to be added
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payLoad,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN { 
        Write-Debug "Set-MirthUser Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        if ([string]::IsNullOrEmpty($targetId)) { 
            Write-Error "A targetId is required!"
            return
        }

        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            Write-Error "A user XML payLoad string is required!"
            return
        } else {
            Write-Verbose "Creating payload from xml: $payLoad"
            $userXML = [xml]$payLoad
        }

        $msg = "Updating user: " + $userXML.user.username + " assigned to " + $userXML.user.firstName + " " + $userXML.user.lastName
        Write-Debug $msg

        $uri = $serverUrl + '/api/users/' + $targetId
        Write-Debug "PUT to Mirth $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method PUT -ContentType 'application/xml' -Body $userXML.OuterXml
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                Write-Debug "Saving Output to $o"
                $r.save($o)     
                Write-Debug "Done!" 
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
        }
        catch {
            Write-Error $_
        }
    }
    END { 
        Write-Debug "Set-MirthUser Ending"
    }
 
}  # Set-MirthUser

function global:Add-MirthUser { 

    <#
    .SYNOPSIS
        Adds a Mirth User. 

    .DESCRIPTION
        This function creates a new mirth user and then updates the password.

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.
        $payLoad is a user XML object describing the user to be added:

            <user>
                <username>testUser4</username>
                <email>andy@datasprite.com</email>
                <firstName>Andrew</firstName>
                <lastName>Hart</lastName>
                <organization>DataSprite</organization>
                <description>This is a test user, added from PowerShell.</description>
                <phoneNumber>210-555-1234</phoneNumber>
            </user>

    .OUTPUTS
        Returns an XML object that is either a list of user elements or a single user element.

    .EXAMPLE
        $newUser = @"                
            <user>
                <username>myNewUserToo</username>
                <email>andy@datasprite.com</email>
                <firstName>Fred</firstName>
                <lastName>Flintstone</lastName>
                <organization>DataSprite</organization>
                <description>This is a test user, added from PowerShell.</description>
                <phoneNumber>210-724-2457</phoneNumber>
            </user>
        "@
        Connect-Mirth | Add-MirthUser -payLoad $newUser -newPassword topsecret

    .LINK
        Links to further documentation.

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # xml of the channel to be added
        [Parameter(ParameterSetName="xmlProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payLoad,

        # path to the file containing the channel xml to import
        [Parameter(ParameterSetName="pathProvided",
                   Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$payloadFilePath,

        # The new password when performing the add-user or change-password commands, default is "changeit"
        [Parameter()]
        [string]$newPassword = "changeit",
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string]$outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )
    BEGIN {
        Write-Debug "Add-MirthUser Beginning..." 
    }
    PROCESS { 

        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth" 
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl

        [xml]$userXML = $null 
        if ([string]::IsNullOrEmpty($payLoad) -or [string]::IsNullOrWhiteSpace($payLoad)) {
            if ([string]::IsNullOrEmpty($payloadFilePath) -or [string]::IsNullOrWhiteSpace($payloadFilePath)) {
                Write-Error "A user XML payLoad string is required!"
                return $null
            } else {
                Write-Debug "Loading user XML from path $payLoadFilePath"
                $userXML = Get-Content $payLoadFilePath  
            }
        } else {
            $userXML = [xml]$payLoad
        }
        $msg = "Adding user: " + $userXML.user.username + " assigned to " + $userXML.user.firstName + " " + $userXML.user.lastName
        Write-Debug $msg

        $uri = $serverUrl + '/api/users'
        Write-Debug "POST to Mirth $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method POST -ContentType 'application/xml' -Body $userXML.OuterXml
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                Write-Debug "Saving Output to $o"
                $r.save($o)     
                Write-Debug "Done!" 
            }
            Write-Verbose "$($r.OuterXml)"
            Set-MirthUserPassword -connection $connection -targetId $userXML.user.username -newPassword $newPassword
        }
        catch {
            Write-Error $_
        }

    } 
    END { 
        Write-Debug "Add-MirthUser Ending..."
    }

}  # Add-MirthUser

function global:Remove-MirthUser {
    <#
    .SYNOPSIS
        Deletes a Mirth user, specified by targetId (id only).

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

        $targetId   The id of the user to delete.
                    Note, the default admin user, id = 1,  cannot be deleted.

    .OUTPUTS

    .EXAMPLE

    .NOTES

    #> 
    [CmdletBinding()] 
    PARAM (

         # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline=$True)]
        [MirthConnection]$connection = $currentConnection,

        # The user id to be deleted, this must be the numeric id.
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [string]$targetId,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML = $false
    )    
    BEGIN { 
        Write-Debug "Remove-MirthUser Beginning"
    }
    PROCESS {
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"  
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        if (-NOT [string]::IsNullOrEmpty($targetId)) { 
            Write-Debug 'Getting user by target identifier'
            $uri = "$uri/$targetId"
        } else { 
            Throw "A targetId is required!"
        }

        $msg = "Deleting user: " + $targetId
        Write-Debug $msg

        $uri = $serverUrl + '/api/users/' + $targetId
        Write-Debug "DELETE to Mirth $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method DELETE -ContentType 'application/xml' -Body $userXML.OuterXml
            Write-Debug "...done."

            if ($saveXML) { 
                [string]$o = Get-PSMirthOutputFolder -create
                $o = Join-Path $o $outFile 
                Write-Debug "Saving Output to $o"
                $r.save($o)     
                #Set-Content -Path $o -Value "$targetId : $newPassword" 
                Write-Debug "Done!" 
            }
            Write-Verbose "$($r.OuterXml)"
            return $r
        }
        catch {
            Write-Error $_
        }
    }
    END {
        Write-Debug "Remove-MirthUser Ending"
    }
       
}  # Remove-MirthUser