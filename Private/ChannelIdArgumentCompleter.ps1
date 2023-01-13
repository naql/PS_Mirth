function ChannelIdArgumentCompleter {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    $searchMap = @{}

    switch ($script:ChannelAutocomplete) {
        None { }
        Cache {
            $searchMap = $script:CachedChannelMapForAutocompletion
        }
        Live {
            $searchMap = Get-MirthChannelIdsAndNames
        }
        Default {
            Write-Warning "Unknown option '$_' in ChannelIdArgumentCompleter, ignoring"
        }
    }

    CommonArgCompletion $searchMap.Keys $wordToComplete
}