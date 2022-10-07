
function Search-ADSI {
    <#
    .SYNOPSIS
        Internal function that searches AD and returns a hash
    .LINK
        <https://learn.microsoft.com/en-us/windows/win32/adsi/search-filter-syntax>
    #>

    [CmdletBinding(
        DefaultParameterSetName = 'AsParam'
    )]
    param(
        # The ObjectClass to search for
        [Parameter(
            ParameterSetName = 'AsParam'
        )]
        [string]$Category = '*',

        # Optionally, provide the property to search
        [Parameter(
            ParameterSetName = 'AsParam')]
        [string]$Property,

        # If the Property is provided, the value to search for
        [Parameter(
            ParameterSetName = 'AsParam')]
        [string]$Value,

        # Optionally provide multiple properties and values in a hashtable
        [Parameter(
            ParameterSetName = 'AsTable'
        )]
        [hashtable]$Properties,

        # LDAP query string
        [Parameter(
            ParameterSetName = 'AsQuery'
        )]
        [string]$Query,

        # The container to search in the directory
        [Parameter(
        )]
        [string]$Root,

        # The ADSISearcher to connect to
        [Parameter(
        )]
        [ADSISearcher]$Connection,

        # Only return the first match
        [Parameter(
        )]
        [switch]$FindOne
    )

    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        if ($null -eq $script:ADSI_Searcher ) {
            if ($PSBoundParameters.ContainsKey('Connection')) {
                $script:ADSI_Searcher = $Connection
            } else {
                Write-Verbose 'ActiveDirectory Connection not set:'
                Write-Verbose "To avoid this warning run 'Connect-ActiveDirectory' first"
                Write-Verbose "run 'get-help about_AdReports' for more information."
                Write-Verbose 'establishing connection now'
                Connect-ActiveDirectory
            }
        }
        if ($PSBoundParameters.ContainsKey('Root')) {
            try {
                $script:ADSI_Searcher.SearchRoot = $Root
            } catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        if ($PSCmdlet.ParameterSetName -like 'AsParam') {
            <#------------------------------------------------------------------
              Parameters where given to build a query
            ------------------------------------------------------------------#>
            $query = "(objectCategory=$Category)"
            if ($PSBoundParameters.ContainsKey('Property') -and
                $PSBoundParameters.ContainsKey('Value')
            ) {
                $query = "(&$query($Property=$Value))"
            } elseif ($PSBoundParameters.ContainsKey('Value')) {
                $query = "(&$query($Value))"
            } elseif ($PSBoundParameters.ContainsKey('Property')) {
                $query = "(&$query($Property=*))"
            } else {
                throw "Could not create query from Parameters"
            }

        } elseif ($PSCmdlet.ParameterSetName -like 'AsTable') {
            if ($PSBoundParameters.ContainsKey('Properties')) {
                # each key creates a (property=value)
                # and then wrap that in with the objectCategory
                # at the end with an &
                $query_group = ''
                foreach ($key in $Properties) {
                    $query_group = -join @('(', $key, '=', $Properties[$key], ')')
                }
                $query = -join @('(&', $query, $query_group, ')')
            } else {
                throw "Could not create query from hashtable"
            }
        } elseif ($PSCmdlet.ParameterSetName -like 'AsQuery') {
            if ($PSBoundParameters.Keys -notcontains 'Query') {
                throw 'No Parameters and no query given to search ADSI'
            }
        }
        <#------------------------------------------------------------------
          Now either the parameters have been formed into a query or one
          has been provided.  Perform the seach
        ------------------------------------------------------------------#>
        try {
            Write-Verbose "Searching AD for $query"
            $script:ADSI_Searcher.Filter = $query
            if ($FindOne) {
                $script:ADSI_Searcher.FindOne() | Write-Output
            } else {
                $script:ADSI_Searcher.FindAll() | Write-Output
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    end {
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
