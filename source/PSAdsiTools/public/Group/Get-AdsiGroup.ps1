
Function Get-AdsiGroup {
    <#
    .SYNOPSIS
        Get one or more groups from ActiveDirectory
    #>
    [CmdletBinding()]
    param(
        # Optionally provide the group name to search
        [Parameter(
            ValueFromPipeline
        )]
        [string]$Identity,

        # Return the raw SearchResult
        [Parameter(
        )]
        [switch]$Raw
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        try {
            $options = @{
                Category = 'group'
                Property = 'name'
                Value = $Identity
            }
            if ($Raw) {
                Search-ADSI @options
            } else {
                Search-ADSI @options | ConvertFrom-SearchResult
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

    }
    end {
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
