<#
This is now deprecated
#>
function Convert-DashboardToArray {
    [CmdletBinding()]
    param (
        $dashboards
    )

    $ReturnList = [System.Collections.ArrayList]::new($dashboards.Count)

    #Write-Debug "Entering with dashboards: $($dashboards.Count)"

    foreach ($dashboard in $dashboards) {
        #Write-Debug "Starting dashboard"

        $DashBoardMap = @{}

        $PropNames = $dashboard | Get-Member -Type Property | Select-Object -ExpandProperty Name

        foreach ($PropName in $PropNames) {

            if ($dashboard.$PropName -is [System.Xml.XmlElement]) {

                $innerContents = @{}
                
                if ($PropName -match "child") {
                    #Write-Debug ("recursing for {0} using {1}" -f $PropName, $dashboard.$PropName.dashboardStatus)

                    $innerContents = Convert-DashboardToArray $dashboard.$PropName.dashboardStatus
                }
                elseif ($Propname -match "stat") {
                    #Write-Debug "Must be stats prop"
                    foreach ($statItem in $dashboard.$PropName.entry) {
                        $innerContents.Add($statItem['com.mirth.connect.donkey.model.message.Status'].InnerText, $statItem.long)
                    }
                }
                else {
                    #just copy the item over directly
                    $innerContents = $dashboard.$PropName

                    <#$DateProps = $dashboard.$PropName | Get-Member -Type Property | select -ExpandProperty Name
                    foreach ($dateProp in $DateProps) {
                        $innerContents.Add($dateProp, $dashboard.$PropName.$dateProp)
                    }#>
                }

                $DashBoardMap.Add($PropName, $innerContents)
            }
            else {
                $DashBoardMap.Add($PropName, $dashboard.$PropName)
            }
        }

        $ReturnList.Add($DashBoardMap) | Out-Null
    }
    
    $ReturnList.ToArray()
}