BeforeAll {
    $Private = @( Get-ChildItem -Path .\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue )

    #Dot source the files
    Foreach ($import in $Private) {
        Try {
            . $import.fullname
        }
        Catch {
            Write-Error -Message "Failed to import class/function $($import.fullname): $_"
        }
    }
}

Describe 'Convert-UnixTimeToDateTimeOffset' {
    It 'Given a timezone, it returns correct data' {
        $UnixTimeInMillis = 1673985402974
        #Timezone should take UTC
        #1/17/2023 7:56:42 PM +00:00
        #to
        #1/17/2023 1:56:42 PM +00:00
        $TimeZone = "America/Chicago"
        $ConvertedTime = Convert-UnixTimeToDateTimeOffset $UnixTimeInMillis $TimeZone
        $ConvertedTime | Should -BeOfType [System.DateTimeOffset]
        $ConvertedTime.ToString() | Should -Be "1/17/2023 1:56:42 PM +00:00"
    }

    It 'Given no timezone, it returns correct data' {
        #1/17/2023 7:56:42 PM +00:00
        $UnixTimeInMillis = 1673985402974
        $TimeZone = "America/Chicago"
        $ConvertedTime = Convert-UnixTimeToDateTimeOffset $UnixTimeInMillis
        $ConvertedTime | Should -BeOfType [System.DateTimeOffset]
        $ConvertedTime.ToString() | Should -Be "1/17/2023 7:56:42 PM +00:00"
    }
}