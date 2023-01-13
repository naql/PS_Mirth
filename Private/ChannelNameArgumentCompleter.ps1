function ChannelNameArgumentCompleter {
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
            Write-Warning "Unknown option '$_' in ChannelNameArgumentCompleter, ignoring"
        }
    }

    CommonArgCompletion $searchMap.Values $wordToComplete
}