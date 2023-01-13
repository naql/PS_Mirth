function Remove-MirthCodeTemplates { 
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
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection]$connection = $currentConnection,

        # Array of code template ids to be removed
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$targetIds,
   
        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch]$saveXML,
                
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
            
        }
        else { 
            $allCodeTemplates = Get-MirthCodeTemplates -connection $connection 
            if ($null -ne $allCodeTemplates) { 
                $targetIds = $allCodeTemplates.list.codeTemplate.id
                Write-Debug "There are $($targetIds.Count) code templates to be removed."
            }
            else { 
                Write-Warning "Unable to fetch list of code templates."
                $targetIds = @()
            }
        }

        $headers = $DEFAULT_HEADERS.Clone()
        $headers.Add("Content-Type", "application/xml")

        foreach ($targetId in $targetIds) {
            
            $uri = $serverUrl + '/api/codeTemplates/' + $targetId
            Write-Debug ("Deleting code template: {0}" -f $targetId)

            Write-Debug "DELETE to Mirth $uri "
            try { 
                $r = Invoke-RestMethod -Uri $uri -WebSession $session -Method DELETE -Headers $headers -Body $userXML.OuterXml

                if ($saveXML) { 
                    Save-Content $r $outFile
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
