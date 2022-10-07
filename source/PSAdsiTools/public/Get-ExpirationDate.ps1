Function Get-ExpirationDate {
    <#
    .SYNOPSIS
        Get the expiration date of the account
    .EXAMPLE
        PS C:\> $acc.accountExpires | Get-ExpirationDate
        Sunday, December 31, 1600 4:00:00 PM # this means never
    #>
    [CmdletBinding()]
    param(
    # Accountexpires field
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true
    )]
    [Object]
    $Field
    )
    try {
        $exp = ($Field).accountexpires
        $date = [datetime]::FromFileTime($exp)
    }
    catch {
        throw "An error occured getting the date expired`n$_"
    }

    $date
}
