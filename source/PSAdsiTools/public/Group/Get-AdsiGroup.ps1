
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
        [string]$Identity
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        try {
            Search-ADSI -Category 'group' -Property 'name' -Value $Identity
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

    }
    end {
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
