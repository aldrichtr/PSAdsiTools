
function Connect-ActiveDirectory {
    <#
    .SYNOPSIS
        Create a new System.DirectoryService.DirectorySearcher
    .EXAMPLE
        PS C:\> Connect-ActiveDirectory
    #>
    [CmdletBinding()]
    [Alias('Connect-Domain')]
    param(
        # The level to root the search
        [Parameter(
        )]
        [string]$Root,

        # Disable cacheing
        [Parameter(
        )]
        [switch]$NoCache,

        # Limit the number of results
        [Parameter(
        )]
        [int]$Page
    )

    $script:ADSI_Searcher = [adsisearcher]""
    switch ($PSBoundParameters.Keys) {
        'Root' {
            $script:ADSI_Searcher.SearchRoot = $Root
        }
        'NoCache' {
            $script:ADSI_Searcher.CacheResults = $false
            Write-Verbose "Disabled caching"
        }
        'Page' {
            $script:ADSI_Searcher.PageSize = $Page
        }
    }
    Write-Verbose "Created ADSI Search in $Root"
}
