
function Get-AdsiUser {
    <#
    .SYNOPSIS
        Get the specified accounts from AD using ADSISearcher
    .DESCRIPTION
        `Get-AdsiAccount` returns an object representing an account for each name specified in the Identity parameter.
    .EXAMPLE
        PS > Get-ADAccount 'taldrich'
    #>
    [CmdletBinding(
        DefaultParameterSetName = 'ByName'
    )]
    param(
        # Optionally provide LDAP Path to the Account
        # the format would be `LDAP://<SID=S-1-5-21-111111111-1111111-11111-111>`
        [Parameter(
            ParameterSetName = 'ByPath',
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [string[]]$Path,

        # Optionally provide the user name to find.
        # fields searched are:
        # - distinguishedname
        # - objectguid
        # - objectsid
        # - samaccountname
        [Parameter(
            ParameterSetName = 'ByName',
            Position = 0,
            ValueFromPipeline
        )]
        [string[]]$Identity,

        # Filter objects
        [Parameter(
        )]
        [scriptblock]$Filter,

        # Return the raw directory entry object
        [Parameter(
        )]
        [switch]$Raw
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        if ($PSBoundParameters['Path']) {
            try {
                Search-ADSI -Property 'distinguishedname' -Value $Path | Write-Output
            } catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        } else {
            foreach ($id in $Identity) {
                $options = @{
                    Category = 'person'
                    Property = ''
                    Value    = ''
                }
                try {
                    switch -Regex ($id) {
                        '^[0-9a-fA-F]+$' {
                            Write-Debug "  Identity $id given as an objectGUID (hex)"
                            $options.Property = 'objectGUID'
                        }
                        '^CN=' {
                            Write-Debug "  Identity $id given was a distinguished name"
                            $options.Property = 'dn'
                        }
                        '^S-1-5' {
                            Write-Debug "  Identity $id given was a sid"
                            $options.Property = 'objectsid'
                        }
                        '.*@.*' {
                            Write-Debug "  Identity $id given was a user principle name"
                            $options.Property = 'userprincipalname'
                        }
                        Default {
                            Write-Debug "  Identity $id given might be a samaccountname"
                            $options.Property = 'samaccountname'
                        }
                    }

                    $options.Value = $id
                    if ($Raw) {
                        Search-ADSI @options | Write-Output
                    } else {
                        Search-ADSI @options | ConvertFrom-SearchResult | Write-Output
                    }

                } catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
        }
    }
    end {
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
