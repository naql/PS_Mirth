function Register-ChannelIdArgumentCompleter {
    [CmdletBinding()]
    param ()

    $sb = {
        param (
            $commandName,
            $parameterName,
            $wordToComplete,
            $commandAst,
            $fakeBoundParameters
        )

        CommonArgCompletion (Get-MirthChannelIdsAndNames).Keys $wordToComplete
    }
    
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