function Get-MirthServerSettings { 
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
        Write-Debug "Get-MirthServerSettings Ending" 
    }

}  #  Get-MirthServerSettings
