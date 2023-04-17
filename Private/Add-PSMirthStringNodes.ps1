function Add-PSMirthStringNodes { 
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