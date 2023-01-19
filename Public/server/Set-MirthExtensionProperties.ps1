function Set-MirthExtensionProperties { 
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
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # The name of the extension that we want to fetch the properties of
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$targetId,

        
        # xml of the properties to be added
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [xml]$payLoad,

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
        
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
         
        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("accept", "application/xml")
        $headers.Add("Content-Type", "application/xml")
        $targetId = [uri]::EscapeDataString($targetId)
        $uri = $serverUrl + '/api/extensions/' + $targetId + "/properties"
        Write-Debug "Invoking PUT Mirth API server at: $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -Method PUT -WebSession $session -Body $payLoad.OuterXml
            Write-Debug "...done."
            if ($decode) { 
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
        Write-Debug "Set-MirthExtensionProperties Ending"
    }
}  #  Set-MirthExtensionProperties