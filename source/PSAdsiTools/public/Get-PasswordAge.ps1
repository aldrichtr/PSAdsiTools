
Function Get-PasswordAge {
    <#
    .SYNOPSIS
        Get the password age from the provided account object
    #>
    [CmdletBinding()]
    param(
        # The user to get the password age from
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object]
        $Account
    )

    try {
        $now = Get-Date

        $a_lastset = $Account.pwdlastset | ConvertTo-DateTime
        Write-Verbose "Account password was last set on : $($a_lastset)"

        $pw_age = New-TimeSpan -Start $a_lastset -End $now
    } catch {
        throw "There was an error computing the password age`n$_"
    }
    Write-Verbose "Account password age : $($pw_age.Days) days"
    $pw_age
}
