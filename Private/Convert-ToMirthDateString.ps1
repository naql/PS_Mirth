function Convert-ToMirthDateString {
    <#
    .SYNOPSIS
        Convert objects to a date string that Mirth accepts
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Value
    )

    begin {
        $Result = ""
    }
    
    process {
        $Result = switch ($Value.GetType().Name) {
            "string" {
                [System.DateTimeOffset]::Parse($Value).ToString("yyyy-MM-ddTHH:mm:ss.fffK")
            }
            "DateTime" {
                if ($Value.Kind -ne "Local") {
                    $Value = $Value.toLocalTime()
                }
                $Value.ToString("yyyy-MM-ddTHH:mm:ss.fffK")
            }
            "DateTimeOffset" {
                $Value.ToString("yyyy-MM-ddTHH:mm:ss.fffK")
            }
            Default {
                Throw "Cannot convert type '$($Value.GetType().Name)' to a Mirth-friendly date string"
            }
        }
    }

    end {
        # Remove the colon from the timezone offset - likely easier to do this in the ToString
        return $Result.Remove($Result.LastIndexOf(":"), 1)
    }
}