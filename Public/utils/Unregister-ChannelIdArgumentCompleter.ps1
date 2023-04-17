function Unregister-ChannelIdArgumentCompleter {
    [CmdletBinding()]
    param ()

    $sb = {}
    
    $params = @{
        #CommandName   = "Get-WinEvent"
        #ParameterName = "Logname"
        ScriptBlock = $sb
    }

    foreach ($FuncName in $script:AutocompleteFunctions.Keys) {
        $params.CommandName = $FuncName
        $params.ParameterName = $AutocompleteFunctions[$FuncName]

        Register-ArgumentCompleter @params
    }
}