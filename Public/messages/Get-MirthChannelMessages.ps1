function Get-MirthChannelMessages { 
    <#
    .SYNOPSIS
        Gets a message id from a channel, specified by id.

    .DESCRIPTION

    .INPUTS
        A -session  WebRequestSession object is required. See Connect-Mirth.

    .OUTPUTS
        [xml] representation of a channel message;  the message itself is in 

    .EXAMPLE
        Get-MirthChannelMessages -channelId ffe2e62c-5dd8-435e-a877-987d3f6c3d09 -minMessageId 8 -limit 5

    .LINK

    .NOTES

    #>
    [CmdletBinding()] 
    PARAM (
        # A MirthConnection is required. You can obtain one from Connect-Mirth.
        [Parameter(ValueFromPipeline = $True)]
        [MirthConnection] $connection = $currentConnection,

        # The id of the channel to interrogate, required
        [Parameter(Mandatory = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$channelId,

        ## these were copied directly from the Mirth API page ##

        # The minimum message ID to query.
        [Parameter()]
        [int]$minMessageId,

        # The maximum message ID to query.
        [Parameter()]
        [int]$maxMessageId,

        # The minimum original message ID to query. Messages that have been reprocessed will retain their original message ID.
        [Parameter()]
        [int]$minOriginalId,

        #The maximum original message ID to query. Messages that have been reprocessed will retain their original message ID.
        [Parameter()]
        [int]$maxOriginalId,

        # The minimum import message ID to query. Messages that have been imported will retain their original message ID under this value.
        [Parameter()]
        [int]$minImportId,

        # The maximum import message ID to query. Messages that have been imported will retain their original message ID under this value.
        [Parameter()]
        [int]$maxImportId,

        # The earliest original received date to query by. Example: 1985-10-26T09:00:00.000-0700
        [Parameter()]
        [datetime]$startDate,

        # The latest original received date to query by. Example: 2015-10-21T07:28:00.000-0700
        [Parameter()]
        [datetime]$endDate,

        # Searches all message content for this string. This process could take a long time depending on the amount of message content currently stored. Any message content that was encrypted by this channel will not be searchable.
        [Parameter()]
        [string]$textSearch,

        # If true, text search input will be considered a regular expression pattern to be matched. Only supported by PostgreSQL, MySQL and Oracle databases.
        [Parameter()]
        [bool]$textSearchRegex,

        # Determines which message statuses to query by.
        [Parameter()]
        [ValidateSet('RECEIVED', 'FILTERED', 'TRANSFORMED', 'SENT', 'QUEUED', 'ERROR', 'PENDING')]
        [string[]]$status,

        # If present, only connector metadata IDs in this list will be queried.
        [Parameter()]
        [int[]]$includedMetaDataId,

        # If present, connector metadata IDs in this list will not be queried.
        [Parameter()]
        [int[]]$excludedMetaDataId,

        # The server ID associated with messages.
        [Parameter()]
        [string]$serverId,

        # Searches the raw content of messages.
        [Parameter()]
        [string[]]$rawContentSearch,

        # Searches the processed raw content of messages.
        [Parameter()]
        [string[]]$processedRawContentSearch,

        # Searches the transformed content of messages.
        [Parameter()]
        [string[]]$transformedContentSearch,

        # Searches the encoded content of messages.
        [Parameter()]
        [string[]]$encodedContentSearch,

        # Searches the sent content of messages.
        [Parameter()]
        [string[]]$sentContentSearch,

        # Searches the response content of messages.
        [Parameter()]
        [string[]]$responseContentSearch,

        # Searches the response transformed content of messages.
        [Parameter()]
        [string[]]$responseTransformedContentSearch,

        # Searches the processed response content of messages.
        [Parameter()]
        [string[]]$processedResponseContentSearch,

        # Searches the connector map content of messages.
        [Parameter()]
        [string[]]$connectorMapContentSearch,

        # Searches the channel map content of messages.
        [Parameter()]
        [string[]]$channelMapContentSearch,

        # Searches the source map content of messages.
        [Parameter()]
        [string[]]$sourceMapContentSearch,

        # Searches the response map content of messages.
        [Parameter()]
        [string[]]$responseMapContentSearch,

        # Searches the processing error content of messages.
        [Parameter()]
        [string[]]$processingErrorContentSearch,

        # Searches the postprocessor error content of messages.
        [Parameter()]
        [string[]]$postprocessorErrorContentSearch,

        # Searches the response error content of messages.
        [Parameter()]
        [string[]]$responseErrorContentSearch,

        # Searches a custom metadata column. Value should be in the form: COLUMN_NAME <operator> value, where operator is one of the following: = , ! = , <, < = , >, > = , CONTAINS, DOES NOT CONTAIN, STARTS WITH, DOES NOT START WITH, ENDS WITH, DOES NOT END WITH
        [Parameter()]
        [string[]]$metaDataSearch,

        # Searches a custom metadata column, ignoring case. Value should be in the form: COLUMN_NAME <operator> value.
        [Parameter()]
        [string[]]$metaDataCaseInsensitiveSearch,

        # When using a text search, these custom metadata columns will also be searched.
        [Parameter()]
        [string[]]$textSearchMetaDataColumn,

        # The minimum number of send attempts for connector messages.
        [Parameter()]
        [int]$minSendAttempts,

        # The maximum number of send attempts for connector messages.
        [Parameter()]
        [int]$maxSendAttempts,

        # If true, only messages with attachments are included in the results.
        [Parameter()]
        [bool]$attachment,

        #The param name in Mirth is actually "error", but that is a reserved word.

        # If true, only messages with errors are included in the results.
        [Parameter()]
        [bool]$includeError,

        # If true, message content will be returned with the results.
        [Parameter()]
        [bool]$includeContent = $false,

        # Used for pagination, determines where to start in the search results.
        [Parameter()]
        [int]$offset = 0,

        # Used for pagination, determines the maximum number of results to return.
        [Parameter()]
        [int]$limit = 20,

        ## end copy directly from the Mirth API page ##

        # Sets the response type via the 'accept' header. Default is XML.
        [Parameter()]
        [ValidateSet('JSON', 'XML')]
        [string] $ResponseType = 'XML',

        # Saves the response from the server as a file in the current location.
        [Parameter()]
        [switch] $saveXML,
        
        # Optional output filename for the saveXML switch, default is "Save-[command]-Output.xml"
        [Parameter()]
        [string] $outFile = 'Save-' + $MyInvocation.MyCommand + '-Output.xml'
    )         
    BEGIN { 
        Write-Debug "Get-MirthChannelMessages Beginning"
    }
    PROCESS { 
        #GET # ​/channels​/{channelId}​/messages
        if ($null -eq $connection) { 
            Throw "You must first obtain a MirthConnection by invoking Connect-Mirth"    
        }          
        [Microsoft.PowerShell.Commands.WebRequestSession]$session = $connection.session
        $serverUrl = $connection.serverUrl
             
        $uri = $serverUrl + "/api/channels/$channelId/messages"

        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)

        if ($PSBoundParameters.ContainsKey('minMessageId')) { 
            $parameters.Add('minMessageId', $minMessageId)
        }
        if ($PSBoundParameters.ContainsKey('maxMessageId')) { 
            $parameters.Add('maxMessageId', $maxMessageId)
        }
        if ($PSBoundParameters.ContainsKey('minOriginalId')) {
            $parameters.Add('minOriginalId', $minOriginalId)
        }
        if ($PSBoundParameters.ContainsKey('maxOriginalId')) {
            $parameters.Add('maxOriginalId', $maxOriginalId)
        }
        if ($PSBoundParameters.ContainsKey('minImportId')) {
            $parameters.Add('minImportId', $minImportId)
        }
        if ($PSBoundParameters.ContainsKey('maxImportId')) {
            $parameters.Add('maxImportId', $maxImportId)
        }
        if ($PSBoundParameters.ContainsKey('startDate')) {
            $FormattedDate = Convert-ToMirthDateString $startDate
            #$FormattedDate = $startDate.ToString("yyyy-MM-ddTHH:mm:ss.fffK")
            $parameters.Add('startDate', $FormattedDate)
        }
        if ($PSBoundParameters.ContainsKey('endDate')) {
            $FormattedDate = Convert-ToMirthDateString $endDate
            #$FormattedDate = $endDate.ToString("yyyy-MM-ddTHH:mm:ss.fffK")
            $parameters.Add('endDate', $FormattedDate)
        }
        if ($PSBoundParameters.ContainsKey('textSearch')) {
            $parameters.Add('textSearch', $textSearch)
        }
        if ($PSBoundParameters.ContainsKey('textSearchRegex')) {
            $parameters.Add('textSearchRegex', $textSearchRegex)
        }
        if ($PSBoundParameters.ContainsKey('status')) {
            foreach ($value in $status) {
                $parameters.Add('status', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('includedMetaDataId')) {
            foreach ($value in $includedMetaDataId) {
                $parameters.Add('includedMetaDataId', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('excludedMetaDataId')) {
            foreach ($value in $excludedMetaDataId) {
                $parameters.Add('excludedMetaDataId', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('serverId')) {
            $parameters.Add('serverId', $serverId)
        }
        if ($PSBoundParameters.ContainsKey('rawContentSearch')) {
            foreach ($value in $rawContentSearch) {
                $parameters.Add('rawContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('processedRawContentSearch')) {
            foreach ($value in $processedRawContentSearch) {
                $parameters.Add('processedRawContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('transformedContentSearch')) {
            foreach ($value in $transformedContentSearch) {
                $parameters.Add('transformedContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('encodedContentSearch')) {
            foreach ($value in $encodedContentSearch) {
                $parameters.Add('encodedContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('sentContentSearch')) {
            foreach ($value in $sentContentSearch) {
                $parameters.Add('sentContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('responseContentSearch')) {
            foreach ($value in $responseContentSearch) {
                $parameters.Add('responseContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('responseTransformedContentSearch')) {
            foreach ($value in $responseTransformedContentSearch) {
                $parameters.Add('responseTransformedContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('processedResponseContentSearch')) {
            foreach ($value in $processedResponseContentSearch) {
                $parameters.Add('processedResponseContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('connectorMapContentSearch')) {
            foreach ($value in $connectorMapContentSearch) {
                $parameters.Add('connectorMapContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('channelMapContentSearch')) {
            foreach ($value in $channelMapContentSearch) {
                $parameters.Add('channelMapContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('sourceMapContentSearch')) {
            foreach ($value in $sourceMapContentSearch) {
                $parameters.Add('sourceMapContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('responseMapContentSearch')) {
            foreach ($value in $responseMapContentSearch) {
                $parameters.Add('responseMapContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('processingErrorContentSearch')) {
            foreach ($value in $processingErrorContentSearch) {
                $parameters.Add('processingErrorContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('postprocessorErrorContentSearch')) {
            foreach ($value in $postprocessorErrorContentSearch) {
                $parameters.Add('postprocessorErrorContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('responseErrorContentSearch')) {
            foreach ($value in $responseErrorContentSearch) {
                $parameters.Add('responseErrorContentSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('metaDataSearch')) {
            foreach ($value in $metaDataSearch) {
                $parameters.Add('metaDataSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('metaDataCaseInsensitiveSearch')) {
            foreach ($value in $metaDataCaseInsensitiveSearch) {
                $parameters.Add('metaDataCaseInsensitiveSearch', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('textSearchMetaDataColumn')) {
            foreach ($value in $textSearchMetaDataColumn) {
                $parameters.Add('textSearchMetaDataColumn', $value)
            }
        }
        if ($PSBoundParameters.ContainsKey('minSendAttempts')) {
            $parameters.Add('minSendAttempts', $minSendAttempts)
        }
        if ($PSBoundParameters.ContainsKey('maxSendAttempts')) {
            $parameters.Add('maxSendAttempts', $maxSendAttempts)
        }
        if ($PSBoundParameters.ContainsKey('attachment')) {
            $parameters.Add('attachment', $attachment)
        }
        if ($PSBoundParameters.ContainsKey('includeError')) {
            #note that this param name does not match its variable name
            $parameters.Add('error', $includeError)
        }
        
        #these are all required, says https://github.com/nextgenhealthcare/connect/discussions/4638#discussioncomment-2090314
        $parameters.Add('limit', $limit)
        $parameters.Add('offset', $offset)
        $parameters.Add('includeContent', $includeContent)
        
        $uri = $uri + '?' + $parameters.toString()

        $headers = $DEFAULT_HEADERS.clone()
        switch ($ResponseType) {
            'JSON' { $headers.Add('accept', 'application/json') }
            'XML' { $headers.Add('accept', 'application/xml') }
            Default {}
        }

        Write-Debug "Invoking GET Mirth  $uri "
        try { 
            $r = Invoke-RestMethod -Uri $uri -Method GET -WebSession $session -Headers $headers
            Write-Debug "...done."

            <#
            #a non-match returns an empty string,
            #so safety check before printing XML content
            if ($r -is [System.Xml.XmlDocument]) {
                Write-Verbose $r.innerXml
            }
            #>

            #Write-Debug $r.OuterXml

            if ($saveXML) {
                #we could be helpful and match the file extension to the response type
                <#if ($ResponseType -eq "JSON") {
                    $item = Get-Item $outFile
                    $outFile = Join-Path $item.Directory.FullName ($item.BaseName + ".json")
                }#>
                
                Save-Content $r $outFile
            }

            $r

            <#if ($Raw) {
                $r
            }
            else {
                Write-Debug "Converting XML to hashtable"
                ConvertFrom-Xml $r.DocumentElement -ConvertAsList @('list') -ConvertAsMap @{ 'connectorMessages' = $false }

            }#>
        }
        catch {
            Write-Error $_
        }        
    }
    END { 
        Write-Debug "Get-MirthChannelMessages Ending"
    }
}