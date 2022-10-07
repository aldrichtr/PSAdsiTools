
Function Get-LogonDetail {
    <#
    .SYNOPSIS
        Return a collection of details related to Account Logon
    .DESCRIPTION
        Logon details for an individual account looks like
        @{
            Category = 'person'
            Type = 'AD_ACCOUNT_TYPE'
            Path = distinguishedname # (OU path to account)
            Name = @{
                display = "...."
                account = "sam.account.name"
            }
            Mail = 'first.last@domain'
            Lock = @{
                Set  = $false
                Time = nil

            }
            Modified    = 1/1/19 12:22
            Enabled     = $true
            Created     = 1/1/18 13:45
            Expires     = 1/1/30 23:59
            Logon   = @{
                CloEnforced = $false
                Count  = 246
                Last   = 1/1/21 11:21
            }
            Password = @{
                Required = $true
                CanSet   = $true
                Expires  = $false
                LastSet  = 1/1/18 22:40
            }
            Groups = @('all','groups', 'account', 'is', 'in' )
        }
    .EXAMPLE
        $domain = Connect-Domain
        $All_HA_Accounts = Get-ADGroup $domain -Name "IMEFDM-All-HA-Admins"
        Get-LogonDetail $All_HA_Accounts
    #>

    [CmdletBinding(
        DefaultParameterSetName = 'SearchResult'
    )]
    param(
        # One or more groups or accounts to get the LogonDetails for
        [Parameter(
            ParameterSetName = 'SearchResult',
            ValueFromPipeline
        )]
        [System.DirectoryServices.SearchResult[]]$Result,

        # A fully qualified path (distinguishedname) to an object
        [Parameter(
            ParameterSetName = 'ObjectPath',
            ValueFromPipelineByPropertyName
        )]
        [ValidatePattern('^\s*[LDAP:\/\/]*CN=.+$')]
        [string[]]$Path
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        Write-Verbose 'Evaluating parameters and values'
        if ($PSBoundParameters.ContainsKey('Path')) {
                # let's make sure the Path looks correct before we search using it
                Write-Verbose "Validating Path: $Path"
                $null = $Path -match '^\s*[LDAP:\/\/]*(CN=.*?DC=.*)$'
                if ($Matches.Count -gt 0) {
                    Write-Debug "DistinguishedName from path is $($Matches.1)"
                    $Result += Search-ADSI -Property 'distinguishedname' -Value $Matches.1
                } else {
                    throw "$Path doesn't look like a valid distinguishedname"
                }
                $Matches.Clear()
            } else {
                Write-Verbose 'A path was not provided'
            }
            if ($PSBoundParameters['Result']) {
                Write-Verbose "Getting Logon Details for $($Result.Count) objects"
            }

            $report = @{
                'Date'    = (Get-Date)
                'Results' = @()
            }

            # the ADSI domain object has useful tools
            $entry_count = 0
            Write-Verbose 'Processing results'
            if ($PSCmdlet.ShouldProcess("$($Result.name)", 'Get-LogonDetail')) {
                foreach ($entry in $Result) {
                    $entry_count++
                    $p = $entry.GetDirectoryEntry()
                    Write-Verbose ('Getting Logon Details for entry {0}: {1}' -f $entry_count, $p.name)


                    Write-Verbose "Checking the objectcategory '$($p.objectCategory)'"
                    $null = [string]$p.objectcategory -match '^\s*CN=([A-Za-z0-9_\-]+?),.*$'
                    if ($Matches.Count -gt 0) {
                        Write-Verbose "Found the $($Matches.1) category"
                        switch ($Matches.1) {
                            'Group' {
                                ## build up a group object
                                Write-Verbose 'Gathering the group details'
                                $group = @{
                                    'Category' = 'group'
                                    'Type'     = [ADGroupType]$p.groupType
                                    'Path'     = $p.distinguishedName
                                    'Name'     = $p.name
                                    'Members'  = @()
                                    'Groups'   = @()
                                }
                                #recursively add the members and subgroups
                                $member_count = 0
                                foreach ($member in $p.member) {
                                    $member_count++
                                    $member = Get-LogonDetail -Path $member
                                    Write-Verbose ('Adding {0} member number {1} to the {2}s' -f $p.name, $member_count, $member.Category)
                                    switch ($member.Category) {
                                        'group' { $group.Groups += $member }
                                        'person' { $group.Members += $member }
                                    }
                                }
                                # push this group onto the result stack and move to the next entry
                                Write-Verbose "Adding $entry_count to the results"
                                $report.Results += $group
                                break
                            }
                            'Person' {
                                Write-Verbose 'Gathering the person details'
                                ## build up the Account logon details
                                $person = @{
                                    'Category' = 'person'
                                    'Type'     = [ADAccountType]$p.sAMAccountType
                                    'Path'     = $p.distinguishedName
                                    'SID'      = $p.objectSid | ConvertTo-StringSID
                                    'Name'     = @{
                                        'Display' = $p.displayname
                                        'Account' = $p.sAMAccountName
                                    }
                                    'Mail'     = $p.mail
                                    'Lock'     = @{
                                        'Time' = $p.lockouttime | ConvertTo-DateTime
                                    }
                                    'Modified' = $p.whenchanged
                                    'Created'  = $p.whencreated
                                    'Expires'  = $p.accountexpires | Get-ExpirationDate
                                    'Logon'    = @{
                                        'Count' = $p.logoncount
                                        'Last'  = $p.lastlogontimestamp | ConvertTo-DateTime
                                    }
                                    'Password' = @{
                                        'LastSet' = $p.pwdlastset | ConvertTo-DateTime
                                    }
                                    'Groups'   = @()
                                }
                                Write-Verbose "Finished getting names and timestamps on $($p.sAMAccountName)"
                                $pwAge = $p | Get-PasswordAge
                                $d_pw_max = $p | Get-MaxPasswordAge
                                Write-Verbose 'Gathering UserAccountControls'
                                # Unpack the Logon Details in the Account Control Flags
                                [ADAccountControl]$controls = $p.useraccountcontrol
                                # Personal choice here to reverse the 'disabled' control to 'enabled'
                                $person.Enabled = -not (Test-AccountControl ACCOUNT_DISABLE $controls)
                                $person.Lock.Set = (Test-AccountControl LOCKOUT $controls)
                                # Again here, 'CloExempt means the reverse of 'Smartcard required'
                                $person.Logon.CloExempt = -not (Test-AccountControl SMARTCARD_REQUIRED $controls)
                                $person.Password.CanSet = -not (Test-AccountControl PASSWD_CANT_CHANGE $controls)
                                $person.Password.Required = -not (Test-AccountControl PASSWD_NOTREQD $controls)
                                $person.Password.Expires = -not (Test-AccountControl DONT_EXPIRE_PASSWD $controls)

                                $person.Password.DaysRemaining = ($d_pw_max.Days - $pwAge.Days)
                                Write-Verbose "Adding the groups $($p.sAMAccountName) belongs to"
                                $p.memberof | ForEach-Object { $person.Groups += $_ }

                                # push this person onto the results stack
                                Write-Verbose "Adding $($p.sAMAccountName) to results"
                                $report.Results += $person
                            }
                            Default {
                                Write-Verbose "$_ Category, not added to results"
                            }
                        }
                    } else {
                        Write-Verbose ("{0} doesn't seem to be a valid category" -f $p.objectcategory )
                    }
                    $Matches.Clear()
                }
            }
        }
        end {
            Write-Verbose "Processed $entry_count entries"
            $report
            Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
        }
    }
