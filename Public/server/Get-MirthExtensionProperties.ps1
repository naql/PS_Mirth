function Get-MirthExtensionProperties { 
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
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The name of the extension that we want to fetch the properties of
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$targetId,

        # Switch to decode html encoded data
        [Parameter()]
        [switch]$decode,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
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
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Content-Type", "application/xml")
        Write-Debug "Invoking GET Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session -Headers $headers
            Write-Debug "...done."
            if ($decode) {
                Write-Debug "Decoding XML escaped data..." 
                $decoded = [System.Web.HttpUtility]::HtmlDecode($r.OuterXml)
                $r = [xml]$decoded
            }

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
        Write-Debug "Get-MirthExtensionProperties Ending"
    }
}  #  Get-MirthExtensionProperties