function Format-SecurityPrincipal {

    # Format Security Principals (distinguish group members from principals directly listed in the NTFS DACLs)
    # The IdentityReference property will be null for any principals directly listed in the NTFS DACLs

    param (

        # Security Principals received from Expand-IdentityReference in the Adsi module
        $SecurityPrincipal

    )

    ForEach ($ThisPrincipal in $SecurityPrincipal) {

        # Format and output the security principal
        $ThisPrincipal |
        Select-Object -ExcludeProperty Name -Property @{
            Label      = 'User'
            Expression = {
                $ThisPrincipalAccount = $null
                if ($_.Properties) {
                    $ThisPrincipalAccount = $_.Properties['sAmAccountName']
                }
                if ("$ThisPrincipalAccount" -eq '') {
                    $_.Name
                } else {
                    $ThisPrincipalAccount
                }
            }
        },
        @{
            Label      = 'IdentityReference'
            Expression = { $null }
        },
        @{
            Label      = 'NtfsAccessControlEntries'
            Expression = { $_.Group }
        },
        @{
            Label      = 'Name'
            Expression = {
                $ThisName = $null
                if ($_.DirectoryEntry.Properties) {
                    $ThisName = $_.DirectoryEntry.Properties['name']
                }
                if ("$ThisName" -eq '') {
                    $_.Name -replace [regex]::Escape("$($_.DomainNetBios)\"), ''
                } else {
                    $ThisName
                }
            }
        },
        *

        # Format and output its members if it is a group
        $ThisPrincipal.Members |
        <#
        # Because we have already recursively retrieved all group members, we now have all the users so we can filter out the groups from the group members.
        Where-Object -FilterScript {
            if ($_.DirectoryEntry.Properties) {
                $_.DirectoryEntry.Properties['objectClass'] -notcontains 'group' -and
                $null -eq $_.DirectoryEntry.Properties['groupType'].Value
            } else {
                $_.Properties['objectClass'] -notcontains 'group' -and
                $null -eq $_.Properties['groupType'].Value
            }
        } |
        #>
        Select-Object -Property @{
            Label      = 'User'
            Expression = {
                $ThisPrincipalAccount = $null
                if ($_.Properties) {
                    $ThisPrincipalAccount = $_.Properties['sAmAccountName']
                    if ("$ThisPrincipalAccount" -eq '') {
                        $ThisPrincipalAccount = $_.Properties['Name']
                    }
                }

                if ("$ThisPrincipalAccount" -eq '') {
                    # This code should never execute
                    # but if we are somehow not dealing with a DirectoryEntry,
                    # it will not have sAmAcountName or Name properties
                    # However it may have a direct Name attribute on the PSObject itself
                    # We will attempt that as a last resort in hopes of avoiding a null Account name
                    $ThisPrincipalAccount = $_.Name
                }
                "$($_.Domain.Netbios)\$ThisPrincipalAccount"
            }
        },
        @{
            Label      = 'IdentityReference'
            Expression = {
                $ThisPrincipal.Group.IdentityReferenceResolved |
                Sort-Object -Unique
            }
        },
        @{
            Label      = 'NtfsAccessControlEntries'
            Expression = { $ThisPrincipal.Group }
        },
        *

    }

}
