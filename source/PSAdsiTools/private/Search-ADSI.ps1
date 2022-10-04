
function Search-ADSI {
    <#
    .SYNOPSIS
        Internal function that searches AD and returns a hash
    #>

    [CmdletBinding()]
    param(
        # The ObjectClass to search for
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]$Class = '*',

        # Optionally, provide the property to search
        [Parameter(
            ParameterSetName = 'Search')]
        [string]$Property,

        # If the Property is provided, the value to search for
        [Parameter(
            ParameterSetName = 'Search')]
        [string]$Value,

        # The ADSISearcher to connect to
        [Parameter(
        )]
        [ADSISearcher]$Connection
    )

    if ($null -eq $script:ADSI_Searcher ) {
        if ($PSBoundParameters['Connection']) {
            $script:ADSI_Searcher = $Connection
        } else {
            Write-Warning "ActiveDirectory Connection not set:"
            Write-Warning "To avoid this warning run 'Connect-ActiveDirectory' first"
            Write-Warning "run 'get-help about_AdReports' for more information."
            Write-Warning "establishing connection now"
            Connect-ActiveDirectory
        }
    }

    $query = "(objectclass=$Class)"
    if ($PSBoundParameters['Property'] -and $PSBoundParameters['Value']) {
        $query = "(&$query($Property=$Value))"
    } elseif ($PSBoundParameters['Value']) {
        $query = "(&$query($Value))"
    } elseif ($PSBoundParameters['Property']) {
        $query = "(&$query($Property='*'))"
    }
    try {
        Write-Verbose "Searching AD for $query"
        $script:ADSI_Searcher.Filter = $query
        $results = $script:ADSI_Searcher.FindAll()
        Write-Verbose "Query returned $($results.Count) results"
    } catch {
        throw "An error occured searching AD for $query`n$_"
    }

    $results
}
