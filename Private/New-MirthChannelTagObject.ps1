function New-MirthChannelTagObject {
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
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string]$tagId = $(New-Guid).toString(),

        # the property key name
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$tagName,

        # the alpha value, 0-255, defaults to 255
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [ValidateRange(0, 255)]
        [int]$alpha = 255,
   
        # the red value, 0-255, defaults to 0
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [ValidateRange(0, 255)]
        [int]$red = 0,
        
        # the green value,, 0-255, defaults to 0
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [ValidateRange(0, 255)]
        [int]$green = 0,

        # the blue value, 0-255, defaults to 0
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [ValidateRange(0, 255)]
        [int]$blue = 0,

        # an optional array of channelId guids
        # the channelTag id guid strings that the tag applies to
        [Parameter(ValueFromPipelineByPropertyName = $True)]
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