
Function Get-ManagedServiceAccount {
    <#
    .SYNOPSIS
        Return the AD Managed Service Accounts found in AD
    #>
    [CmdletBinding()]
    param(
        # The searcher object to use
        [Parameter(
            Mandatory = $false
        )]
        [System.DirectoryServices.DirectorySearcher]$Searcher = [ADSISearcher]""

    )
    try {
        $svcs = Search-ADSI -Class 'msDS-GroupManagedServiceAccount' -Connection $Searcher
    } catch {
        throw "An error occured getting the Managed Service Accounts`n$_"
    }
    $svcs
}
