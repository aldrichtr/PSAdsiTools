
Function Test-CloExempt {
    <#
    .SYNOPSIS
        Test the CLO Exemption status of the given account.
    .DESCRIPTION
        Return true if the account flag SMARTCARD_REQUIRED is not set
    #>
    [CmdletBinding()]
    param(
        # sAMAccountName of user to test defaults to current user if not specified
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true
        )]
        [string]
        $Name = $env:USERNAME,

        # Optionally provide LDAP Path to the Account
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true
        )]
        [string]
        $Path
    )

    $result = $false

    if ($PSBoundParameters['Path']) {
        try {
            $search = Search-ADSI -Property 'distinguishedname' -Value $Path -Class 'Person'
        } catch {
            throw "An error occured getting the account`n$Path`n$_"
        }
    } else {
        try {
            $search = Search-ADSI -Class 'Person' -Property 'samaccountname' -Value $Name
        } catch {
            throw "An error occured getting the account $Name`n$_"
        }

        switch ($search.Count) {
            0 {
                throw "Search did not return any results"
                break
            }
            1 {
                # notice the '-not' because if the CAC is required, the user is NOT exempt
                $user = $search.GetDirectoryEntry()
                $result = -not (Test-AccountControl SMARTCARD_REQUIRED $user.userAccountControl)
                break
            }
            default {
                if ($PSBoundParameters['Path']) { $Account = $Path } else { $Account = $Name }
                throw "$Account returned $($search.Count) results"
                break
            }
        }

        $result
    }
}
