
Function Get-MaxPasswordAge {
    <#
    .SYNOPSIS
        Get the maximum password age of the accounts domain as a timespan
    #>
    [CmdletBinding()]
    param(
        # The account to use.  The domain is read from the path
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object]
        $Account
    )

    $null = $Account.Path -match '^.*?(DC=.*)$'

    if ($Matches.Count -eq 0) {
        throw "An error occured getting the domain for $($Account.Path)"
    } else {
        $Domain = $Matches.1
        Write-Verbose "Connecting to $Domain for password rules"
    }
    try {
        $ad = [adsi]"LDAP://$Domain"
        $pw_seconds = $ad.ConvertLargeIntegerToInt64($ad.maxPwdAge[0])
        $pw_span = New-TimeSpan -Seconds ($pw_seconds = 10000000)
        Write-Verbose "Maximum Password Age : $($pw_span.Days) days"
    } catch {
        throw "There was an error computing the password age`n$_"
    }

    $pw_span
}
