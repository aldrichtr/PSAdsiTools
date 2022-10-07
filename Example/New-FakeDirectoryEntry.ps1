function New-FakeDirectoryEntry {
    <#
        .SYNOPSIS
        Returns a PSCustomObject in place of a DirectoryEntry for certain WinNT security principals that do not have objects in the directory
        .DESCRIPTION
        The WinNT provider only throws an error if you try to retrieve certain accounts/identities
        We will create dummy objects instead of performing the query
        .INPUTS
        None. Pipeline input is not accepted.
        .OUTPUTS
        [System.Management.Automation.PSCustomObject]
        .EXAMPLE
        ---------- EXAMPLE 1 ----------
        New-FakeDirectoryEntry -DirectoryPath 'WinNT://WORKGROUP/Computer/CREATOR OWNER'

        Create a fake DirectoryEntry to represent the CREATOR OWNER special security principal
    #>
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (

        <#
        Path to the directory object to retrieve
        Defaults to the root of the current domain (but don't use it for that, just do this instead: [System.DirectoryServices.DirectorySearcher]::new())
        #>
        [string]$DirectoryPath

    )

    $DirectoryEntry = $null
    $Properties = @{
        Name        = ($DirectoryPath -split '\/') | Select-Object -Last 1
        Parent      = $DirectoryPath | Split-Path -Parent
        Path        = $DirectoryPath
        SchemaEntry = [System.DirectoryServices.DirectoryEntry]
    }

    switch -regex ($DirectoryPath) {

        'CREATOR OWNER$' {
            $Properties['objectSid'] = 'S-1-3-0' | ConvertTo-SidByteArray
            $Properties['Description'] = 'A SID to be replaced by the SID of the user who creates a new object. This SID is used in inheritable ACEs.'
            $Properties['Properties'] = @{
                Name        = $Properties['Name']
                Description = $Description
                objectSid   = $SidByteAray
            }
            $Properties['SchemaClassName'] = 'user'
        }
        'SYSTEM$' {
            $Properties['objectSid'] = 'S-1-5-18' | ConvertTo-SidByteArray
            $Properties['Description'] = 'By default, the SYSTEM account is granted Full Control permissions to all files on an NTFS volume'
            $Properties['Properties'] = @{
                Name        = $Properties['Name']
                Description = $Description
                objectSid   = $SidByteAray
            }
            $Properties['SchemaClassName'] = 'user'
        }
        'INTERACTIVE$' {
            $Properties['objectSid'] = 'S-1-5-4' | ConvertTo-SidByteArray
            $Properties['Description'] = 'Users who log on for interactive operation. This is a group identifier added to the token of a process when it was logged on interactively.'
            $Properties['Properties'] = @{
                Name        = $Properties['Name']
                Description = $Description
                objectSid   = $SidByteAray
            }
            $Properties['SchemaClassName'] = 'group'
        }
        'Authenticated Users$' {
            $Properties['objectSid'] = 'S-1-5-11' | ConvertTo-SidByteArray
            $Properties['Description'] = 'Any user who accesses the system through a sign-in process has the Authenticated Users identity.'
            $Properties['Properties'] = @{
                Name        = $Properties['Name']
                Description = $Description
                objectSid   = $SidByteAray
            }
            $Properties['SchemaClassName'] = 'group'
        }
        'TrustedInstaller$' {
            $Properties['objectSid'] = 'S-1-5-11' | ConvertTo-SidByteArray
            $Properties['Description'] = 'Most of the operating system files are owned by the TrustedInstaller security identifier (SID)'
            $Properties['Properties'] = @{
                Name        = $Properties['Name']
                Description = $Description
                objectSid   = $SidByteAray
            }
            $Properties['SchemaClassName'] = 'user'
        }
    }

    $DirectoryEntry = [pscustomobject]::new($Properties)

    $DirectoryEntry |
    Add-Member -MemberType ScriptMethod -Name RefreshCache -Force -Value {}

    return $DirectoryEntry

}
