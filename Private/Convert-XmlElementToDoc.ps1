function Convert-XmlElementToDoc { 
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
        [Parameter(Mandatory = $True)]
        [Xml.XmlElement]$element
    )
    $xml = New-Object -TypeName xml
    $xml.AppendChild($xml.ImportNode($element, $true)) | Out-Null 
    return $xml
}  # Convert-XmlElementToDoc