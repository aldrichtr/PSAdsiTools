<#PSScriptInfo

.VERSION 0.0.162

.GUID c7308309-badf-44ea-8717-28e5f5beffd5

.AUTHOR Jeremy La Camera

.COMPANYNAME Jeremy La Camera

.COPYRIGHT (c) Jeremy La Camera. All rights reserved.

.TAGS adsi ldap winnt ntfs acl

.LICENSEURI https://github.com/IMJLA/Export-Permission/blob/main/LICENSE

.PROJECTURI https://github.com/IMJLA/Export-Permission

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
bugfix in report footer

.PRIVATEDATA

#>














<#
.SYNOPSIS
    Portable version of Export-Permission with all ScriptModule dependencies rolled up into this single .ps1 file

    Create CSV, HTML, and XML reports of permissions

.DESCRIPTION
    Benefits:
    - Presents complex nested permissions and group memberships in a report that is easy to read
    - Provides additional information about each account such as Name, Department, Title
    - Multithreaded with caching for fast results
    - Works as a scheduled task
    - Works as a custom sensor script for Paessler PRTG Network Monitor (Push sensor recommended due to execution time)

    Supports these scenarios:
    - Local folder paths
    - UNC folder paths
    - DFS folder paths
    - Mapped network drives
    - Active Directory domain trusts
    - Unresolved SIDs for deleted accounts
    - Group memberships via the Primary Group as well as the memberOf property

    Does not support these scenarios:
    - ACL Owners or Groups (ToDo enhancement; for now only the DACL is reported)
    - File permissions (ToDo enhancement; for now only folder permissions are reported)
    - Share permissions (ToDo enhancement; for now only NTFS permissions are reported)

    Behavior:
    - Resolves the TargetPath parameter
      - Local folder paths become UNC paths using the administrative shares, so the computer name is shown in reports
      - DFS folder paths become all of their UNC folder targets, including disabled ones
      - Mapped network drives become their UNC paths
    - Gets all permissions for the target folder
    - Gets non-inherited permissions for subfolders (if specified)
    - Exports the permissions to a .csv file
    - Uses ADSI to get information about the accounts and groups listed in the permissions
    - Exports information about the accounts and groups to a .csv file
    - Uses ADSI to recursively retrieve group members
      - Retrieves group members using both the memberOf and primaryGroupId attributes
      - The entire chain of group memberships is not retrieved (for performance reasons)
    - Exports information about all accounts with access to a .csv file
    - Exports information about all accounts with access to a report generated as a .html file
    - Outputs an XML-formatted list of common misconfigurations for use in Paessler PRTG Network Monitor as a custom XML sensor
.INPUTS
    [System.IO.DirectoryInfo[]] TargetPath parameter

    Strings can be passed to this parameter and will be re-cast as DirectoryInfo objects.
.OUTPUTS
    [System.String] XML PRTG sensor output
.NOTES
    This code has not been reviewed or audited by a third party

    This code has limited or no tests

    It was designed for presenting reports to non-technical management or administrative staff

    It is convenient for that purpose but it is not recommended for compliance reporting or similar formal uses

    ToDo bugs/enhancements: https://github.com/IMJLA/Export-Permission/issues
.EXAMPLE
    Export-Permission.ps1 -TargetPath C:\Test

    Generate reports on the NTFS permissions for the folder C:\Test and all subfolders
.EXAMPLE
    Export-Permission.ps1 -TargetPath C:\Test -ExcludeAccount 'BUILTIN\\Administrator'

    Generate reports on the NTFS permissions for the folder C:\Test and all subfolders

    Exclude the built-in Administrator account from the HTML report

    The ExcludeAccount parameter uses RegEx, so the \ in BUILTIN\Administrator needed to be escaped.

    The RegEx escape character is \ so that is why the regular expression needed for the parameter is 'BUILTIN\\Administrator'
.EXAMPLE
    Export-Permission.ps1 -TargetPath C:\Test -ExcludeAccount @(
        'BUILTIN\\Administrators',
        'BUILTIN\\Administrator',
        'CREATOR OWNER',
        'NT AUTHORITY\\SYSTEM'
    )

    Generate reports on the NTFS permissions for the folder C:\Test and all subfolders

    Exclude from the HTML report:
    - The built-in Administrator account
    - The built-in Administrators group and its members (unless they appear elsewhere in the permissions)
    - The CREATOR OWNER security principal
    - The computer account (NT AUTHORITY\SYSTEM)

    Note: CREATOR OWNER will still be reported as an alarm in the PRTG XML output
.EXAMPLE
    Export-Permission.ps1 -TargetPath C:\Test -ExcludeEmptyGroups

    Generate reports on the NTFS permissions for the folder C:\Test and all subfolders

    Exclude empty groups from the HTML report (leaving accounts only)
.EXAMPLE
    Export-Permission.ps1 -TargetPath C:\Test -IgnoreDomain 'CONTOSO'

    Generate reports on the NTFS permissions for the folder C:\Test and all subfolders

    Remove the CONTOSO domain prefix from associated accounts and groups
.EXAMPLE
    Export-Permission.ps1 -TargetPath C:\Test -IgnoreDomain 'CONTOSO1','CONTOSO2'

    Generate reports on the NTFS permissions for the folder C:\Test and all subfolders

    Remove the CONTOSO1\ and CONTOSO2\ domain prefixes from associated accounts and groups

    Across the two domains, accounts with the same samAccountNames will be considered equivalent

    Across the two domains, groups with the same Names will be considered equivalent
.EXAMPLE
    Export-Permission.ps1 -TargetPath C:\Test -LogDir C:\Logs

    Generate reports on the NTFS permissions for the folder C:\Test and all subfolders

    Redirect logs and output files to C:\Logs instead of the default location in AppData
.EXAMPLE
    Export-Permission.ps1 -TargetPath C:\Test -LevelsOfSubfolders 0

    Generate reports on the NTFS permissions for the folder C:\Test only (no subfolders)
.EXAMPLE
    Export-Permission.ps1 -TargetPath C:\Test -LevelsOfSubfolders 2

    Generate reports on the NTFS permissions for the folder C:\Test

    Only include subfolders to a maximum of 2 levels deep (C:\Test\Level1\Level2)
.EXAMPLE
    Export-Permission.ps1 -TargetPath C:\Test -Title 'New Custom Report Title'

    Generate reports on the NTFS permissions for the folder C:\Test and all subfolders

    Change the title of the HTML report to 'New Custom Report Title'
.EXAMPLE
    Export-Permission.ps1 -TargetPath '\\ad.contoso.com\DfsNamespace\DfsFolderWithTarget'

    The target path is a DFS folder with folder targets

    Generate reports on the NTFS permissions for the DFS folder targets associated with this path
.EXAMPLE
    Export-Permission.ps1 -TargetPath '\\ad.contoso.com\DfsNamespace\DfsFolderWithoutTarget\DfsSubfolderWithoutTarget\DfsSubfolderWithTarget'

    The target path is a DFS subfolder with folder targets

    Generate reports on the NTFS permissions for the DFS folder targets associated with this path
.EXAMPLE
    Export-Permission.ps1 -TargetPath '\\ad.contoso.com\DfsNamespace\DfsFolderWithoutTarget\DfsSubfolderWithoutTarget\DfsSubfolderWithTarget\Subfolder'

    The target path is a subfolder of a DFS subfolder with folder targets

    Generate reports on the NTFS permissions for the DFS folder targets associated with this path
.EXAMPLE
    Export-Permission.ps1 -TargetPath '\\ad.contoso.com\'

    This is an edge case that is not currently supported

    The target path is the root of an AD domain

    Generate reports on the NTFS permissions for ? Invalid/fail param validation?
.EXAMPLE
    Export-Permission.ps1 -TargetPath '\\computer.ad.contoso.com\'

    This is an edge case that is not currently supported

    The target path is the root of a server

    Generate reports on the NTFS permissions for ? Invalid/fail param validation?
.EXAMPLE
    Export-Permission.ps1 -TargetPath '\\ad.contoso.com\DfsNamespace'

    This is an edge case that is not currently supported

    The target path is a DFS namespace

    Generate reports on the NTFS permissions for the folder on the DFS namespace server associated with this path

    Add a warning that they are permissions from the DFS namespace server and could be confusing
.EXAMPLE
    Export-Permission.ps1 -TargetPath '\\ad.contoso.com\DfsNamespace\DfsFolderWithoutTarget'

    This is an edge case that is not currently supported.

    The target path is a DFS folder without a folder target

    Generate reports on the NTFS permissions for the folder on the DFS namespace server associated with this path

    Add a warning that they are permissions from the DFS namespace server and could be confusing
.EXAMPLE
    Export-Permission.ps1 -TargetPath '\\ad.contoso.com\DfsNamespace\DfsFolderWithoutTarget\DfsSubfolderWithoutTarget'

    This is an edge case that is not currently supported.

    The target path is a DFS subfolder without a folder target.

    Generate reports on the NTFS permissions for the folder on the DFS namespace server associated with this path

    Add a warning that they are permissions from the DFS namespace server and could be confusing
#>
param (

    # Path to the NTFS folder whose permissions to export
    [Parameter(ValueFromPipeline)]
    [ValidateScript({ Test-Path $_ })]
    [System.IO.DirectoryInfo[]]$TargetPath = 'Z:\',

    # Regular expressions matching names of security principals to exclude from the HTML report
    [string[]]$ExcludeAccount = 'user123',

    # Exclude empty groups from the HTML report (this param will be replaced by ExcludeAccountClass in the future)
    [switch]$ExcludeEmptyGroups,

    # Accounts whose objectClass property is in this list are excluded from the HTML report
    [string[]]$ExcludeAccountClass = @('group', 'computer'),

    <#
    Domain(s) to ignore (they will be removed from the username)

    Intended when a user has matching SamAccountNames in multiple domains but you only want them to appear once on the report.

    Can also be used to remove all domains simply for brevity in the report.
    #>
    [string[]]$IgnoreDomain = 'CONTOSO',

    # Path to the folder to save the logs and reports generated by this script
    [string]$OutputDir = "$env:AppData\Export-Permission",

    # Do not get group members (only report the groups themselves)
    [switch]$NoGroupMembers,

    <#
    How many levels of subfolder to enumerate

        Set to 0 to ignore all subfolders

        Set to -1 (default) to recurse infinitely

        Set to any whole number to enumerate that many levels
    #>
    [int]$SubfolderLevels = -1,

    # Title at the top of the HTML report
    [string]$Title = "Permissions Report",

    <#
    Valid group names that are allowed to appear in ACEs

    Specify as a ScriptBlock meant for the FilterScript parameter of Where-Object

    In the scriptblock, use string comparisons on the Name property

    e.g. {$_.Name -like 'CONTOSO\Group1*' -or $_.Name -eq 'CONTOSO\Group23'}

    The naming format that will be used for the groups is CONTOSO\Group1

    where CONTOSO is the NetBIOS name of the domain, and Group1 is the samAccountName of the group

    By default, this is a scriptblock that always evaluates to $true so it doesn't evaluate any naming convention compliance
    #>
    [scriptblock]$GroupNamingConvention = { $true },

    # Number of asynchronous threads to use
    [uint16]$ThreadCount = (Get-CimInstance -ClassName CIM_Processor | Measure-Object -Sum -Property NumberOfLogicalProcessors).Sum,

    # Open the HTML report after the script is finished using Invoke-Item (only useful interactively)
    [switch]$OpenReportAtEnd,

    <#
    If all four of the PRTG parameters are specified,

    the results will be XML-formatted and pushed to the specified PRTG probe for a push sensor
    #>
    [string]$PrtgProbe,

    <#
    If all four of the PRTG parameters are specified,

    the results will be XML-formatted and pushed to the specified PRTG probe for a push sensor
    #>
    [string]$PrtgSensorProtocol,

    <#
    If all four of the PRTG parameters are specified,

    the results will be XML-formatted and pushed to the specified PRTG probe for a push sensor
    #>
    [uint16]$PrtgSensorPort,

    <#
    If all four of the PRTG parameters are specified,

    the results will be XML-formatted and pushed to the specified PRTG probe for a push sensor
    #>
    [string]$PrtgSensorToken

)

begin {

    #----------------[ Functions ]------------------

# Definition of Module 'Adsi' is below

function Add-DomainFqdnToLdapPath {
    <#
        .SYNOPSIS
        Add a domain FQDN to an LDAP directory path as the server address so the new path can be used for remote queries
        .DESCRIPTION
        Uses RegEx to:
            - Match the Domain Components from the Distinguished Name in the LDAP directory path
            - Convert the Domain Components to an FQDN
            - Insert them into the directory path as the server address
        .INPUTS
        [System.String]$DirectoryPath
        .OUTPUTS
        [System.String] Complete LDAP directory path including server address
        .EXAMPLE
        Add-DomainFqdnToLdapPath -DirectoryPath 'LDAP://CN=user1,OU=UsersOU,DC=ad,DC=contoso,DC=com'
        LDAP://ad.contoso.com/CN=user1,OU=UsersOU,DC=ad,DC=contoso,DC=com

        Add the domain FQDN to a single LDAP directory path
    #>
    [OutputType([System.String])]
    param (

        # Incomplete LDAP directory path containing a distinguishedName but lacking a server address
        [Parameter(ValueFromPipeline)]
        [string[]]$DirectoryPath,

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    begin {

        <#
        $LogParams = @{
            ThisHostname = $ThisHostname
            Type = 'Debug'
            LogMsgCache = $LogMsgCache
            WhoAmI = $WhoAmI
        }
        #>

        $LoggingParams = @{
            ThisHostname = $ThisHostname
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $PathRegEx = '(?<Path>LDAP:\/\/[^\/]*)'
        $DomainRegEx = '(?i)DC=\w{1,}?\b'

    }
    process {

        ForEach ($ThisPath in $DirectoryPath) {

            if ($ThisPath -match $PathRegEx) {

                $RegExMatches = $null
                $RegExMatches = [regex]::Matches($ThisPath, $DomainRegEx)

                if ($RegExMatches) {
                    $DomainDN = $null
                    $DomainFqdn = $null

                    $RegExMatches = $RegExMatches |
                    ForEach-Object { $_.Value }

                    $DomainDN = $RegExMatches -join ','
                    $DomainFqdn = ConvertTo-Fqdn -DistinguishedName $DomainDN -ThisFqdn $ThisFqdn @LoggingParams
                    if ($ThisPath -match "LDAP:\/\/$DomainFqdn\/") {
                        #Write-LogMsg @LogParams -Text " # Domain FQDN already found in the directory path: '$ThisPath'"
                        $ThisPath
                    } else {
                        $ThisPath -replace 'LDAP:\/\/', "LDAP://$DomainFqdn/"
                    }
                } else {
                    #Write-LogMsg @LogParams -Text " # Domain DN not found in the directory path: '$ThisPath'"
                    $ThisPath
                }
            } else {
                #Write-LogMsg @LogParams -Text " # Not an expected directory path: '$ThisPath'"
                $ThisPath
            }
        }
    }
}
function Add-SidInfo {
    <#
        .SYNOPSIS
        Add some useful properties to a DirectoryEntry object for easier access
        .DESCRIPTION
        Add SidString, Domain, and SamAccountName NoteProperties to a DirectoryEntry
        .INPUTS
        [System.DirectoryServices.DirectoryEntry] or a [PSCustomObject] imitation. InputObject parameter. Must contain the objectSid property.
        .OUTPUTS
        [System.DirectoryServices.DirectoryEntry] or a [PSCustomObject] imitation. Whatever was input, but with three extra properties added now.
        .EXAMPLE
        [System.DirectoryServices.DirectoryEntry]::new('WinNT://localhost/Administrator') | Add-SidInfo
        distinguishedName :
        Path : WinNT://localhost/Administrator

        The output object's default format is not modified so with default formatting it appears identical to the original.
        Upon closer inspection it now has SidString, Domain, and SamAccountName properties.
    #>
    [OutputType([System.DirectoryServices.DirectoryEntry[]], [PSCustomObject[]])]
    param (

        # Expecting a [System.DirectoryServices.DirectoryEntry] from the LDAP or WinNT providers, or a [PSCustomObject] imitation from Get-DirectoryEntry.
        # Must contain the objectSid property
        [Parameter(ValueFromPipeline)]
        $InputObject,

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

    }

    process {

        ForEach ($Object in $InputObject) {

            $SID = $null
            $SamAccountName = $null
            $DomainObject = $null

            if ($null -eq $Object) {
                continue
            } elseif ($Object.objectSid.Value ) {
                # With WinNT directory entries for the root (WinNT://localhost), objectSid is a method rather than a property
                # So we need to filter out those instances here to avoid this error:
                # The following exception occurred while retrieving the string representation for method "objectSid":
                # "Object reference not set to an instance of an object."
                if ( $Object.objectSid.Value.GetType().FullName -ne 'System.Management.Automation.PSMethod' ) {
                    [string]$SID = [System.Security.Principal.SecurityIdentifier]::new([byte[]]$Object.objectSid.Value, 0)
                }
            } elseif ($Object.objectSid) {
                # With WinNT directory entries for the root (WinNT://localhost), objectSid is a method rather than a property
                # So we need to filter out those instances here to avoid this error:
                # The following exception occurred while retrieving the string representation for method "objectSid":
                # "Object reference not set to an instance of an object."
                if ($Object.objectSid.GetType().FullName -ne 'System.Management.Automation.PSMethod') {
                    [string]$SID = [System.Security.Principal.SecurityIdentifier]::new([byte[]]$Object.objectSid, 0)
                }
            } elseif ($Object.Properties) {
                if ($Object.Properties['objectSid'].Value) {
                    [string]$SID = [System.Security.Principal.SecurityIdentifier]::new([byte[]]$Object.Properties['objectSid'].Value, 0)
                } elseif ($Object.Properties['objectSid']) {
                    [string]$SID = [System.Security.Principal.SecurityIdentifier]::new([byte[]]($Object.Properties['objectSid'] | ForEach-Object { $_ }), 0)
                }
                if ($Object.Properties['samaccountname']) {
                    $SamAccountName = $Object.Properties['samaccountname']
                } else {
                    #DirectoryEntries from the WinNT provider for local accounts do not have a samaccountname attribute so we use name instead
                    $SamAccountName = $Object.Properties['name']
                }
            } elseif ($Object.objectSid) {
                [string]$SID = [System.Security.Principal.SecurityIdentifier]::new([byte[]]$Object.objectSid, 0)
            }

            if ($Object.Domain.Sid) {
                #if ($Object.Domain.GetType().FullName -ne 'System.Management.Automation.PSMethod') {
                # This would only have come from Add-SidInfo in the first place
                # This means it was added with Add-Member in Get-DirectoryEntry for the root of the computer's directory
                if ($null -eq $SID) {
                    [string]$SID = $Object.Domain.Sid
                }
                $DomainObject = $Object.Domain
                #}
            }
            if (-not $DomainObject) {
                # The SID of the domain is the SID of the user minus the last block of numbers
                $DomainSid = $SID.Substring(0, $Sid.LastIndexOf("-"))

                # Lookup other information about the domain using its SID as the key
                $DomainObject = $DomainsBySid[$DomainSid]
            }

            #Write-LogMsg @LogParams -Text "$SamAccountName`t$SID"

            Add-Member -InputObject $Object -PassThru -Force @{
                SidString      = $SID
                Domain         = $DomainObject
                SamAccountName = $SamAccountName
            }
        }
    }
}
function ConvertFrom-DirectoryEntry {
    <#
    .SYNOPSIS
    Convert a DirectoryEntry to a PSCustomObject
    .DESCRIPTION
    Recursively convert every property into a string, or a PSCustomObject (whose properties are all strings, or more PSCustomObjects)
    This obfuscates the troublesome PropertyCollection and PropertyValueCollection and Hashtable aspects of working with ADSI
    .NOTES
    # TODO: There is a faster way than Select-Object, just need to dig into the default formatting of DirectoryEntry to see how to get those properties
    #>

    param (
        [Parameter(
            Position = 0,
            ValueFromPipeline
        )]
        [System.DirectoryServices.DirectoryEntry[]]$DirectoryEntry
    )

    process {
        ForEach ($ThisDirectoryEntry in $DirectoryEntry) {
            $ObjectWithProperties = $ThisDirectoryEntry |
            Select-Object -Property *

            $ObjectNoteProperties = $ObjectWithProperties |
            Get-Member -MemberType Property, CodeProperty, ScriptProperty, NoteProperty

            $ThisObject = @{}
            ForEach ($ThisObjProperty in $ObjectNoteProperties) {
                $ThisObject = ConvertTo-SimpleProperty -InputObject $ObjectWithProperties -Property $ThisObjProperty.Name -PropertyDictionary $ThisObject
            }

            [PSCustomObject]$ThisObject
        }
    }
}
function ConvertFrom-PropertyValueCollectionToString {
    <#
        .SYNOPSIS
        Convert a PropertyValueCollection to a string
        .DESCRIPTION
        Useful when working with System.DirectoryServices and some other namespaces
        .INPUTS
        None. Pipeline input is not accepted.
        .OUTPUTS
        [System.String]
        .EXAMPLE
        $DirectoryEntry = [adsi]("WinNT://$(hostname)")
        $DirectoryEntry.Properties.Keys |
        ForEach-Object {
            ConvertFrom-PropertyValueCollectionToString -PropertyValueCollection $DirectoryEntry.Properties[$_]
        }

        For each property in a DirectoryEntry, convert its corresponding PropertyValueCollection to a string
    #>
    param (
        [System.DirectoryServices.PropertyValueCollection]$PropertyValueCollection
    )
    $SubType = & { $PropertyValueCollection.Value.GetType().FullName } 2>$null
    switch ($SubType) {
        'System.Byte[]' { ConvertTo-DecStringRepresentation -ByteArray $PropertyValueCollection.Value }
        default { "$($PropertyValueCollection.Value)" }
    }
}
function ConvertFrom-ResultPropertyValueCollectionToString {
    <#
        .SYNOPSIS
        Convert a ResultPropertyValueCollection to a string
        .DESCRIPTION
        Useful when working with System.DirectoryServices and some other namespaces
        .INPUTS
        None. Pipeline input is not accepted.
        .OUTPUTS
        [System.String]
        .EXAMPLE
        $DirectoryEntry = [adsi]("WinNT://$(hostname)")
        $DirectoryEntry.Properties.Keys |
        ForEach-Object {
            ConvertFrom-PropertyValueCollectionToString -PropertyValueCollection $DirectoryEntry.Properties[$_]
        }

        For each property in a DirectoryEntry, convert its corresponding PropertyValueCollection to a string
    #>
    param (
        [System.DirectoryServices.ResultPropertyValueCollection]$ResultPropertyValueCollection
    )
    $SubType = & { $ResultPropertyValueCollection.Value.GetType().FullName } 2>$null
    switch ($SubType) {
        'System.Byte[]' { ConvertTo-DecStringRepresentation -ByteArray $ResultPropertyValueCollection.Value }
        default { "$($ResultPropertyValueCollection.Value)" }
    }
}
function ConvertFrom-SearchResult {
    <#
    .SYNOPSIS
    Convert a SearchResult to a PSCustomObject
    .DESCRIPTION
    Recursively convert every property into a string, or a PSCustomObject (whose properties are all strings, or more PSCustomObjects)
    This obfuscates the troublesome ResultPropertyCollection and ResultPropertyValueCollection and Hashtable aspects of working with ADSI searches
    .NOTES
    # TODO: There is a faster way than Select-Object, just need to dig into the default formatting of SearchResult to see how to get those properties
    #>

    param (
        [Parameter(
            Position = 0,
            ValueFromPipeline
        )]
        [System.DirectoryServices.SearchResult[]]$SearchResult
    )

    process {
        ForEach ($ThisSearchResult in $SearchResult) {
            $ObjectWithProperties = $ThisSearchResult |
            Select-Object -Property *

            $ObjectNoteProperties = $ObjectWithProperties |
            Get-Member -MemberType Property, CodeProperty, ScriptProperty, NoteProperty

            $ThisObject = @{}

            # Enumerate the keys of the ResultPropertyCollection
            ForEach ($ThisProperty in $ThisSearchResult.Properties.Keys) {
                $ThisObject = ConvertTo-SimpleProperty -InputObject $ThisSearchResult.Properties -Property $ThisProperty -PropertyDictionary $ThisObject
            }

            # We will allow any existing properties to override members of the ResultPropertyCollection
            ForEach ($ThisObjProperty in $ObjectNoteProperties) {
                $ThisObject = ConvertTo-SimpleProperty -InputObject $ObjectWithProperties -Property $ThisObjProperty.Name -PropertyDictionary $ThisObject
            }

            [PSCustomObject]$ThisObject
        }
    }
}
function ConvertFrom-SidString {
    #[OutputType([System.Security.Principal.NTAccount])]
    param (
        [string]$SID
    )
    #[System.Security.Principal.SecurityIdentifier]::new($SID)
    # Only works if SID is in the current domain...otherwise SID not found
    Get-DirectoryEntry -DirectoryPath "LDAP://<SID=$SID>"
}
function ConvertTo-DecStringRepresentation {
    <#
        .SYNOPSIS
        Convert a byte array to a string representation of its decimal format
        .DESCRIPTION
        Uses the custom format operator -f to format each byte as a string decimal representation
        .INPUTS
        [System.Byte[]]$ByteArray
        .OUTPUTS
        [System.String] Array of strings representing the byte array's decimal values
        .EXAMPLE
        ConvertTo-DecStringRepresentation -ByteArray $Bytes

        Convert the binary SID $Bytes to a decimal string representation
    #>
    [OutputType([System.String])]
    param (
        # Byte array. Often the binary format of an objectSid or LoginHours
        [byte[]]$ByteArray
    )

    $ByteArray |
    ForEach-Object {
        '{0}' -f $_
    }
}
function ConvertTo-DistinguishedName {
    <#
        .SYNOPSIS
        Convert a domain NetBIOS name to its distinguishedName
        .DESCRIPTION
        https://docs.microsoft.com/en-us/windows/win32/api/iads/nn-iads-iadsnametranslate
        .INPUTS
        [System.String]$Domain
        .OUTPUTS
        [System.String] distinguishedName of the domain
        .EXAMPLE
        ConvertTo-DistinguishedName -Domain 'CONTOSO'
        DC=ad,DC=contoso,DC=com

        Resolve the NetBIOS domain 'CONTOSO' to its distinguishedName 'DC=ad,DC=contoso,DC=com'
    #>
    [OutputType([System.String])]
    param (

        # NetBIOS name of the domain
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'NetBIOS')]
        [string[]]$Domain,

        [Parameter(ParameterSetName = 'NetBIOS')]
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # NetBIOS name of the domain
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'FQDN')]
        [string[]]$DomainFQDN,

        # Type of initialization to be performed
        # Will be translated to the corresponding integer for use as the lnSetType parameter of the IADsNameTranslate::Init method (iads.h)
        # https://docs.microsoft.com/en-us/windows/win32/api/iads/ne-iads-ads_name_inittype_enum
        [string]$InitType = 'ADS_NAME_INITTYPE_GC',

        # Format of the name of the directory object that will be used for the input
        # Will be translated to the corresponding integer for use as the lnSetType parameter of the IADsNameTranslate::Set method (iads.h)
        # https://docs.microsoft.com/en-us/windows/win32/api/iads/ne-iads-ads_name_type_enum
        [string]$InputType = 'ADS_NAME_TYPE_NT4',

        # Format of the name of the directory object that will be used for the output
        # Will be translated to the corresponding integer for use as the lnSetType parameter of the IADsNameTranslate::Get method (iads.h)
        # https://docs.microsoft.com/en-us/windows/win32/api/iads/ne-iads-ads_name_type_enum
        [string]$OutputType = 'ADS_NAME_TYPE_1779',

        <#
        AdsiProvider (WinNT or LDAP) of the servers associated with the provided FQDNs or NetBIOS names

        This parameter can be used to reduce calls to Find-AdsiProvider

        Useful when that has been done already but the DomainsByFqdn and DomainsByNetbios caches have not been updated yet
        #>
        [string]$AdsiProvider,

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $LoggingParams = @{
            ThisHostname = $ThisHostname
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        # Declare constants for these Windows enums
        # We need to because PowerShell makes it hard to directly use the Win32 API and read the enum definition
        # Use hashtables instead of enums since this use case is so simple
        $ADS_NAME_INITTYPE_dict = @{
            ADS_NAME_INITTYPE_DOMAIN = 1 #Initializes a NameTranslate object by setting the domain that the object binds to.
            ADS_NAME_INITTYPE_SERVER = 2 #Initializes a NameTranslate object by setting the server that the object binds to.
            ADS_NAME_INITTYPE_GC     = 3 #Initializes a NameTranslate object by locating the global catalog that the object binds to.
        }
        $ADS_NAME_TYPE_dict = @{
            ADS_NAME_TYPE_1779                    = 1 #Name format as specified in RFC 1779. For example, "CN=Jeff Smith,CN=users,DC=Fabrikam,DC=com".
            ADS_NAME_TYPE_CANONICAL               = 2 #Canonical name format. For example, "Fabrikam.com/Users/Jeff Smith".
            ADS_NAME_TYPE_NT4                     = 3 #Account name format used in Windows. For example, "Fabrikam\JeffSmith".
            ADS_NAME_TYPE_DISPLAY                 = 4 #Display name format. For example, "Jeff Smith".
            ADS_NAME_TYPE_DOMAIN_SIMPLE           = 5 #Simple domain name format. For example, "JeffSmith@Fabrikam.com".
            ADS_NAME_TYPE_ENTERPRISE_SIMPLE       = 6 #Simple enterprise name format. For example, "JeffSmith@Fabrikam.com".
            ADS_NAME_TYPE_GUID                    = 7 #Global Unique Identifier format. For example, "{95ee9fff-3436-11d1-b2b0-d15ae3ac8436}".
            ADS_NAME_TYPE_UNKNOWN                 = 8 #Unknown name type. The system will estimate the format. This element is a meaningful option only with the IADsNameTranslate.Set or the IADsNameTranslate.SetEx method, but not with the IADsNameTranslate.Get or IADsNameTranslate.GetEx method.
            ADS_NAME_TYPE_USER_PRINCIPAL_NAME     = 9 #User principal name format. For example, "JeffSmith@Fabrikam.com".
            ADS_NAME_TYPE_CANONICAL_EX            = 10 #Extended canonical name format. For example, "Fabrikam.com/Users Jeff Smith".
            ADS_NAME_TYPE_SERVICE_PRINCIPAL_NAME  = 11 #Service principal name format. For example, "www/www.fabrikam.com@fabrikam.com".
            ADS_NAME_TYPE_SID_OR_SID_HISTORY_NAME = 12 #A SID string, as defined in the Security Descriptor Definition Language (SDDL), for either the SID of the current object or one from the object SID history. For example, "O:AOG:DAD:(A;;RPWPCCDCLCSWRCWDWOGA;;;S-1-0-0)"
        }
        $ChosenInitType = $ADS_NAME_INITTYPE_dict[$InitType]
        $ChosenInputType = $ADS_NAME_TYPE_dict[$InputType]
        $ChosenOutputType = $ADS_NAME_TYPE_dict[$OutputType]

    }
    process {
        ForEach ($ThisDomain in $Domain) {
            $DomainCacheResult = $DomainsByNetbios[$ThisDomain]
            if ($DomainCacheResult) {
                Write-LogMsg @LogParams -Text " # Domain NetBIOS cache hit for '$ThisDomain'"
                #ConvertTo-DistinguishedName -DomainFQDN $DomainCacheResult.Dns -AdsiProvider $DomainCacheResult.AdsiProvider
                $DomainCacheResult.DistinguishedName
            } else {
                Write-LogMsg @LogParams -Text " # Domain NetBIOS cache miss for '$ThisDomain'. Available keys: $($DomainsByNetBios.Keys -join ',')"
                Write-LogMsg @LogParams -Text "`$IADsNameTranslateComObject = New-Object -comObject 'NameTranslate' # For '$ThisDomain'"
                $IADsNameTranslateComObject = New-Object -comObject "NameTranslate"
                Write-LogMsg @LogParams -Text "`$IADsNameTranslateInterface = `$IADsNameTranslateComObject.GetType() # For '$ThisDomain'"
                $IADsNameTranslateInterface = $IADsNameTranslateComObject.GetType()
                Write-LogMsg @LogParams -Text "`$null = `$IADsNameTranslateInterface.InvokeMember('Init', 'InvokeMethod', `$Null, `$IADsNameTranslateComObject, ($ChosenInitType, `$Null)) # For '$ThisDomain'"
                $null = $IADsNameTranslateInterface.InvokeMember("Init", "InvokeMethod", $Null, $IADsNameTranslateComObject, ($ChosenInitType, $Null))

                # For a non-domain-joined system there is no DistinguishedName for the domain
                # Suppress errors when calling these next 2 methods
                # Exception calling "InvokeMember" with "5" argument(s): "Name translation: Could not find the name or insufficient right to see name. (Exception from HRESULT: 0x80072116)"
                Write-LogMsg @LogParams -Text "`$null = `$IADsNameTranslateInterface.InvokeMember('Set', 'InvokeMethod', `$Null, `$IADsNameTranslateComObject, ($ChosenInputType, '$ThisDomain\')) # For '$ThisDomain'"
                $null = { $IADsNameTranslateInterface.InvokeMember("Set", "InvokeMethod", $Null, $IADsNameTranslateComObject, ($ChosenInputType, "$ThisDomain\")) } 2>$null
                # Exception calling "InvokeMember" with "5" argument(s): "Unspecified error (Exception from HRESULT: 0x80004005 (E_FAIL))"
                Write-LogMsg @LogParams -Text "`$IADsNameTranslateInterface.InvokeMember('Get', 'InvokeMethod', `$Null, `$IADsNameTranslateComObject, $ChosenOutputType) # For '$ThisDomain'"
                $null = { $null = { $IADsNameTranslateInterface.InvokeMember("Get", "InvokeMethod", $Null, $IADsNameTranslateComObject, $ChosenOutputType) } 2>$null } 2>$null
            }
        }
        ForEach ($ThisDomain in $DomainFQDN) {
            $DomainCacheResult = $DomainsByFqdn[$ThisDomain]
            if ($DomainCacheResult) {
                Write-LogMsg @LogParams -Text " # Domain FQDN cache hit for '$ThisDomain'"
                $DomainCacheResult.DistinguishedName
            } else {
                Write-LogMsg @LogParams -Text " # Domain FQDN cache miss for '$ThisDomain'"

                if (-not $PSBoundParameters.ContainsKey('AdsiProvider')) {
                    $AdsiProvider = Find-AdsiProvider -AdsiServer $ThisDomain @LoggingParams
                }

                if ($AdsiProvider -ne 'WinNT') {
                    "dc=$($ThisDomain -replace '\.',',dc=')"
                }
            }
        }
    }
}
function ConvertTo-DomainNetBIOS {
    param (
        [string]$DomainFQDN,

        [string]$AdsiProvider,

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    $LoggingParams = @{
        ThisHostname = $ThisHostname
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    $DomainCacheResult = $DomainsByFqdn[$DomainFQDN]
    if ($DomainCacheResult) {
        Write-LogMsg @LogParams -Text " # Domain FQDN cache hit for '$DomainFQDN'"
        return $DomainCacheResult.Netbios
    }

    Write-LogMsg @LogParams -Text " # Domain FQDN cache miss for '$DomainFQDN'"

    if ($AdsiProvider -eq 'LDAP') {
        $RootDSE = Get-DirectoryEntry -DirectoryPath "LDAP://$DomainFQDN/rootDSE" -DirectoryEntryCache $DirectoryEntryCache -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid @LoggingParams
        Write-LogMsg @LogParams -Text "`$RootDSE.InvokeGet('defaultNamingContext')"
        $DomainDistinguishedName = $RootDSE.InvokeGet("defaultNamingContext")
        Write-LogMsg @LogParams -Text "`$RootDSE.InvokeGet('configurationNamingContext')"
        $ConfigurationDN = $rootDSE.InvokeGet("configurationNamingContext")
        $partitions = Get-DirectoryEntry -DirectoryPath "LDAP://$DomainFQDN/cn=partitions,$ConfigurationDN" -DirectoryEntryCache $DirectoryEntryCache -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid @LoggingParams

        ForEach ($Child In $Partitions.Children) {
            If ($Child.nCName -contains $DomainDistinguishedName) {
                return $Child.nETBIOSName
            }
        }
    } else {
        $LengthOfNetBIOSName = $DomainFQDN.IndexOf('.')
        if ($LengthOfNetBIOSName -eq -1) {
            $DomainFQDN
        } else {
            $DomainFQDN.Substring(0, $LengthOfNetBIOSName)
        }
    }

}
function ConvertTo-DomainSidString {
    param (

        # Domain DNS name to convert to the domain's SID
        [Parameter(Mandatory)]
        [string]$DomainDnsName,

        <#
        Hashtable containing cached directory entries so they don't have to be retrieved from the directory again

        Uses a thread-safe hashtable by default
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        AdsiProvider (WinNT or LDAP) of the servers associated with the provided FQDNs or NetBIOS names

        This parameter can be used to reduce calls to Find-AdsiProvider

        Useful when that has been done already but the DomainsByFqdn and DomainsByNetbios caches have not been updated yet
        #>
        [string]$AdsiProvider,

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    $LoggingParams = @{
        ThisHostname = $ThisHostname
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }


    $CacheResult = $DomainsByFqdn[$DomainDnsName]
    if ($CacheResult) {
        Write-LogMsg @LogParams -Text " # Domain FQDN cache hit for '$DomainDnsName'"
        return $CacheResult.Sid
    }
    Write-LogMsg @LogParams -Text " # Domain FQDN cache miss for '$DomainDnsName'"

    if (
        -not $AdsiProvider -or
        $AdsiProvider -eq 'LDAP'
    ) {
        $DomainDirectoryEntry = Get-DirectoryEntry -DirectoryPath "LDAP://$DomainDnsName" -DirectoryEntryCache $DirectoryEntryCache -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid @LoggingParams
        try {
            $null = $DomainDirectoryEntry.RefreshCache('objectSid')
        } catch {
            Write-Debug "$(Get-Date -Format s)`t$ThisHostname`tConvertTo-DomainSidString`t # LDAP connection failed to '$DomainDnsName' - $($_.Exception.Message)"
            Write-LogMsg @LogParams -Text "Find-LocalAdsiServerSid -ComputerName '$DomainDnsName'"
            $DomainSid = Find-LocalAdsiServerSid -ComputerName $DomainDnsName-ThisFqdn $ThisFqdn @LoggingParams
            return $DomainSid
        }
    } else {
        Write-LogMsg @LogParams -Text "Find-LocalAdsiServerSid -ComputerName '$DomainDnsName'"
        $DomainSid = Find-LocalAdsiServerSid -ComputerName $DomainDnsName -ThisFqdn $ThisFqdn @LoggingParams
        return $DomainSid
    }

    $DomainSid = $null

    if ($DomainDirectoryEntry.Properties) {
        $objectSIDProperty = $DomainDirectoryEntry.Properties['objectSid']
        if ($objectSIDProperty.Value) {
            $SidByteArray = [byte[]]$objectSIDProperty.Value
        } else {
            $SidByteArray = [byte[]]$objectSIDProperty
        }
    } else {
        $SidByteArray = [byte[]]$DomainDirectoryEntry.objectSid
    }

    Write-Debug " $(Get-Date -Format s)`t$ThisHostname`tConvertTo-DomainSidString`t[System.Security.Principal.SecurityIdentifier]::new([byte[]]@($($SidByteArray -join ',')), 0).ToString()"
    $DomainSid = [System.Security.Principal.SecurityIdentifier]::new($SidByteArray, 0).ToString()

    if ($DomainSid) {
        return $DomainSid
    } else {
        Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tConvertTo-DomainSidString`t # LDAP Domain: '$DomainDnsName' has an invalid SID - $($_.Exception.Message)"
    }

}
function ConvertTo-Fqdn {
    <#
        .SYNOPSIS
        Convert a domain distinguishedName name or NetBIOS name to its FQDN
        .DESCRIPTION
        For the DistinguishedName parameter, uses PowerShell's -replace operator to perform the conversion
        For the NetBIOS parameter, uses ConvertTo-DistinguishedName to convert from NetBIOS to distinguishedName, then recursively calls this function to get the FQDN
        .INPUTS
        [System.String]$DistinguishedName
        .OUTPUTS
        [System.String] FQDN version of the distinguishedName
        .EXAMPLE
        ConvertTo-Fqdn -DistinguishedName 'DC=ad,DC=contoso,DC=com'
        ad.contoso.com

        Convert the domain distinguishedName 'DC=ad,DC=contoso,DC=com' to its FQDN format 'ad.contoso.com'
    #>
    [OutputType([System.String])]
    param (
        # distinguishedName of the domain
        [Parameter(
            ParameterSetName = 'DistinguishedName',
            ValueFromPipeline
        )]
        [string[]]$DistinguishedName,

        # NetBIOS name of the domain
        [Parameter(
            ParameterSetName = 'NetBIOS',
            ValueFromPipeline
        )]
        [string[]]$NetBIOS,

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $LoggingParams = @{
            ThisHostname = $ThisHostname
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

    }
    process {
        ForEach ($DN in $DistinguishedName) {
            $DN -replace ',DC=', '.' -replace 'DC=', ''
        }

        ForEach ($ThisNetBios in $NetBIOS) {
            $DomainObject = $DomainsByNetbios[$DomainNetBIOS]

            if (
                -not $DomainObject -and
                -not [string]::IsNullOrEmpty($DomainNetBIOS)
            ) {
                Write-LogMsg @LogParams -Text " # Domain NetBIOS cache miss for '$DomainNetBIOS'"
                $DomainObject = Get-AdsiServer -Netbios $DomainNetBIOS -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams
                $DomainsByNetbios[$DomainNetBIOS] = $DomainObject
            }

            $DomainObject.Dns
        }
    }
}
function ConvertTo-HexStringRepresentation {
    <#
        .SYNOPSIS
        Convert a SID from byte array format to a string representation of its hexadecimal format
        .DESCRIPTION
        Uses the custom format operator -f to format each byte as a string hex representation
        .INPUTS
        [System.Byte[]]$SIDByteArray
        .OUTPUTS
        [System.String] SID as an array of strings representing the byte array's hexadecimal values
        .EXAMPLE
        ConvertTo-HexStringRepresentation -SIDByteArray $Bytes

        Convert the binary SID $Bytes to a hexadecimal string representation
    #>
    [OutputType([System.String[]])]
    param (
        # SID
        [byte[]]$SIDByteArray
    )

    $SIDHexString = $SIDByteArray |
    ForEach-Object {
        '{0:X}' -f $_
    }
    return $SIDHexString
}
function ConvertTo-HexStringRepresentationForLDAPFilterString {
    <#
        .SYNOPSIS
        Convert a SID from byte array format to a string representation of its hexadecimal format, properly formatted for an LDAP filter string
        .DESCRIPTION
        Uses the custom format operator -f to format each byte as a string hex representation
        .INPUTS
        [System.Byte[]]$SIDByteArray
        .OUTPUTS
        [System.String] SID as an array of strings representing the byte array's hexadecimal values
        .EXAMPLE
        ConvertTo-HexStringRepresentationForLDAPFilterString -SIDByteArray $Bytes

        Convert the binary SID $Bytes to a hexadecimal string representation, formatted for use in an LDAP filter string
    #>
    [OutputType([System.String])]
    param (
        # SID to convert to a hex string
        [byte[]]$SIDByteArray
    )
    $Hexes = $SIDByteArray |
    ForEach-Object {
        '{0:X}' -f $_
    } |
    ForEach-Object {
        if ($_.Length -eq 2) {
            $_
        } else {
            "0$_"
        }
    }
    "\$($Hexes -join '\')"
}
function ConvertTo-SidByteArray {
    <#
        .SYNOPSIS
        Convert a SID from a string to binary format (byte array)
        .DESCRIPTION
        Uses the GetBinaryForm method of the [System.Security.Principal.SecurityIdentifier] class
        .INPUTS
        [System.String]$SidString
        .OUTPUTS
        [System.Byte] SID a a byte array
        .EXAMPLE
        ConvertTo-SidByteArray -SidString $SID

        Convert the SID string to a byte array
    #>
    [OutputType([System.Byte[]])]
    param (
        # SID to convert to binary
        [Parameter(ValueFromPipeline)]
        [string[]]$SidString
    )
    process {
        ForEach ($ThisSID in $SidString) {
            $SID = [System.Security.Principal.SecurityIdentifier]::new($ThisSID)
            [byte[]]$Bytes = [byte[]]::new($SID.BinaryLength)
            $SID.GetBinaryForm($Bytes, 0)
            $Bytes
        }
    }
}
function Expand-AdsiGroupMember {
    <#
        .SYNOPSIS
        Use the LDAP provider to add information about group members to a DirectoryEntry of a group for easier access
        .DESCRIPTION
        Recursively retrieves group members and detailed information about them
        Specifically gets the SID, and resolves foreign security principals to their DirectoryEntry from the trusted domain
        .INPUTS
        [System.DirectoryServices.DirectoryEntry]$DirectoryEntry
        .OUTPUTS
        [System.DirectoryServices.DirectoryEntry] Returned with member info added now (if the DirectoryEntry is a group).
        .EXAMPLE
        [System.DirectoryServices.DirectoryEntry]::new('WinNT://localhost/Administrators') | Get-AdsiGroupMember | Expand-AdsiGroupMember

        Need to fix example and add notes
    #>
    [OutputType([System.DirectoryServices.DirectoryEntry])]
    param (

        # Expecting a DirectoryEntry from the LDAP or WinNT providers, or a PSObject imitation from Get-DirectoryEntry
        [parameter(ValueFromPipeline)]
        $DirectoryEntry,

        # Properties of the group members to retrieve
        [string[]]$PropertiesToLoad = (@('Department', 'description', 'distinguishedName', 'grouptype', 'managedby', 'member', 'name', 'objectClass', 'objectSid', 'operatingSystem', 'primaryGroupToken', 'samAccountName', 'Title')),

        # Cache of known Win32_Account instances keyed by domain and SID
        [hashtable]$Win32AccountsBySID = ([hashtable]::Synchronized(@{})),

        # Cache of known Win32_Account instances keyed by domain (e.g. CONTOSO) and Caption (NTAccount name e.g. CONTOSO\User1)
        [hashtable]$Win32AccountsByCaption = ([hashtable]::Synchronized(@{})),

        <#
        Hashtable containing cached directory entries so they don't need to be retrieved from the directory again

        Uses a thread-safe hashtable by default
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid,

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $LoggingParams = @{
            ThisHostname = $ThisHostname
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        # The DomainsBySID cache must be populated with trusted domains in order to translate foreign security principals
        if ( $DomainsBySid.Keys.Count -lt 1 ) {
            Write-LogMsg @LogParams -Text "# No valid DomainsBySid cache found"
            $DomainsBySid = ([hashtable]::Synchronized(@{}))

            $GetAdsiServerParams = @{
                Win32AccountsBySID     = $Win32AccountsBySID
                Win32AccountsByCaption = $Win32AccountsByCaption
                DirectoryEntryCache    = $DirectoryEntryCache
                DomainsByNetbios       = $DomainsByNetbios
                DomainsBySid           = $DomainsBySid
                DomainsByFqdn          = $DomainsByFqdn
                ThisFqdn               = $ThisFqdn
            }

            Get-TrustedDomain |
            ForEach-Object {
                Write-LogMsg @LogParams -Text "Get-AdsiServer -Fqdn $($_.DomainFqdn)"
                $null = Get-AdsiServer -Fqdn $_.DomainFqdn @GetAdsiServerParams @LoggingParams
            }
        } else {
            Write-LogMsg @LogParams -Text "# Valid DomainsBySid cache found"
        }

        $CacheParams = @{
            DirectoryEntryCache = $DirectoryEntryCache
            DomainsByNetbios    = $DomainsByNetbios
            DomainsBySid        = $DomainsBySid
        }

        $i = 0
    }

    process {

        ForEach ($Entry in $DirectoryEntry) {

            $i++

            #$status = ("$(Get-Date -Format s)`t$ThisHostname`tExpand-AdsiGroupMember`tStatus: Using ADSI to get info on group member $i`: " + $Entry.Name)
            #Write-LogMsg @LogParams -Text "$status"

            $Principal = $null

            if ($Entry.objectClass -contains 'foreignSecurityPrincipal') {

                if ($Entry.distinguishedName.Value -match '(?>^CN=)(?<SID>[^,]*)') {

                    [string]$SID = $Matches.SID

                    #The SID of the domain is the SID of the user minus the last block of numbers
                    $DomainSid = $SID.Substring(0, $Sid.LastIndexOf("-"))
                    $Domain = $DomainsBySid[$DomainSid]

                    $Principal = Get-DirectoryEntry -DirectoryPath "LDAP://$($Domain.Dns)/<SID=$SID>" @CacheParams @LogginParams

                    try {
                        $null = $Principal.RefreshCache($PropertiesToLoad)
                    } catch {
                        #$Success = $false
                        $Principal = $Entry
                        Write-LogMsg @LogParams -Text " # SID '$SID' could not be retrieved from domain '$Domain'"
                    }

                    # Recursively enumerate group members
                    if ($Principal.properties['objectClass'].Value -contains 'group') {
                        Write-LogMsg @LogParams -Text "'$($Principal.properties['name'])' is a group in '$Domain'"
                        $AdsiGroupWithMembers = Get-AdsiGroupMember -Group $Principal -DomainsByFqdn $DomainsByFqdn -ThisFqdn $ThisFqdn @CacheParams @LoggingParams
                        $Principal = Expand-AdsiGroupMember -DirectoryEntry $AdsiGroupWithMembers.FullMembers -DomainsByFqdn $DomainsByFqdn -ThisFqdn $ThisFqdn -ThisHostName $ThisHostName @CacheParams

                    }

                }

            } else {
                $Principal = $Entry
            }

            Add-SidInfo -InputObject $Principal -DomainsBySid $DomainsBySid @LoggingParams

        }
    }

}
function Expand-IdentityReference {
    <#
        .SYNOPSIS
        Use ADSI to collect more information about the IdentityReference in NTFS Access Control Entries
        .DESCRIPTION
        Recursively retrieves group members and detailed information about them
        Use caching to reduce duplicate directory queries
        .INPUTS
        [System.Object]$AccessControlEntry
        .OUTPUTS
        [System.Object] The input object is returned with additional properties added:
            DirectoryEntry
            DomainDn
            DomainNetBIOS
            ObjectType
            Members (if the DirectoryEntry is a group).

        .EXAMPLE
        (Get-Acl).Access |
        Resolve-IdentityReference |
        Group-Object -Property IdentityReferenceResolved |
        Expand-IdentityReference

        Incomplete example but it shows the chain of functions to generate the expected input for this
    #>
    [OutputType([System.Object])]
    param (

        # The NTFS AccessControlEntry object(s), grouped by their IdentityReference property
        # TODO: Use System.Security.Principal.NTAccount instead
        [Parameter(ValueFromPipeline)]
        [System.Object[]]$AccessControlEntry,

        # Do not get group members
        [switch]$NoGroupMembers,

        # Thread-safe hashtable to use for caching directory entries and avoiding duplicate directory queries
        [hashtable]$IdentityReferenceCache = ([hashtable]::Synchronized(@{})),

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $LoggingParams = @{
            ThisHostname = $ThisHostname
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        #Write-LogMsg @LogParams -Text "$(($AccessControlEntry | Measure).Count) unique IdentityReferences found in the $(($AccessControlEntry | Measure).Count) ACEs"

        # Get the SID of the current domain
        $CurrentDomain = (Get-CurrentDomain)

        # Convert the objectSID attribute (byte array) to a security descriptor string formatted according to SDDL syntax (Security Descriptor Definition Language)
        [string]$CurrentDomainSID = & { [System.Security.Principal.SecurityIdentifier]::new([byte[]]$CurrentDomain.objectSid.Value, 0) } 2>$null

        #$i = 0

    }

    process {

        ForEach ($ThisIdentity in $AccessControlEntry) {

            if (-not $ThisIdentity) {
                continue
            }

            $ThisIdentityGroup = $ThisIdentity.Group

            #$i++
            #Calculate the completion percentage, and format it to show 0 decimal places
            #$percentage = "{0:N0}" -f (($i / ($AccessControlEntry.Count)) * 100)

            #Display the progress bar
            #$status = $percentage + "% - Using ADSI to get info on NTFS IdentityReference $i of " + $AccessControlEntry.Count + ": " + $ThisIdentity.Name
            #Write-LogMsg @LogParams -Text "Status: $status"

            #Write-Progress -Activity ("Unique IdentityReferences: " + $AccessControlEntry.Count) -Status $status -PercentComplete $percentage

            if ($null -eq $IdentityReferenceCache[$ThisIdentity.Name]) {

                Write-LogMsg @LogParams -Text " # IdentityReferenceCache miss for '$($ThisIdentity.Name)'"

                $DomainDN = $null
                $DirectoryEntry = $null
                $Members = $null

                $GetDirectoryEntryParams = @{
                    DirectoryEntryCache = $DirectoryEntryCache
                    DomainsByNetbios    = $DomainsByNetbios
                    ThisHostname        = $ThisHostname
                    LogMsgCache         = $LogMsgCache
                    WhoAmI              = $WhoAmI
                }
                $SearchDirectoryParams = @{
                    DirectoryEntryCache = $DirectoryEntryCache
                    DomainsByNetbios    = $DomainsByNetbios
                    ThisHostname        = $ThisHostname
                    LogMsgCache         = $LogMsgCache
                    WhoAmI              = $WhoAmI
                }

                $StartingIdentityName = $ThisIdentity.Name
                $split = $StartingIdentityName.Split('\')
                $domainNetbiosString = $split[0]
                $name = $split[1]

                if (
                    $null -ne $name -and
                    @($ThisIdentity.Group.AdsiProvider)[0] -eq 'LDAP'
                ) {
                    Write-LogMsg @LogParams -Text " # '$StartingIdentityName' is a domain security principal"

                    $DomainNetbiosCacheResult = $DomainsByNetbios[$domainNetbiosString]
                    if ($DomainNetbiosCacheResult) {
                        Write-LogMsg @LogParams -Text " # Domain NetBIOS cache hit for '$domainNetbiosString' for '$StartingIdentityName'"
                        $DomainDn = $DomainNetbiosCacheResult.DistinguishedName
                        $SearchDirectoryParams['DirectoryPath'] = "LDAP://$($DomainNetbiosCacheResult.Dns)/$DomainDn"
                    } else {
                        Write-LogMsg @LogParams -Text " # Domain NetBIOS cache miss for '$domainNetbiosString' for '$StartingIdentityName'"
                        if ( -not [string]::IsNullOrEmpty($domainNetbiosString) ) {
                            $DomainDn = ConvertTo-DistinguishedName -Domain $domainNetbiosString -DomainsByNetbios $DomainsByNetbios @LoggingParams
                        }
                        $SearchDirectoryParams['DirectoryPath'] = Add-DomainFqdnToLdapPath -DirectoryPath "LDAP://$domainNetbiosString" -ThisFqdn $ThisFqdn @LogParams
                    }

                    # Search the domain for the principal
                    $SearchDirectoryParams['Filter'] = "(samaccountname=$Name)"
                    $SearchDirectoryParams['PropertiesToLoad'] = @(
                        'objectClass',
                        'objectSid',
                        'samAccountName',
                        'distinguishedName',
                        'name',
                        'grouptype',
                        'description',
                        'managedby',
                        'member',
                        'Department',
                        'Title',
                        'primaryGroupToken'
                    )
                    try {
                        $DirectoryEntry = Search-Directory @SearchDirectoryParams
                    } catch {
                        Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tExpand-IdentityReference`t # '$StartingIdentityName' could not be resolved against its directory"
                        Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tExpand-IdentityReference`t # $($_.Exception.Message) for '$StartingIdentityName"
                    }

                } elseif (
                    $StartingIdentityName.Substring(0, $StartingIdentityName.LastIndexOf('-') + 1) -eq $CurrentDomainSID
                    #((($StartingIdentityName -split '-') | Select-Object -SkipLast 1) -join '-') -eq $CurrentDomainSID
                ) {
                    Write-LogMsg @LogParams -Text " # '$StartingIdentityName' is an unresolved SID from the current domain"

                    # Get the distinguishedName and netBIOSName of the current domain. This also determines whether the domain is online.
                    $DomainDN = $CurrentDomain.distinguishedName.Value
                    $DomainFQDN = ConvertTo-Fqdn -DistinguishedName $DomainDN -ThisFqdn $ThisFqdn @LoggingParams

                    $SearchDirectoryParams['DirectoryPath'] = "LDAP://$DomainFQDN/cn=partitions,cn=configuration,$DomainDn"
                    $SearchDirectoryParams['Filter'] = "(&(objectcategory=crossref)(dnsroot=$DomainFQDN)(netbiosname=*))"
                    $SearchDirectoryParams['PropertiesToLoad'] = 'netbiosname'

                    $DomainCrossReference = Search-Directory @SearchDirectoryParams
                    if ($DomainCrossReference.Properties ) {
                        Write-LogMsg @LogParams -Text " # The domain '$DomainFQDN' is online for '$StartingIdentityName'"
                        [string]$domainNetbiosString = $DomainCrossReference.Properties['netbiosname']
                        # TODO: The domain is online, so let's see if any domain trusts have issues? Determine if SID is foreign security principal?
                        # TODO: What if the foreign security principal exists but the corresponding domain trust is down? Don't want to recommend deletion of the ACE in that case.
                    }
                    $SidObject = [System.Security.Principal.SecurityIdentifier]::new($StartingIdentityName)
                    $SidBytes = [byte[]]::new($SidObject.BinaryLength)
                    $null = $SidObject.GetBinaryForm($SidBytes, 0)
                    $ObjectSid = ConvertTo-HexStringRepresentationForLDAPFilterString -SIDByteArray $SidBytes
                    $SearchDirectoryParams['DirectoryPath'] = "LDAP://$DomainFQDN/$DomainDn"
                    $SearchDirectoryParams['Filter'] = "(objectsid=$ObjectSid)"
                    $SearchDirectoryParams['PropertiesToLoad'] = @(
                        'objectClass',
                        'objectSid',
                        'samAccountName',
                        'distinguishedName',
                        'name',
                        'grouptype',
                        'description',
                        'managedby',
                        'member',
                        'Department',
                        'Title',
                        'primaryGroupToken'
                    )
                    try {
                        $DirectoryEntry = Search-Directory @SearchDirectoryParams
                    } catch {
                        Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tExpand-IdentityReference`t # '$StartingIdentityName' could not be resolved against its directory"
                        Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tExpand-IdentityReference`t # $($_.Exception.Message) for '$StartingIdentityName'"
                    }


                } else {

                    Write-LogMsg @LogParams -Text " # '$StartingIdentityName' is a local security principal or unresolved SID"

                    if ($null -eq $name) { $name = $StartingIdentityName }

                    if ($name -like "S-1-*") {
                        Write-LogMsg @LogParams -Text "$($StartingIdentityName) is an unresolved SID"

                        # The SID of the domain is the SID of the user minus the last block of numbers
                        $DomainSid = $name.Substring(0, $name.LastIndexOf("-"))

                        # Determine if SID belongs to current domain
                        if ($DomainSid -eq $CurrentDomainSID) {
                            Write-LogMsg @LogParams -Text "$($StartingIdentityName) belongs to the current domain. Could be a deleted user. ?possibly a foreign security principal corresponding to an offline trusted domain or deleted user in the trusted domain?"
                        } else {
                            Write-LogMsg @LogParams -Text "$($StartingIdentityName) does not belong to the current domain. Could be a local security principal or belong to an unresolvable domain."
                        }

                        # Lookup other information about the domain using its SID as the key
                        $DomainObject = $DomainsBySID[$DomainSid]
                        if ($DomainObject) {
                            $GetDirectoryEntryParams['DirectoryPath'] = "WinNT://$($DomainObject.Dns)/Users,group"
                            $domainNetbiosString = $DomainObject.Netbios
                        } else {
                            $GetDirectoryEntryParams['DirectoryPath'] = "WinNT://$domainNetbiosString/Users,group"
                        }

                        try {
                            $UsersGroup = Get-DirectoryEntry @GetDirectoryEntryParams
                        } catch {
                            Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tExpand-IdentityReference`tCould not get '$($GetDirectoryEntryParams['DirectoryPath'])' using PSRemoting"
                            Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tExpand-IdentityReference`t$_"
                        }
                        $MembersOfUsersGroup = Get-WinNTGroupMember -DirectoryEntry $UsersGroup -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams

                        $DirectoryEntry = $MembersOfUsersGroup |
                        Where-Object -FilterScript { ($name -eq [System.Security.Principal.SecurityIdentifier]::new([byte[]]$_.Properties['objectSid'].Value, 0)) }

                        if ($DirectoryEntry.Name) {
                            $AccountName = $DirectoryEntry.Name
                        } else {
                            if ($DirectoryEntry.Properties) {
                                if ($DirectoryEntry.Properties['name'].Value) {
                                    $AccountName = $DirectoryEntry.Properties['name'].Value
                                } else {
                                    $AccountName = $DirectoryEntry.Properties['name']
                                }
                            }
                        }

                        $ThisIdentity = [pscustomobject]@{
                            Count = $(($ThisIdentityGroup | Measure-Object).Count)
                            Name  = "$domainNetbiosString\" + $AccountName
                            Group = $ThisIdentityGroup
                            # Unclear why this was filtered so I have removed it to see what happens
                            #Group = $ThisIdentityGroup | Where-Object -FilterScript { ($_.SourceAccessList.Path -split '\\')[2] -eq $domainNetbiosString } # Should be already Resolved to a UNC path so it reflects the server name
                        }

                    } else {
                        Write-LogMsg @LogParams -Text " # '$StartingIdentityName' is a local security principal"
                        $DomainNetbiosCacheResult = $DomainsByNetbios[$domainNetbiosString]
                        if ($DomainNetbiosCacheResult) {
                            $GetDirectoryEntryParams['DirectoryPath'] = "WinNT://$($DomainNetbiosCacheResult.Dns)/$name"
                        } else {
                            $GetDirectoryEntryParams['DirectoryPath'] = "WinNT://$domainNetbiosString/$name"
                        }
                        try {
                            $GetDirectoryEntryParams['PropertiesToLoad'] = @(
                                'members',
                                'objectClass',
                                'objectSid',
                                'samAccountName',
                                'distinguishedName',
                                'name',
                                'grouptype',
                                'description',
                                'managedby',
                                'member',
                                'Department',
                                'Title',
                                'primaryGroupToken'
                            )
                            $DirectoryEntry = Get-DirectoryEntry @GetDirectoryEntryParams
                        } catch {
                            Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tExpand-IdentityReference`t$($GetDirectoryEntryParams['DirectoryPath']) could not be resolved for '$StartingIdentityName'"
                        }
                    }
                }

                $ObjectType = $null
                if ($null -ne $DirectoryEntry) {

                    if (
                        $DirectoryEntry.Properties['objectClass'] -contains 'group' -or
                        $DirectoryEntry.SchemaClassName -eq 'group'
                    ) {
                        $ObjectType = 'Group'
                    } else {
                        $ObjectType = 'User'
                    }

                    if ($NoGroupMembers -eq $false) {

                        if (
                            # WinNT DirectoryEntries do not contain an objectClass property
                            # If this property exists it is an LDAP DirectoryEntry rather than WinNT
                            $DirectoryEntry.Properties['objectClass'] -contains 'group'
                        ) {
                            # Retrieve the members of groups from the LDAP provider
                            Write-LogMsg @LogParams -Text " # '$($DirectoryEntry.Path)' is an LDAP security principal for '$StartingIdentityName'"
                            $Members = (Get-AdsiGroupMember -Group $DirectoryEntry -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams).FullMembers
                        } else {
                            # Retrieve the members of groups from the WinNT provider
                            Write-LogMsg @LogParams -Text " # '$($DirectoryEntry.Path)' is a WinNT security principal for '$StartingIdentityName'"
                            if ( $DirectoryEntry.SchemaClassName -eq 'group') {
                                Write-LogMsg @LogParams -Text " # '$($DirectoryEntry.Path)' is a WinNT group for '$StartingIdentityName'"
                                $Members = Get-WinNTGroupMember -DirectoryEntry $DirectoryEntry -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams
                            }
                        }

                        # (Get-AdsiGroupMember).FullMembers or Get-WinNTGroupMember could return an array with null members so we must verify that is not true
                        if ($Members) {
                            $Members |
                            ForEach-Object {

                                if ($_.Domain) {

                                    Add-Member -InputObject $_ -Force -NotePropertyMembers @{
                                        Group = $ThisIdentityGroup
                                    }

                                } else {

                                    Add-Member -InputObject $_ -Force -NotePropertyMembers @{
                                        Group  = $ThisIdentityGroup
                                        Domain = [pscustomobject]@{
                                            Dns     = $domainNetbiosString
                                            Netbios = $domainNetbiosString
                                            Sid     = ($name -split '-') | Select-Object -Last 1
                                        }
                                    }

                                }
                            }
                        }

                        Write-LogMsg @LogParams -Text " # $($DirectoryEntry.Path) has $(($Members | Measure-Object).Count) members for '$StartingIdentityName'"

                    }
                } else {
                    Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tExpand-IdentityReference`t # '$StartingIdentityName' could not be matched to a DirectoryEntry"
                }

                Add-Member -InputObject $ThisIdentity -Force -NotePropertyMembers @{
                    DomainDn       = $DomainDn
                    DomainNetbios  = $DomainNetBiosString
                    ObjectType     = $ObjectType
                    DirectoryEntry = $DirectoryEntry
                    Members        = $Members
                }
                $IdentityReferenceCache[$StartingIdentityName] = $ThisIdentity

            } else {
                Write-LogMsg @LogParams -Text " # IdentityReferenceCache hit for '$($ThisIdentity.Name)'"
                $null = $IdentityReferenceCache[$ThisIdentity.Name].Group.Add($ThisIdentityGroup)
                $ThisIdentity = $IdentityReferenceCache[$ThisIdentity.Name]
            }

            $ThisIdentity

        }

    }

}
function Expand-WinNTGroupMember {
    <#
        .SYNOPSIS
        Use the LDAP provider to add information about group members to a DirectoryEntry of a group for easier access
        .DESCRIPTION
        Recursively retrieves group members and detailed information about them
        .INPUTS
        [System.DirectoryServices.DirectoryEntry]$DirectoryEntry
        .OUTPUTS
        [System.DirectoryServices.DirectoryEntry] Returned with member info added now (if the DirectoryEntry is a group).
        .EXAMPLE
        [System.DirectoryServices.DirectoryEntry]::new('WinNT://localhost/Administrators') | Get-WinNTGroupMember | Expand-WinNTGroupMember

        Need to fix example and add notes
    #>
    [OutputType([System.DirectoryServices.DirectoryEntry])]
    param (

        # Expecting a DirectoryEntry from the WinNT provider, or a PSObject imitation from Get-DirectoryEntry
        [Parameter(ValueFromPipeline)]
        $DirectoryEntry,

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $LoggingParams = @{
            ThisHostname = $ThisHostname
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

    }
    process {
        ForEach ($ThisEntry in $DirectoryEntry) {

            if (!($ThisEntry.Properties)) {
                Write-Warning "'$ThisEntry' has no properties"
            } elseif ($ThisEntry.Properties['objectClass'] -contains 'group') {

                Write-LogMsg @LogParams -Text "'$($ThisEntry.Path)' is an ADSI group"
                $AdsiGroup = Get-AdsiGroup -DirectoryEntryCache $DirectoryEntryCache -DirectoryPath $ThisEntry.Path -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams
                Add-SidInfo -InputObject $AdsiGroup.FullMembers -DomainsBySid $DomainsBySid @LoggingParams

            } else {

                if ($ThisEntry.SchemaClassName -eq 'group') {
                    Write-LogMsg @LogParams -Text "'$($ThisEntry.Path)' is a WinNT group"

                    if ($ThisEntry.GetType().FullName -eq 'System.Collections.Hashtable') {
                        Write-LogMsg @LogParams -Text "$($ThisEntry.Path)' is a special group with no direct memberships"
                        Add-SidInfo -InputObject $ThisEntry -DomainsBySid $DomainsBySid @LoggingParams
                    } else {
                        Get-WinNTGroupMember -DirectoryEntry $ThisEntry -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams
                    }

                } else {
                    Write-LogMsg @LogParams -Text "$($ThisEntry.Path)' is a user account"
                    Add-SidInfo -InputObject $ThisEntry -DomainsBySid $DomainsBySid @LoggingParams
                }

            }

        }
    }
}
function Find-AdsiProvider {
    <#
        .SYNOPSIS
        Determine whether a directory server is an LDAP or a WinNT server
        .DESCRIPTION
        Uses the ADSI provider to attempt to query the server using LDAP first, then WinNT second
        .INPUTS
        [System.String] AdsiServer parameter.
        .OUTPUTS
        [System.String] Possible return values are:
            None
            LDAP
            WinNT
        .EXAMPLE
        Find-AdsiProvider -AdsiServer localhost

        Find the ADSI provider of the local computer
        .EXAMPLE
        Find-AdsiProvider -AdsiServer 'ad.contoso.com'

        Find the ADSI provider of the AD domain 'ad.contoso.com'
    #>
    [OutputType([System.String])]

    param (

        # IP address or hostname of the directory server whose ADSI provider type to determine
        [Parameter(ValueFromPipeline)]
        [string[]]$AdsiServer,

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

    }
    process {
        ForEach ($ThisServer in $AdsiServer) {
            $AdsiProvider = $null
            $AdsiPath = "LDAP://$ThisServer"
            Write-LogMsg @LogParams -Text "[System.DirectoryServices.DirectoryEntry]::Exists('$AdsiPath')"
            try {
                $null = [System.DirectoryServices.DirectoryEntry]::Exists($AdsiPath)
                $AdsiProvider = 'LDAP'
            } catch { Write-LogMsg @LogParams -Text " # $ThisServer did not respond to LDAP" }
            if (!$AdsiProvider) {
                $AdsiPath = "WinNT://$ThisServer"
                Write-LogMsg @LogParams -Text "[System.DirectoryServices.DirectoryEntry]::Exists('$AdsiPath')"
                try {
                    $null = [System.DirectoryServices.DirectoryEntry]::Exists($AdsiPath)
                    $AdsiProvider = 'WinNT'
                } catch {
                    Write-LogMsg @LogParams -Text " # $ThisServer did not respond to WinNT"
                }
            }
            if (!$AdsiProvider) {
                $AdsiProvider = 'none'
            }
        }
        $AdsiProvider
    }
}
function Find-LocalAdsiServerSid {
    param (
        [string]$ComputerName,

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    $LoggingParams = @{
        ThisHostname = $ThisHostname
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    Write-LogMsg @LogParams -Text "Get-Win32UserAccount -ComputerName '$ComputerName'"
    $Win32UserAccounts = Get-Win32UserAccount -ComputerName $ComputerName -ThisFqdn $ThisFqdn @LoggingParams
    if (-not $Win32UserAccounts) {
        return
    }
    [string]$LocalAccountSID = @($Win32UserAccounts.SID)[0]
    return $LocalAccountSID.Substring(0, $LocalAccountSID.LastIndexOf("-"))
}
function Get-AdsiGroup {
    <#
        .SYNOPSIS
        Get the directory entries for a group and its members using ADSI
        .DESCRIPTION
        Uses the ADSI components to search a directory for a group, then get its members
        Both the WinNT and LDAP providers are supported
        .INPUTS
        None. Pipeline input is not accepted.
        .OUTPUTS
        [System.DirectoryServices.DirectoryEntry] for each group memeber
        .EXAMPLE
        Get-AdsiGroup -DirectoryPath 'WinNT://WORKGROUP/localhost' -GroupName Administrators

        Get members of the local Administrators group
        .EXAMPLE
        Get-AdsiGroup -GroupName Administrators

        On a domain-joined computer, this will get members of the domain's Administrators group
        On a workgroup computer, this will get members of the local Administrators group
    #>
    [OutputType([System.DirectoryServices.DirectoryEntry])]

    param (

        <#
        Path to the directory object to retrieve
        Defaults to the root of the current domain
        #>
        [string]$DirectoryPath = (([System.DirectoryServices.DirectorySearcher]::new()).SearchRoot.Path),

        # Name (CN or Common Name) of the group to retrieve
        [string]$GroupName,

        # Properties of the group members to retrieve
        [string[]]$PropertiesToLoad = (@('Department', 'description', 'distinguishedName', 'grouptype', 'managedby', 'member', 'name', 'objectClass', 'objectSid', 'operatingSystem', 'primaryGroupToken', 'samAccountName', 'Title')),

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    $GroupParams = @{
        DirectoryPath       = $DirectoryPath
        PropertiesToLoad    = $PropertiesToLoad
        DirectoryEntryCache = $DirectoryEntryCache
        DomainsByFqdn       = $DomainsByFqdn
        DomainsByNetbios    = $DomainsByNetbios
        DomainsBySid        = $DomainsBySid
        ThisHostname        = $ThisHostname
        LogMsgCache         = $LogMsgCache
        WhoAmI              = $WhoAmI
    }
    $GroupMemberParams = @{
        PropertiesToLoad    = $PropertiesToLoad
        DirectoryEntryCache = $DirectoryEntryCache
        DomainsByFqdn       = $DomainsByFqdn
        DomainsByNetbios    = $DomainsByNetbios
        DomainsBySid        = $DomainsBySid
        ThisHostName        = $ThisHostName
        ThisFqdn            = $ThisFqdn
        LogMsgCache         = $LogMsgCache
        WhoAmI              = $WhoAmI
    }

    switch -Regex ($DirectoryPath) {
        '^WinNT' {
            $GroupParams['DirectoryPath'] = "$DirectoryPath/$GroupName"
            $GroupMemberParams['DirectoryEntry'] = Get-DirectoryEntry @GroupParams
            $FullMembers = Get-WinNTGroupMember @GroupMemberParams
        }
        '^$' {
            # This is expected for a workgroup computer
            $GroupParams['DirectoryPath'] = "WinNT://localhost/$GroupName"
            $GroupMemberParams['DirectoryEntry'] = Get-DirectoryEntry @GroupParams
            $FullMembers = Get-WinNTGroupMember @GroupMemberParams
        }
        default {
            if ($GroupName) {
                $GroupParams['Filter'] = "(&(objectClass=group)(cn=$GroupName))"
            } else {
                $GroupParams['Filter'] = "(objectClass=group)"
            }
            $GroupMemberParams['Group'] = Search-Directory @GroupParams
            $FullMembers = Get-AdsiGroupMember @GroupMemberParams
        }
    }

    $FullMembers

}
function Get-AdsiGroupMember {
    <#
        .SYNOPSIS
        Get members of a group from the LDAP provider
        .DESCRIPTION
        Use ADSI to get members of a group from the LDAP provider
        Return the group's DirectoryEntry plus a FullMembers property containing the member DirectoryEntries
        .INPUTS
        [System.DirectoryServices.DirectoryEntry]$DirectoryEntry
        .OUTPUTS
        [System.DirectoryServices.DirectoryEntry] plus a FullMembers property
        .EXAMPLE
        [System.DirectoryServices.DirectoryEntry]::new('LDAP://ad.contoso.com/CN=Administrators,CN=BuiltIn,DC=ad,DC=contoso,DC=com') | Get-AdsiGroupMember

        Get members of the domain Administrators group
    #>
    [OutputType([System.DirectoryServices.DirectoryEntry])]
    param (

        # Directory entry of the LDAP group whose members to get
        [Parameter(ValueFromPipeline)]
        $Group,

        # Properties of the group members to find in the directory
        [string[]]$PropertiesToLoad,

        # Cache of known Win32_Account instances keyed by domain and SID
        [hashtable]$Win32AccountsBySID = ([hashtable]::Synchronized(@{})),

        # Cache of known Win32_Account instances keyed by domain (e.g. CONTOSO) and Caption (NTAccount name e.g. CONTOSO\User1)
        [hashtable]$Win32AccountsByCaption = ([hashtable]::Synchronized(@{})),

        <#
        Hashtable containing cached directory entries so they don't have to be retrieved from the directory again
        Uses a thread-safe hashtable by default
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages,

        <#
        Perform a non-recursive search of the memberOf attribute

        Otherwise the search will be recursive by default
        #>
        [switch]$NoRecurse,

        <#
        Search the primaryGroupId attribute only

        Ignore the memberOf attribute
        #>
        [switch]$PrimaryGroupOnly

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $LoggingParams = @{
            ThisHostname = $ThisHostname
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $PathRegEx = '(?<Path>LDAP:\/\/[^\/]*)'
        $DomainRegEx = '(?i)DC=\w{1,}?\b'

        $PropertiesToLoad += 'primaryGroupToken', 'objectSid', 'objectClass'

        $PropertiesToLoad = $PropertiesToLoad |
        Sort-Object -Unique

        $SearchParameters = @{
            PropertiesToLoad    = $PropertiesToLoad
            DirectoryEntryCache = $DirectoryEntryCache
            DomainsByNetbios    = $DomainsByNetbios
        }

        $CacheParams = @{
            DirectoryEntryCache = $DirectoryEntryCache
            DomainsByNetbios    = $DomainsByNetbios
            DomainsBySid        = $DomainsBySid
        }

    }
    process {

        foreach ($ThisGroup in $Group) {

            if (-not $ThisGroup.Properties['primaryGroupToken']) {
                $ThisGroup.RefreshCache('primaryGroupToken')
            }

            # The memberOf attribute does not reflect a user's Primary Group membership so the primaryGroupId attribute must be searched
            $primaryGroupIdFilter = "(primaryGroupId=$($ThisGroup.Properties['primaryGroupToken']))"

            if ($PrimaryGroupOnly) {
                $SearchParameters['Filter'] = $primaryGroupIdFilter
            } else {

                if ($NoRecurse) {
                    # Non-recursive search of the memberOf attribute
                    $MemberOfFilter = "(memberOf=$($ThisGroup.Properties['distinguishedname']))"
                } else {
                    # Recursive search of the memberOf attribute
                    $MemberOfFilter = "(memberOf:1.2.840.113556.1.4.1941:=$($ThisGroup.Properties['distinguishedname']))"
                }

                $SearchParameters['Filter'] = "(|$MemberOfFilter$primaryGroupIdFilter)"
            }

            if ($ThisGroup.Path -match $PathRegEx) {

                $SearchParameters['DirectoryPath'] = Add-DomainFqdnToLdapPath -DirectoryPath $Matches.Path -ThisFqdn $ThisFqdn @LoggingParams

                if ($ThisGroup.Path -match $DomainRegEx) {
                    $Domain = ([regex]::Matches($ThisGroup.Path, $DomainRegEx) | ForEach-Object { $_.Value }) -join ','
                    $SearchParameters['DirectoryPath'] = Add-DomainFqdnToLdapPath -DirectoryPath "LDAP://$Domain" -ThisFqdn $ThisFqdn @LoggingParams
                } else {
                    $SearchParameters['DirectoryPath'] = Add-DomainFqdnToLdapPath -DirectoryPath $ThisGroup.Path -ThisFqdn $ThisFqdn @LoggingParams
                }

            } else {
                $SearchParameters['DirectoryPath'] = Add-DomainFqdnToLdapPath -DirectoryPath $ThisGroup.Path -ThisFqdn $ThisFqdn @LoggingParams
            }

            Write-LogMsg @LogParams -Text "Search-Directory -DirectoryPath '$($SearchParameters['DirectoryPath'])' -Filter '$($SearchParameters['Filter'])'"

            $GroupMemberSearch = Search-Directory @SearchParameters
            Write-LogMsg @LogParams -Text " # '$($GroupMemberSearch.Count)' results for Search-Directory -DirectoryPath '$($SearchParameters['DirectoryPath'])' -Filter '$($SearchParameters['Filter'])'"

            if ($GroupMemberSearch.Count -gt 0) {
                $CurrentADGroupMembers = [System.Collections.Generic.List[System.DirectoryServices.DirectoryEntry]]::new()

                $MembersThatAreGroups = $GroupMemberSearch |
                Where-Object -FilterScript { $_.Properties['objectClass'] -contains 'group' }

                if ($MembersThatAreGroups.Count -gt 0) {
                    $FilterBuilder = [System.Text.StringBuilder]::new("(|")

                    $MembersThatAreGroups |
                    ForEach-Object {
                        $null = $FilterBuilder.Append("(primaryGroupId=$($_.Properties['primaryGroupToken'])))")
                    }

                    $null = $FilterBuilder.Append(")")
                    $PrimaryGroupFilter = $FilterBuilder.ToString()
                    $SearchParameters['Filter'] = $PrimaryGroupFilter
                    Write-LogMsg @LogParams -Text "Search-Directory -DirectoryPath '$($SearchParameters['DirectoryPath'])' -Filter '$($SearchParameters['Filter'])'"
                    $PrimaryGroupMembers = Search-Directory @SearchParameters

                    $PrimaryGroupMembers |
                    ForEach-Object {
                        $FQDNPath = Add-DomainFqdnToLdapPath -DirectoryPath $_.Path -ThisFqdn $ThisFqdn @LoggingParams
                        $DirectoryEntry = $null
                        Write-LogMsg @LogParams -Text "Get-DirectoryEntry -DirectoryPath '$FQDNPath'"
                        $DirectoryEntry = Get-DirectoryEntry -DirectoryPath $FQDNPath -PropertiesToLoad $PropertiesToLoad @CacheParams @LoggingParams
                        if ($DirectoryEntry) {
                            $null = $CurrentADGroupMembers.Add($DirectoryEntry)
                        }
                    }
                }

                $GroupMemberSearch |
                ForEach-Object {
                    $FQDNPath = Add-DomainFqdnToLdapPath -DirectoryPath $_.Path -ThisFqdn $ThisFqdn @LoggingParams
                    $DirectoryEntry = $null
                    Write-LogMsg @LogParams -Text "Get-DirectoryEntry -DirectoryPath '$FQDNPath'"
                    $DirectoryEntry = Get-DirectoryEntry -DirectoryPath $FQDNPath -PropertiesToLoad $PropertiesToLoad @CacheParams @LoggingParams
                    if ($DirectoryEntry) {
                        $null = $CurrentADGroupMembers.Add($DirectoryEntry)
                    }
                }

            } else {
                $CurrentADGroupMembers = $null
            }

            Write-LogMsg @LogParams -Text "$($ThisGroup.Properties.name) has $(($CurrentADGroupMembers | Measure-Object).Count) members"

            $ProcessedGroupMembers = Expand-AdsiGroupMember -DirectoryEntry $CurrentADGroupMembers -Win32AccountsBySID $Win32AccountsBySID -Win32AccountsByCaption $Win32AccountsByCaption -DomainsByFqdn $DomainsByFqdn -ThisFqdn $ThisFqdn @CacheParams @LoggingParams

            Add-Member -InputObject $ThisGroup -MemberType NoteProperty -Name FullMembers -Value $ProcessedGroupMembers -Force -PassThru

        }
    }
}
function Get-AdsiServer {
    <#
        .SYNOPSIS
        Get information about a directory server including the ADSI provider it hosts and its well-known SIDs
        .DESCRIPTION
        Uses the ADSI provider to query the server using LDAP first, then WinNT upon failure
        Uses WinRM to query the CIM class Win32_SystemAccount for well-known SIDs
        .INPUTS
        [System.String]$Fqdn
        .OUTPUTS
        [PSCustomObject] with AdsiProvider and WellKnownSIDs properties
        .EXAMPLE
        Get-AdsiServer -Fqdn localhost

        Find the ADSI provider of the local computer
        .EXAMPLE
        Get-AdsiServer -Fqdn 'ad.contoso.com'

        Find the ADSI provider of the AD domain 'ad.contoso.com'
    #>
    [OutputType([System.String])]

    param (

        # IP address or hostname of the directory server whose ADSI provider type to determine
        [Parameter(ValueFromPipeline)]
        [string[]]$Fqdn,

        # NetBIOS name of the ADSI server whose information to determine
        [string[]]$Netbios,

        # Cache of known Win32_Account instances keyed by domain and SID
        [hashtable]$Win32AccountsBySID = ([hashtable]::Synchronized(@{})),

        # Cache of known Win32_Account instances keyed by domain (e.g. CONTOSO) and Caption (NTAccount name e.g. CONTOSO\User1)
        [hashtable]$Win32AccountsByCaption = ([hashtable]::Synchronized(@{})),

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName,AdsiProvider,Win32Accounts properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $LoggingParams = @{
            ThisHostname = $ThisHostname
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $CacheParams = @{
            DirectoryEntryCache = $DirectoryEntryCache
            DomainsByFqdn       = $DomainsByFqdn
            DomainsByNetbios    = $DomainsByNetbios
            DomainsBySid        = $DomainsBySid
        }

    }
    process {
        ForEach ($DomainFqdn in $Fqdn) {
            $OutputObject = $DomainsByFqdn[$DomainFqdn]
            if ($OutputObject) {
                Write-LogMsg @LogParams -Text " # Domain FQDN cache hit for '$DomainFqdn'"
                $OutputObject
                continue
            }
            Write-LogMsg @LogParams -Text " # Domain FQDN cache miss for '$DomainFqdn'"

            Write-LogMsg @LogParams -Text "Find-AdsiProvider -AdsiServer '$DomainFqdn'"
            $AdsiProvider = Find-AdsiProvider -AdsiServer $DomainFqdn @LoggingParams
            $CacheParams['AdsiProvider'] = $AdsiProvider

            Write-LogMsg @LogParams -Text "ConvertTo-DistinguishedName -AdsiProvider '$AdsiProvider' -DomainFQDN '$DomainFqdn'"
            $DomainDn = ConvertTo-DistinguishedName -DomainFQDN $DomainFqdn -AdsiProvider $AdsiProvider @LoggingParams

            Write-LogMsg @LogParams -Text "ConvertTo-DomainSidString -AdsiProvider '$AdsiProvider' -DomainDnsName '$DomainFqdn'"
            $DomainSid = ConvertTo-DomainSidString -DomainDnsName $DomainFqdn -ThisFqdn $ThisFqdn @CacheParams @LoggingParams

            Write-LogMsg @LogParams -Text "ConvertTo-DomainNetBIOS -AdsiProvider '$AdsiProvider' -DomainFQDN '$DomainFqdn'"
            $DomainNetBIOS = ConvertTo-DomainNetBIOS -DomainFQDN $DomainFqdn @CacheParams @LoggingParams

            Write-LogMsg @LogParams -Text "Get-Win32Account -AdsiProvider '$AdsiProvider' -ComputerName '$DomainFqdn' -ThisFqdn '$ThisFqdn'"
            $Win32Accounts = Get-Win32Account -ComputerName $DomainFqdn -ThisFqdn $ThisFqdn -AdsiProvider $AdsiProvider -Win32AccountsBySID $Win32AccountsBySID -ErrorAction SilentlyContinue @LoggingParams

            $Win32Accounts |
            ForEach-Object {
                $Win32AccountsBySID["$($_.Domain)\$($_.SID)"] = $_
                $Win32AccountsByCaption["$($_.Domain)\$($_.Caption)"] = $_
            }

            $OutputObject = [PSCustomObject]@{
                DistinguishedName = $DomainDn
                Dns               = $DomainFqdn
                Sid               = $DomainSid
                Netbios           = $DomainNetBIOS
                AdsiProvider      = $AdsiProvider
                Win32Accounts     = $Win32Accounts
            }
            $DomainsBySid[$OutputObject.Sid] = $OutputObject
            $DomainsByNetbios[$OutputObject.Netbios] = $OutputObject
            $DomainsByFqdn[$DomainFqdn] = $OutputObject
            $OutputObject
        }

        ForEach ($DomainNetbios in $Netbios) {
            $OutputObject = $DomainsByNetbios[$DomainNetbios]
            if ($OutputObject) {
                Write-LogMsg @LogParams -Text " # Domain NetBIOS cache hit for '$DomainNetbios'"
                $OutputObject
                continue
            }
            Write-LogMsg @LogParams -Text " # Domain NetBIOS cache hit for '$DomainNetbios'"

            Write-LogMsg @LogParams -Text "New-AdsiServerCimSession -ComputerName '$DomainNetBIOS'"
            $CimSession = New-AdsiServerCimSession -ComputerName $DomainNetBIOS -ThisFqdn $ThisFqdn @LoggingParams

            Write-LogMsg @LogParams -Text "Find-AdsiProvider -AdsiServer '$DomainDnsName' # for '$DomainNetbios'"
            $AdsiProvider = Find-AdsiProvider -AdsiServer $DomainDnsName @LoggingParams
            $CacheParams['AdsiProvider'] = $AdsiProvider

            Write-LogMsg @LogParams -Text "ConvertTo-DistinguishedName -Domain '$DomainNetBIOS'"
            $DomainDn = ConvertTo-DistinguishedName -Domain $DomainNetBIOS -DomainsByNetbios $DomainsByNetbios @LoggingParams

            if ($DomainDn) {
                Write-LogMsg @LogParams -Text "ConvertTo-Fqdn -DistinguishedName '$DomainDn' # for '$DomainNetbios'"
                $DomainDnsName = ConvertTo-Fqdn -DistinguishedName $DomainDn -ThisFqdn $ThisFqdn @LoggingParams
            } else {
                $ParentDomainDnsName = Get-ParentDomainDnsName -DomainsByNetbios $DomainNetBIOS -CimSession $CimSession -ThisFqdn $ThisFqdn @LoggingParams
                $DomainDnsName = "$DomainNetBIOS.$ParentDomainDnsName"
            }

            Write-LogMsg @LogParams -Text "ConvertTo-DomainSidString -DomainDnsName '$DomainFqdn' -AdsiProvider '$AdsiProvider' -ThisFqdn '$ThisFqdn' # for '$DomainNetbios'"
            $DomainSid = ConvertTo-DomainSidString -DomainDnsName $DomainDnsName -ThisFqdn $ThisFqdn @CacheParams @LoggingParams

            Write-LogMsg @LogParams -Text "Get-Win32Account -ComputerName '$DomainDnsName' -AdsiProvider '$AdsiProvider' -ThisFqdn '$ThisFqdn' # for '$DomainNetbios'"
            $Win32Accounts = Get-Win32Account -ComputerName $DomainDnsName -ThisFqdn $ThisFqdn -AdsiProvider $AdsiProvider -Win32AccountsBySID $Win32AccountsBySID -CimSession $CimSession -ErrorAction SilentlyContinue @LoggingParams

            Remove-CimSession -CimSession $CimSession

            $Win32Accounts |
            ForEach-Object {
                $Win32AccountsBySID["$($_.Domain)\$($_.SID)"] = $_
                $Win32AccountsByCaption["$($_.Domain)\$($_.Caption)"] = $_
            }

            $OutputObject = [PSCustomObject]@{
                DistinguishedName = $DomainDn
                Dns               = $DomainDnsName
                Sid               = $DomainSid
                Netbios           = $DomainNetBIOS
                AdsiProvider      = $AdsiProvider
                Win32Accounts     = $Win32Accounts
            }
            $DomainsBySid[$OutputObject.Sid] = $OutputObject
            $DomainsByNetbios[$OutputObject.Netbios] = $OutputObject
            $DomainsByFqdn[$OutputObject.Dns] = $OutputObject
            $OutputObject
        }
    }
}
function Get-CurrentDomain {
    <#
        .SYNOPSIS
        Use ADSI to get the current domain
        .DESCRIPTION
        Works only on domain-joined systems, otherwise returns nothing
        .INPUTS
        None. Pipeline input is not accepted.
        .OUTPUTS
        [System.DirectoryServices.DirectoryEntry] The current domain

        .EXAMPLE
        Get-CurrentDomain

        Get the domain of the current computer
    #>
    [OutputType([System.DirectoryServices.DirectoryEntry])]
    $Obj = [adsi]::new()
    try { $null = $Obj.RefreshCache('objectSid') } catch { return }
    return $Obj
}
function Get-DirectoryEntry {
    <#
        .SYNOPSIS
        Use Active Directory Service Interfaces to retrieve an object from a directory
        .DESCRIPTION
        Retrieve a directory entry using either the WinNT or LDAP provider for ADSI
        .INPUTS
        None. Pipeline input is not accepted.
        .OUTPUTS
        [System.DirectoryServices.DirectoryEntry] where possible
        [PSCustomObject] for security principals with no directory entry
        .EXAMPLE
        Get-DirectoryEntry
        distinguishedName : {DC=ad,DC=contoso,DC=com}
        Path : LDAP://DC=ad,DC=contoso,DC=com

        As the current user on a domain-joined computer, bind to the current domain and retrieve the DirectoryEntry for the root of the domain
        .EXAMPLE
        Get-DirectoryEntry
        distinguishedName :
        Path : WinNT://ComputerName

        As the current user on a workgroup computer, bind to the local system and retrieve the DirectoryEntry for the root of the directory
    #>
    [OutputType([System.DirectoryServices.DirectoryEntry], [PSCustomObject])]
    [CmdletBinding()]
    param (

        <#
        Path to the directory object to retrieve
        Defaults to the root of the current domain
        #>
        [string]$DirectoryPath = (([System.DirectoryServices.DirectorySearcher]::new()).SearchRoot.Path),

        <#
        Credentials to use to bind to the directory
        Defaults to the credentials of the current user
        #>
        [pscredential]$Credential,

        # Properties of the target object to retrieve
        [string[]]$PropertiesToLoad,

        <#
        Hashtable containing cached directory entries so they don't have to be retrieved from the directory again
        Uses a thread-safe hashtable by default
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    $LoggingParams = @{
        ThisHostname = $ThisHostname
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    $DirectoryEntry = $null
    if ($null -eq $DirectoryEntryCache[$DirectoryPath]) {
        switch -regex ($DirectoryPath) {
            <#
            The WinNT provider only throws an error if you try to retrieve certain accounts/identities
            We will create own dummy objects instead of performing the query
            #>
            '^WinNT:\/\/.*\/CREATOR OWNER$' {
                $DirectoryEntry = New-FakeDirectoryEntry -DirectoryPath $DirectoryPath
            }
            '^WinNT:\/\/.*\/SYSTEM$' {
                $DirectoryEntry = New-FakeDirectoryEntry -DirectoryPath $DirectoryPath
            }
            '^WinNT:\/\/.*\/INTERACTIVE$' {
                $DirectoryEntry = New-FakeDirectoryEntry -DirectoryPath $DirectoryPath
            }
            '^WinNT:\/\/.*\/Authenticated Users$' {
                $DirectoryEntry = New-FakeDirectoryEntry -DirectoryPath $DirectoryPath
            }
            '^WinNT:\/\/.*\/TrustedInstaller$' {
                $DirectoryEntry = New-FakeDirectoryEntry -DirectoryPath $DirectoryPath
            }
            # Workgroup computers do not return a DirectoryEntry with a SearchRoot Path so this ends up being an empty string
            # This is also invoked when DirectoryPath is null for any reason
            # We will return a WinNT object representing the local computer's WinNT directory
            '^$' {
                Write-LogMsg @LogParams -Text "$ThisHostname does not appear to be domain-joined since the SearchRoot Path is empty. Defaulting to WinNT provider for localhost instead."
                $Workgroup = (Get-CimInstance -ClassName Win32_ComputerSystem).Workgroup
                $DirectoryPath = "WinNT://$Workgroup/$ThisHostname"
                Write-LogMsg @LogParams -Text "[System.DirectoryServices.DirectoryEntry]::new('$DirectoryPath')"
                if ($Credential) {
                    $DirectoryEntry = [System.DirectoryServices.DirectoryEntry]::new($DirectoryPath, $($Credential.UserName), $($Credential.GetNetworkCredential().password))
                } else {
                    $DirectoryEntry = [System.DirectoryServices.DirectoryEntry]::new($DirectoryPath)
                }

                $SampleUser = $DirectoryEntry.PSBase.Children |
                Where-Object -FilterScript { $_.schemaclassname -eq 'user' } |
                Select-Object -First 1 |
                Add-SidInfo -DomainsBySid $DomainsBySid @LoggingParams

                $DirectoryEntry |
                Add-Member -MemberType NoteProperty -Name 'Domain' -Value $SampleUser.Domain -Force

            }
            # Otherwise the DirectoryPath is an LDAP path or a WinNT path (treated the same at this stage)
            default {

                Write-LogMsg @LogParams -Text "[System.DirectoryServices.DirectoryEntry]::new('$DirectoryPath')"
                if ($Credential) {
                    $DirectoryEntry = [System.DirectoryServices.DirectoryEntry]::new($DirectoryPath, $($Credential.UserName), $($Credential.GetNetworkCredential().password))
                } else {
                    $DirectoryEntry = [System.DirectoryServices.DirectoryEntry]::new($DirectoryPath)
                }

            }

        }

        $DirectoryEntryCache[$DirectoryPath] = $DirectoryEntry
    } else {
        #Write-LogMsg @LogParams -Text "DirectoryEntryCache hit for '$DirectoryPath'"
        $DirectoryEntry = $DirectoryEntryCache[$DirectoryPath]
    }

    if ($PropertiesToLoad) {
        try {
            # If the $DirectoryPath was invalid, this line will return an error
            $null = $DirectoryEntry.RefreshCache($PropertiesToLoad)

        } catch {
            Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tGet-DirectoryEntry`t'$DirectoryPath' could not be retrieved."

            # Ensure that the error message appears on 1 line
            # Use .Trim() to remove leading and trailing whitespace
            # Use -replace to remove an errant line break in the following specific error I encountered: The following exception occurred while retrieving member "RefreshCache": "The group name could not be found.`r`n"
            Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tGet-DirectoryEntry`t'$($_.Exception.Message.Trim() -replace '\s"',' "')"
            return
        }
    }
    return $DirectoryEntry

}
function Get-ParentDomainDnsName {
    param (

        # NetBIOS name of the domain whose parent domain DNS to return
        [string]$DomainNetbios,

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages,

        # Existing CIM session to the computer (to avoid creating redundant CIM sessions)
        [CimSession]$CimSession
    )

    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    if (-not $CimSession) {
        Write-LogMsg @LogParams -Text "New-AdsiServerCimSession -ComputerName '$DomainNetbios'"
        $CimSession = New-AdsiServerCimSession -ComputerName $DomainNetbios -ThisFqdn $ThisFqdn @LoggingParams
        $RemoveCimSession = $true
    }

    Write-LogMsg @LogParams -Text "(Get-CimInstance -CimSession `$CimSession -ClassName CIM_ComputerSystem).domain # for '$DomainNetbios'"
    $ParentDomainDnsName = (Get-CimInstance -CimSession $CimSession -ClassName CIM_ComputerSystem).domain

    if ($ParentDomainDnsName -eq 'WORKGROUP' -or $null -eq $ParentDomainDnsName) {
        # For workgroup computers there is no parent domain DNS (workgroups operate on NetBIOS)
        # There could also be unexpeted scenarios where the parent domain DNS is null
        # In all of these cases, we will use the primary DNS search suffix (that is where the OS would attempt to register DNS records for the computer)
        Write-LogMsg @LogParams -Text "(Get-DnsClientGlobalSetting -CimSession `$CimSession).SuffixSearchList[0] # for '$DomainNetbios'"
        $ParentDomainDnsName = (Get-DnsClientGlobalSetting -CimSession $CimSession).SuffixSearchList[0]
    }

    if ($RemoveCimSession) {
        Remove-CimSession -CimSession $CimSession
    }

    return $ParentDomainDnsName
}
function Get-TrustedDomain {
    <#
        .SYNOPSIS
        Returns a dictionary of trusted domains by the current computer
        .DESCRIPTION
        Works only on domain-joined systems
        Use nltest to get the domain trust relationships for the domain of the current computer
        Use ADSI's LDAP provider to get each trusted domain's DNS name, NETBIOS name, and SID
        For each trusted domain the key is the domain's SID, or its NETBIOS name if the -KeyByNetbios switch parameter was used
        For each trusted domain the value contains the details retrieved with ADSI
        .INPUTS
        None. Pipeline input is not accepted.
        .OUTPUTS
        [PSCustomObject] One object per trusted domain, each with a DomainFqdn property and a DomainNetbios property

        .EXAMPLE
        Get-TrustedDomain

        Get the trusted domains of the current computer
        .NOTES
    #>
    [OutputType([PSCustomObject])]
    param (

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        $ThisHostname = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    # Redirect the error stream to null, errors are expected on non-domain-joined systems
    Write-LogMsg @LogParams -Text "$('& nltest /domain_trusts 2> $null')"
    $nltestresults = & nltest /domain_trusts 2> $null
    $NlTestRegEx = '[\d]*: .*'
    $TrustRelationships = $nltestresults -match $NlTestRegEx

    $RegExForEachTrust = '(?<index>[\d]*): (?<netbios>\S*) (?<dns>\S*).*'
    foreach ($TrustRelationship in $TrustRelationships) {
        if ($TrustRelationship -match $RegExForEachTrust) {
            [PSCustomObject]@{
                DomainFqdn    = $Matches.dns
                DomainNetbios = $Matches.netbios
            }
        } else {
            continue
        }
    }
}
function Get-Win32Account {
    <#
        .SYNOPSIS
        Use CIM to get well-known SIDs
        .DESCRIPTION
        Use WinRM to query the CIM namespace root/cimv2 for instances of the Win32_Account class
        .INPUTS
        [System.String]$ComputerName
        .OUTPUTS
        [Microsoft.Management.Infrastructure.CimInstance] for each instance of the Win32_Account class in the root/cimv2 namespace
        .EXAMPLE
        Get-Win32Account

        Get the well-known SIDs on the current computer
        .EXAMPLE
        Get-Win32Account -CimServerName 'server123'

        Get the well-known SIDs on the remote computer 'server123'
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param (

        # Name or address of the computer whose Win32_Account instances to return
        [Parameter(ValueFromPipeline)]
        [string[]]$ComputerName,

        # Cache of known Win32_Account instances keyed by domain and SID
        [hashtable]$Win32AccountsBySID = ([hashtable]::Synchronized(@{})),

        # Cache of known Win32_Account instances keyed by domain (e.g. CONTOSO) and Caption (NTAccount name e.g. CONTOSO\User1)
        [hashtable]$Win32AccountsByCaption = ([hashtable]::Synchronized(@{})),

        # Cache of known directory servers to reduce duplicate queries
        [hashtable]$AdsiServersByDns = [hashtable]::Synchronized(@{}),

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        <#
        AdsiProvider (WinNT or LDAP) of the servers associated with the provided FQDNs or NetBIOS names

        This parameter can be used to reduce calls to Find-AdsiProvider

        Useful when that has been done already but the DomainsByFqdn and DomainsByNetbios caches have not been updated yet
        #>
        [string]$AdsiProvider,

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages,

        # Existing CIM session to the computer (to avoid creating redundant CIM sessions)
        [CimSession]$CimSession

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $LoggingParams = @{
            ThisHostname = $ThisHostname
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $AdsiServersWhoseWin32AccountsExistInCache = $Win32AccountsBySID.Keys |
        ForEach-Object { ($_ -split '\\')[0] } |
        Sort-Object -Unique
    }
    process {
        ForEach ($ThisServer in $ComputerName) {
            if (
                $ThisServer -eq 'localhost' -or
                $ThisServer -eq '127.0.0.1' -or
                [string]::IsNullOrEmpty($ThisServer)
            ) {
                $ThisServer = $ThisHostName
            }
            if (-not $PSBoundParameters.ContainsKey('AdsiProvider')) {
                $AdsiProvider = Find-AdsiProvider -AdsiServer $ThisServer @LoggingParams
            }
            # Return matching objects from the cache if possible rather than performing a CIM query
            # The cache is based on the Caption of the Win32 accounts which conatins only NetBios names
            if ($AdsiServersWhoseWin32AccountsExistInCache -contains $ThisServer) {
                $Win32AccountsBySID.Keys |
                ForEach-Object {
                    if ($_ -like "$ThisServer\*") {
                        $Win32AccountsBySID[$_]
                    }
                }
            } else {

                if (-not $CimSession) {
                    Write-LogMsg @LogParams -Text "New-AdsiServerCimSession -ComputerName '$ThisServer'"
                    $CimSession = New-AdsiServerCimSession -ComputerName $ThisServer -ThisFqdn $ThisFqdn @LoggingParams
                    $RemoveCimSession = $true
                }

                Write-LogMsg @LogParams -Text "Get-CimInstance -ClassName Win32_Account -CimSession `$CimSession # For '$ThisServer'"
                Get-CimInstance -ClassName Win32_Account -CimSession $CimSession

                if ($RemoveCimSession) {
                    Remove-CimSession -CimSession $CimSession
                }

            }
        }
    }
}
function Get-Win32UserAccount {
    param (
        [string]$ComputerName,

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages
    )

    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    if (
        $ComputerName -eq $ThisHostname -or
        $ComputerName -eq "$ThisHostname." -or
        $ComputerName -eq $ThisFqdn
    ) {
        Write-LogMsg @LogParams -Text "Get-CimInstance -Query `"SELECT SID FROM Win32_UserAccount WHERE LocalAccount = 'True'`""
        Get-CimInstance -Query "SELECT SID FROM Win32_UserAccount WHERE LocalAccount = 'True'"
    } else {
        Write-LogMsg @LogParams -Text "Get-CimInstance -ComputerName $ComputerName -Query `"SELECT SID FROM Win32_UserAccount WHERE LocalAccount = 'True'`""
        # If an Active Directory domain is targeted there are no local accounts and CIM connectivity is not expected
        # Suppress errors and return nothing in that case
        Get-CimInstance -ComputerName $ComputerName -Query "SELECT SID FROM Win32_UserAccount WHERE LocalAccount = 'True'" -ErrorAction SilentlyContinue
    }
}
function Get-WinNTGroupMember {
    <#
        .SYNOPSIS
        Get members of a group from the WinNT provider
        .DESCRIPTION
        Get members of a group from the WinNT provider
        Convert them from COM objects into usable DirectoryEntry objects
        .INPUTS
        [System.DirectoryServices.DirectoryEntry]$DirectoryEntry
        .OUTPUTS
        [System.DirectoryServices.DirectoryEntry] for each group member
        .EXAMPLE
        [System.DirectoryServices.DirectoryEntry]::new('WinNT://localhost/Administrators') | Get-WinNTGroupMember

        Get members of the local Administrators group
    #>
    [OutputType([System.DirectoryServices.DirectoryEntry])]
    param (

        # DirectoryEntry [System.DirectoryServices.DirectoryEntry] of the WinNT group whose members to get
        [Parameter(ValueFromPipeline)]
        $DirectoryEntry,

        # Properties of the group members to find in the directory
        [string[]]$PropertiesToLoad,

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $LoggingParams = @{
            ThisHostname = $ThisHostname
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $PropertiesToLoad += 'Department',
        'description',
        'distinguishedName',
        'grouptype',
        'managedby',
        'member',
        'name',
        'objectClass',
        'objectSid',
        'operatingSystem',
        'primaryGroupToken',
        'samAccountName',
        'Title'

        $PropertiesToLoad = $PropertiesToLoad |
        Sort-Object -Unique

    }
    process {
        ForEach ($ThisDirEntry in $DirectoryEntry) {
            $SourceDomain = $ThisDirEntry.Path | Split-Path -Parent | Split-Path -Leaf
            # Retrieve the members of local groups
            if ($null -ne $ThisDirEntry.Properties['groupType'] -or $ThisDirEntry.schemaclassname -eq 'group') {
                # Assembly: System.DirectoryServices.dll
                # Namespace: System.DirectoryServices
                # DirectoryEntry.Invoke(String, Object[]) Method
                # Calls a method on the native Active Directory Domain Services object
                # https://docs.microsoft.com/en-us/dotnet/api/system.directoryservices.directoryentry.invoke?view=dotnet-plat-ext-6.0

                # I am using it to call the IADsGroup::Members method
                # The IADsGroup programming interface is part of the iads.h header
                # The iads.h header is part of the ADSI component of the Win32 API
                # The IADsGroup::Members method retrieves a collection of the immediate members of the group.
                # The collection does not include the members of other groups that are nested within the group.
                # The default implementation of this method uses LsaLookupSids to query name information for the group members.
                # LsaLookupSids has a maximum limitation of 20480 SIDs it can convert, therefore that limitation also applies to this method.
                # Returns a pointer to an IADsMembers interface pointer that receives the collection of group members. The caller must release this interface when it is no longer required.
                # https://docs.microsoft.com/en-us/windows/win32/api/iads/nf-iads-iadsgroup-members
                # The IADsMembers::Members method would use the same provider but I have chosen not to implement that here
                # Recursion through nested groups can be handled outside of Get-WinNTGroupMember for now
                # Maybe that could be a feature in the future
                # https://docs.microsoft.com/en-us/windows/win32/adsi/adsi-object-model-for-winnt-providers?redirectedfrom=MSDN
                $DirectoryMembers = & { $ThisDirEntry.Invoke('Members') } 2>$null
                Write-LogMsg @LogParams -Text " # '$($ThisDirEntry.Path)' has $(($DirectoryMembers | Measure-Object).Count) members # For $($ThisDirEntry.Path)"
                $MembersToGet = @{
                    'WinNTMembers' = @()
                }
                $MemberParams = @{
                    DirectoryEntryCache = $DirectoryEntryCache
                    PropertiesToLoad    = $PropertiesToLoad
                    DomainsByNetbios    = $DomainsByNetbios
                    LogMsgCache         = $LogMsgCache
                    WhoAmI              = $WhoAmI
                }
                ForEach ($DirectoryMember in $DirectoryMembers) {
                    # The IADsGroup::Members method returns ComObjects
                    # But proper .Net objects are much easier to work with
                    # So we will convert the ComObjects into DirectoryEntry objects
                    $DirectoryPath = Invoke-ComObject -ComObject $DirectoryMember -Property 'ADsPath'
                    $MemberDomainDn = $null
                    if ($DirectoryPath -match 'WinNT:\/\/(?<Domain>[^\/]*)\/(?<Acct>.*$)') {
                        Write-LogMsg @LogParams -Text " # '$DirectoryPath' has a domain of '$($Matches.Domain)' and an account name of '$($Matches.Acct)'"
                        $MemberName = $Matches.Acct
                        $MemberDomainNetbios = $Matches.Domain

                        $DomainCacheResult = $DomainsByNetbios[$MemberDomainNetbios]
                        if ($DomainCacheResult) {
                            Write-LogMsg @LogParams -Text " # Domain NetBIOS cache hit for '$MemberDomainNetBios'"
                            if ( "WinNT:\\$MemberDomainNetbios" -ne $SourceDomain ) {
                                $MemberDomainDn = $DomainCacheResult.DistinguishedName
                            }
                        } else {
                            Write-LogMsg @LogParams -Text " # Domain NetBIOS cache miss for '$MemberDomainNetBios'. Available keys: $($DomainsByNetBios.Keys -join ',')"
                        }
                        if ($DirectoryPath -match 'WinNT:\/\/(?<Domain>[^\/]*)\/(?<Middle>[^\/]*)\/(?<Acct>.*$)') {
                            Write-LogMsg @LogParams -Text " # '$DirectoryPath' came from an ADSI server joined to the domain of '$($Matches.Domain)' but its domain is '$($Matches.Middle)' and its name is '$($Matches.Acct)'"
                            if ($Matches.Middle -eq ($ThisDirEntry.Path | Split-Path -Parent | Split-Path -Leaf)) {
                                $MemberDomainDn = $null
                            }
                        }
                    } else {
                        Write-LogMsg @LogParams -Text " # '$DirectoryPath' does not match 'WinNT:\/\/(?<Domain>[^\/]*)\/(?<Acct>.*$)'"
                    }

                    # LDAP directories have a distinguishedName
                    if ($MemberDomainDn) {
                        # LDAP directories support searching
                        # Combine all members' samAccountNames into a single search per directory distinguishedName
                        # Use a hashtable with the directory path as the key and a string as the definition
                        # The string is a partial LDAP filter, just the segments of the LDAP filter for each samAccountName
                        Write-LogMsg @LogParams -Text " # '$MemberName' is a domain security principal"
                        $MembersToGet["LDAP://$MemberDomainDn"] += "(samaccountname=$MemberName)"
                        ##$MemberParams['DirectoryPath'] = "LDAP://$MemberDomainDn"
                        ##$MemberParams['Filter'] = "(samaccountname=$MemberName)"
                        ##$MemberDirectoryEntry = Search-Directory @MemberParams
                    } else {
                        # WinNT directories do not support searching so we will retrieve each member individually
                        # Use a hashtable with 'WinNTMembers' as the key and an array of WinNT directory paths as the value
                        Write-LogMsg @LogParams -Text " # '$DirectoryPath' is a local security principal"
                        $MembersToGet['WinNTMembers'] = $DirectoryPath
                        ##$MemberDirectoryEntry = Get-DirectoryEntry @MemberParams
                    }

                    ##Expand-WinNTGroupMember -DirectoryEntry $MemberDirectoryEntry -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams

                }

                # Get and Expand the directory entries for the WinNT group members
                $MembersToGet['WinNTMembers'] |
                ForEach-Object {
                    $MemberParams['DirectoryPath'] = $_
                    Write-LogMsg @LogParams -Text "Get-DirectoryEntry -DirectoryPath '$DirectoryPath'"
                    $MemberDirectoryEntry = Get-DirectoryEntry @MemberParams
                    Expand-WinNTGroupMember -DirectoryEntry $MemberDirectoryEntry -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams
                }

                # Remove the WinNTMembers key from the hashtable so the only remaining keys are distinguishedName(s) of LDAP directories
                $MembersToGet.Remove('WinNTMembers')

                # Get and Expand the directory entries for the LDAP group members
                $MembersToGet.Keys |
                ForEach-Object {
                    $MemberParams['DirectoryPath'] = $_
                    $MemberParams['Filter'] = "(|$($MembersToGet[$_]))"
                    $MemberDirectoryEntries = Search-Directory @MemberParams
                    Expand-WinNTGroupMember -DirectoryEntry $MemberDirectoryEntries -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams
                }
            } else {
                Write-LogMsg @LogParams -Text " # '$($ThisDirEntry.Path)' is not a group"
            }
        }
    }

}
function Invoke-ComObject {
    <#
        .SYNOPSIS
        Invoke a member method of a ComObject [__ComObject]
        .DESCRIPTION
        Use the InvokeMember method to invoke the InvokeMethod or GetProperty or SetProperty methods
        By default, invokes the GetProperty method for the specified Property
        If the Value parameter is specified, invokes the SetProperty method for the specified Property
        If the Method switch is specified, invokes the InvokeMethod method
        .INPUTS
        None. Pipeline input is not accepted.
        .OUTPUTS
        The output of the invoked method is returned directly
        .EXAMPLE
        $ComObject = [System.DirectoryServices.DirectoryEntry]::new('WinNT://localhost/Administrators').Invoke('Members') | Select -First 1
        Invoke-ComObject -ComObject $ComObject -Property AdsPath

        Get the first member of the local Administrators group on the current computer
        Then use Invoke-ComObject to invoke the GetProperty method and return the value of the AdsPath property
    #>
    param (

        # The ComObject whose member method to invoke
        [Parameter(Mandatory)]
        $ComObject,

        # The property to use with the invoked method
        [Parameter(Mandatory)]
        [String]$Property,

        # The value to set with the SetProperty method, or the name of the method to run with the InvokeMethod method
        $Value,

        # Use the InvokeMethod method of the ComObject
        [Switch]$Method

    )
    <#
    # Don't remember what this is for
    If ($ComObject -IsNot "__ComObject") {
        If (!$ComInvoke) {
            $Global:ComInvoke = @{}
        }
        If (!$ComInvoke.$ComObject) {
            $ComInvoke.$ComObject = New-Object -ComObject $ComObject
        }
        $ComObject = $ComInvoke.$ComObject
    }
    #>
    If ($Method) {
        $Invoke = "InvokeMethod"
    } ElseIf ($MyInvocation.BoundParameters.ContainsKey("Value")) {
        $Invoke = "SetProperty"
    } Else {
        $Invoke = "GetProperty"
    }
    [__ComObject].InvokeMember($Property, $Invoke, $Null, $ComObject, $Value)
}
function New-AdsiServerCimSession {
    param (

        # Name of the computer to start a CIM session on
        [string]$ComputerName,

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages
    )

    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }


    if (
        $ComputerName -eq $ThisHostName -or
        $ComputerName -eq 'localhost' -or
        $ComputerName -eq '127.0.0.1' -or
        $ComputerName -eq $ThisFqdn -or
        [string]::IsNullOrEmpty($ComputerName)
    ) {
        Write-LogMsg @LogParams -Text "`$CimSession = New-CimSession # for '$ComputerName'"
        New-CimSession
    } else {
        Write-LogMsg @LogParams -Text "`$CimSession = New-CimSession -ComputerName '$ComputerName'"
        New-CimSession -ComputerName $ComputerName
    }

}
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
function Resolve-Ace {
    <#
        .SYNOPSIS
        Use ADSI to lookup info about IdentityReferences from Authorization Rule Collections that came from Discretionary Access Control Lists
        .DESCRIPTION
        Based on the IdentityReference proprety of each Access Control Entry:
        Resolve SID to NT account name and vise-versa
        Resolve well-known SIDs
        Resolve generic defaults like 'NT AUTHORITY' and 'BUILTIN' to the applicable computer or domain name
        Add these properties (IdentityReferenceSID,IdentityReferenceName,IdentityReferenceResolved) to the object and return it
        .INPUTS
        [System.Security.AccessControl.AuthorizationRuleCollection]$InputObject
        .OUTPUTS
        [PSCustomObject] Original object plus IdentityReferenceSID,IdentityReferenceName,IdentityReferenceResolved, and AdsiProvider properties
        .EXAMPLE
        Get-Acl |
        Expand-Acl |
        Resolve-Ace

        Use Get-Acl from the Microsoft.PowerShell.Security module as the source of the access list
        This works in either Windows Powershell or in Powershell
        Get-Acl does not support long paths (>256 characters)
        That was why I originally used the .Net Framework method
        .EXAMPLE
        Get-FolderAce -LiteralPath C:\Test -IncludeInherited |
        Resolve-Ace
        .EXAMPLE
        [System.String]$FolderPath = 'C:\Test'
        [System.IO.DirectoryInfo]$DirectoryInfo = Get-Item -LiteralPath $FolderPath
        $Sections = [System.Security.AccessControl.AccessControlSections]::Access -bor [System.Security.AccessControl.AccessControlSections]::Owner
        $FileSecurity = [System.Security.AccessControl.FileSecurity]::new($DirectoryInfo,$Sections)
        $IncludeExplicitRules = $true
        $IncludeInheritedRules = $true
        $AccountType = [System.Security.Principal.SecurityIdentifier]
        $FileSecurity.GetAccessRules($IncludeExplicitRules,$IncludeInheritedRules,$AccountType) |
        Resolve-Ace

        This uses .Net Core as the source of the access list
        It uses the GetAccessRules method on the [System.Security.AccessControl.FileSecurity] class
        The targetType parameter of the method is used to specify that the accounts in the ACL are returned as SIDs
        .EXAMPLE
        [System.String]$FolderPath = 'C:\Test'
        [System.IO.DirectoryInfo]$DirectoryInfo = Get-Item -LiteralPath $FolderPath
        $Sections = [System.Security.AccessControl.AccessControlSections]::Access -bor
        [System.Security.AccessControl.AccessControlSections]::Owner -bor
        [System.Security.AccessControl.AccessControlSections]::Group
        $DirectorySecurity = [System.Security.AccessControl.DirectorySecurity]::new($DirectoryInfo,$Sections)
        $IncludeExplicitRules = $true
        $IncludeInheritedRules = $true
        $AccountType = [System.Security.Principal.NTAccount]
        $FileSecurity.GetAccessRules($IncludeExplicitRules,$IncludeInheritedRules,$AccountType) |
        Resolve-Ace

        This uses .Net Core as the source of the access list
        It uses the GetAccessRules method on the [System.Security.AccessControl.FileSecurity] class
        The targetType parameter of the method is used to specify that the accounts in the ACL are returned as NT account names (DOMAIN\User)
        .EXAMPLE
        [System.String]$FolderPath = 'C:\Test'
        [System.IO.DirectoryInfo]$DirectoryInfo = Get-Item -LiteralPath $FolderPath
        [System.Security.AccessControl.DirectorySecurity]$DirectorySecurity = $DirectoryInfo.GetAccessControl('Access')
        [System.Security.AccessControl.AuthorizationRuleCollection]$AuthRules = $DirectorySecurity.Access
        $AuthRules | Resolve-Ace

        Use the .Net Framework (or legacy .Net Core up to 2.2) as the source of the access list
        Only works in Windows PowerShell
        Those versions of .Net had a GetAccessControl method on the [System.IO.DirectoryInfo] class
        This method is removed in modern versions of .Net Core

        .EXAMPLE
        [System.String]$FolderPath = 'C:\Test'
        [System.IO.DirectoryInfo]$DirectoryInfo = Get-Item -LiteralPath $FolderPath
        $Sections = [System.Security.AccessControl.AccessControlSections]::Access -bor [System.Security.AccessControl.AccessControlSections]::Owner
        $FileSecurity = [System.IO.FileSystemAclExtensions]::GetAccessControl($DirectoryInfo,$Sections)

        The [System.IO.FileSystemAclExtensions] class is a Windows-specific implementation
        It provides no known benefit over the cross-platform equivalent [System.Security.AccessControl.FileSecurity]

        .NOTES
        Dependencies:
            Get-DirectoryEntry
            Add-SidInfo
            Get-TrustedDomain
            Find-AdsiProvider

        if ($FolderPath.Length -gt 255) {
            $FolderPath = "\\?\$FolderPath"
        }
    #>
    [OutputType([PSCustomObject])]
    param (

        # Authorization Rule Collection of Access Control Entries from Discretionary Access Control Lists
        [Parameter(
            ValueFromPipeline
        )]
        [PSObject[]]$InputObject,

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        [hashtable]$Win32AccountsBySID = ([hashtable]::Synchronized(@{})),

        [hashtable]$Win32AccountsByCaption = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $LoggingParams = @{
            ThisHostname = $ThisHostname
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

    }

    process {

        $ACEPropertyNames = (Get-Member -InputObject $InputObject[0] -MemberType Property, CodeProperty, ScriptProperty, NoteProperty).Name
        ForEach ($ThisACE in $InputObject) {

            $IdentityReference = $ThisACE.IdentityReference.ToString()

            if ([string]::IsNullOrEmpty($IdentityReference)) {
                continue
            }

            $ThisServerDns = $null
            $DomainNetBios = $null

            # Remove the PsProvider prefix from the path string
            if (-not [string]::IsNullOrEmpty($ThisACE.SourceAccessList.Path)) {
                $LiteralPath = $ThisACE.SourceAccessList.Path -replace [regex]::escape("$($ThisACE.SourceAccessList.PsProvider)::"), ''
            } else {
                $LiteralPath = $LiteralPath -replace [regex]::escape("$($ThisACE.SourceAccessList.PsProvider)::"), ''
            }

            switch -Wildcard ($IdentityReference) {
                "S-1-*" {
                    # IdentityReference is a SID (Revision 1)
                    Write-LogMsg @LogParams -Text "'$IdentityReference'.LastIndexOf('-')"
                    $IndexOfLastHyphen = $IdentityReference.LastIndexOf("-")
                    Write-LogMsg @LogParams -Text "'$IdentityReference'.Substring(0, $IndexOfLastHyphen)"
                    $DomainSid = $IdentityReference.Substring(0, $IndexOfLastHyphen)
                    if ($DomainSid) {
                        $DomainCacheResult = $DomainsBySID[$DomainSid]
                        if ($DomainCacheResult) {
                            Write-LogMsg @LogParams -Text " # Domain SID cache hit for '$DomainSid' for '$IdentityReference'"
                            $ThisServerDns = $DomainCacheResult.Dns
                            $DomainNetBios = $DomainCacheResult.Netbios
                        } else {
                            Write-LogMsg @LogParams -Text " # Domain SID cache miss for '$DomainSid' for '$IdentityReference'"
                        }
                    }
                }
                "NT SERVICE\*" {
                    $ThisServerDns = Find-ServerNameInPath -LiteralPath $LiteralPath
                }
                "BUILTIN\*" {
                    $ThisServerDns = Find-ServerNameInPath -LiteralPath $LiteralPath
                }
                "NT AUTHORITY\*" {
                    $ThisServerDns = Find-ServerNameInPath -LiteralPath $LiteralPath
                }
                default {
                    $DomainNetBios = ($IdentityReference -split '\\')[0]
                    if ($DomainNetBios) {
                        $ThisServerDns = $DomainsByNetbios[$DomainNetBios].Dns #Doesn't work for BUILTIN, etc.
                    }
                    if (-not $ThisServerDns) {
                        $ThisServerDn = ConvertTo-DistinguishedName -Domain $DomainNetBios -DomainsByNetbios $DomainsByNetbios @LoggingParams
                        $ThisServerDns = ConvertTo-Fqdn -DistinguishedName $ThisServerDn -ThisFqdn $ThisFqdn @LoggingParams
                    }
                }
            }

            if (-not $ThisServerDns) {
                # Bug: I think this will report incorrectly for a remote domain not in the cache (trust broken or something)
                $ThisServerDns = Find-ServerNameInPath -LiteralPath $LiteralPath
            }
            Write-LogMsg @LogParams -Text " # Domain FQDN is '$ThisServerDns' for '$IdentityReference'"

            $GetAdsiServerParams = @{
                Fqdn                   = $ThisServerDns
                Win32AccountsBySID     = $Win32AccountsBySID
                Win32AccountsByCaption = $Win32AccountsByCaption
                DirectoryEntryCache    = $DirectoryEntryCache
                DomainsByFqdn          = $DomainsByFqdn
                DomainsByNetbios       = $DomainsByNetbios
                DomainsBySid           = $DomainsBySid
                ThisHostName           = $ThisHostName
                ThisFqdn               = $ThisFqdn
                LogMsgCache            = $LogMsgCache
                WhoAmI                 = $WhoAmI
            }
            $AdsiServer = Get-AdsiServer @GetAdsiServerParams
            Write-LogMsg @LogParams -Text " # ADSI server is '$($AdsiServer.AdsiProvider)://$($AdsiServer.Dns)' for '$IdentityReference'"

            if ([string]$DomainNetBios -eq '') {
                $DomainNetBios = $AdsiServer.Netbios
            }

            Write-LogMsg @LogParams -Text " # Domain NetBIOS is '$DomainNetBios' for '$IdentityReference'"

            <#
            $AdsiProvider = $null
            if (-not $DomainNetBios) {
                $DomainCacheResult = $DomainsByFqdn[$ThisServerDns]
                if ($DomainCacheResult) {
                    Write-LogMsg @LogParams -Text " # Domain FQDN cache hit for '$ThisServerDns'"
                    $DomainNetBios = $DomainCacheResult.Netbios
                    $AdsiProvider = $DomainCacheResult.AdsiProvider
                } else {
                    Write-LogMsg @LogParams -Text " # Domain FQDN cache miss for '$ThisServerDns'"
                }
            }

            if (-not $DomainNetBios) {
                if (-not $AdsiProvider) {
                    $AdsiProvider = Find-AdsiProvider -AdsiServer $ThisServerDns
                }
                $DomainNetBios = ConvertTo-DomainNetBIOS -DomainFQDN $ThisServerDns -AdsiProvider $AdsiProvider -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid
            }
            #>

            $ResolveIdentityReferenceParams = @{
                IdentityReference      = $IdentityReference
                AdsiServer             = $AdsiServer
                Win32AccountsBySID     = $Win32AccountsBySID
                Win32AccountsByCaption = $Win32AccountsByCaption
                DirectoryEntryCache    = $DirectoryEntryCache
                DomainsBySID           = $DomainsBySID
                DomainsByNetbios       = $DomainsByNetbios
                DomainsByFqdn          = $DomainsByFqdn
                ThisHostName           = $ThisHostName
                ThisFqdn               = $ThisFqdn
                LogMsgCache            = $LogMsgCache
                WhoAmI                 = $WhoAmI
            }
            Write-LogMsg @LogParams -Text "Resolve-IdentityReference -IdentityReference '$IdentityReference'..."
            $ResolvedIdentityReference = Resolve-IdentityReference @ResolveIdentityReferenceParams

            # not sure if I should add a param to offer DNS instead of NetBIOS

            $ObjectProperties = @{
                AdsiProvider              = $AdsiServer.AdsiProvider
                AdsiServer                = $AdsiServer.Dns
                IdentityReferenceSID      = $ResolvedIdentityReference.SIDString
                IdentityReferenceName     = $ResolvedIdentityReference.IdentityReferenceUnresolved
                IdentityReferenceResolved = $ResolvedIdentityReference.IdentityReferenceNetBios
            }
            ForEach ($ThisProperty in $ACEPropertyNames) {
                $ObjectProperties[$ThisProperty] = $ThisACE.$ThisProperty
            }
            [PSCustomObject]$ObjectProperties

        }

    }

}
function Resolve-Ace3 {
    <#
        .SYNOPSIS
        Use ADSI to lookup info about IdentityReferences from Authorization Rule Collections that came from Discretionary Access Control Lists
        .DESCRIPTION
        Based on the IdentityReference proprety of each Access Control Entry:
        Resolve SID to NT account name and vise-versa
        Resolve well-known SIDs
        Resolve generic defaults like 'NT AUTHORITY' and 'BUILTIN' to the applicable computer or domain name
        Add these properties (IdentityReferenceSID,IdentityReferenceName,IdentityReferenceResolved) to the object and return it
        .INPUTS
        [System.Security.AccessControl.AuthorizationRuleCollection]$InputObject
        .OUTPUTS
        [PSCustomObject] Original object plus IdentityReferenceSID,IdentityReferenceName,IdentityReferenceResolved, and AdsiProvider properties
        .EXAMPLE
        Get-Acl |
        Expand-Acl |
        Resolve-Ace

        Use Get-Acl from the Microsoft.PowerShell.Security module as the source of the access list
        This works in either Windows Powershell or in Powershell
        Get-Acl does not support long paths (>256 characters)
        That was why I originally used the .Net Framework method
        .EXAMPLE
        Get-FolderAce -LiteralPath C:\Test -IncludeInherited |
        Resolve-Ace
        .EXAMPLE
        [System.String]$FolderPath = 'C:\Test'
        [System.IO.DirectoryInfo]$DirectoryInfo = Get-Item -LiteralPath $FolderPath
        $Sections = [System.Security.AccessControl.AccessControlSections]::Access -bor [System.Security.AccessControl.AccessControlSections]::Owner
        $FileSecurity = [System.Security.AccessControl.FileSecurity]::new($DirectoryInfo,$Sections)
        $IncludeExplicitRules = $true
        $IncludeInheritedRules = $true
        $AccountType = [System.Security.Principal.SecurityIdentifier]
        $FileSecurity.GetAccessRules($IncludeExplicitRules,$IncludeInheritedRules,$AccountType) |
        Resolve-Ace

        This uses .Net Core as the source of the access list
        It uses the GetAccessRules method on the [System.Security.AccessControl.FileSecurity] class
        The targetType parameter of the method is used to specify that the accounts in the ACL are returned as SIDs
        .EXAMPLE
        [System.String]$FolderPath = 'C:\Test'
        [System.IO.DirectoryInfo]$DirectoryInfo = Get-Item -LiteralPath $FolderPath
        $Sections = [System.Security.AccessControl.AccessControlSections]::Access -bor
        [System.Security.AccessControl.AccessControlSections]::Owner -bor
        [System.Security.AccessControl.AccessControlSections]::Group
        $DirectorySecurity = [System.Security.AccessControl.DirectorySecurity]::new($DirectoryInfo,$Sections)
        $IncludeExplicitRules = $true
        $IncludeInheritedRules = $true
        $AccountType = [System.Security.Principal.NTAccount]
        $FileSecurity.GetAccessRules($IncludeExplicitRules,$IncludeInheritedRules,$AccountType) |
        Resolve-Ace

        This uses .Net Core as the source of the access list
        It uses the GetAccessRules method on the [System.Security.AccessControl.FileSecurity] class
        The targetType parameter of the method is used to specify that the accounts in the ACL are returned as NT account names (DOMAIN\User)
        .EXAMPLE
        [System.String]$FolderPath = 'C:\Test'
        [System.IO.DirectoryInfo]$DirectoryInfo = Get-Item -LiteralPath $FolderPath
        [System.Security.AccessControl.DirectorySecurity]$DirectorySecurity = $DirectoryInfo.GetAccessControl('Access')
        [System.Security.AccessControl.AuthorizationRuleCollection]$AuthRules = $DirectorySecurity.Access
        $AuthRules | Resolve-Ace

        Use the .Net Framework (or legacy .Net Core up to 2.2) as the source of the access list
        Only works in Windows PowerShell
        Those versions of .Net had a GetAccessControl method on the [System.IO.DirectoryInfo] class
        This method is removed in modern versions of .Net Core

        .EXAMPLE
        [System.String]$FolderPath = 'C:\Test'
        [System.IO.DirectoryInfo]$DirectoryInfo = Get-Item -LiteralPath $FolderPath
        $Sections = [System.Security.AccessControl.AccessControlSections]::Access -bor [System.Security.AccessControl.AccessControlSections]::Owner
        $FileSecurity = [System.IO.FileSystemAclExtensions]::GetAccessControl($DirectoryInfo,$Sections)

        The [System.IO.FileSystemAclExtensions] class is a Windows-specific implementation
        It provides no known benefit over the cross-platform equivalent [System.Security.AccessControl.FileSecurity]

        .NOTES
        Dependencies:
            Get-DirectoryEntry
            Add-SidInfo
            Get-TrustedDomain
            Find-AdsiProvider

        if ($FolderPath.Length -gt 255) {
            $FolderPath = "\\?\$FolderPath"
        }
    #>
    [OutputType([PSCustomObject])]
    param (

        # Authorization Rule Collection of Access Control Entries from Discretionary Access Control Lists
        [Parameter(
            ValueFromPipeline
        )]
        [PSObject[]]$InputObject,

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        [hashtable]$Win32AccountsBySID = ([hashtable]::Synchronized(@{})),

        [hashtable]$Win32AccountsByCaption = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

        $LoggingParams = @{
            ThisHostname = $ThisHostname
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }

    }

    process {

        $ACEPropertyNames = (Get-Member -InputObject $InputObject[0] -MemberType Property, CodeProperty, ScriptProperty, NoteProperty).Name
        ForEach ($ThisACE in $InputObject) {

            $IdentityReference = $ThisACE.IdentityReference.ToString()

            if ([string]::IsNullOrEmpty($IdentityReference)) {
                continue
            }

            $ThisServerDns = $null
            $DomainNetBios = $null

            # Remove the PsProvider prefix from the path string
            if (-not [string]::IsNullOrEmpty($ThisACE.SourceAccessList.Path)) {
                $LiteralPath = $ThisACE.SourceAccessList.Path -replace [regex]::escape("$($ThisACE.SourceAccessList.PsProvider)::"), ''
            } else {
                $LiteralPath = $LiteralPath -replace [regex]::escape("$($ThisACE.SourceAccessList.PsProvider)::"), ''
            }

            switch -Wildcard ($IdentityReference) {
                "S-1-*" {
                    # IdentityReference is a SID (Revision 1)
                    Write-LogMsg @LogParams -Text "'$IdentityReference'.LastIndexOf('-')"
                    $IndexOfLastHyphen = $IdentityReference.LastIndexOf("-")
                    Write-LogMsg @LogParams -Text "'$IdentityReference'.Substring(0, $IndexOfLastHyphen)"
                    $DomainSid = $IdentityReference.Substring(0, $IndexOfLastHyphen)
                    if ($DomainSid) {
                        $DomainCacheResult = $DomainsBySID[$DomainSid]
                        if ($DomainCacheResult) {
                            Write-LogMsg @LogParams -Text " # Domain SID cache hit for '$DomainSid' for '$IdentityReference'"
                            $ThisServerDns = $DomainCacheResult.Dns
                            $DomainNetBios = $DomainCacheResult.Netbios
                        } else {
                            Write-LogMsg @LogParams -Text " # Domain SID cache miss for '$DomainSid' for '$IdentityReference'"
                        }
                    }
                }
                "NT SERVICE\*" {
                    $ThisServerDns = Find-ServerNameInPath -LiteralPath $LiteralPath
                }
                "BUILTIN\*" {
                    $ThisServerDns = Find-ServerNameInPath -LiteralPath $LiteralPath
                }
                "NT AUTHORITY\*" {
                    $ThisServerDns = Find-ServerNameInPath -LiteralPath $LiteralPath
                }
                default {
                    $DomainNetBios = ($IdentityReference -split '\\')[0]
                    if ($DomainNetBios) {
                        $ThisServerDns = $DomainsByNetbios[$DomainNetBios].Dns #Doesn't work for BUILTIN, etc.
                    }
                    if (-not $ThisServerDns) {
                        $ThisServerDn = ConvertTo-DistinguishedName -Domain $DomainNetBios -DomainsByNetbios $DomainsByNetbios @LoggingParams
                        $ThisServerDns = ConvertTo-Fqdn -DistinguishedName $ThisServerDn -ThisFqdn $ThisFqdn @LoggingParams
                    }
                }
            }

            if (-not $ThisServerDns) {
                # Bug: I think this will report incorrectly for a remote domain not in the cache (trust broken or something)
                $ThisServerDns = Find-ServerNameInPath -LiteralPath $LiteralPath
            }
            Write-LogMsg @LogParams -Text " # Domain FQDN is '$ThisServerDns' for '$IdentityReference'"

            $GetAdsiServerParams = @{
                Fqdn                   = $ThisServerDns
                Win32AccountsBySID     = $Win32AccountsBySID
                Win32AccountsByCaption = $Win32AccountsByCaption
                DirectoryEntryCache    = $DirectoryEntryCache
                DomainsByFqdn          = $DomainsByFqdn
                DomainsByNetbios       = $DomainsByNetbios
                DomainsBySid           = $DomainsBySid
                ThisHostName           = $ThisHostName
                ThisFqdn               = $ThisFqdn
                LogMsgCache            = $LogMsgCache
                WhoAmI                 = $WhoAmI
            }
            $AdsiServer = Get-AdsiServer @GetAdsiServerParams
            Write-LogMsg @LogParams -Text " # ADSI server is '$($AdsiServer.AdsiProvider)://$($AdsiServer.Dns)' for '$IdentityReference'"

            if ([string]$DomainNetBios -eq '') {
                $DomainNetBios = $AdsiServer.Netbios
            }

            Write-LogMsg @LogParams -Text " # Domain NetBIOS is '$DomainNetBios' for '$IdentityReference'"

            <#
            $AdsiProvider = $null
            if (-not $DomainNetBios) {
                $DomainCacheResult = $DomainsByFqdn[$ThisServerDns]
                if ($DomainCacheResult) {
                    Write-LogMsg @LogParams -Text " # Domain FQDN cache hit for '$ThisServerDns'"
                    $DomainNetBios = $DomainCacheResult.Netbios
                    $AdsiProvider = $DomainCacheResult.AdsiProvider
                } else {
                    Write-LogMsg @LogParams -Text " # Domain FQDN cache miss for '$ThisServerDns'"
                }
            }

            if (-not $DomainNetBios) {
                if (-not $AdsiProvider) {
                    $AdsiProvider = Find-AdsiProvider -AdsiServer $ThisServerDns
                }
                $DomainNetBios = ConvertTo-DomainNetBIOS -DomainFQDN $ThisServerDns -AdsiProvider $AdsiProvider -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid
            }
            #>

            $ResolveIdentityReferenceParams = @{
                IdentityReference      = $IdentityReference
                AdsiServer             = $AdsiServer
                Win32AccountsBySID     = $Win32AccountsBySID
                Win32AccountsByCaption = $Win32AccountsByCaption
                DirectoryEntryCache    = $DirectoryEntryCache
                DomainsBySID           = $DomainsBySID
                DomainsByNetbios       = $DomainsByNetbios
                DomainsByFqdn          = $DomainsByFqdn
                ThisHostName           = $ThisHostName
                ThisFqdn               = $ThisFqdn
                LogMsgCache            = $LogMsgCache
                WhoAmI                 = $WhoAmI
            }
            Write-LogMsg @LogParams -Text "Resolve-IdentityReference -IdentityReference '$IdentityReference'..."
            $ResolvedIdentityReference = Resolve-IdentityReference @ResolveIdentityReferenceParams

            # not sure if I should add a param to offer DNS instead of NetBIOS

            $ObjectProperties = @{
                AdsiProvider              = $AdsiServer.AdsiProvider
                AdsiServer                = $AdsiServer.Dns
                IdentityReferenceSID      = $ResolvedIdentityReference.SIDString
                IdentityReferenceName     = $ResolvedIdentityReference.IdentityReferenceUnresolved
                IdentityReferenceResolved = $ResolvedIdentityReference.IdentityReferenceNetBios
            }
            ForEach ($ThisProperty in $ACEPropertyNames) {
                $ObjectProperties[$ThisProperty] = $ThisACE.$ThisProperty
            }
            [PSCustomObject]$ObjectProperties

        }

    }

}

function Resolve-Ace4 {
    <#
        .SYNOPSIS
        Use ADSI to lookup info about IdentityReferences from Authorization Rule Collections that came from Discretionary Access Control Lists
        .DESCRIPTION
        Based on the IdentityReference proprety of each Access Control Entry:
        Resolve SID to NT account name and vise-versa
        Resolve well-known SIDs
        Resolve generic defaults like 'NT AUTHORITY' and 'BUILTIN' to the applicable computer or domain name
        Add these properties (IdentityReferenceSID,IdentityReferenceName,IdentityReferenceResolved) to the object and return it
        .INPUTS
        [System.Security.AccessControl.AuthorizationRuleCollection]$InputObject
        .OUTPUTS
        [PSCustomObject] Original object plus IdentityReferenceSID,IdentityReferenceName,IdentityReferenceResolved, and AdsiProvider properties
        .EXAMPLE
        Get-Acl |
        Expand-Acl |
        Resolve-Ace

        Use Get-Acl from the Microsoft.PowerShell.Security module as the source of the access list
        This works in either Windows Powershell or in Powershell
        Get-Acl does not support long paths (>256 characters)
        That was why I originally used the .Net Framework method
        .EXAMPLE
        Get-FolderAce -LiteralPath C:\Test -IncludeInherited |
        Resolve-Ace
        .EXAMPLE
        [System.String]$FolderPath = 'C:\Test'
        [System.IO.DirectoryInfo]$DirectoryInfo = Get-Item -LiteralPath $FolderPath
        $Sections = [System.Security.AccessControl.AccessControlSections]::Access -bor [System.Security.AccessControl.AccessControlSections]::Owner
        $FileSecurity = [System.Security.AccessControl.FileSecurity]::new($DirectoryInfo,$Sections)
        $IncludeExplicitRules = $true
        $IncludeInheritedRules = $true
        $AccountType = [System.Security.Principal.SecurityIdentifier]
        $FileSecurity.GetAccessRules($IncludeExplicitRules,$IncludeInheritedRules,$AccountType) |
        Resolve-Ace

        This uses .Net Core as the source of the access list
        It uses the GetAccessRules method on the [System.Security.AccessControl.FileSecurity] class
        The targetType parameter of the method is used to specify that the accounts in the ACL are returned as SIDs
        .EXAMPLE
        [System.String]$FolderPath = 'C:\Test'
        [System.IO.DirectoryInfo]$DirectoryInfo = Get-Item -LiteralPath $FolderPath
        $Sections = [System.Security.AccessControl.AccessControlSections]::Access -bor
        [System.Security.AccessControl.AccessControlSections]::Owner -bor
        [System.Security.AccessControl.AccessControlSections]::Group
        $DirectorySecurity = [System.Security.AccessControl.DirectorySecurity]::new($DirectoryInfo,$Sections)
        $IncludeExplicitRules = $true
        $IncludeInheritedRules = $true
        $AccountType = [System.Security.Principal.NTAccount]
        $FileSecurity.GetAccessRules($IncludeExplicitRules,$IncludeInheritedRules,$AccountType) |
        Resolve-Ace

        This uses .Net Core as the source of the access list
        It uses the GetAccessRules method on the [System.Security.AccessControl.FileSecurity] class
        The targetType parameter of the method is used to specify that the accounts in the ACL are returned as NT account names (DOMAIN\User)
        .EXAMPLE
        [System.String]$FolderPath = 'C:\Test'
        [System.IO.DirectoryInfo]$DirectoryInfo = Get-Item -LiteralPath $FolderPath
        [System.Security.AccessControl.DirectorySecurity]$DirectorySecurity = $DirectoryInfo.GetAccessControl('Access')
        [System.Security.AccessControl.AuthorizationRuleCollection]$AuthRules = $DirectorySecurity.Access
        $AuthRules | Resolve-Ace

        Use the .Net Framework (or legacy .Net Core up to 2.2) as the source of the access list
        Only works in Windows PowerShell
        Those versions of .Net had a GetAccessControl method on the [System.IO.DirectoryInfo] class
        This method is removed in modern versions of .Net Core

        .EXAMPLE
        [System.String]$FolderPath = 'C:\Test'
        [System.IO.DirectoryInfo]$DirectoryInfo = Get-Item -LiteralPath $FolderPath
        $Sections = [System.Security.AccessControl.AccessControlSections]::Access -bor [System.Security.AccessControl.AccessControlSections]::Owner
        $FileSecurity = [System.IO.FileSystemAclExtensions]::GetAccessControl($DirectoryInfo,$Sections)

        The [System.IO.FileSystemAclExtensions] class is a Windows-specific implementation
        It provides no known benefit over the cross-platform equivalent [System.Security.AccessControl.FileSecurity]

        .NOTES
        Dependencies:
            Get-DirectoryEntry
            Add-SidInfo
            Get-TrustedDomain
            Find-AdsiProvider

        if ($FolderPath.Length -gt 255) {
            $FolderPath = "\\?\$FolderPath"
        }
    #>
    [OutputType([PSCustomObject])]
    param (

        # Authorization Rule Collection of Access Control Entries from Discretionary Access Control Lists
        [Parameter(
            ValueFromPipeline
        )]
        [PSObject[]]$InputObject,

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        [hashtable]$Win32AccountsBySID = ([hashtable]::Synchronized(@{})),

        [hashtable]$Win32AccountsByCaption = ([hashtable]::Synchronized(@{})),

        [hashtable]$DomainsBySID = ([hashtable]::Synchronized(@{})),

        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{}))

    )
    return $InputObject
}

function Resolve-IdentityReference {
    <#
        .SYNOPSIS
        Use ADSI to lookup info about IdentityReferences from Access Control Entries that came from Discretionary Access Control Lists
        .DESCRIPTION
        Based on the IdentityReference proprety of each Access Control Entry:
        Resolve SID to NT account name and vise-versa
        Resolve well-known SIDs
        Resolve generic defaults like 'NT AUTHORITY' and 'BUILTIN' to the applicable computer or domain name
        .INPUTS
        None. Pipeline input is not accepted.
        .OUTPUTS
        [PSCustomObject] with UnresolvedIdentityReference and SIDString properties (each strings)
        .EXAMPLE
        Resolve-IdentityReference -IdentityReference 'BUILTIN\Administrator' -AdsiServer (Get-AdsiServer 'localhost')

        Get information about the local Administrator account
    #>
    [OutputType([PSCustomObject])]
    param (
        # IdentityReference from an Access Control Entry
        # Expecting either a SID (S-1-5-18) or an NT account name (CONTOSO\User)
        [Parameter(Mandatory)]
        [string]$IdentityReference,

        # Object from Get-AdsiServer representing the directory server and its attributes
        [PSObject]$AdsiServer,

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        [hashtable]$Win32AccountsBySID = ([hashtable]::Synchronized(@{})),

        [hashtable]$Win32AccountsByCaption = ([hashtable]::Synchronized(@{})),

        <#
        Dictionary to cache known servers to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$AdsiServersByDns = [hashtable]::Synchronized(@{}),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    $LoggingParams = @{
        ThisHostname = $ThisHostname
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    # Populate the caches of known domains if they are currently empty (not sure if this is required so commenting it out for now)
    #if (($DomainsByFqdn.Keys.Count + $DomainsByNetBios.Keys.Count + $DomainsBySid.Keys.Count) -lt 1) {
    # $null = Get-TrustedDomainInfo -DirectoryEntryCache $DirectoryEntryCache -DomainsBySID $DomainsBySid -DomainsByNetbios $DomainsByNetbios -DomainsByFqdn $DomainsByFqdn
    #}

    # Populate the caches of known domains if they are currently empty (not sure if this is required so commenting it out for now)
    #if (($DomainsByFqdn.Keys.Count + $DomainsByNetBios.Keys.Count + $DomainsBySid.Keys.Count) -lt 1) {
    # $null = Get-TrustedDomainInfo -DirectoryEntryCache $DirectoryEntryCache -DomainsBySID $DomainsBySid -DomainsByNetbios $DomainsByNetbios -DomainsByFqdn $DomainsByFqdn
    #}

    $ServerNetBIOS = $AdsiServer.Netbios
    $split = $IdentityReference.Split('\')
    $DomainNetBIOS = $split[0]
    $DomainNetBIOS = $ServerNetBIOS
    $Name = $split[1]

    # Many Well-Known SIDs cannot be translated with the Translate method
    # Instead we have used CIM to collect information on instances of the Win32_Account class from the AdsiServer
    # This has been done by Get-AdsiServer and it updated the Win32AccountsBySID and Win32AccountsByCaption caches
    # Search the caches now
    $CacheResult = $Win32AccountsBySID["$ServerNetBIOS\$IdentityReference"]
    if ($CacheResult) {
        #IdentityReference is a SID, and has been cached from this server
        Write-LogMsg @LogParams -Text " # Win32_Account SID cache hit for '$ServerNetBIOS\$IdentityReference'"
        return [PSCustomObject]@{
            IdentityReferenceOriginal   = $IdentityReference
            # IdentityReferenceNameUnresolved below is not available, the Win32_Account instances in the cache are already resolved to the NetBios domain names
            IdentityReferenceUnresolved = $null # Could parse SID to get this?
            SIDString                   = $CacheResult.SID
            IdentityReferenceNetBios    = $CacheResult.Caption -replace "^$ThisHostname\\", "$ThisHostname\"
            IdentityReferenceDns        = "$($AdsiServer.Dns)\$($CacheResult.Name)"
        }
    } else {
        Write-LogMsg @LogParams -Text " # Win32_Account SID cache miss for '$ServerNetBIOS\$IdentityReference'"
    }
    if ($Name) {
        # Win32_Account provides a NetBIOS-resolved IdentityReference
        # NT Authority\SYSTEM would be SERVER123\SYSTEM as a Win32_Account on a server with hostname server123
        # This could also match on a domain account since those can be returned as Win32_Account, not sure if that will be a bug or what
        $CacheResult = $Win32AccountsByCaption["$ServerNetBIOS\$ServerNetBIOS\$Name"]
        if ($CacheResult) {
            # IdentityReference is an NT Account Name, and has been cached from this server
            Write-LogMsg @LogParams -Text " # Win32_Account caption cache hit for '$ServerNetBIOS\$ServerNetBIOS\$Name'"
            if ($ServerNetBIOS -eq $CacheResult.Domain) {
                $DomainDns = $AdsiServer.Dns
            }
            if (-not $DomainDns) {
                $DomainCacheResult = $DomainsByNetbios[$CacheResult.Domain]
                if ($DomainCacheResult) {
                    $DomainDns = $DomainCacheResult.Dns
                }
            }
            if (-not $DomainDns) {
                $DomainDns = ConvertTo-Fqdn -NetBIOS $DomainNetBIOS -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams
                $DomainDn = $DomainsByNetbios[$DomainNetBIOS].DistinguishedName
            }

            return [PSCustomObject]@{
                IdentityReferenceOriginal   = $IdentityReference
                # IdentityReferenceNameUnresolved below is not available, the Win32_Account instances in the cache are already resolved to the NetBios domain names
                IdentityReferenceUnresolved = $IdentityReference
                SIDString                   = $CacheResult.SID
                IdentityReferenceNetBios    = $CacheResult.Caption -replace "^$ThisHostname\\", "$ThisHostname\"
                IdentityReferenceDns        = "$DomainDns\$($CacheResult.Name)"
            }
        } else {
            Write-LogMsg @LogParams -Text " # Win32_Account caption cache miss for '$ServerNetBIOS\$ServerNetBIOS\$Name'"
        }
    }
    $CacheResult = $Win32AccountsByCaption["$ServerNetBIOS\$IdentityReference"]
    if ($CacheResult) {
        # IdentityReference is an NT Account Name, and has been cached from this server
        Write-LogMsg @LogParams -Text " # Win32_Account caption cache hit for '$ServerNetBIOS\$IdentityReference'"
        return [PSCustomObject]@{
            IdentityReferenceOriginal   = $IdentityReference
            # IdentityReferenceNameUnresolved below is not available, the Win32_Account instances in the cache are already resolved to the NetBios domain names
            IdentityReferenceUnresolved = $null
            SIDString                   = $CacheResult.SID
            IdentityReferenceNetBios    = $CacheResult.Caption -replace "^$ThisHostname\\", "$ThisHostname\"
            IdentityReferenceDns        = "$($AdsiServer.Dns)\$($CacheResult.Name)"
        }
    } else {
        Write-LogMsg @LogParams -Text " # Win32_Account caption cache miss for '$ServerNetBIOS\$IdentityReference'"
    }

    switch -Wildcard ($IdentityReference) {
        "S-1-*" {
            # IdentityReference is a Revision 1 SID
            <#
            Use the SecurityIdentifier.Translate() method to translate the SID to an NT Account name
                This .Net method makes it impossible to redirect the error stream directly
                Wrapping it in a scriptblock (which is then executed with &) fixes the problem
                I don't understand exactly why
                The scriptblock will evaluate null if the SID cannot be translated, and the error stream redirection supresses the error
            #>
            Write-LogMsg @LogParams -Text "[System.Security.Principal.SecurityIdentifier]::new('$IdentityReference').Translate([System.Security.Principal.NTAccount])"
            $SecurityIdentifier = [System.Security.Principal.SecurityIdentifier]::new($IdentityReference)
            $UnresolvedIdentityReference = & { $SecurityIdentifier.Translate([System.Security.Principal.NTAccount]).Value } 2>$null

            # The SID of the domain is everything up to (but not including) the last hyphen
            $DomainSid = $IdentityReference.Substring(0, $IdentityReference.LastIndexOf("-"))

            # Search the cache of domains, first by SID, then by NetBIOS name
            $DomainCacheResult = $DomainsBySID[$DomainSid]
            if (-not $DomainCacheResult) {
                $split = $UnresolvedIdentityReference -split '\\'
                $DomainCacheResult = $DomainsByNetbios[$split[0]]
                Write-LogMsg @LogParams -Text " # Domain SID cache miss for '$DomainSid'"
            } else {
                Write-LogMsg @LogParams -Text " # Domain SID cache hit for '$DomainSid'"
            }
            if ($DomainCacheResult) {
                $DomainNetBIOS = $DomainCacheResult.Netbios
                $DomainDns = $DomainCacheResult.Dns
            } else {
                Write-LogMsg @LogParams -Text " # Domain SID '$DomainSid' is unknown."
                $DomainNetBIOS = $split[0]
                Write-LogMsg @LogParams -Text " # Translated NTAccount name for '$IdentityReference' is '$UnresolvedIdentityReference'"
                $DomainDns = ConvertTo-Fqdn -NetBIOS $DomainNetBIOS -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams
            }
            $AdsiServer = Get-AdsiServer -Fqdn $DomainDns -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams

            if ( -not $UnresolvedIdentityReference ) {
                $Resolved = [PSCustomObject]@{
                    IdentityReferenceOriginal   = $IdentityReference
                    IdentityReferenceUnresolved = $IdentityReference
                    SIDString                   = $IdentityReference
                    IdentityReferenceNetBios    = "$DomainNetBIOS\$IdentityReference" -replace "^$ThisHostname\\", "$ThisHostname\"
                    IdentityReferenceDns        = "$DomainDns\$IdentityReference"
                }
            } else {
                # Recursively call this function to resolve the new IdentityReference we have
                $ResolveIdentityReferenceParams = @{
                    IdentityReference      = $UnresolvedIdentityReference
                    AdsiServer             = $AdsiServer
                    Win32AccountsBySID     = $Win32AccountsBySID
                    Win32AccountsByCaption = $Win32AccountsByCaption
                    AdsiServersByDns       = $AdsiServersByDns
                    DirectoryEntryCache    = $DirectoryEntryCache
                    DomainsBySID           = $DomainsBySID
                    DomainsByNetbios       = $DomainsByNetbios
                    DomainsByFqdn          = $DomainsByFqdn
                    ThisHostName           = $ThisHostName
                    ThisFqdn               = $ThisFqdn
                    LogMsgCache            = $LogMsgCache
                    WhoAmI                 = $WhoAmI
                }
                $Resolved = Resolve-IdentityReference @ResolveIdentityReferenceParams
            }

            return $Resolved

        }
        "NT SERVICE\*" {
            # Some of them are services (yes services can have SIDs, notably this includes TrustedInstaller but it is also common with SQL)
            if ($ServerNetBIOS -eq $ThisHostName) {
                Write-LogMsg @LogParams -Text "sc.exe showsid $Name"
                [string[]]$ScResult = & sc.exe showsid $Name
            } else {
                Write-LogMsg @LogParams -Text "Invoke-Command -ComputerName $ServerNetBIOS -ScriptBlock { & sc.exe showsid `$args[0] } -ArgumentList $Name"
                [string[]]$ScResult = Invoke-Command -ComputerName $ServerNetBIOS -ScriptBlock { & sc.exe showsid $args[0] } -ArgumentList $Name
            }
            $ScResultProps = @{}

            $ScResult |
            ForEach-Object {
                $Prop, $Value = ($_ -split ':').Trim()
                $ScResultProps[$Prop] = $Value
            }

            $SIDString = $ScResultProps['SERVICE SID']
            $Caption = $IdentityReference -replace 'NT SERVICE', $ServerNetBIOS -replace "^$ThisHostname\\", "$ThisHostname\"

            $DomainCacheResult = $DomainsByNetbios[$ServerNetBIOS]
            if ($DomainCacheResult) {
                $DomainDns = $DomainCacheResult.Dns
            }
            if (-not $DomainDns) {
                $DomainDns = ConvertTo-Fqdn -NetBIOS $ServerNetBIOS -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams
            }

            # Update the caches
            $Win32Acct = [PSCustomObject]@{
                SID     = $SIDString
                Caption = $Caption
                Domain  = $ServerNetBIOS
                Name    = $Name
            }
            $Win32AccountsByCaption["$ServerNetBIOS\$Caption"] = $Win32Acct
            $Win32AccountsBySID["$ServerNetBIOS\$SIDString"] = $Win32Acct

            return [PSCustomObject]@{
                IdentityReferenceOriginal   = $IdentityReference
                IdentityReferenceUnresolved = $IdentityReference
                SIDString                   = $SIDString
                IdentityReferenceNetBios    = $Caption
                IdentityReferenceDns        = "$DomainDns\$Name"
            }
        }
        "BUILTIN\*" {
            # Some built-in groups such as BUILTIN\Users and BUILTIN\Administrators are not in the CIM class or translatable with the NTAccount.Translate() method
            # But they may have real DirectoryEntry objects
            # Try to find the DirectoryEntry object locally on the server
            $DirectoryPath = "$($AdsiServer.AdsiProvider)`://$ServerNetBIOS/$Name"
            $DirectoryEntry = Get-DirectoryEntry -DirectoryPath $DirectoryPath -DirectoryEntryCache $DirectoryEntryCache -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -DomainsBySid $DomainsBySid @LoggingParams
            $SIDString = (Add-SidInfo -InputObject $DirectoryEntry -DomainsBySid $DomainsBySid @LoggingParams).SidString
            $Caption = $IdentityReference -replace 'BUILTIN', $ServerNetBIOS -replace "^$ThisHostname\\", "$ThisHostname\"
            $DomainDns = $AdsiServer.Dns

            # Update the caches
            $Win32Acct = [PSCustomObject]@{
                SID     = $SIDString
                Caption = $Caption
                Domain  = $ServerNetBIOS
                Name    = $Name
            }
            $Win32AccountsByCaption["$ServerNetBIOS\$Caption"] = $Win32Acct
            $Win32AccountsBySID["$ServerNetBIOS\$SIDString"] = $Win32Acct

            return [PSCustomObject]@{
                IdentityReferenceOriginal   = $IdentityReference
                IdentityReferenceUnresolved = $IdentityReference
                SIDString                   = $SIDString
                IdentityReferenceNetBios    = $Caption
                IdentityReferenceDns        = "$DomainDns\$Name"
            }
        }
    }

    # The IdentityReference is an NTAccount
    # Resolve NTAccount to SID
    # Start by determining the domain

    if (-not [string]::IsNullOrEmpty($DomainNetBIOS)) {
        $DomainNetBIOSCacheResult = $DomainsByNetbios[$DomainNetBIOS]
        if (-not $DomainNetBIOSCacheResult) {
            Write-LogMsg @LogParams -Text " # Domain NetBIOS cache miss for '$($DomainNetBIOS)'."
            $DomainNetBIOSCacheResult = Get-AdsiServer -Netbios $DomainNetBIOS -DirectoryEntryCache $DirectoryEntryCache -DomainsByFqdn $DomainsByFqdn -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -ThisFqdn $ThisFqdn @LoggingParams
            $DomainsByNetbios[$DomainNetBIOS] = $DomainNetBIOSCacheResult

        } else {
            Write-LogMsg @LogParams -Text " # Domain NetBIOS cache hit for '$($DomainNetBIOS)'."
        }

        $DomainDn = $DomainNetBIOSCacheResult.DistinguishedName
        $DomainDns = $DomainNetBIOSCacheResult.Dns

        # Try to resolve the account against the server the Access Control Entry came from (which may or may not be the directory server for the account)
        Write-LogMsg @LogParams -Text "[System.Security.Principal.NTAccount]::new('$ServerNetBIOS', '$Name').Translate([System.Security.Principal.SecurityIdentifier])"
        $NTAccount = [System.Security.Principal.NTAccount]::new($ServerNetBIOS, $Name)
        $SIDString = & { $NTAccount.Translate([System.Security.Principal.SecurityIdentifier]) } 2>$null

        if (-not $SIDString) {
            # Try to resolve the account against the domain indicated in its NT Account Name (which may or may not be the correct ADSI server for the account, it won't be if it's NT AUTHORITY\SYSTEM for example)
            Write-LogMsg @LogParams -Text "[System.Security.Principal.NTAccount]::new('$DomainNetBIOS', '$Name')"
            $NTAccount = [System.Security.Principal.NTAccount]::new($DomainNetBIOS, $Name)
            Write-LogMsg @LogParams -Text "[System.Security.Principal.NTAccount]::new('$DomainNetBIOS', '$Name').Translate([System.Security.Principal.SecurityIdentifier])"
            $SIDString = & { $NTAccount.Translate([System.Security.Principal.SecurityIdentifier]) } 2>$null
        } else {
            $DomainNetBIOS = $ServerNetBIOS
        }

        if (-not $SIDString) {
            # Try to resolve the account against the domain indicated in its NT Account Name
            # Add this domain to our list of known domains
            try {
                $SearchPath = Add-DomainFqdnToLdapPath -DirectoryPath "LDAP://$DomainDn" -ThisFqdn $ThisFqdn @LogParams
                $DirectoryEntry = Search-Directory -DirectoryEntryCache $DirectoryEntryCache -DirectoryPath $SearchPath -Filter "(samaccountname=$Name)" -PropertiesToLoad @('objectClass', 'distinguishedName', 'name', 'grouptype', 'description', 'managedby', 'member', 'objectClass', 'Department', 'Title') -DomainsByNetbios $DomainsByNetbios
                $SIDString = (Add-SidInfo -InputObject $DirectoryEntry -DomainsBySid $DomainsBySid @LoggingParams).SidString
            } catch {
                Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tResolve-IdentityReference`t$($StartingIdentityName) could not be resolved against its directory"
                Write-Warning "$(Get-Date -Format s)`t$ThisHostname`tResolve-IdentityReference`t$($_.Exception.Message)"
            }
        }

        if (-not $SIDString) {

            # Try to find the DirectoryEntry object directly on the server
            $DirectoryPath = "$($AdsiServer.AdsiProvider)`://$ServerNetBIOS/$Name"
            $DirectoryEntry = Get-DirectoryEntry -DirectoryPath $DirectoryPath -DirectoryEntryCache $DirectoryEntryCache -DomainsByNetbios $DomainsByNetbios -DomainsBySid $DomainsBySid -DomainsBySid $DomainsBySid @LoggingParams
            $SIDString = (Add-SidInfo -InputObject $DirectoryEntry -DomainsBySid $DomainsBySid @LoggingParams).SidString

        }

        if ($SIDString) {
            $DomainNetBIOS = $ServerNetBIOS
        }

        # This covers unresolved SIDs for deleted accounts, broken domain trusts, etc.
        if ( '' -eq "$Name" ) {
            $Name = $IdentityReference
            Write-LogMsg @LogParams -Text " # An identity reference girl has no name ($Name)"
        } else {
            Write-LogMsg @LogParams -Text " # '$IdentityReference' is named '$Name'"
        }

        return [PSCustomObject]@{
            IdentityReferenceOriginal   = $IdentityReference
            IdentityReferenceUnresolved = $IdentityReference
            SIDString                   = $SIDString
            IdentityReferenceNetBios    = "$DomainNetBios\$Name" -replace "^$ThisHostname\\", "$ThisHostname\"
            IdentityReferenceDns        = "$DomainDns\$Name"
        }

    }
}
function Search-Directory {
    <#
        .SYNOPSIS
        Use Active Directory Service Interfaces to search an LDAP directory
        .DESCRIPTION
        Find directory entries using the LDAP provider for ADSI (the WinNT provider does not support searching)
        Provides a wrapper around the [System.DirectoryServices.DirectorySearcher] class
        .INPUTS
        None. Pipeline input is not accepted.
        .OUTPUTS
        [System.DirectoryServices.DirectoryEntry]
        .EXAMPLE
        Search-Directory -Filter ''

        As the current user on a domain-joined computer, bind to the current domain and search for all directory entries matching the LDAP filter
    #>
    param (

        <#
        Path to the directory object to retrieve
        Defaults to the root of the current domain
        #>
        [string]$DirectoryPath = (([adsisearcher]'').SearchRoot.Path),

        # Filter for the LDAP search
        [string]$Filter,

        # Number of records per page of results
        [int]$PageSize = 1000,

        # Additional properties to return
        [string[]]$PropertiesToLoad,

        # Credentials to use
        [pscredential]$Credential,

        # Scope of the search
        [string]$SearchScope = 'subtree',

        <#
        Hashtable containing cached directory entries so they don't have to be retrieved from the directory again
        Uses a thread-safe hashtable by default
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    $DirectoryEntryParameters = @{
        DirectoryEntryCache = $DirectoryEntryCache
        DomainsByNetbios    = $DomainsByNetbios
        ThisHostname        = $ThisHostname
        LogMsgCache         = $LogMsgCache
        WhoAmI              = $WhoAmI
    }

    if ($Credential) {
        $DirectoryEntryParameters['Credential'] = $Credential
    }

    if (($null -eq $DirectoryPath -or '' -eq $DirectoryPath)) {
        $Workgroup = (Get-CimInstance -ClassName Win32_ComputerSystem).Workgroup
        $DirectoryPath = "WinNT://$Workgroup/$ThisHostname"
    }
    $DirectoryEntryParameters['DirectoryPath'] = $DirectoryPath

    $DirectoryEntry = Get-DirectoryEntry @DirectoryEntryParameters

    Write-LogMsg @LogParams -Text "`$DirectorySearcher = [System.DirectoryServices.DirectorySearcher]::new(([System.DirectoryServices.DirectoryEntry]::new('$DirectoryPath')))"
    $DirectorySearcher = [System.DirectoryServices.DirectorySearcher]::new($DirectoryEntry)

    if ($Filter) {
        Write-LogMsg @LogParams -Text "`$DirectorySearcher.Filter = '$Filter'"
        $DirectorySearcher.Filter = $Filter
    }

    Write-LogMsg @LogParams -Text "`$DirectorySearcher.PageSize = '$PageSize'"
    $DirectorySearcher.PageSize = $PageSize
    Write-LogMsg @LogParams -Text "`$DirectorySearcher.SearchScope = '$SearchScope'"
    $DirectorySearcher.SearchScope = $SearchScope

    ForEach ($Property in $PropertiesToLoad) {
        Write-LogMsg @LogParams -Text "`$DirectorySearcher.PropertiesToLoad.Add('$Property')"
        $null = $DirectorySearcher.PropertiesToLoad.Add($Property)
    }

    Write-LogMsg @LogParams -Text "`$DirectorySearcher.FindAll()"
    $SearchResultCollection = $DirectorySearcher.FindAll()
    # TODO: Fix this. Problems in integration testing trying to use the objects later if I dispose them here now.
    # Error: Cannot access a disposed object.
    #$null = $DirectorySearcher.Dispose()
    #$null = $DirectoryEntry.Dispose()
    $Output = [System.DirectoryServices.SearchResult[]]::new($SearchResultCollection.Count)
    $SearchResultCollection.CopyTo($Output, 0)
    #$null = $SearchResultCollection.Dispose()
    return $Output

}
<#
# Add any custom C# classes as usable (exported) types
$CSharpFiles = Get-ChildItem -Path "$PSScriptRoot\*.cs"
ForEach ($ThisFile in $CSharpFiles) {
    Add-Type -Path $ThisFile.FullName -ErrorAction Stop
}
#>

# Definition of Module 'SimplePrtg' is below

function Format-PrtgXmlResult {

    <#
        .SYNOPSIS
        Generate an XML result for a single channel to include in the result for a PRTG custom XML sensor
        .DESCRIPTION
        Generate a <result>...</result> XML channel for a PRTG custom XML sensor
        .INPUTS
        [System.String]$Channel
        .OUTPUTS
        [System.String] A single XML channel to include in the output for a PRTG XML sensor
        .EXAMPLE
        New-PrtgXmlResult -Channel 'Channel123' -Value 'Value123' -CustomUnit 'Miles Per Hour'
        <result>
        <channel>Channel123</channel>
        <value>Value123</value>
        <unit>Custom</unit>
        <customUnit>Miles Per Hour</customUnit>
        <showchart>0</showchart>
        </result>

        Generate XML output for a PRTG sensor that will put it in an OK state
    #>

    param (

        # PRTG sensor channel of the result
        [parameter(Mandatory)]
        [string]$Channel,

        # Value to return
        [parameter(Mandatory)]
        [string]$Value,

        # Reccomend leaving this as 'Custom' but see PRTG docs for other options
        [string]$Unit = 'Custom',

        # Custom unit label to apply to the value
        [string]$CustomUnit,

        # Show the channel on charts in PRTG
        [int]$ShowChart = 0,

        # If the value goes above this the channel will be in an alarm state in PRTG
        [string]$MaxError,

        # If the value goes below this the channel will be in an alarm state in PRTG
        [string]$MinError,

        # If the value goes above this the channel will be in a warning state in PRTG
        [string]$MaxWarn,

        # If the value goes below this the channel will be in a warning state in PRTG
        [string]$MinWarn,

        # Force the channel into a warning state in PRTG
        [switch]$Warning

    )

    $Xml = [System.Collections.Generic.List[string]]::new()

    $null = $Xml.Add('<result>')
    $null = $Xml.Add(" <channel>$Channel</channel>")
    $null = $Xml.Add(" <value>$Value</value>")
    $null = $Xml.Add(" <unit>$Unit</unit>")
    $null = $Xml.Add(" <showchart>$ShowChart</showchart>")

    if ($CustomUnit) {
        $null = $Xml.Add(" <customUnit>$CustomUnit</customUnit>")
    }

    if ($MaxError -or $MinError -or $MaxWarn -or $MinWarn) {

        $null = $Xml.Add(" <limitmode>1</limitmode>")

        if ($MaxError) {
            $null = $Xml.Add(" <limitmaxerror>$MaxError</limitmaxerror>")
        }

        if ($MinError) {
            $null = $Xml.Add(" <limitminerror>$MinError</limitminerror>")
        }

        if ($MaxWarn) {
            $null = $Xml.Add(" <limitmaxwarn>$MaxWarn</limitmaxwarn>")
        }

        if ($MinWarn) {
            $null = $Xml.Add(" <limitminwarn>$MinWarn</limitminwarn>")
        }

    }

    if ($Warning) {
        $null = $Xml.Add(' <Warning>1</Warning>')
    } else {
        $null = $Xml.Add(' <Warning>0</Warning>')
    }

    $null = $Xml.Add('</result>')
    $Xml

}

function Format-PrtgXmlSensorOutput {
    <#
        .SYNOPSIS
        Assemble the complete output for a PRTG XML sensor
        .DESCRIPTION
        Combine multiple channels into a single PRTG XML sensor result
        .INPUTS
        [System.String]$PrtgXmlResult
        .OUTPUTS
        [System.String] Complete XML output for a PRTG custom XML sensor
        .EXAMPLE
        @"
        <result>
        <channel>Channel123</channel>
        <value>Value123</value>
        <unit>Custom</unit>
        <customUnit>Miles Per Hour</customUnit>
        <showchart>$ShowChart</showchart>
        </result>
        @" |
        New-PrtgXmlSensorOutput

        Generate XML output for a PRTG sensor that will put it in an OK state
        .EXAMPLE
        @"
        <result>
        <channel>Channel123</channel>
        <value>Value123</value>
        <unit>Custom</unit>
        <customUnit>Miles Per Hour</customUnit>
        <showchart>0</showchart>
        </result>
        @" |
        New-PrtgXmlSensorOutput -IssueDetected

        Generate XML output for a PRTG sensor that will put it in an alarm state
    #>

    param (

        # Valid XML for a PRTG result for a single channel
        # Can be created by Format-PrtgXmlResult
        [Parameter(ValueFromPipeline)]
        [string[]]$PrtgXmlResult,

        # Force the PRTG sensor into an alarm state
        [switch]$IssueDetected

    )

    begin {
        $Strings = [System.Collections.Generic.List[string]]::new()
        $null = $Strings.add("<prtg>")
    }
    process {
        foreach ($XmlResult in $PrtgXmlResult) {
            $null = $Strings.add($XmlResult)
        }
    }
    end {
        if ($IssueDetected) {
            $null = $Strings.add("<text>Issue detected, see sensor channels for details</text>")
        } else {
            $null = $Strings.add("<text>OK</text>")
        }
        $null = $Strings.add("</prtg>")
        $Strings
    }
}
function Send-PrtgXmlSensorOutput {

    <#
        .SYNOPSIS
        Wrapper for Invoke-WebRequest to make it easy to push results to PRTG XML push sensors
        .DESCRIPTION
        Use HTTP post to post results to PRTG XML push sensors
        .INPUTS
        [System.String]$XmlOutput
        .OUTPUTS
        Passes through the output of Invoke-WebRequest
        .EXAMPLE
        New-PrtgXmlSensorOutput ... |
        Send-PrtgXmlSensorOutput -PrtgSensorProtocol 'https' -PrtgProbe 'server1' -PrtgSensorPort 443 -PrtgSensorToken 'e3edd633-3018-4d8a-91b6-d2635b42b85b'

        Post sensor output to PRTG push sensor e3edd633-3018-4d8a-91b6-d2635b42b85b on server1 using HTTPS on TCP port 443
    #>

    param(

        # Valid XML for a PRTG custom XML sensor
        # Can be created by Format-PrtgXmlSensorOutput
        [string]$XmlOutput,

        # If all four of the PRTG parameters are specified, then the results will be XML-formatted and pushed to the specified PRTG probe for a push sensor
        [string]$PrtgProbe,

        # If all four of the PRTG parameters are specified, then the results will be XML-formatted and pushed to the specified PRTG probe for a push sensor
        [string]$PrtgSensorProtocol,

        # If all four of the PRTG parameters are specified, then the results will be XML-formatted and pushed to the specified PRTG probe for a push sensor
        [int]$PrtgSensorPort,

        # If all four of the PRTG parameters are specified, then the results will be XML-formatted and pushed to the specified PRTG probe for a push sensor
        [string]$PrtgSensorToken
    )

    $ResultToPost = @{
        Body            = $XMLOutput
        ContentType     = 'application/xml'
        Method          = 'Post'
        Uri             = "$PrtgSensorProtocol`://$PrtgProbe`:$PrtgSensorPort/$PrtgSensorToken"
        UseBasicParsing = $true
    }

    if ($PrtgSensorToken) {
        Write-Verbose "URI: $PrtgSensorProtocol`://$PrtgProbe`:$PrtgSensorPort/$PrtgSensorToken"

        Invoke-WebRequest @ResultToPost
    }

}
<#
# Add any custom C# classes as usable (exported) types
$CSharpFiles = Get-ChildItem -Path "$PSScriptRoot\*.cs"
ForEach ($ThisFile in $CSharpFiles) {
    Add-Type -Path $ThisFile.FullName -ErrorAction Stop
}
#>

# Definition of Module 'PsNtfs' is below

function GetDirectories {
    param (
        [Parameter(Mandatory)]
        [string]$TargetPath,

        [string]$SearchPattern = '*',

        [System.IO.SearchOption]$SearchOption = [System.IO.SearchOption]::AllDirectories
    )
    Write-Debug " $(Get-Date -Format s)`t$(hostname)`tGetDirectories`t[System.IO.Directory]::GetDirectories('$TargetPath','$SearchPattern',[System.IO.SearchOption]::$SearchOption)"
    try {
        [System.IO.Directory]::GetDirectories($TargetPath, $SearchPattern, $SearchOption)
    } catch {
        Write-Warning "$(Get-Date -Format s)`t$(hostname)`tGetDirectories`t$($_.Exception.Message)"
    }
}
function ConvertTo-SimpleProperty {
    param (
        $InputObject,

        [string]$Property,

        [hashtable]$PropertyDictionary = @{},

        [string]$Prefix
    )

    $Value = $InputObject.$Property

    [string]$Type = $null
    if ($Value) {
        # Ensure the GetType method exists to avoid this error:
        # The following exception occurred while retrieving member "GetType": "Not implemented"
        if (Get-Member -InputObject $Value -Name GetType) {
            [string]$Type = $Value.GetType().FullName
        } else {
            # The only scenario we've encountered where the GetType() method does not exist is DirectoryEntry objects from the WinNT provider
            # Force the type to 'System.DirectoryServices.DirectoryEntry'
            [string]$Type = 'System.DirectoryServices.DirectoryEntry'
        }
    }

    switch ($Type) {
        'System.DirectoryServices.DirectoryEntry' {
            $PropertyDictionary["$Prefix$Property"] = ConvertFrom-DirectoryEntry -DirectoryEntry $Value
        }
        'System.DirectoryServices.PropertyCollection' {
            $ThisObject = @{}
            <#
            This error was happening when:
                A DirectoryEntry has a SchemaEntry property
                which is a DirectoryEntry
                which has a Properties property
                which is a System.DirectoryServices.PropertyCollection
                but throws the following error to the Success stream (not the error stream, so it is hard to catch):
                    PS C:\Users\Test> $ThisDirectoryEntry.Properties
                    format-default : The entry properties cannot be enumerated. Consider using the entry schema to determine what properties are available.
                        + CategoryInfo : NotSpecified: (:) [format-default], NotSupportedException
                        + FullyQualifiedErrorId : System.NotSupportedException,Microsoft.PowerShell.Commands.FormatDefaultCommand
            To catch the error we will redirect the Success Stream to the Error Stream
            Then if the Exception type matches, we will use the continue keyword to break out of the current switch statement
            #>
            try {
                $Value 1>2
            } catch [System.NotSupportedException] {
                continue
            }

            ForEach ($ThisProperty in $Value.Keys) {
                $ThisPropertyString = ConvertFrom-PropertyValueCollectionToString -PropertyValueCollection $Value[$ThisProperty]
                $ThisObject[$ThisProperty] = $ThisPropertyString

                # This copies the properties up to the top level.
                # Want to remove this later
                # The nested pscustomobject accomplishes the goal of removing hashtables and PropertyValueCollections and PropertyCollections
                # But I may have existing functionality expecting these properties so I am not yet ready to remove this
                # When I am, I should move this code into a ConvertFrom-PropertyCollection function in the Adsi module
                $PropertyDictionary["$Prefix$ThisProperty"] = $ThisPropertyString

            }
            $PropertyDictionary["$Prefix$Property"] = [PSCustomObject]$ThisObject
            continue
        }
        'System.DirectoryServices.PropertyValueCollection' {
            $PropertyDictionary["$Prefix$Property"] = ConvertFrom-PropertyValueCollectionToString -PropertyValueCollection $Value
            continue
        }
        'System.Object[]' {
            $PropertyDictionary["$Prefix$Property"] = $Value
            continue
        }
        'System.Object' {
            $PropertyDictionary["$Prefix$Property"] = $Value
            continue
        }
        'System.DirectoryServices.SearchResult' {
            $PropertyDictionary["$Prefix$Property"] = ConvertFrom-SearchResult -SearchResult $Value
            continue
        }
        'System.DirectoryServices.ResultPropertyCollection' {
            $ThisObject = @{}

            ForEach ($ThisProperty in $Value.Keys) {
                $ThisPropertyString = ConvertFrom-ResultPropertyValueCollectionToString -ResultPropertyValueCollection $Value[$ThisProperty]
                $ThisObject[$ThisProperty] = $ThisPropertyString

                # This copies the properties up to the top level.
                # Want to remove this later
                # The nested pscustomobject accomplishes the goal of removing hashtables and PropertyValueCollections and PropertyCollections
                # But I may have existing functionality expecting these properties so I am not yet ready to remove this
                # When I am, I should move this code into a ConvertFrom-PropertyCollection function in the Adsi module
                $PropertyDictionary["$Prefix$ThisProperty"] = $ThisPropertyString

            }
            $PropertyDictionary["$Prefix$Property"] = [PSCustomObject]$ThisObject
            continue
        }
        'System.DirectoryServices.ResultPropertyValueCollection' {
            $PropertyDictionary["$Prefix$Property"] = ConvertFrom-ResultPropertyValueCollectionToString -ResultPropertyValueCollection $Value
            continue
        }
        'System.Management.Automation.PSCustomObject' {
            $PropertyDictionary["$Prefix$Property"] = $Value
            continue
        }
        'System.Collections.Hashtable' {
            $PropertyDictionary["$Prefix$Property"] = [PSCustomObject]$Value
            continue
        }
        'System.Byte[]' {
            $PropertyDictionary["$Prefix$Property"] = ConvertTo-DecStringRepresentation -ByteArray $Value
        }
        default {
            <#
                By default we will just let most types get cast as a string
                Includes but not limited to:
                    $null (because GetType is not implemented)
                    System.String
                    System.Boolean
            #>
            $PropertyDictionary["$Prefix$Property"] = "$Value"
            continue
        }
    }

    return $PropertyDictionary
}
function Expand-AccountPermission {
    <#
        .SYNOPSIS
        Expand an object representing a security principal and into a collection of objects respresenting the access control entries for that principal
        .DESCRIPTION
        Expand an object from Format-SecurityPrincipal (one object per principal, containing nested access entries) into flat objects (one per access entry per account)
        .INPUTS
        [pscustomobject]$AccountPermission
        .OUTPUTS
        [pscustomobject] One object per access control entry per account
        .EXAMPLE
        (Get-Acl).Access |
        Group-Object -Property IdentityReference |
        Expand-IdentityReference |
        Format-SecurityPrincipal |
        Expand-AccountPermission

        Incomplete example but it shows the chain of functions to generate the expected input for this
    #>
    param (
        # Object that was output from Format-SecurityPrincipal
        $AccountPermission,

        # Properties to exclude from the output
        # All properties listed on a single line to workaround a bug in PlatyPS when building MAML help
        # (error is 'Invalid yaml: expected simple key-value pairs')
        # Caused by multi-line default parameter values in the markdown
        [string[]]$PropertiesToExclude = @('NativeObject', 'NtfsAccessControlEntries', 'Group')
    )
    ForEach ($Account in $AccountPermission) {

        $Props = @{}

        $AccountNoteProperties = $Account |
        Get-Member -MemberType Property, CodeProperty, ScriptProperty, NoteProperty |
        Where-Object -Property Name -NotIn $PropertiesToExclude

        ForEach ($ThisProperty in $AccountNoteProperties) {
            if ($null -eq $Props[$ThisProperty.Name]) {
                $Props = ConvertTo-SimpleProperty -InputObject $Account -Property $ThisProperty.Name -PropertyDictionary $Props
            }
        }

        ForEach ($ACE in $Account.NtfsAccessControlEntries) {

            $ACENoteProperties = $ACE |
            Get-Member -MemberType Property, CodeProperty, ScriptProperty, NoteProperty

            ForEach ($ThisProperty in $ACENoteProperties) {
                $Props = ConvertTo-SimpleProperty -InputObject $ACE -Property $ThisProperty.Name -PropertyDictionary $Props -Prefix "ACE"
            }

            $Props['SourceAclPath'] = $ACE.SourceAccessList.Path

            [pscustomobject]$Props

        }
    }
}
function Expand-Acl {
    <#
        .SYNOPSIS
        Expand an Access Control List into its constituent Access Control Entries
        .DESCRIPTION
        Enumerate the members of the Access property of the $InputObject parameter (which is an AuthorizationRuleCollection or similar)
        Append the original ACL to each member as a SourceAccessList property
        Then return each member
        .INPUTS
        [PSObject]$InputObject
        Expected:
        [System.Security.AccessControl.DirectorySecurity]$InputObject from Get-Acl
        or
        [System.Security.AccessControl.FileSecurity]$InputObject from Get-Acl
        .OUTPUTS
        [PSCustomObject]
        .EXAMPLE
        Get-Acl |
        Expand-Acl

        Use Get-Acl from the Microsoft.PowerShell.Security module as the source of the access list
        This works in either Windows Powershell or in Powershell
        Get-Acl does not support long paths (>256 characters)
        That was why I originally used the .Net Framework method
    #>
    param (

        # Access Control List whose Access Control Entries to return
        # Expects [System.Security.AccessControl.FileSecurity] objects from Get-Acl or otherwise
        # Expects [System.Security.AccessControl.DirectorySecurity] objects from Get-Acl or otherwise
        # Accepts any [PSObject] as long as it has an 'Access' property that contains a collection
        [Parameter(
            ValueFromPipeline
        )]
        [PSObject]$InputObject

    )

    process {

        ForEach ($ThisInputObject in $InputObject) {

            $ObjectProperties = @{
                SourceAccessList = $ThisInputObject
            }
            $AllACEs = $ThisInputObject.Access
            $AceProperties = (Get-Member -InputObject $AllACEs[0] -MemberType Property, CodeProperty, ScriptProperty, NoteProperty).Name
            ForEach ($ThisACE in $AllACEs) {
                ForEach ($ThisProperty in $AceProperties) {
                    $ObjectProperties["$Prefix$ThisProperty"] = $ThisACE.$ThisProperty
                }
                [PSCustomObject]$ObjectProperties
            }

        }

    }

}
function Find-ServerNameInPath {
    <#
        .SYNOPSIS
        Parse a literal path to find its server
        .DESCRIPTION
        Currently only supports local file paths or UNC paths
        .INPUTS
        None. Pipeline input is not accepted.
        .OUTPUTS
        [System.String] representing the name of the server that was extracted from the path
        .EXAMPLE
        Find-ServerNameInPath -LiteralPath 'C:\Test'

        Return the hostname of the local computer because a local filepath was used
        .EXAMPLE
        Find-ServerNameInPath -LiteralPath '\\server123\Test\'

        Return server123 because a UNC path for a folder shared on server123 was used
    #>
    [OutputType([System.String])]
    param (
        [string]$LiteralPath
    )
    if ($LiteralPath -match '[A-Za-z]\:\\' -or $null -eq $LiteralPath -or '' -eq $LiteralPath) {
        # For local file paths, the "server" is the local computer. Assume the same for null paths.
        hostname
    } else {
        # Otherwise it must be a UNC path, so the server is the first non-empty string between backwhacks (\)
        $ThisServer = $LiteralPath -split '\\' |
        Where-Object -FilterScript { $_ -ne '' } |
        Select-Object -First 1

        $ThisServer -replace '\?', (hostname)
    }
}
function Format-FolderPermission {

    Param (

        # Expects ACEs grouped using Group-Object
        $UserPermission,

        # Ignore these FileSystemRights
        [string[]]$FileSystemRightsToIgnore = @('Synchronize')

    )

    begin {
        $i = 0
    }
    process {

        ForEach ($ThisUser in $UserPermission) {

            $i++
            #Calculate the completion percentage, and format it to show 0 decimal places
            $percentage = "{0:N0}" -f (($i / ($UserPermission.Count)) * 100)

            #Display the progress bar
            $status = ("$(Get-Date -Format s)`t$(hostname)`tFormat-FolderPermission`tStatus: " + $percentage + "% - Processing user permission $i of " + $UserPermission.Count + ": " + $ThisUser.Name)
            Write-Verbose $status
            Write-Progress -Activity ("Total Users: " + $UserPermission.Count) -Status $status -PercentComplete $percentage

            if ($ThisUser.Group.DirectoryEntry.Properties) {
                if (
                    (
                        $ThisUser.Group.DirectoryEntry |
                        ForEach-Object {
                            if ($null -ne $_) {
                                $_.GetType().FullName 2>$null
                            }
                        }
                    ) -contains 'System.Management.Automation.PSCustomObject'
                ) {
                    $Names = $ThisUser.Group.DirectoryEntry.Properties.Name
                    $Depts = $ThisUser.Group.DirectoryEntry.Properties.Department
                    $Titles = $ThisUser.Group.DirectoryEntry.Properties.Title
                } else {
                    $Names = $ThisUser.Group.DirectoryEntry |
                    ForEach-Object {
                        if ($_.Properties) {
                            $_.Properties['name']
                        }
                    }

                    $Depts = $ThisUser.Group.DirectoryEntry |
                    ForEach-Object {
                        if ($_.Properties) {
                            $_.Properties['department']
                        }
                    }

                    $Titles = $ThisUser.Group.DirectoryEntry |
                    ForEach-Object {
                        if ($_.Properties) {
                            $_.Properties['title']
                        }
                    }

                    if ($ThisUser.Group.DirectoryEntry.Properties['objectclass'] -contains 'group' -or
                        "$($ThisUser.Group.DirectoryEntry.Properties['groupType'])" -ne ''
                    ) {
                        $SchemaClassName = 'group'
                    } else {
                        $SchemaClassName = 'user'
                    }
                }
                $Name = $Names | Sort-Object -Unique
                $Dept = $Depts | Sort-Object -Unique
                $Title = $Titles | Sort-Object -Unique
            } else {
                $Name = $ThisUser.Group.name | Sort-Object -Unique
                $Dept = $ThisUser.Group.department | Sort-Object -Unique
                $Title = $ThisUser.Group.title | Sort-Object -Unique

                if ($ThisUser.Group.Properties) {
                    if (
                        $ThisUser.Group.Properties['objectclass'] -contains 'group' -or
                        "$($ThisUser.Group.Properties['groupType'])" -ne ''
                    ) {
                        $SchemaClassName = 'group'
                    } else {
                        $SchemaClassName = 'user'
                    }
                } else {
                    if ($ThisUser.Group.DirectoryEntry.SchemaClassName) {
                        $SchemaClassName = $ThisUser.Group.DirectoryEntry.SchemaClassName |
                        Select-Object -First 1
                    } else {
                        $SchemaClassName = $ThisUser.Group.SchemaClassName |
                        Select-Object -First 1
                    }
                }
            }
            if ("$Name" -eq '') {
                $Name = $ThisUser.Name
            }

            ForEach ($ThisACE in $ThisUser.Group) {

                switch ($ThisACE.ACEInheritanceFlags) {
                    'ContainerInherit, ObjectInherit' { $Scope = 'this folder, subfolders, and files' }
                    'ContainerInherit' { $Scope = 'this folder and subfolders' }
                    'ObjectInherit' { $Scope = 'this folder and files, but not subfolders' }
                    default { $Scope = 'this folder but not subfolders' }
                }

                if ($null -eq $ThisUser.Group.IdentityReference) {
                    $IdentityReference = $null
                } else {
                    $IdentityReference = $ThisACE.ACEIdentityReferenceResolved
                }

                $FileSystemRights = $ThisACE.ACEFileSystemRights
                ForEach ($Ignore in $FileSystemRightsToIgnore) {
                    $FileSystemRights = $FileSystemRights -replace ", $Ignore\Z", '' -replace "$Ignore,", ''
                }

                [pscustomobject]@{
                    Folder                   = $ThisACE.ACESourceAccessList.Path
                    FolderInheritanceEnabled = !($ThisACE.ACESourceAccessList.AreAccessRulesProtected)
                    Access                   = "$($ThisACE.ACEAccessControlType) $FileSystemRights $Scope"
                    Account                  = $ThisUser.Name
                    Name                     = $Name
                    Department               = $Dept
                    Title                    = $Title
                    IdentityReference        = $IdentityReference
                    AccessControlEntry       = $ThisACE
                    SchemaClassName          = $SchemaClassName
                }

            }

        }

    }

    end {
        Write-Progress -Activity ("Total User Permissions: " + $UserPermission.Count) -Completed
    }

}
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
function Get-FolderAce {
    <#
    .SYNOPSIS
    Alternative to Get-Acl designed to be as lightweight and flexible as possible
    .DESCRIPTION
    Returns an object for each access control entry instead of a single object for the ACL
    Excludes inherited permissions by default but allows them to be included with the -IncludeInherited switch parameter
    .INPUTS
    None. Pipeline input is not accepted.
    .OUTPUTS
    [PSCustomObject]
    .NOTES
    Currently only supports Directories but could easily be copied to support files, or Registry or AD providers
    #>

    [CmdletBinding(
        SupportsShouldProcess = $false,
        ConfirmImpact = "Low"
    )]

    param(

        # Path to the directory whose permissions to get
        [string]$LiteralPath,

        # Include inherited Access Control Entries in the results
        [Switch]$IncludeInherited,

        # Include all sections except Audit because it requires admin rights if run on the local system and we want to avoid that requirement
        [System.Security.AccessControl.AccessControlSections]$Sections = (
            [System.Security.AccessControl.AccessControlSections]::Access -bor
            [System.Security.AccessControl.AccessControlSections]::Owner -bor
            [System.Security.AccessControl.AccessControlSections]::Group),

        # Include non-inherited Access Control Entries in the results
        [bool]$IncludeExplicitRules = $true,

        # Type of IdentityReference to return in each ACE
        [System.Type]$AccountType = [System.Security.Principal.SecurityIdentifier]

    )

    $TodaysHostname = HOSTNAME.exe

    Write-Debug " $(Get-Date -Format s)`t$TodaysHostname`tGet-FolderAce`t[System.Security.AccessControl.DirectorySecurity]::new('$LiteralPath', '$Sections').GetAccessRules(`$$IncludeExplicitRules, `$$IncludeInherited, [$AccountType])"
    $DirectorySecurity = & { [System.Security.AccessControl.DirectorySecurity]::new(
            $LiteralPath,
            $Sections
        ) } 2>$null

    if (-not $DirectorySecurity.Access) {
        Write-Debug " $(Get-Date -Format s)`t$TodaysHostname`tGet-FolderAce`t# Found no ACL for '$LiteralPath'"
        return
    }

    $AclProperties = @{}
    $AclPropertyNames = (Get-Member -InputObject $DirectorySecurity -MemberType Property, CodeProperty, ScriptProperty, NoteProperty).Name
    ForEach ($ThisProperty in $AclPropertyNames) {
        $AclProperties[$ThisProperty] = $DirectorySecurity.$ThisProperty
    }
    $AclProperties['Path'] = $LiteralPath

    Write-Debug " $(Get-Date -Format s)`t$TodaysHostname`tGet-FolderAce`t[System.Security.AccessControl.DirectorySecurity]::new('$LiteralPath', '$Sections').GetAccessRules(`$$IncludeExplicitRules, `$$IncludeInherited, [$AccountType])"
    $AccessRules = $DirectorySecurity.GetAccessRules($IncludeExplicitRules, $IncludeInherited, $AccountType)
    if ($AccessRules.Count -lt 1) {
        Write-Debug " $(Get-Date -Format s)`t$TodaysHostname`tGet-FolderAce`t# Found no matching access rules for '$LiteralPath'"
        return
    }
    $ACEPropertyNames = (Get-Member -InputObject $AccessRules[0] -MemberType Property, CodeProperty, ScriptProperty, NoteProperty).Name
    ForEach ($ThisAccessRule in $AccessRules) {
        $ACEProperties = @{
            SourceAccessList = [PSCustomObject]$AclProperties
        }
        ForEach ($ThisProperty in $ACEPropertyNames) {
            $ACEProperties[$ThisProperty] = $ThisAccessRule.$ThisProperty
        }
        [PSCustomObject]$ACEProperties
    }

    #TODO: Output an object for the owner as well to represent that they have Full Control
    ##$ACEProperties['IsInherited'] = $false
    ##$ACEProperties['IdentityReference'] = $DirectorySecurity.Owner -replace '^O:', ''
    ##$ACEProperties['FileSystemRights'] = [System.Security.AccessControl.FileSystemRights]::FullControl
    ##$ACEProperties['InheritanceFlags'] = [System.Security.AccessControl.InheritanceFlags]::None
    ##$ACEProperties['PropagationFlags'] = [System.Security.AccessControl.PropagationFlags]::None
    ##$ACEProperties['AccessControlType'] = [System.Security.AccessControl.AccessControlType]::Allow
    ##[PSCustomObject]$ACEProperties

}
function Get-Subfolder {

    # Use the fastest available method to enumerate subfolders

    [CmdletBinding()]
    param (

        # Parent folder whose subfolders to enumerate
        [string]$TargetPath,

        <#
        How many levels of subfolder to enumerate
            Set to 0 to ignore all subfolders
            Set to -1 (default) to recurse infinitely
            Set to any whole number to enumerate that many levels
        #>
        [int]$FolderRecursionDepth = -1
    )

    if ($FolderRecursionDepth -eq -1) {
        $DepthString = '∞'
    } else {
        $DepthString = $FolderRecursionDepth
    }
    Write-Progress -Activity ("Retrieving subfolders...") -Status ("Enumerating all subfolders of '$TargetPath' to a depth of $DepthString levels of recursion") -PercentComplete 50
    if ($Host.Version.Major -gt 2) {
        switch ($FolderRecursionDepth) {
            -1 {
                GetDirectories -TargetPath $TargetPath -SearchOption ([System.IO.SearchOption]::AllDirectories)
            }
            0 {}
            1 {
                GetDirectories -TargetPath $TargetPath -SearchOption ([System.IO.SearchOption]::TopDirectoryOnly)
            }
            Default {
                $FolderRecursionDepth = $FolderRecursionDepth - 1
                Write-Debug " $(Get-Date -Format s)`t$(hostname)`tGet-Subfolder`tGet-ChildItem '$TargetPath' -Force -Name -Recurse -Attributes Directory -Depth $FolderRecursionDepth"
                (Get-ChildItem $TargetPath -Force -Recurse -Attributes Directory -Depth $FolderRecursionDepth).FullName
            }
        }
    } else {
        Write-Debug " $(Get-Date -Format s)`t$(hostname)`tGet-Subfolder`tGet-ChildItem '$TargetPath' -Recurse"
        Get-ChildItem $TargetPath -Recurse | Where-Object -FilterScript { $_.PSIsContainer } | ForEach-Object { $_.FullName }
    }
    Write-Progress -Activity ("Retrieving subfolders...") -Completed
}
function Get-Win32MappedLogicalDisk {
    param (
        [string]$ComputerName,

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages
    )

    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    if (
        $ComputerName -eq $ThisHostname -or
        $ComputerName -eq "$ThisHostname." -or
        $ComputerName -eq $ThisFqdn
    ) {
        #Write-LogMsg @LogParams -Text "Get-CimInstance -ClassName Win32_MappedLogicalDisk"
        Get-CimInstance -ClassName Win32_MappedLogicalDisk
    } else {
        #Write-LogMsg @LogParams -Text "Get-CimInstance -ComputerName $ComputerName -ClassName Win32_MappedLogicalDisk"
        # If an Active Directory domain is targeted there are no local accounts and CIM connectivity is not expected
        # Suppress errors and return nothing in that case
        Get-CimInstance -ComputerName $ComputerName -ClassName Win32_MappedLogicalDisk -ErrorAction SilentlyContinue
    }
}
function New-NtfsAclIssueReport {

    param (

        $FolderPermissions,

        $UserPermissions,

        <#
        If specified, all groups that have NTFS access to the target folder/subfolders will be evaluated for compliance with this naming convention
        The naming format that will be used for the users is CONTOSO\User1 where CONTOSO is the NetBIOS name of the domain, and User1 is the samAccountName of the user
        By default, this is a scriptblock that always evaluates to $true so it doesn't evaluate any naming convention compliance
        #>
        [scriptblock]$GroupNamingConvention = { $true }
    )

    $IssuesDetected = $false

    # List of folders with broken inheritance (recommend moving to higher level to avoid breaking inheritance. Deny entries are a less desirable alternative)
    $FoldersWithBrokenInheritance = $FolderPermissions |
    Select-Object -Skip 1 |
    Where-Object -FilterScript {
                ($_.Group.FolderInheritanceEnabled | Select-Object -First 1) -eq $false -and
                (($_.Name -replace ([regex]::Escape($TargetPath)), '' -split '\\') | Measure-Object).Count -ne 2
    }
    $Count = ($FoldersWithBrokenInheritance | Measure-Object).Count
    if ($Count -gt 0) {
        $IssuesDetected = $true
        $Txt = "folders with broken inheritance: $($FoldersWithBrokenInheritance.Name -join "`r`n")"
    } else {
        $Txt = 'OK'
    }
    Write-Verbose "$Count`:$Txt"

    # List of ACEs for groups that do not match the specified naming convention
    # Invert the naming convention scriptblock (because we actually want to identify groups that do NOT follow the convention)
    $ViolatesNamingConvention = [scriptblock]::Create("!($GroupNamingConvention)")
    $NonCompliantGroups = $SecurityPrincipals |
    Where-Object -FilterScript { $_.ObjectType -contains 'Group' } |
    Where-Object -FilterScript $ViolatesNamingConvention |
    Select-Object -ExpandProperty Group |
    ForEach-Object { "$($_.IdentityReference) on '$($_.Path)'" }

    $Count = ($NonCompliantGroups | Measure-Object).Count
    if ($Count -gt 0) {
        $IssuesDetected = $true
        $Txt = "groups that don't match naming convention: $($NonCompliantGroups -join "`r`n")"
    } else {
        $Txt = 'OK'
    }
    Write-Verbose "$Count`:$Txt"

    # ACEs for users (recommend replacing with group-based access on any folder that is not a home folder)
    $UserACEs = $UserPermissions.Group |
    Where-Object -FilterScript { $_.ObjectType -contains 'User' } |
    ForEach-Object { $_.NtfsAccessControlEntries } |
    ForEach-Object { "$($_.IdentityReference) on '$($_.Path)'" } |
    Sort-Object -Unique
    $Count = ($UserACEs | Measure-Object).Count
    if ($Count -gt 0) {
        $IssuesDetected = $true
        $Txt = "users with ACEs: $($UserACEs -join "`r`n")"
    } else {
        $Txt = 'OK'
    }
    Write-Verbose "$Count`:$Txt"

    # ACEs for unresolvable SIDs (recommend removing these ACEs)
    $SIDsToCleanup = $UserPermissions.Group.NtfsAccessControlEntries |
    Where-Object -FilterScript { $_.IdentityReference -match 'S-\d+-\d+-\d+-\d+-\d+\-\d+\-\d+' } |
    ForEach-Object { "$($_.IdentityReference) on '$($_.Path)'" } |
    Sort-Object -Unique
    $Count = ($SIDsToCleanup | Measure-Object).Count
    if ($Count -gt 0) {
        $IssuesDetected = $true
        $Txt = "ACEs for unresolvable SIDs: $($SIDsToCleanup -join "`r`n")"
    } else {
        $Txt = 'OK'
    }
    Write-Verbose "$Count`:$Txt"

    # CREATOR OWNER access (recommend replacing with group-based access, or with explicit user access for a home folder.)
    $FoldersWithCreatorOwner = ($UserPermissions | ? { $_.Name -match 'CREATOR OWNER' }).Group.NtfsAccessControlEntries.Path | Sort -Unique
    $Count = ($FoldersWithCreatorOwner | Measure-Object).Count
    if ($Count -gt 0) {
        $IssuesDetected = $true
        $Txt = "folders with 'CREATOR OWNER' ACEs: $($FoldersWithCreatorOwner -join "`r`n")"
    } else {
        $Txt = 'OK'
    }
    Write-Verbose "$Count`:$Txt"

    [PSCustomObject]@{
        IssueDetected                = $IssuesDetected
        FoldersWithBrokenInheritance = $FoldersWithBrokenInheritance
        NonCompliantGroups           = $NonCompliantGroups
        UserACEs                     = $UserACEs
        SIDsToCleanup                = $SIDsToCleanup
        FoldersWithCreatorOwner      = $FoldersWithCreatorOwner
    }
}
function Resolve-Folder {

    # Resolve the provided FolderPath to all of its associated UNC paths

    param (
        [string[]]$FolderPath
    )

    process {
        foreach ($TargetPath in $FolderPath) {

            $RegEx = '^(?<DriveLetter>\w):'
            if ($TargetPath -match $RegEx) {
                $MappedNetworkDrives = Get-Win32MappedLogicalDisk

                $MatchingNetworkDrive = $MappedNetworkDrives |
                Where-Object -FilterScript { $_.DeviceID -eq "$($Matches.DriveLetter):" }

                if ($MatchingNetworkDrive) {
                    # Resolve mapped network drives to their UNC path
                    $UNC = $MatchingNetworkDrive.ProviderName
                } else {
                    # Resolve local drive letters to their UNC paths using administrative shares
                    $UNC = $TargetPath -replace $RegEx, "\\$(hostname)\$($Matches.DriveLetter)$"
                }
                if ($UNC) {
                    # Replace hostname with FQDN in the path
                    $Server = $UNC.split('\')[2]
                    $FQDN = ConvertTo-DnsFqdn -ComputerName $Server
                    $UNC -replace "^\\\\$Server\\", "\\$FQDN\"
                }
            } else {
                # Can't use [NetApi32Dll]::NetDfsGetInfo($TargetPath) because it doesn't work if the provided path is a subfolder of a DFS folder
                # Can't use [NetApi32Dll]::NetDfsGetClientInfo($TargetPath) because it does not return disabled folder targets
                # Instead need to use [NetApi32Dll]::NetDfsEnum($TargetPath) then Where-Object to filter results
                $AllDfs = Get-NetDfsEnum -Verbose -FolderPath $TargetPath -ErrorAction SilentlyContinue

                if ($AllDfs) {
                    $MatchingDfsEntryPaths = $AllDfs |
                    Group-Object -Property DfsEntryPath |
                    Where-Object -FilterScript {
                        $TargetPath -match [regex]::Escape($_.Name)
                    }

                    # Filter out the DFS Namespace
                    # TODO: I know this is an inefficient n2 algorithm, but my brain is fried...plez...halp...leeloo dallas multipass
                    $RemainingDfsEntryPaths = $MatchingDfsEntryPaths |
                    Where-Object -FilterScript {
                        -not [bool]$(
                            ForEach ($ThisEntryPath in $MatchingDfsEntryPaths) {
                                if ($ThisEntryPath.Name -match "$([regex]::Escape("$($_.Name)")).+") { $true }
                            }
                        )
                    } |
                    Sort-Object -Property Name

                    $RemainingDfsEntryPaths |
                    Select-Object -Last 1 -ExpandProperty Group |
                    ForEach-Object {
                        $_.FullOriginalQueryPath -replace [regex]::Escape($_.DfsEntryPath), $_.DfsTarget
                    }
                } else {
                    $Server = $TargetPath.split('\')[2]
                    $FQDN = ConvertTo-DnsFqdn -ComputerName $Server
                    $TargetPath -replace "^\\\\$Server\\", "\\$FQDN\"
                }

            }
        }
    }

}
<#
# Dot source any functions
ForEach ($ThisScript in $ScriptFiles) {
    # Dot source the function
    . $($ThisScript.FullName)
}
#>

# Definition of Module 'PsLogMessage' is below

function ConvertTo-DnsFqdn {

    # Output the results of a DNS lookup to the default DNS server for the specified

    # Wrapper for [System.Net.Dns]::GetHostByName([string]$ComputerName)

    param (

        [string]$ComputerName,

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }
    Write-LogMsg @LogParams -Text "[System.Net.Dns]::GetHostByName('$ComputerName')"
    [System.Net.Dns]::GetHostByName($ComputerName).HostName # -replace "^$ThisHostname", "$ThisHostname" #replace does not appear to be needed, capitalization is correct from GetHostByName()

}
function Get-CurrentHostName {
    # Future function to universally retrieve hostname using various methods (in order of preference):
    # hostname.exe
    # $env:hostname
    # CIM
    # other?
}
function Get-CurrentWhoAmI {

    # Output the results of whoami.exe after editing them to correct capitalization

    # whoami.exe returns lowercase but we want to honor the correct capitalization

    # Correct capitalization is regurned from $ENV:USERNAME

    param (

        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Dictionary of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    $WhoAmI -replace "^$ThisHostname\\", "$ThisHostname\" -replace "$ENV:USERNAME", $ENV:USERNAME
    if (-not $PSBoundParameters.ContainsKey('WhoAmI')) {
        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = 'Debug'
            LogMsgCache  = $LogMsgCache
            WhoAmI       = $WhoAmI
        }
        # Technically this exe has already been run, but it is advantageous to offer it as a parameter
        # Also, this way the log will use the correct capitalization
        Write-LogMsg @LogParams -Text "& whoami.exe"
    }
}
function New-DatedSubfolder {
    # Creates a folder structure with a folder for each year and month
    # Then it creates one timestamped folder inside the appropriate month
    # This folder is intended to be used to store output from a single execution of a script
    param (
        [parameter(Mandatory)]
        [string]$Root,

        # A suffix to append to the folder name
        [string]$Suffix
    )
    $Year = Get-Date -Format 'yyyy'
    $Month = Get-Date -Format 'MM'
    $Timestamp = (Get-Date -Format s) -replace ':', '-'

    $NewDir = "$Root\$Year\$Month\$Timestamp$Suffix"

    $null = New-Item -ItemType Directory -Path $NewDir -ErrorAction SilentlyContinue
    Write-Output $NewDir
}
function Write-LogMsg {

    <#
        .SYNOPSIS
            Prepend a prefix to a log message, write the message to an output stream, and write the message to a text file.
            Writes a message to a log file and/or PowerShell output stream
        .DESCRIPTION
            Prepends the log message with:
                a current timestamp
                the current hostname
                the current username
                the current command (function or file name)
                the current location (line number in the code)

            Tab-delimits these fields for a compromise between readability and parseability

            Adds the log message to either:
            * a hashtable (which can be thread-safe) using the timestamp as the key, which was passed to the $LogMsgCache parameter
            * a Global:$LogMessages variable which was created by the PsLogMessage module during import

            Optionally writes the message to a log file

            Optionally writes the message to a PowerShell output stream
        .INPUTS
        [System.String]$Text parameter
        .OUTPUTS
        [System.String] Resulting log line, returned if the -PassThru or -Type Output parameters were used
    #>
    [OutputType([System.String])]
    [CmdletBinding()]
    param(

        # Message to log
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$Text,

        # Output stream to send the message to
        [ValidateSet('Silent', 'Quiet', 'Success', 'Debug', 'Verbose', 'Output', 'Host', 'Warning', 'Error', 'Information', $null)]
        [string]$Type = 'Information',

        # Add a prefix to the message including the date, hostname, current user, and info about the current call stack
        [bool]$AddPrefix = $true,

        # Text file to append the log message to
        [string]$LogFile,

        # Output the message to the pipeline
        [bool]$PassThru = $false,

        # Hostname to use in the log messages and/or output object
        [string]$ThisHostname = (HOSTNAME.EXE),

        # Hostname to use in the log messages and/or output object
        [string]$WhoAmI = (whoami.EXE),

        [hashtable]$LogMsgCache = $Global:LogMessages

    )


    # This will ensure the message is not written to any PowerShell output streams or log files
    if ($Type -eq 'Silent') { return }

    $Timestamp = Get-Date -Format 'yyyy-MM-ddThh:mm:ss.ffff'
    $OutputToPipeline = $false
    $PSCallStack = Get-PSCallStack

    if ($AddPrefix) {
        # This method is faster than StringBuilder or the -join operator
        [string]$MessageToLog = "$Timestamp`t$ThisHostname`t$WhoAmI`t$($PSCallStack[1].Location)`t$($PSCallStack[1].Command)`t$($MyInvocation.ScriptLineNumber)`t$($Type)`t$($Text)"
    } else {
        [string]$MessageToLog = $Text
    }

    Switch ($Type) {

        # This will ensure the message is added to log files, but not written to any PowerShell output streams
        'Quiet' {}

        # This one is made-up to correspond with the 'success' contextual class in Bootstrap.
        'Success' { Write-Information "SUCCESS: $MessageToLog" }

        # These represent normal PowerShell output streams
        # The correct number of spaces should be added to maintain proper column alignment
        'Debug' { Write-Debug " $MessageToLog" }
        'Verbose' { Write-Verbose $MessageToLog }
        'Host' { Write-Host "HOST: $MessageToLog" }
        'Warning' { Write-Warning $MessageToLog }
        'Error' { Write-Error $MessageToLog }
        'Output' { $OutputToPipeline = $true }
        default { Write-Information "INFO: $MessageToLog" }
    }

    if ('' -ne $LogFile) {
        $MessageToLog | Out-File $LogFile -Append
    }

    if ($PassThru -or $OutputToPipeline) {
        $MessageToLog
    }

    # Add a GUID to the timestamp and use it as a unique key in the hashtable of log messages
    [string]$Guid = [guid]::NewGuid()
    [string]$Key = "$Timestamp$Guid"

    $LogMsgCache[$Key] = [pscustomobject]@{
        Timestamp = $Timestamp
        Hostname  = $ThisHostname
        WhoAmI    = $WhoAmI
        Location  = $PSCallStack[1].Location
        Command   = $PSCallStack[1].Command
        Line      = $MyInvocation.ScriptLineNumber
        Type      = $Type
        Text      = $Text
    }

}
<#
# Add any custom C# classes as usable (exported) types
$CSharpFiles = Get-ChildItem -Path "$PSScriptRoot\*.cs"
ForEach ($ThisFile in $CSharpFiles) {
    Add-Type -Path $ThisFile.FullName -ErrorAction Stop
}
#>

#$Global:LogMessages = [system.collections.generic.list[pscustomobject]]::new()
$Global:LogMessages = [hashtable]::Synchronized(@{})

# Definition of Module 'PsRunspace' is below

function Add-PsCommand {

    <#
    .Synopsis
        Add a command to a [System.Management.Automation.PowerShell] instance
    .Description
        Used by Invoke-Thread
        Uses AddScript() or AddStatement() and AddCommand() depending on the command
    .EXAMPLE
        [powershell]::Create() | Add-PsCommand -Command 'Write-Output'

        Add a command by sending a Cmdlet name to the -Command parameter
    #>

    param(

        # Powershell interface to add the Command to
        [Parameter(ValueFromPipeline = $true)]
        [powershell[]]$PowershellInterface,

        <#
        Command to add to the Powershell interface
        This can be a scriptblock object, or a string that specifies a:
            Alias
            Function (the name of the function)
            ExternalScript (the path to the .ps1 file)
            All, Application, Cmdlet, Configuration, Filter, or Script
        #>
        [Parameter(Position = 0)]
        $Command,

        # Output from Get-PsCommandInfo
        # Optional, to improve performance if it will be re-used for multiple calls of Add-PsCommand
        [pscustomobject]$CommandInfo,

        # Add Commands rather than their definitions
        [switch]$Force,

        # Will be sent to the Type parameter of Write-LogMsg in the PsLogMessage module
        [string]$DebugOutputStream = 'Silent',

        # Hostname to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$TodaysHostname = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Hashtable of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    begin {

        $LogParams = @{
            LogMsgCache  = $LogMsgCache
            ThisHostname = $TodaysHostname
            Type         = $DebugOutputStream
            WhoAmI       = $WhoAmI
        }

        $CommandInfoParams = @{
            DebugOutputStream = $DebugOutputStream
            TodaysHostname    = $TodaysHostname
            WhoAmI            = $WhoAmI
            LogMsgCache       = $LogMsgCache
        }

        if ($CommandInfo -eq $null) {
            $CommandInfo = Get-PsCommandInfo @CommandInfoParams -Command $Command
        }

    }
    process {

        ForEach ($ThisPowershell in $PowershellInterface) {

            switch ($CommandInfo.CommandType) {

                'Alias' {
                    # Resolve the alias to its command and start from the beginning with that command.
                    $CommandInfo = Get-PsCommandInfo @CommandInfoParams -Command $CommandInfo.CommandInfo.Definition
                    $null = Add-PsCommand @CommandInfoParams -Command $CommandInfo.CommandInfo.Definition -CommandInfo $CommandInfo -PowershellInterface $ThisPowerShell
                }
                'Function' {

                    if ($Force) {
                        Write-LogMsg @LogParams -Text " # Adding command '$Command' of type '$($CommandInfo.CommandType)' (treating it as a command instead of a Function because -Force was used)"
                        # If the type is All, Application, Cmdlet, Configuration, Filter, or Script then run the command as-is
                        Write-LogMsg @LogParams -Text "`$PowershellInterface.AddStatement().AddCommand('$Command')"
                        $null = $ThisPowershell.AddStatement().AddCommand($Command)
                    } else {
                        # Add the definitions of the function
                        # BUG: Look at the definition of Get-Member for example, it is not in a ScriptModule so its definition is not PowerShell code
                        [string]$ThisFunction = "function $($CommandInfo.CommandInfo.Name) {`r`n$($CommandInfo.CommandInfo.Definition)`r`n}"
                        Write-LogMsg @LogParams -Text " # Adding Script (the Definition of a Function, `$CommandInfo.CommandInfo.Definition not expanded below for brevity)"
                        ##Write-LogMsg @LogParams -Text "`$PowershellInterface.AddScript('function $($CommandInfo.CommandInfo.Name) { `$CommandInfo.CommandInfo.Definition }')"
                        Write-LogMsg @LogParams -Text "`$PowershellInterface.AddScript('$ThisFunction')"
                        $null = $ThisPowershell.AddScript($ThisFunction)
                    }
                }
                'ExternalScript' {
                    Write-LogMsg @LogParams -Text " # Adding Script (the ScriptBlock of an ExternalScript, `$CommandInfo.ScriptBlock not expanded below for brevity)"
                    ##Write-LogMsg @LogParams -Text "`$PowershellInterface.AddScript(`"`$(`$CommandInfo.ScriptBlock)`") # "
                    Write-LogMsg @LogParams -Text "`$PowershellInterface.AddScript('$($CommandInfo.ScriptBlock)')"
                    $null = $ThisPowershell.AddScript($CommandInfo.ScriptBlock)
                }
                'ScriptBlock' {
                    Write-LogMsg @LogParams -Text " # Adding Script (a ScriptBlock, not expanded below for brevity)"
                    ##Write-LogMsg @LogParams -Text "`$PowershellInterface.AddScript(`"`$Command`")
                    Write-LogMsg @LogParams -Text "`$PowershellInterface.AddScript('$Command')"
                    $null = $ThisPowershell.AddScript($Command)
                }
                default {
                    Write-LogMsg @LogParams -Text " # Adding command '$Command' of type '$($CommandInfo.CommandType)'"
                    # If the type is All, Application, Cmdlet, Configuration, Filter, or Script then run the command as-is
                    Write-LogMsg @LogParams -Text "`$PowershellInterface.AddStatement().AddCommand('$Command')"
                    $null = $ThisPowershell.AddStatement().AddCommand($Command)
                }

            }
        }
    }
}
function Add-PsModule {
    <#
    .Synopsis
        Import a Module in a [System.Management.Automation.Runspaces.InitialSessionState] instance
    .Description
        Used by Add-PsCommand
        Uses ImportPSModule() or ImportPSModulesFromPath() depending on the module
    .EXAMPLE
        $InitialSessionState = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
        Add-PsModule -InitialSessionState $InitialSessionState -ModuleInfo $ModuleInfo
    #>

    param(

        # Powershell interface to add the Command to
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.InitialSessionState]$InitialSessionState,

        <#
        ModuleInfo object for the module to add to the Powershell interface
        #>
        [Parameter(
            Position = 0
        )]
        [System.Management.Automation.PSModuleInfo[]]$ModuleInfo,

        # Will be sent to the Type parameter of Write-LogMsg in the PsLogMessage module
        [string]$DebugOutputStream = 'Silent',

        # Hostname to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$TodaysHostname = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Hashtable of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    begin {

        $LogParams = @{
            LogMsgCache  = $LogMsgCache
            ThisHostname = $TodaysHostname
            Type         = $DebugOutputStream
            WhoAmI       = $WhoAmI
        }

    }

    process {

        ForEach ($ThisModule in $ModuleInfo) {

            switch ($ThisModule.ModuleType) {
                'Binary' {
                    Write-LogMsg @LogParams -Text "`$InitialSessionState.ImportPSModule('$($ThisModule.Name)')"
                    $InitialSessionState.ImportPSModule($ThisModule.Name)
                }
                'Script' {
                    $ModulePath = Split-Path -Path $ThisModule.Path -Parent
                    Write-LogMsg @LogParams -Text "`$InitialSessionState.ImportPSModulesFromPath('$ModulePath')"
                    $InitialSessionState.ImportPSModulesFromPath($ModulePath)
                }
                'Manifest' {
                    $ModulePath = Split-Path -Path $ThisModule.Path -Parent
                    Write-LogMsg @LogParams -Text "`$InitialSessionState.ImportPSModulesFromPath('$ModulePath')"
                    $InitialSessionState.ImportPSModulesFromPath($ModulePath)
                }
                default {
                    # Scriptblocks or Functions not from modules will have no module to import so ModuleInfo will be null
                }

            }

        }

    }

}
function Convert-FromPsCommandInfoToString {
    param (
        [Parameter (
            Mandatory,
            Position = 0
        )]
        [PSCustomObject[]]$CommandInfo,

        # Will be sent to the Type parameter of Write-LogMsg in the PsLogMessage module
        [string]$DebugOutputStream = 'Silent',

        # Hostname to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$TodaysHostname = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Hashtable of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )
    begin {
        $CommandInfoParams = @{
            DebugOutputStream = $DebugOutputStream
            TodaysHostname    = $TodaysHostname
            WhoAmI            = $WhoAmI
            LogMsgCache       = $LogMsgCache
        }
    }

    process {
        ForEach ($ThisCmd in $CommandInfo) {

            switch ($ThisCmd.CommandType) {

                'Alias' {
                    # Resolve the alias to its command and start from the beginning with that command
                    $ThisCmd = Get-PsCommandInfo @CommandInfoParams -Command $ThisCmd.CommandInfo.Definition
                    Convert-FromPsCommandInfoToString @CommandInfoParams -CommandInfo $ThisCmd
                }
                'Function' {
                    "function $($ThisCmd.CommandInfo.Name) {`r`n$($ThisCmd.CommandInfo.Definition)`r`n}"
                }
                'ExternalScript' {
                    "$($ThisCmd.ScriptBlock)"
                    #"$($ThisCmd.CommandInfo.ScriptBlock)"
                    #"$Command"
                }
                'ScriptBlock' {
                    "$Command"
                }
                default {
                    "$Command"
                }

            }
        }
    }
}
function Expand-PsCommandInfo {

    <#
    .SYNOPSIS
        Return the original PsCommandInfo object as well as CommandInfo objects for any nested commands
    #>

    param (
        # CommandInfo object for the command whose nested command names to return
        [PSCustomObject]$PsCommandInfo,

        # Cache of already identified CommmandInfo objects
        [hashtable]$Cache = [hashtable]::Synchronized(@{}),

        # Will be sent to the Type parameter of Write-LogMsg in the PsLogMessage module
        [string]$DebugOutputStream = 'Silent',

        # Hostname to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$TodaysHostname = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Hashtable of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages
    )

    $CommandInfoParams = @{
        DebugOutputStream = $DebugOutputStream
        TodaysHostname    = $TodaysHostname
        WhoAmI            = $WhoAmI
        LogMsgCache       = $LogMsgCache
    }

    # Add the first object to the cache
    if (-not $PsCommandInfo.CommandInfo.Name) {
        $PsCommandInfo
    } else {
        $Cache[$PsCommandInfo.CommandInfo.Name] = $PsCommandInfo
    }

    # Tokenize the function definition
    $PsTokens = $null
    $TokenizerErrors = $null
    $AbstractSyntaxTree = [System.Management.Automation.Language.Parser]::ParseInput(
        # We need the property which contains tokenizable PowerShell
        # For a function in a ScriptModule, the definition and scriptblock properties are the same
        # For an ExternalScript, the definition is the filepath and the scriptblock is tokenizable powershell
        # This is why the Scriptblock property has been chosen
        #$PsCommandInfo.CommandInfo.Definition,
        $PsCommandInfo.CommandInfo.Scriptblock,
        [ref]$PsTokens,
        [ref]$TokenizerErrors
    )

    # Get all nested tokens
    $AllPsTokens = Expand-PsToken -InputObject $PsTokens

    # Find any other functions we also need to add
    $CommandTokens = $AllPsTokens |
    Where-Object -FilterScript {
        $_.Kind -eq 'Generic' -and
        $_.TokenFlags.HasFlag([System.Management.Automation.Language.TokenFlags]::CommandName)
    }

    # Add the definitions of those functions if available
    # TODO: Add modules if available? Not needed at this time but maybe later
    ForEach ($ThisCommandToken in $CommandTokens) {
        if (
            -not $Cache[$ThisCommandToken.Value] -and
            $ThisCommandToken.Value -notmatch '[\.\\]' # Exclude any file paths since they are not PowerShell commands with tokenizable definitions (they contain \ or .)
        ) {
            $TokenCommandInfo = Get-PsCommandInfo @CommandInfoParams -Command $ThisCommandToken.Value
            $Cache[$ThisCommandToken.Value] = $TokenCommandInfo

            # Suppress the output of the Expand-PsCommandInfo function because we will instead be using the updated cache contents
            # This way the results are already deduplicated for us by the hashtable
            $null = Expand-PsCommandInfo @CommandInfoParams -PsCommandInfo $TokenCommandInfo -Cache $Cache
        }
    }

    # Output the objects in the cache
    ForEach ($ThisKey in $Cache.Keys) {
        $Cache[$ThisKey]
    }

}
function Expand-PsToken {
    <#
    .SYNOPSIS
        Recursively get nested tokens
    .DESCRIPTION
        Recursively emits all tokens embedded in a token of type "StringExpandable"
        The original token is also emitted.
    .EXAMPLE
        $Tokens = $null
        $TokenizerErrors = $null
        $AbstractSyntaxTree = [System.Management.Automation.Language.Parser]::ParseInput(
          [string]$Code,
          [ref]$Tokens,
          [ref]$TokenizerErrors
      )
      $Tokens |
      Expand-PsToken

      Return all tokens nested inside the provided $Code
    #>

    param (
        # Management.Automation.Language.StringExpandableToken or
        # Management.Automation.Language.Token
        [Parameter(
            Mandatory,
            Position = 0
        )]
        [psobject]$InputObject
    )

    process {
        if ($InputObject.GetType().FullName -eq 'Management.Automation.Language.StringExpandableToken]') {
            ForEach ($ThisToken in $InputObject.NestedTokens) {
                if ($ThisToken) {
                    Expand-PsToken -InputObject $ThisToken
                }
            }
        }
        $InputObject
    }

}
function Get-PsCommandInfo {

    <#
    .Synopsis
        Get info about a PowerShell command

    .Description
        Used by Split-Thread, Invoke-Thread, and Add-PsCommand

       Determine whether the Command is a [System.Management.Automation.ScriptBlock] object
       If not, passes it to the Name parameter of Get-Command

    .EXAMPLE
        The following demonstrates sending a Cmdlet name to the -Command parameter
            Get-PsCommandInfo -Command 'Write-Output'
    #>

    param(
        <#
        Command to retrieve info on
        This can be a scriptblock object, or a string that specifies an:
            Alias
            Function (the name of the function)
            ExternalScript (the path to the .ps1 file)
            All, Application, Cmdlet, Configuration, Filter, or Script
        #>
        $Command,

        # Will be sent to the Type parameter of Write-LogMsg in the PsLogMessage module
        [string]$DebugOutputStream = 'Silent',

        # Hostname to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$TodaysHostname = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Hashtable of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    $LogParams = @{
        LogMsgCache  = $LogMsgCache
        ThisHostname = $TodaysHostname
        Type         = $DebugOutputStream
        WhoAmI       = $WhoAmI
    }

    if ($Command.GetType().FullName -eq 'System.Management.Automation.ScriptBlock') {
        [string]$CommandType = 'ScriptBlock'
    } else {
        $CommandInfo = Get-Command $Command -ErrorAction SilentlyContinue
        [string]$CommandType = $CommandInfo.CommandType
        if ($CommandInfo.Source -like "*\*") {
            $ModuleInfo = Get-Module -Name $CommandInfo.Source -ListAvailable -ErrorAction SilentlyContinue
        } else {
            if ($CommandInfo.Source) {
                Write-LogMsg @LogParams -Text "Get-Module -Name '$($CommandInfo.Source)'"
                $ModuleInfo = Get-Module -Name $CommandInfo.Source -ErrorAction SilentlyContinue
            }
        }
    }

    if ($ModuleInfo.Path -like "*.ps1") {
        $ModuleInfo = $null
        $SourceModuleName = $null
    } else {
        $SourceModuleName = $CommandInfo.Source
    }

    Write-LogMsg @LogParams -Text " # $Command is a $CommandType"
    [pscustomobject]@{
        CommandInfo            = $CommandInfo
        ModuleInfo             = $ModuleInfo
        CommandType            = $CommandType
        SourceModuleDefinition = $ModuleInfo.Definition
        SourceModuleName       = $SourceModuleName
    }

}
function Open-Thread {

    <#
    .Synopsis
        Prepares each thread so it is ready to execute a command and capture the output streams

    .Description
        Used by Split-Thread

        For each InputObject an instance will be created of [System.Management.Automation.PowerShell]
        Then a series of commands will be run to enable the specified output streams (all by default)
    #>

    Param(

        # Objects to pass to the Command as an argument or parameter
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        $InputObject,

        # .Net Framework runspace pool to use for the threads
        [Parameter(
            Mandatory = $true
        )]
        [System.Management.Automation.Runspaces.RunspacePool]$RunspacePool,

        <#
        Name of a property (whose value is a string) that exists on each $InputObject
        It will be used to represent the object in text form
        If left null, the object's ToString() method will be used instead.
        #>
        [string]$ObjectStringProperty,

        # PowerShell Command or Script to run against each InputObject
        [Parameter(Mandatory = $true)]
        $Command,

        # Output from Get-PsCommandInfo
        [pscustomobject[]]$CommandInfo,

        # Named parameter of the Command to pass InputObject to
        # If this is not specified, InputObject will be passed to the Command as an argument
        [string]$InputParameter = $null,

        <#
        Parameters to add to the Command
        Each parameter is a name-value pair in the hashtable:
            @{"ParameterName" = "Value"}
            @{"ParameterName" = "Value" ; "ParameterTwo" = "Value2"}
        #>
        [HashTable]$AddParam = @{},

        # Switches to add to the Command
        [string[]]$AddSwitch = @(),

        # Will be sent to the Type parameter of Write-LogMsg in the PsLogMessage module
        [string]$DebugOutputStream = 'Silent',

        # Hostname to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$TodaysHostname = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Hashtable of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    begin {

        $LogParams = @{
            LogMsgCache  = $LogMsgCache
            ThisHostname = $TodaysHostname
            Type         = $DebugOutputStream
            WhoAmI       = $WhoAmI
        }

        $CommandInfoParams = @{
            DebugOutputStream = $DebugOutputStream
            TodaysHostname    = $TodaysHostname
            WhoAmI            = $WhoAmI
            LogMsgCache       = $LogMsgCache
        }

        [int64]$CurrentObjectIndex = 0
        $ThreadCount = @($InputObject).Count
        Write-LogMsg @LogParams -Text " # Received $(($CommandInfo | Measure-Object).Count) PsCommandInfos from Split-Thread for '$Command'"

        if ($CommandInfo) {

            # Begin to build the command that the script will run with all its parameters
            if (Test-Path $Command -ErrorAction SilentlyContinue) {
                # If $Command is a valid file path, dot-source it and wrap it in single quotes to handle spaces
                $CommandStringForScriptDefinition = [System.Text.StringBuilder]::new(". '$Command'")
            } else {
                $CommandStringForScriptDefinition = [System.Text.StringBuilder]::new($Command)
            }

            # Build the param block of the script. Along the way, add any necessary parameters and switches
            # Avoided using AppendJoin. It would provide slight performance and code readability but lacks support in PS 5.1
            $ScriptDefinition = [System.Text.StringBuilder]::new()
            $null = $ScriptDefinition.AppendLine('param (')
            If ([string]::IsNullOrEmpty($InputParameter)) {
                $null = $ScriptDefinition.Append(" `$PsRunspaceArgument1")
                $null = $CommandStringForScriptDefinition.Append(" `$PsRunspaceArgument1")
            } else {
                $null = $ScriptDefinition.Append(" `$$InputParameter")
                $null = $CommandStringForScriptDefinition.Append(" -$InputParameter `$$InputParameter")
            }

            ForEach ($ThisKey in $AddParam.Keys) {
                $null = $ScriptDefinition.Append(",`r`n `$$ThisKey")
                $null = $CommandStringForScriptDefinition.Append(" -$ThisKey `$$ThisKey")
            }

            ForEach ($ThisSwitch in $AddSwitch) {
                $null = $ScriptDefinition.Append(",`r`n [switch]`$", $ThisSwitch)
                $null = $CommandStringForScriptDefinition.Append(" -$ThisSwitch")
            }
            $null = $ScriptDefinition.AppendLine("`r`n)`r`n")

            # Define the command in the script ($Command)
            Convert-FromPsCommandInfoToString @CommandInfoParams -CommandInfo $CommandInfo |
            ForEach-Object {
                $null = $ScriptDefinition.AppendLine("`r`n$_")
            }
            $null = $ScriptDefinition.AppendLine()

            # Call the function in the script
            Write-LogMsg @LogParams -Text " # Command string is $($CommandStringForScriptDefinition.ToString())"
            $CommandStringForScriptDefinition |
            ForEach-Object {
                $null = $ScriptDefinition.AppendLine("`r`n$_")
            }
            $null = $ScriptDefinition.AppendLine()

            # Convert the script to a single string
            $ScriptString = $ScriptDefinition.ToString()

            # Remove blank lines
            # Commented out due to risk of unintended side effects: what if the code includes a here-string that requires blank lines, etc)
            #while ( $ScriptString -match '\r\n\r\n' ) {
            # $ScriptString = $ScriptString -replace "`r`n`r`n", "`r`n"
            #}

            # Convert the script to a single scriptblock
            $ScriptBlock = [scriptblock]::Create($ScriptString)
        }

    }
    process {

        ForEach ($Object in $InputObject) {

            $CurrentObjectIndex++

            if ($ObjectStringProperty -ne '') {
                [string]$ObjectString = $Object."$ObjectStringProperty"
            } else {
                [string]$ObjectString = $Object.ToString()
            }

            Write-LogMsg @LogParams -Text "`$PowershellInterface = [powershell]::Create() # for '$Command' on '$ObjectString'"
            $PowershellInterface = [powershell]::Create()

            Write-LogMsg @LogParams -Text "`$PowershellInterface.RunspacePool = `$RunspacePool # for '$Command' on '$ObjectString'"
            $PowershellInterface.RunspacePool = $RunspacePool

            # Do I need this one? What commands would be in there?
            Write-LogMsg @LogParams -Text "`$PowershellInterface.Commands.Clear() # for '$Command' on '$ObjectString'"
            $null = $PowershellInterface.Commands.Clear()

            if ($ScriptBlock) {
                $null = Add-PsCommand @CommandInfoParams -Command $ScriptBlock -PowershellInterface $PowershellInterface
            } else {
                $null = Add-PsCommand @CommandInfoParams -Command $Command -CommandInfo $CommandInfo -PowershellInterface $PowershellInterface -Force
            }

            # Prepare to pass $InputObject into the runspace as a parameter not an argument
            # Do this even if we end up passing it as an argument to the command inside the runspace
            If ([string]::IsNullOrEmpty($InputParameter)) {
                $InputParameter = 'PsRunspaceArgument1'
            }

            Write-LogMsg @LogParams -Text "`$PowershellInterface.AddParameter('$InputParameter', '$ObjectString') # for '$Command' on '$ObjectString'"
            $null = $PowershellInterface.AddParameter($InputParameter, $Object)
            <#NormallyCommentThisForPerformanceOptimization#>$InputParameterStringForDebug = "-$InputParameter '$ObjectString'"


            $AdditionalParameters = @()
            $AdditionalParameters = ForEach ($Key in $AddParam.Keys) {
                Write-LogMsg @LogParams -Text "`$PowershellInterface.AddParameter('$Key', '$($AddParam.$key)') # for '$Command' on '$ObjectString'"
                $null = $PowershellInterface.AddParameter($Key, $AddParam.$key)
                <#NormallyCommentThisForPerformanceOptimization#>"-$Key '$($AddParam.$key)'"
            }
            $AdditionalParametersString = $AdditionalParameters -join ' '

            $Switches = @()
            $Switches = ForEach ($Switch in $AddSwitch) {
                Write-LogMsg @LogParams -Text "`$PowershellInterface.AddParameter('$Switch') # for '$Command' on '$ObjectString'"
                $null = $PowershellInterface.AddParameter($Switch)
                <#NormallyCommentThisForPerformanceOptimization#>"-$Switch"
            }
            $SwitchParameterString = $Switches -join ' '

            $StatusString = "Invoking thread $CurrentObjectIndex`: $Command $InputParameterStringForDebug $AdditionalParametersString $SwitchParameterString"
            $Progress = @{
                Activity        = $StatusString
                PercentComplete = $CurrentObjectIndex / $ThreadCount * 100
                Status          = "$($ThreadCount - $CurrentObjectIndex) remaining"
            }
            Write-Progress @Progress

            Write-LogMsg @LogParams -Text "`$Handle = `$PowershellInterface.BeginInvoke() # for '$Command' on '$ObjectString'"
            $Handle = $PowershellInterface.BeginInvoke()

            [PSCustomObject]@{
                Handle              = $Handle
                PowerShellInterface = $PowershellInterface
                Object              = $Object
                ObjectString        = $ObjectString
                Index               = $CurrentObjectIndex
                Command             = "$Command"
            }

        }

    }

    end {

        Write-Progress -Activity 'Completed' -Completed

    }
}
function Split-Thread {

    <#
    .Synopsis
        Split a command for a collection of input objects into multiple threads for asynchronous processing
    .Description
        The specified command will be run for each input object in a separate powershell instance with its own runspace
        These runspaces are part of the same runspace pool inside the same powershell.exe process
    .EXAMPLE
        The following demonstrates sending a Cmdlet name to the -Command parameter
            $InputObject | Split-Thread -Command 'Write-Output'
    .EXAMPLE
        The following demonstrates sending a scriptblock to the -Command parameter
            $InputObject | Split-Thread -Command [scriptblock]::create("Write-Output `$args[0]")
    .EXAMPLE
        The following demonstrates sending a script file path to the -Command parameter
            $InputObject | Split-Thread -Command "C:\Test-Command.ps1"
    .EXAMPLE
        The following demonstrates sending a function to the -Command parameter
            $InputObject | Split-Thread -Command 'Test-Function'
    .EXAMPLE
        The following demonstrates the -AddParam parameter

        $InputObject | Split-Thread -Command "Get-Service" -InputParameter ComputerName -AddParam @{"Name" = "BITS"}
    .EXAMPLE
        The following demonstrates the -AddSwitch parameter

        $InputObject | Split-Thread -Command "Get-Service" -AddSwitch @('RequiredServices','DependentServices')
    .EXAMPLE
        The following demonstrates the use of a threadsafe hashtable to store results
        The hastable can be accessed and updated from inside each runspace

        $ThreadsafeHashtable = [hashtable]::Synchronized(@{})
        $InputObject | Split-Thread -Command "Fake-Function" -InputParameter ComputerName -AddParam @{"ResultHashTableParameter" = $ThreadsafeHashtable}
    #>

    param (

        # PowerShell Command or Script to run against each InputObject
        [Parameter(Mandatory = $true)]
        $Command,

        # Objects to pass to the Command as an argument or parameter
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        $InputObject,

        # Named parameter of the Command to pass InputObject to
        # If this is not specified, InputObject will be passed to the Command as an argument
        $InputParameter = $null,

        # Maximum number of concurrent threads to allow
        [int]$Threads = (Get-CimInstance -ClassName CIM_Processor | Measure-Object -Sum -Property NumberOfLogicalProcessors).Sum,

        # Milliseconds to wait between cycles of the loop that checks threads for completion
        [int]$SleepTimer = 200,

        # Seconds to wait without receiving any new results before giving up and stopping all remaining threads
        [int]$Timeout = 120,

        <#
        Parameters to add to the Command
        Each parameter is a name-value pair in the hashtable:
            @{"ParameterName" = "Value"}
            @{"ParameterName" = "Value" ; "ParameterTwo" = "Value2"}
        #>
        [HashTable]$AddParam = @{},

        # Switches to add to the Command
        [string[]]$AddSwitch = @(),

        # Names of modules to import in each runspace
        [String[]]$AddModule,

        <#
        Name of a property (whose value is a string) that exists on each $InputObject and can be used to represent the object in text form
        If left null, the object's ToString() method will be used instead.
        #>
        [string]$ObjectStringProperty,

        # Will be sent to the Type parameter of Write-LogMsg in the PsLogMessage module
        [string]$DebugOutputStream = 'Silent',

        # Hostname to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$TodaysHostname = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Hashtable of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    begin {

        $LogParams = @{
            LogMsgCache  = $LogMsgCache
            ThisHostname = $TodaysHostname
            Type         = $DebugOutputStream
            WhoAmI       = $WhoAmI
        }

        $CommandInfoParams = @{
            DebugOutputStream = $DebugOutputStream
            TodaysHostname    = $TodaysHostname
            WhoAmI            = $WhoAmI
            LogMsgCache       = $LogMsgCache
        }
        Write-LogMsg @LogParams -Text " # Entered begin block for '$Command'"

        Write-LogMsg @LogParams -Text "`$InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault() # for '$Command'"
        $InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

        # Import the source module containing the specified Command in each thread

        $OriginalCommandInfo = Get-PsCommandInfo @CommandInfoParams -Command $Command
        Write-LogMsg @LogParams -Text " # Found 1 original PsCommandInfo for '$Command'"

        $CommandInfo = Expand-PsCommandInfo @CommandInfoParams -PsCommandInfo $OriginalCommandInfo
        Write-LogMsg @LogParams -Text " # Found $(($CommandInfo | Measure-Object).Count) nested PsCommandInfos for '$Command' ($($CommandInfo.CommandInfo.Name -join ','))"

        # Prepare our collection of PowerShell modules to import in each thread
        # This will include any modules specified by name with the -AddModule parameter
        $ModulesToAdd = [System.Collections.Generic.List[System.Management.Automation.PSModuleInfo]]::new()
        ForEach ($Module in $AddModule) {
            Write-LogMsg @LogParams -Text "Get-Module -Name '$Module'"
            $ModuleObj = Get-Module -Name $Module -ErrorAction SilentlyContinue
            $null = $ModulesToAdd.Add($ModuleObj)
        }

        # This will also include any modules identified by tokenizing the -Command parameter or its definition, and recursing through all nested command tokens
        $CommandInfo.ModuleInfo |
        ForEach-Object {
            $null = $ModulesToAdd.Add($_)
        }
        $ModulesToAdd = $ModulesToAdd |
        Sort-Object -Property Name -Unique

        $CommandsToAdd = $CommandInfo |
        Where-Object -FilterScript {
            (
                -not $_.ModuleInfo.Name -or
                $ModulesToAdd.Name -notcontains $_.ModuleInfo.Name
            ) -and
            $_.CommandType -ne 'Cmdlet'
        }
        Write-LogMsg @LogParams -Text " # Found $(($CommandsToAdd | Measure-Object).Count) remaining PsCommandInfos to define for '$Command' (not in modules: $($CommandsToAdd.CommandInfo.Name -join ','))"

        if ($ModulesToAdd.Count -gt 0) {
            $null = Add-PsModule -InitialSessionState $InitialSessionState -ModuleInfo $ModulesToAdd @CommandInfoParams
        }

        # Set the preference variables for PowerShell output streams in each thread to match the current preferences
        $OutputStream = @('Debug', 'Verbose', 'Information', 'Warning', 'Error')
        ForEach ($ThisStream in $OutputStream) {
            if ($ThisStream -eq 'Error') {
                $VariableName = 'ErrorActionPreference'
            } else {
                $VariableName = "$($ThisStream)Preference"
            }
            $VariableValue = (Get-Variable -Name $VariableName).Value
            $VariableEntry = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new($VariableName, $VariableValue, '')
            $InitialSessionState.Variables.Add($VariableEntry)
        }

        Write-LogMsg @LogParams -Text "`$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $Threads, `$InitialSessionState, `$Host) # for '$Command'"
        $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $Threads, $InitialSessionState, $Host)
        Write-LogMsg @LogParams -Text "`$RunspacePool.Open() # for '$Command'"
        $RunspacePool.Open()

        $Global:TimedOut = $false

        $AllInputObjects = [System.Collections.Generic.List[psobject]]::new()

    }

    process {
        if ($ObjectStringProperty) {
            $ObjectString = $InputObject.$ObjectStringProperty
        } else {
            $ObjectString = $InputObject.ToString()
        }
        Write-LogMsg @LogParams -Text " # Entered process block for '$Command' on '$ObjectString'"

        # Add all the input objects from the pipeline to a single collection; allows progress bars later
        ForEach ($ThisObject in $InputObject) {
            $null = $AllInputObjects.Add($ThisObject)
        }

    }
    end {
        Write-LogMsg @LogParams -Text " # Entered end block for '$Command'"
        Write-LogMsg @LogParams -Text " # Sending $(($CommandsToAdd | Measure-Object).Count) PsCommandInfos to Open-Thread for '$Command'"
        $ThreadParameters = @{
            Command              = $Command
            InputParameter       = $InputParameter
            InputObject          = $AllInputObjects
            AddParam             = $AddParam
            AddSwitch            = $AddSwitch
            ObjectStringProperty = $ObjectStringProperty
            CommandInfo          = $CommandsToAdd
            RunspacePool         = $RunspacePool
            DebugOutputStream    = $DebugOutputStream
            WhoAmI               = $WhoAmI
            LogMsgCache          = $LogMsgCache
        }
        $AllThreads = Open-Thread @ThreadParameters
        Write-LogMsg @LogParams -Text " # Received $(($AllThreads | Measure-Object).Count) threads from Open-Thread for $Command"

        $ThreadParameters = @{
            Thread            = $AllThreads
            Threads           = $Threads
            SleepTimer        = $SleepTimer
            Timeout           = $Timeout
            Dispose           = $true
            DebugOutputStream = $DebugOutputStream
            TodaysHostname    = $TodaysHostname
            WhoAmI            = $WhoAmI
            LogMsgCache       = $LogMsgCache
        }
        Wait-Thread @ThreadParameters
        $VerbosePreference = 'Continue'

        if ($Global:TimedOut -eq $false) {

            Write-LogMsg @LogParams -Text "[System.Management.Automation.Runspaces.RunspacePool]::Close()"
            $null = $RunspacePool.Close()
            Write-LogMsg @LogParams -Text " # [System.Management.Automation.Runspaces.RunspacePool]::Close() completed"

            Write-LogMsg @LogParams -Text "[System.Management.Automation.Runspaces.RunspacePool]::Dispose()"
            $null = $RunspacePool.Dispose()
            Write-LogMsg @LogParams -Text " # [System.Management.Automation.Runspaces.RunspacePool]::Dispose() completed"

        } else {
            # Statement-terminating error
            #$PSCmdlet.ThrowTerminatingError()

            # Script-terminating error
            throw 'Split-Thread timeout reached'
        }

        Write-Progress -Activity 'Completed' -Completed

    }

}
function Wait-Thread {

    <#
    .Synopsis
        Waits for a thread to be completed so the results can be returned, or for a timeout to be reached

    .Description
        Used by Split-Thread

    .INPUTS
        [PSCustomObject]$Thread

    .OUTPUTS
        Outputs the specified output streams from the threads
    #>

    param (

        # Threads to wait for
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [PSCustomObject[]]$Thread,

        # Maximum number of concurrent threads that are allowed (used only for progress display)
        [int]$Threads = 20,

        # Milliseconds to wait between cycles of the loop that checks threads for completion
        [int]$SleepTimer = 200,

        # Seconds to wait without receiving any new results before giving up and stopping all remaining threads
        [int]$Timeout = 120,

        # Dispose of the thread when it is finished
        [switch]$Dispose,

        # Will be sent to the Type parameter of Write-LogMsg in the PsLogMessage module
        [string]$DebugOutputStream = 'Silent',

        # Hostname to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$TodaysHostname = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Hashtable of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    begin {

        $LogParams = @{
            LogMsgCache  = $LogMsgCache
            ThisHostname = $TodaysHostname
            Type         = $DebugOutputStream
            WhoAmI       = $WhoAmI
        }

        $StopWatch = [System.Diagnostics.Stopwatch]::new()
        $StopWatch.Start()

        $AllThreads = [System.Collections.Generic.List[PSCustomObject]]::new()

        $FirstThread = $Thread | Select-Object -First 1

        $RunspacePool = $FirstThread.PowershellInterface.RunspacePool

        $CommandString = $FirstThread.Command

    }

    process {

        ForEach ($ThisThread in $Thread) {

            # If the threads do not have handles, there is nothing to wait for, so output the thread as-is.
            # Otherwise wait for the handle to indicate completion (or a timeout to be reached)
            if ($ThisThread.Handle -eq $false) {
                Write-LogMsg @LogParams -Text "`$PowerShellInterface.Streams.ClearStreams() # for '$CommandString' on '$($ThisThread.ObjectString)'"
                $null = $ThisThread.PowerShellInterface.Streams.ClearStreams()
                $ThisThread
            } else {
                $null = $AllThreads.Add($ThisThread)
            }

        }

    }

    end {

        # If the threads have handles, we can check to see if they are complete.
        While (@($AllThreads | Where-Object -FilterScript { $null -ne $_.Handle }).Count -gt 0) {

            Write-LogMsg @LogParams -Text "Start-Sleep -Milliseconds $SleepTimer # for '$CommandString'"
            Start-Sleep -Milliseconds $SleepTimer

            if ($RunspacePool) { $AvailableRunspaces = $RunspacePool.GetAvailableRunspaces() }

            $CleanedUpThreads = [System.Collections.Generic.List[PSCustomObject]]::new()
            $CompletedThreads = [System.Collections.Generic.List[PSCustomObject]]::new()
            $IncompleteThreads = [System.Collections.Generic.List[PSCustomObject]]::new()
            ForEach ($ThisThread in $AllThreads) {
                if ($null -eq $ThisThread.Handle) {
                    $null = $CleanedUpThreads.Add($ThisThread)
                }
                if ($ThisThread.Handle.IsCompleted -eq $true) {
                    $null = $CompletedThreads.Add($ThisThread)
                }
                if ($ThisThread.Handle.IsCompleted -eq $false) {
                    $null = $IncompleteThreads.Add($ThisThread)
                }
            }

            $ActiveThreadCountString = "$($Threads - $AvailableRunspaces) of $Threads are active"

            Write-LogMsg @LogParams -Text " # $ActiveThreadCountString for '$CommandString'"
            Write-LogMsg @LogParams -Text " # $($CompletedThreads.Count) completed threads for '$CommandString'"
            Write-LogMsg @LogParams -Text " # $($CleanedUpThreads.Count) cleaned up threads for '$CommandString'"
            Write-LogMsg @LogParams -Text " # $($IncompleteThreads.Count) incomplete threads for '$CommandString'"

            $RemainingString = "$($IncompleteThreads.ObjectString)"
            If ($RemainingString.Length -gt 60) {
                $RemainingString = $RemainingString.Substring(0, 60) + "..."
            }

            $Progress = @{
                Activity        = "Waiting on threads - $ActiveThreadCountString`: $CommandString"
                PercentComplete = ($($CleanedUpThreads).count) / @($Thread).Count * 100
                Status          = "$(@($IncompleteThreads).Count) remaining - $RemainingString"
            }
            Write-Progress @Progress

            ForEach ($CompletedThread in $CompletedThreads) {

                # TODO: Debug these counts, something seems off, they vary wildly with Test-Multithreading.ps1 but I would expect consistency (same number of Warnings per thread)
                Write-LogMsg @LogParams -Text " # $($CompletedThread.PowerShellInterface.Streams.Progress.Count) Progress messages for '$CommandString' on '$($CompletedThread.ObjectString)'"
                Write-LogMsg @LogParams -Text " # $($CompletedThread.PowerShellInterface.Streams.Information.Count) Information messages for '$CommandString' on '$($CompletedThread.ObjectString)'"
                Write-LogMsg @LogParams -Text " # $($CompletedThread.PowerShellInterface.Streams.Verbose.Count) Verbose messages for '$CommandString' on '$($CompletedThread.ObjectString)'"
                Write-LogMsg @LogParams -Text " # $($CompletedThread.PowerShellInterface.Streams.Debug.Count) Debug messages for '$CommandString' on '$($CompletedThread.ObjectString)'"
                Write-LogMsg @LogParams -Text " # $($CompletedThread.PowerShellInterface.Streams.Warning.Count) Warning messages for '$CommandString' on '$($CompletedThread.ObjectString)'"

                # Because $Host was used to create the RunspacePool, any output to $Host (which includes Write-Host and Write-Information and Write-Progress) has already been displayed
                #$CompletedThread.PowerShellInterface.Streams.Progress | ForEach-Object {Write-Progress "$_"}
                #$CompletedThread.PowerShellInterface.Streams.Information | ForEach-Object { Write-Information "$_" }
                #$CompletedThread.PowerShellInterface.Streams.Verbose | ForEach-Object { Write-Verbose "$_" }
                #$CompletedThread.PowerShellInterface.Streams.Debug | ForEach-Object { Write-Debug "$_" }
                #$CompletedThread.PowerShellInterface.Streams.Warning | ForEach-Object { Write-Warning "$_" }

                Write-LogMsg @LogParams -Text "`$PowerShellInterface.Streams.ClearStreams() # for '$CommandString' on '$($CompletedThread.ObjectString)'"
                $null = $CompletedThread.PowerShellInterface.Streams.ClearStreams()

                Write-LogMsg @LogParams -Text "`$PowerShellInterface.EndInvoke(`$Handle) # for '$CommandString' on '$($CompletedThread.ObjectString)'"
                $ThreadOutput = $CompletedThread.PowerShellInterface.EndInvoke($CompletedThread.Handle)

                if (@($ThreadOutput).Count -gt 0) {
                    Write-LogMsg @LogParams -Text " # Output (count of $(@($ThreadOutput).Count)) received from thread $($CompletedThread.Index): $($CompletedThread.ObjectString)"
                } else {
                    Write-LogMsg @LogParams -Text " # Null result for thread $($CompletedThread.Index) ($($CompletedThread.ObjectString))"
                }

                if ($Dispose -eq $true) {
                    $ThreadOutput
                    Write-LogMsg @LogParams -Text "`$PowerShellInterface.Dispose() # for '$CommandString' on '$($CompletedThread.ObjectString)'"
                    $null = $CompletedThread.PowerShellInterface.Dispose()
                    $CompletedThread.PowerShellInterface = $null
                    $CompletedThread.Handle = $null
                } else {
                    Write-LogMsg @LogParams -Text " # Thread $($CompletedThread.Index) is finished opening for '$CommandString' on '$($CompletedThread.ObjectString)'"
                    $CompletedThread.Handle = $null
                    $CompletedThread
                }

                $StopWatch.Reset()
                $StopWatch.Start()

            }

            If ($StopWatch.ElapsedMilliseconds / 1000 -gt $Timeout) {

                Write-Warning " Reached Timeout of $Timeout seconds. Skipping $($IncompleteThreads.Count) remaining threads: $RemainingString"

                $Global:TimedOut = $true

                $IncompleteThreads |
                ForEach-Object {
                    $_.Handle = $null
                    [PSCustomObject]@{
                        Handle              = $null
                        PowerShellInterface = $_.PowershellInterface
                        Object              = $_.Object
                        ObjectString        = $_.ObjectString
                        Index               = $_.CurrentObjectIndex
                        Command             = $_.Command
                    }
                }
            }

        }

        $StopWatch.Stop()

        Write-LogMsg @LogParams -Text " # Finished waiting for threads"
        Write-Progress -Activity 'Completed' -Completed

    }

}
<#
# Dot source any functions
ForEach ($ThisScript in $ScriptFiles) {
    # Dot source the function
    . $($ThisScript.FullName)
}
#>
Import-Module PsLogMessage -ErrorAction SilentlyContinue

# Definition of Module 'PsDfs' is below

Function Get-DfsNetInfo {
    # Wrapper for the NetDfsGetInfo([string]) method in the lmdfs.h header in NetApi32.dll for Distributed File Systems
    [CmdletBinding()]
    Param (

        [PSCredential]$Credentials,

        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({
                Test-Path -LiteralPath $_ -PathType Container
            })]
        [String[]]$FolderPath

    )

    Process {

        foreach ($ThisFolderPath in $FolderPath) {

            $Split = $ThisFolderPath -split '\\'
            $ServerOrDomain = $Split[0]
            $DfsNamespace = $Split[1]
            $DfsLink = ""
            $Remainder = ""

            <#
            # Use the NetDfsGetInfo method instead as it does not filter out disabled folder targets
            # But it does not work
            #>
            #[NetApi32Dll]::NetDfsGetClientInfo($ThisFolderPath)

            #[NetApi32Dll]::NetDfsEnum($ThisFolderPath)

            [NetApi32Dll]::NetDfsGetInfo($ThisFolderPath)

        }

    }

}
function Get-FileShareInfo {
    # Get the corresponding local file path for DFS folder targets (which are UNC paths)
    param (

        [Parameter(ValueFromPipeline)]
        [psobject[]]$ServerAndShare

    )

    process {

        # State 6 notes that the DFS path is online and active
        #$DFS = $DfsNetClientInfo #| Where-Object -FilterScript { $_.State -eq 6 }

        ForEach ($DFS in $ServerAndShare) {

            $SessionParams = @{
                #Credential = $Credentials
                ComputerName  = $DFS.ServerName
                SessionOption = New-CimSessionOption -Protocol Dcom
            }
            $CimParams = @{
                CimSession = New-CimSession @SessionParams
                ClassName  = 'Win32_Share'
            }

            $ShareName = ($DFS.ShareName -split '\\')[0]
            $ShareLocalPath = Get-CimInstance @CimParams |
            Where-Object Name -EQ $ShareName
            $LocalPath = $DFS.ShareName -replace [regex]::Escape("$ShareName\"), $ShareLocalPath.Path

            $DFS | Add-Member -PassThru -NotePropertyMembers @{
                #DfsPath = $DFS.DfsPath
                FolderTarget = "$($DFS.ServerName)\$($DFS.ShareName)\$($DFS.DfsPath -replace [regex]::Escape($DFS.ShareName))"
                #DfsState = $DFS.State
                #ServerName = $DFS.ServerName
                #ShareName = $DFS.ShareName
                LocalPath    = $LocalPath
            }

        }

    }

}
Function Get-NetDfsEnum {
    # Wrapper for the NetDfsEnum([string]) method in the lmdfs.h header in NetApi32.dll for Distributed File Systems
    [CmdletBinding()]
    Param (

        [PSCredential]$Credentials,

        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({
                Test-Path -LiteralPath $_ -PathType Container
            })]
        [String[]]$FolderPath

    )

    Process {

        foreach ($ThisFolderPath in $FolderPath) {

            $Split = $ThisFolderPath -split '\\'
            $ServerOrDomain = $Split[0]
            $DfsNamespace = $Split[1]
            $DfsLink = ""
            $Remainder = ""

            <#
            # Use the NetDfsGetInfo method instead as it does not filter out disabled folder targets
            # But it does not work
            #>
            #[NetApi32Dll]::NetDfsGetClientInfo($ThisFolderPath)

            [NetApi32Dll]::NetDfsEnum($ThisFolderPath)

            #[NetApi32Dll]::NetDfsGetInfo($ThisFolderPath)

        }

    }

}

Add-Type -ErrorAction Stop -TypeDefinition @"


using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Management.Automation;
using System.Runtime.InteropServices;

public class NetApi32Dll
{

    [DllImport("netapi32.dll", SetLastError = true)]
    private static extern int NetApiBufferFree
    (
        IntPtr buffer
    );

    [DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int NetDfsEnum
    (
        [MarshalAs(UnmanagedType.LPWStr)] string DfsName,
        int Level,
        int PrefMaxLen,
        out IntPtr Buffer,
        [MarshalAs(UnmanagedType.I4)] out int EntriesRead,
        [MarshalAs(UnmanagedType.I4)] ref int ResumeHandle
    );

    [DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int NetDfsGetClientInfo
    (
        [MarshalAs(UnmanagedType.LPWStr)] string EntryPath,
        [MarshalAs(UnmanagedType.LPWStr)] string ServerName,
        [MarshalAs(UnmanagedType.LPWStr)] string ShareName,
        int Level,
        ref IntPtr Buffer
    );

    [DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int NetDfsGetInfo
    (
        [MarshalAs(UnmanagedType.LPWStr)] string EntryPath,
        [MarshalAs(UnmanagedType.LPWStr)] string ServerName,
        [MarshalAs(UnmanagedType.LPWStr)] string ShareName,
        int Level,
        ref IntPtr Buffer
    );

    public struct DFS_INFO_3
    {
        [MarshalAs(UnmanagedType.LPWStr)] public string EntryPath;
        [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
        public UInt32 State;
        public UInt32 NumberOfStorages;
        public IntPtr Storages;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DFS_INFO_6
    {
        [MarshalAs(UnmanagedType.LPWStr)] public string EntryPath;
        [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
        public UInt32 State;
        public UInt64 Timeout;
        public Guid Guid;
        public UInt32 NumberOfStorages;
        public UInt64 MetadataSize;
        public UInt64 PropertyFlags;
        public IntPtr Storages;
    }

    public struct DFS_STORAGE_INFO
    {
        public Int32 State;
        [MarshalAs(UnmanagedType.LPWStr)] public string ServerName;
        [MarshalAs(UnmanagedType.LPWStr)] public string ShareName;
    }
    public struct DFS_STORAGE_INFO_1
    {
        public DFS_STORAGE_STATE State;
        [MarshalAs(UnmanagedType.LPWStr)] public string ServerName;
        [MarshalAs(UnmanagedType.LPWStr)] public string ShareName;
        public DFS_TARGET_PRIORITY TargetPriority;
    }

    public struct DFS_TARGET_PRIORITY
    {
        public DFS_TARGET_PRIORITY_CLASS TargetPriorityClass;
        public UInt16 TargetPriorityRank;
        public UInt16 Reserved;
    }

    public enum DFS_TARGET_PRIORITY_CLASS
    {
        DfsInvalidPriorityClass = -1,
        DfsSiteCostNormalPriorityClass = 0,
        DfsGlobalHighPriorityClass = 1,
        DfsSiteCostHighPriorityClass = 2,
        DfsSiteCostLowPriorityClass = 3,
        DfsGlobalLowPriorityClass = 4
    }

    public enum DFS_STORAGE_STATE
    {
        DFS_STORAGE_STATE_OFFLINE = 1,

        DFS_STORAGE_STATE_ONLINE = 2,

        DFS_STORAGE_STATE_ACTIVE = 4,

        DFS_STORAGE_STATES = 0xF,
    }

    public static List<PSObject> NetDfsEnum(string DfsName)
    {

        IntPtr buffer = new IntPtr();
        int EntriesRead = 0;
        int ResumeHere = 0;
        List<PSObject> returnList = new List<PSObject>();
        const int MAX_PREFERRED_LENGTH = 0xFFFFFFF;
        const int NERR_Success = 0;

        try
        {
            int result = NetDfsEnum(DfsName, 3, MAX_PREFERRED_LENGTH, out buffer, out EntriesRead, ref ResumeHere);

            if (result != NERR_Success)
            {
                string errorMessage = new Win32Exception(Marshal.GetLastWin32Error()).Message;

                throw (new SystemException("NetDfsEnum error. System Error Code: " + result + " - " + errorMessage));
            }
            else
            {

                for (int n = 0; n < EntriesRead; n++)
                {

                    IntPtr DfsPtr = new IntPtr(buffer.ToInt64() + n * Marshal.SizeOf(typeof(DFS_INFO_3)));
                    object dfsObject = Marshal.PtrToStructure(DfsPtr, typeof(DFS_INFO_3));
                    DFS_INFO_3 dfsInfo = (DFS_INFO_3)dfsObject;

                    for (int i = 0; i < dfsInfo.NumberOfStorages; i++)
                    {
                        IntPtr storage = new IntPtr(dfsInfo.Storages.ToInt64() + i * Marshal.SizeOf(typeof(DFS_STORAGE_INFO)));

                        DFS_STORAGE_INFO storageInfo = (DFS_STORAGE_INFO)Marshal.PtrToStructure(storage, typeof(DFS_STORAGE_INFO));

                        PSObject psObject = new PSObject();
                        psObject.Properties.Add(new PSNoteProperty("FullOriginalQueryPath", DfsName));
                        psObject.Properties.Add(new PSNoteProperty("DfsEntryPath", dfsInfo.EntryPath));
                        psObject.Properties.Add(new PSNoteProperty("DfsTarget", System.IO.Path.Combine(new string[] { @"\\", storageInfo.ServerName, storageInfo.ShareName })));
                        psObject.Properties.Add(new PSNoteProperty("DfsTargetState", storageInfo.State));
                        psObject.Properties.Add(new PSNoteProperty("TargetServerName", storageInfo.ServerName));
                        psObject.Properties.Add(new PSNoteProperty("TargetShareName", storageInfo.ShareName));

                        returnList.Add(psObject);
                    }

                }
            }
        }
        finally
        {
            NetApiBufferFree(buffer);
        }
        return returnList;
    }

    public static List<PSObject> NetDfsEnum6(string DfsName)
    {

        IntPtr buffer = new IntPtr();
        int EntriesRead = 0;
        int ResumeHere = 0;
        List<PSObject> returnList = new List<PSObject>();
        const int MAX_PREFERRED_LENGTH = 0xFFFFFFF;
        const int NERR_Success = 0;
        const int Level = 6;

        try
        {
            int result = NetDfsEnum(DfsName, Level, MAX_PREFERRED_LENGTH, out buffer, out EntriesRead, ref ResumeHere);

            if (result != NERR_Success)
            {
                string errorMessage = new Win32Exception(Marshal.GetLastWin32Error()).Message;
                string customErrorMessage = "NetDfsEnum error for '" + DfsName + "'. System Error Code: " + result + " - " + errorMessage;
                throw (new SystemException(customErrorMessage));
            }
            else
            {

                Int64 dfsStart = buffer.ToInt64();
                Type dfsType = typeof(DFS_INFO_6);
                Int64 dfsSize = Marshal.SizeOf(dfsType);

                for (int n = 0; n < EntriesRead; n++)
                {

                    IntPtr dfsPtr = new IntPtr(dfsStart + n * dfsSize);

                    object dfsObject = Marshal.PtrToStructure(dfsPtr, dfsType);
                    DFS_INFO_6 dfsInfo = (DFS_INFO_6)dfsObject;

                    //if (dfsInfo.EntryPath == DfsName) { // skip link for namespace
                    // continue;
                    //}

                    Int64 storagesStart = dfsInfo.Storages.ToInt64();
                    Type storageType = typeof(DFS_STORAGE_INFO_1);
                    Int64 storageSize = Marshal.SizeOf(storageType);

                    for (int i = 0; i < dfsInfo.NumberOfStorages; i++)
                    {

                        //Attempted some different properties in case they were mis-mapped the same way that NumberofStorages was
                        //Int64 StartPoint = Convert.ToInt64(dfsInfo.MetadataSize); //System.AccessViolationException
                        //Int64 StartPoint = Convert.ToInt64(dfsInfo.PropertyFlags); //System.AccessViolationException
                        //Int64 StartPoint = Convert.ToInt64(dfsInfo.Timeout); //System.AccessViolationException
                        //IntPtr storagePtr = new IntPtr(StartPoint);

                        IntPtr storagePtr = new IntPtr(storagesStart + i * storageSize);
                        object storageObject = Marshal.PtrToStructure(storagePtr, storageType); //System.NullReferenceException
                        DFS_STORAGE_INFO_1 storageInfo = (DFS_STORAGE_INFO_1)storageObject;
                        PSObject psObject = new PSObject();
                        psObject.Properties.Add(new PSNoteProperty("FullOriginalQueryPath", DfsName));
                        psObject.Properties.Add(new PSNoteProperty("DfsEntryPath", dfsInfo.EntryPath));
                        psObject.Properties.Add(new PSNoteProperty("DfsTarget", System.IO.Path.Combine(new string[] { @"", storageInfo.ServerName, storageInfo.ShareName })));
                        psObject.Properties.Add(new PSNoteProperty("DfsTargetState", storageInfo.State));
                        psObject.Properties.Add(new PSNoteProperty("TargetServerName", storageInfo.ServerName));
                        psObject.Properties.Add(new PSNoteProperty("TargetShareName", storageInfo.ShareName));

                        returnList.Add(psObject);
                    }

                }
            }
        }
        finally
        {
            NetApiBufferFree(buffer);
        }

        return returnList;
    }

    public static List<PSObject> NetDfsGetInfo(string DfsEntryPath)
    {
        IntPtr buffer = new IntPtr();
        List<PSObject> returnList = new List<PSObject>();

        try
        {
            int result = NetDfsGetInfo(DfsEntryPath, null, null, 3, ref buffer);

            if (result != 0)
            {
                throw (new SystemException("Error getting DFS information"));
            }
            else
            {
                DFS_INFO_3 dfsInfo = (DFS_INFO_3)Marshal.PtrToStructure(buffer, typeof(DFS_INFO_3));

                for (int i = 0; i < dfsInfo.NumberOfStorages; i++)
                {
                    IntPtr storage = new IntPtr(dfsInfo.Storages.ToInt64() + i * Marshal.SizeOf(typeof(DFS_STORAGE_INFO)));

                    DFS_STORAGE_INFO storageInfo = (DFS_STORAGE_INFO)Marshal.PtrToStructure(storage, typeof(DFS_STORAGE_INFO));

                    PSObject psObject = new PSObject();

                    psObject.Properties.Add(new PSNoteProperty("State", storageInfo.State));
                    psObject.Properties.Add(new PSNoteProperty("ServerName", storageInfo.ServerName));
                    psObject.Properties.Add(new PSNoteProperty("ShareName", storageInfo.ShareName));

                    returnList.Add(psObject);
                }
            }
        }
        finally
        {
            NetApiBufferFree(buffer);
        }
        return returnList;
    }

    public static List<PSObject> NetDfsGetClientInfo(string DfsPath)
    {
        IntPtr buffer = new IntPtr();
        List<PSObject> returnList = new List<PSObject>();

        try
        {
            int result = NetDfsGetClientInfo(DfsPath, null, null, 3, ref buffer);

            if (result != 0)
            {
                throw (new SystemException("Error getting DFS information"));
            }
            else
            {
                DFS_INFO_3 dfsInfo = (DFS_INFO_3)Marshal.PtrToStructure(buffer, typeof(DFS_INFO_3));

                for (int i = 0; i < dfsInfo.NumberOfStorages; i++)
                {
                    IntPtr storage = new IntPtr(dfsInfo.Storages.ToInt64() + i * Marshal.SizeOf(typeof(DFS_STORAGE_INFO)));

                    DFS_STORAGE_INFO storageInfo = (DFS_STORAGE_INFO)Marshal.PtrToStructure(storage, typeof(DFS_STORAGE_INFO));

                    PSObject psObject = new PSObject();

                    psObject.Properties.Add(new PSNoteProperty("State", storageInfo.State));
                    psObject.Properties.Add(new PSNoteProperty("ServerName", storageInfo.ServerName));
                    psObject.Properties.Add(new PSNoteProperty("ShareName", storageInfo.ShareName));

                    returnList.Add(psObject);
                }
            }
        }
        finally
        {
            NetApiBufferFree(buffer);
        }
        return returnList;
    }

}


"@

# Definition of Module 'PsBootstrapCss' is below

Function ConvertTo-BootstrapListGroup {
    <#
        .SYNOPSIS
            Upgrade a boring HTML list to a fancy Bootstrap list group
        .DESCRIPTION
            Applies the Bootstrap 'list-group' CSS class to an HTML list
            Applies the Bootstrap 'list-group-item' CSS class to each list item
        .OUTPUTS
            A string wih the code for the Bootstrap list
        .EXAMPLE
            1,2,3 |
            ConvertTo-HtmlList |
            ConvertTo-BootstrapListGroup

            This example returns the following string:
            '<ul class ="list-group"><li class ="list-group-item>1</li><li class ="list-group-item>2</li><li class ="list-group-item>3</li></ul>'
    #>
    [OutputType([System.String])]
    [CmdletBinding()]
    param(
        #The HTML table to apply the Bootstrap striped table CSS class to
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [System.String[]]$HtmlList
    )
    process {
        ForEach ($List in $HtmlList) {

            $List -replace
            '<ul>', '<ul class="list-group">' -replace
            '<ol>', '<ol class="list-group">' -replace
            '<li>', '<li class ="list-group-item">'

        }
    }
}
function ConvertTo-HtmlList {
    param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true
        )]
        [string[]]$InputObject,
        [switch]$Ordered
    )
    begin {

        if ($Ordered) {
            $ListType = 'ol'
        } else {
            $ListType = 'ul'
        }

        $StringBuilder = [System.Text.StringBuilder]::new("<$ListType>")

    }
    process {
        ForEach ($ThisObject in $InputObject) {
            $null = $StringBuilder.Append("<li>$ThisObject</li>")
        }
    }
    end {
        $null = $StringBuilder.Append("</$ListType>")
        $StringBuilder.ToString()
    }
}
function Get-BootstrapTemplate {
    @"
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"><html xmlns="http://www.w3.org/1999/xhtml"><head> <style type="text/css">
/*!
 * Bootstrap v5.1.3 (https://getbootstrap.com/)
 * Copyright 2011-2021 The Bootstrap Authors
 * Copyright 2011-2021 Twitter, Inc.
 * Licensed under MIT (https://github.com/twbs/bootstrap/blob/main/LICENSE)
 */
 :root{--bs-blue:#0d6efd;--bs-indigo:#6610f2;--bs-purple:#6f42c1;--bs-pink:#d63384;--bs-red:#dc3545;--bs-orange:#fd7e14;--bs-yellow:#ffc107;--bs-green:#198754;--bs-teal:#20c997;--bs-cyan:#0dcaf0;--bs-white:#fff;--bs-gray:#6c757d;--bs-gray-dark:#343a40;--bs-gray-100:#f8f9fa;--bs-gray-200:#e9ecef;--bs-gray-300:#dee2e6;--bs-gray-400:#ced4da;--bs-gray-500:#adb5bd;--bs-gray-600:#6c757d;--bs-gray-700:#495057;--bs-gray-800:#343a40;--bs-gray-900:#212529;--bs-primary:#0d6efd;--bs-secondary:#6c757d;--bs-success:#198754;--bs-info:#0dcaf0;--bs-warning:#ffc107;--bs-danger:#dc3545;--bs-light:#f8f9fa;--bs-dark:#212529;--bs-primary-rgb:13,110,253;--bs-secondary-rgb:108,117,125;--bs-success-rgb:25,135,84;--bs-info-rgb:13,202,240;--bs-warning-rgb:255,193,7;--bs-danger-rgb:220,53,69;--bs-light-rgb:248,249,250;--bs-dark-rgb:33,37,41;--bs-white-rgb:255,255,255;--bs-black-rgb:0,0,0;--bs-body-color-rgb:33,37,41;--bs-body-bg-rgb:255,255,255;--bs-font-sans-serif:system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,"Noto Sans","Liberation Sans",sans-serif,"Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol","Noto Color Emoji";--bs-font-monospace:SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono","Courier New",monospace;--bs-gradient:linear-gradient(180deg, rgba(255, 255, 255, 0.15), rgba(255, 255, 255, 0));--bs-body-font-family:var(--bs-font-sans-serif);--bs-body-font-size:1rem;--bs-body-font-weight:400;--bs-body-line-height:1.5;--bs-body-color:#212529;--bs-body-bg:#fff}*,::after,::before{box-sizing:border-box}@media (prefers-reduced-motion:no-preference){:root{scroll-behavior:smooth}}body{margin:0;font-family:var(--bs-body-font-family);font-size:var(--bs-body-font-size);font-weight:var(--bs-body-font-weight);line-height:var(--bs-body-line-height);color:var(--bs-body-color);text-align:var(--bs-body-text-align);background-color:var(--bs-body-bg);-webkit-text-size-adjust:100%;-webkit-tap-highlight-color:transparent}hr{margin:1rem 0;color:inherit;background-color:currentColor;border:0;opacity:.25}hr:not([size]){height:1px}.h1,.h2,.h3,.h4,.h5,.h6,h1,h2,h3,h4,h5,h6{margin-top:0;margin-bottom:.5rem;font-weight:500;line-height:1.2}.h1,h1{font-size:calc(1.375rem + 1.5vw)}@media (min-width:1200px){.h1,h1{font-size:2.5rem}}.h2,h2{font-size:calc(1.325rem + .9vw)}@media (min-width:1200px){.h2,h2{font-size:2rem}}.h3,h3{font-size:calc(1.3rem + .6vw)}@media (min-width:1200px){.h3,h3{font-size:1.75rem}}.h4,h4{font-size:calc(1.275rem + .3vw)}@media (min-width:1200px){.h4,h4{font-size:1.5rem}}.h5,h5{font-size:1.25rem}.h6,h6{font-size:1rem}p{margin-top:0;margin-bottom:1rem}abbr[data-bs-original-title],abbr[title]{-webkit-text-decoration:underline dotted;text-decoration:underline dotted;cursor:help;-webkit-text-decoration-skip-ink:none;text-decoration-skip-ink:none}address{margin-bottom:1rem;font-style:normal;line-height:inherit}ol,ul{padding-left:2rem}dl,ol,ul{margin-top:0;margin-bottom:1rem}ol ol,ol ul,ul ol,ul ul{margin-bottom:0}dt{font-weight:700}dd{margin-bottom:.5rem;margin-left:0}blockquote{margin:0 0 1rem}b,strong{font-weight:bolder}.small,small{font-size:.875em}.mark,mark{padding:.2em;background-color:#fcf8e3}sub,sup{position:relative;font-size:.75em;line-height:0;vertical-align:baseline}sub{bottom:-.25em}sup{top:-.5em}a{color:#0d6efd;text-decoration:underline}a:hover{color:#0a58ca}a:not([href]):not([class]),a:not([href]):not([class]):hover{color:inherit;text-decoration:none}code,kbd,pre,samp{font-family:var(--bs-font-monospace);font-size:1em;direction:ltr;unicode-bidi:bidi-override}pre{display:block;margin-top:0;margin-bottom:1rem;overflow:auto;font-size:.875em}pre code{font-size:inherit;color:inherit;word-break:normal}code{font-size:.875em;color:#d63384;word-wrap:break-word}a>code{color:inherit}kbd{padding:.2rem .4rem;font-size:.875em;color:#fff;background-color:#212529;border-radius:.2rem}kbd kbd{padding:0;font-size:1em;font-weight:700}figure{margin:0 0 1rem}img,svg{vertical-align:middle}table{caption-side:bottom;border-collapse:collapse}caption{padding-top:.5rem;padding-bottom:.5rem;color:#6c757d;text-align:left}th{text-align:inherit;text-align:-webkit-match-parent}tbody,td,tfoot,th,thead,tr{border-color:inherit;border-style:solid;border-width:0}label{display:inline-block}button{border-radius:0}button:focus:not(:focus-visible){outline:0}button,input,optgroup,select,textarea{margin:0;font-family:inherit;font-size:inherit;line-height:inherit}button,select{text-transform:none}[role=button]{cursor:pointer}select{word-wrap:normal}select:disabled{opacity:1}[list]::-webkit-calendar-picker-indicator{display:none}[type=button],[type=reset],[type=submit],button{-webkit-appearance:button}[type=button]:not(:disabled),[type=reset]:not(:disabled),[type=submit]:not(:disabled),button:not(:disabled){cursor:pointer}::-moz-focus-inner{padding:0;border-style:none}textarea{resize:vertical}fieldset{min-width:0;padding:0;margin:0;border:0}legend{float:left;width:100%;padding:0;margin-bottom:.5rem;font-size:calc(1.275rem + .3vw);line-height:inherit}@media (min-width:1200px){legend{font-size:1.5rem}}legend+*{clear:left}::-webkit-datetime-edit-day-field,::-webkit-datetime-edit-fields-wrapper,::-webkit-datetime-edit-hour-field,::-webkit-datetime-edit-minute,::-webkit-datetime-edit-month-field,::-webkit-datetime-edit-text,::-webkit-datetime-edit-year-field{padding:0}::-webkit-inner-spin-button{height:auto}[type=search]{outline-offset:-2px;-webkit-appearance:textfield}::-webkit-search-decoration{-webkit-appearance:none}::-webkit-color-swatch-wrapper{padding:0}::-webkit-file-upload-button{font:inherit}::file-selector-button{font:inherit}::-webkit-file-upload-button{font:inherit;-webkit-appearance:button}output{display:inline-block}iframe{border:0}summary{display:list-item;cursor:pointer}progress{vertical-align:baseline}[hidden]{display:none!important}.lead{font-size:1.25rem;font-weight:300}.display-1{font-size:calc(1.625rem + 4.5vw);font-weight:300;line-height:1.2}@media (min-width:1200px){.display-1{font-size:5rem}}.display-2{font-size:calc(1.575rem + 3.9vw);font-weight:300;line-height:1.2}@media (min-width:1200px){.display-2{font-size:4.5rem}}.display-3{font-size:calc(1.525rem + 3.3vw);font-weight:300;line-height:1.2}@media (min-width:1200px){.display-3{font-size:4rem}}.display-4{font-size:calc(1.475rem + 2.7vw);font-weight:300;line-height:1.2}@media (min-width:1200px){.display-4{font-size:3.5rem}}.display-5{font-size:calc(1.425rem + 2.1vw);font-weight:300;line-height:1.2}@media (min-width:1200px){.display-5{font-size:3rem}}.display-6{font-size:calc(1.375rem + 1.5vw);font-weight:300;line-height:1.2}@media (min-width:1200px){.display-6{font-size:2.5rem}}.list-unstyled{padding-left:0;list-style:none}.list-inline{padding-left:0;list-style:none}.list-inline-item{display:inline-block}.list-inline-item:not(:last-child){margin-right:.5rem}.initialism{font-size:.875em;text-transform:uppercase}.blockquote{margin-bottom:1rem;font-size:1.25rem}.blockquote>:last-child{margin-bottom:0}.blockquote-footer{margin-top:-1rem;margin-bottom:1rem;font-size:.875em;color:#6c757d}.blockquote-footer::before{content:"— "}.img-fluid{max-width:100%;height:auto}.img-thumbnail{padding:.25rem;background-color:#fff;border:1px solid #dee2e6;border-radius:.25rem;max-width:100%;height:auto}.figure{display:inline-block}.figure-img{margin-bottom:.5rem;line-height:1}.figure-caption{font-size:.875em;color:#6c757d}.container,.container-fluid,.container-lg,.container-md,.container-sm,.container-xl,.container-xxl{width:100%;padding-right:var(--bs-gutter-x,.75rem);padding-left:var(--bs-gutter-x,.75rem);margin-right:auto;margin-left:auto}@media (min-width:576px){.container,.container-sm{max-width:540px}}@media (min-width:768px){.container,.container-md,.container-sm{max-width:720px}}@media (min-width:992px){.container,.container-lg,.container-md,.container-sm{max-width:960px}}@media (min-width:1200px){.container,.container-lg,.container-md,.container-sm,.container-xl{max-width:1140px}}@media (min-width:1400px){.container,.container-lg,.container-md,.container-sm,.container-xl,.container-xxl{max-width:1320px}}.row{--bs-gutter-x:1.5rem;--bs-gutter-y:0;display:flex;flex-wrap:wrap;margin-top:calc(-1 * var(--bs-gutter-y));margin-right:calc(-.5 * var(--bs-gutter-x));margin-left:calc(-.5 * var(--bs-gutter-x))}.row>*{flex-shrink:0;width:100%;max-width:100%;padding-right:calc(var(--bs-gutter-x) * .5);padding-left:calc(var(--bs-gutter-x) * .5);margin-top:var(--bs-gutter-y)}.col{flex:1 0 0%}.row-cols-auto>*{flex:0 0 auto;width:auto}.row-cols-1>*{flex:0 0 auto;width:100%}.row-cols-2>*{flex:0 0 auto;width:50%}.row-cols-3>*{flex:0 0 auto;width:33.3333333333%}.row-cols-4>*{flex:0 0 auto;width:25%}.row-cols-5>*{flex:0 0 auto;width:20%}.row-cols-6>*{flex:0 0 auto;width:16.6666666667%}.col-auto{flex:0 0 auto;width:auto}.col-1{flex:0 0 auto;width:8.33333333%}.col-2{flex:0 0 auto;width:16.66666667%}.col-3{flex:0 0 auto;width:25%}.col-4{flex:0 0 auto;width:33.33333333%}.col-5{flex:0 0 auto;width:41.66666667%}.col-6{flex:0 0 auto;width:50%}.col-7{flex:0 0 auto;width:58.33333333%}.col-8{flex:0 0 auto;width:66.66666667%}.col-9{flex:0 0 auto;width:75%}.col-10{flex:0 0 auto;width:83.33333333%}.col-11{flex:0 0 auto;width:91.66666667%}.col-12{flex:0 0 auto;width:100%}.offset-1{margin-left:8.33333333%}.offset-2{margin-left:16.66666667%}.offset-3{margin-left:25%}.offset-4{margin-left:33.33333333%}.offset-5{margin-left:41.66666667%}.offset-6{margin-left:50%}.offset-7{margin-left:58.33333333%}.offset-8{margin-left:66.66666667%}.offset-9{margin-left:75%}.offset-10{margin-left:83.33333333%}.offset-11{margin-left:91.66666667%}.g-0,.gx-0{--bs-gutter-x:0}.g-0,.gy-0{--bs-gutter-y:0}.g-1,.gx-1{--bs-gutter-x:0.25rem}.g-1,.gy-1{--bs-gutter-y:0.25rem}.g-2,.gx-2{--bs-gutter-x:0.5rem}.g-2,.gy-2{--bs-gutter-y:0.5rem}.g-3,.gx-3{--bs-gutter-x:1rem}.g-3,.gy-3{--bs-gutter-y:1rem}.g-4,.gx-4{--bs-gutter-x:1.5rem}.g-4,.gy-4{--bs-gutter-y:1.5rem}.g-5,.gx-5{--bs-gutter-x:3rem}.g-5,.gy-5{--bs-gutter-y:3rem}@media (min-width:576px){.col-sm{flex:1 0 0%}.row-cols-sm-auto>*{flex:0 0 auto;width:auto}.row-cols-sm-1>*{flex:0 0 auto;width:100%}.row-cols-sm-2>*{flex:0 0 auto;width:50%}.row-cols-sm-3>*{flex:0 0 auto;width:33.3333333333%}.row-cols-sm-4>*{flex:0 0 auto;width:25%}.row-cols-sm-5>*{flex:0 0 auto;width:20%}.row-cols-sm-6>*{flex:0 0 auto;width:16.6666666667%}.col-sm-auto{flex:0 0 auto;width:auto}.col-sm-1{flex:0 0 auto;width:8.33333333%}.col-sm-2{flex:0 0 auto;width:16.66666667%}.col-sm-3{flex:0 0 auto;width:25%}.col-sm-4{flex:0 0 auto;width:33.33333333%}.col-sm-5{flex:0 0 auto;width:41.66666667%}.col-sm-6{flex:0 0 auto;width:50%}.col-sm-7{flex:0 0 auto;width:58.33333333%}.col-sm-8{flex:0 0 auto;width:66.66666667%}.col-sm-9{flex:0 0 auto;width:75%}.col-sm-10{flex:0 0 auto;width:83.33333333%}.col-sm-11{flex:0 0 auto;width:91.66666667%}.col-sm-12{flex:0 0 auto;width:100%}.offset-sm-0{margin-left:0}.offset-sm-1{margin-left:8.33333333%}.offset-sm-2{margin-left:16.66666667%}.offset-sm-3{margin-left:25%}.offset-sm-4{margin-left:33.33333333%}.offset-sm-5{margin-left:41.66666667%}.offset-sm-6{margin-left:50%}.offset-sm-7{margin-left:58.33333333%}.offset-sm-8{margin-left:66.66666667%}.offset-sm-9{margin-left:75%}.offset-sm-10{margin-left:83.33333333%}.offset-sm-11{margin-left:91.66666667%}.g-sm-0,.gx-sm-0{--bs-gutter-x:0}.g-sm-0,.gy-sm-0{--bs-gutter-y:0}.g-sm-1,.gx-sm-1{--bs-gutter-x:0.25rem}.g-sm-1,.gy-sm-1{--bs-gutter-y:0.25rem}.g-sm-2,.gx-sm-2{--bs-gutter-x:0.5rem}.g-sm-2,.gy-sm-2{--bs-gutter-y:0.5rem}.g-sm-3,.gx-sm-3{--bs-gutter-x:1rem}.g-sm-3,.gy-sm-3{--bs-gutter-y:1rem}.g-sm-4,.gx-sm-4{--bs-gutter-x:1.5rem}.g-sm-4,.gy-sm-4{--bs-gutter-y:1.5rem}.g-sm-5,.gx-sm-5{--bs-gutter-x:3rem}.g-sm-5,.gy-sm-5{--bs-gutter-y:3rem}}@media (min-width:768px){.col-md{flex:1 0 0%}.row-cols-md-auto>*{flex:0 0 auto;width:auto}.row-cols-md-1>*{flex:0 0 auto;width:100%}.row-cols-md-2>*{flex:0 0 auto;width:50%}.row-cols-md-3>*{flex:0 0 auto;width:33.3333333333%}.row-cols-md-4>*{flex:0 0 auto;width:25%}.row-cols-md-5>*{flex:0 0 auto;width:20%}.row-cols-md-6>*{flex:0 0 auto;width:16.6666666667%}.col-md-auto{flex:0 0 auto;width:auto}.col-md-1{flex:0 0 auto;width:8.33333333%}.col-md-2{flex:0 0 auto;width:16.66666667%}.col-md-3{flex:0 0 auto;width:25%}.col-md-4{flex:0 0 auto;width:33.33333333%}.col-md-5{flex:0 0 auto;width:41.66666667%}.col-md-6{flex:0 0 auto;width:50%}.col-md-7{flex:0 0 auto;width:58.33333333%}.col-md-8{flex:0 0 auto;width:66.66666667%}.col-md-9{flex:0 0 auto;width:75%}.col-md-10{flex:0 0 auto;width:83.33333333%}.col-md-11{flex:0 0 auto;width:91.66666667%}.col-md-12{flex:0 0 auto;width:100%}.offset-md-0{margin-left:0}.offset-md-1{margin-left:8.33333333%}.offset-md-2{margin-left:16.66666667%}.offset-md-3{margin-left:25%}.offset-md-4{margin-left:33.33333333%}.offset-md-5{margin-left:41.66666667%}.offset-md-6{margin-left:50%}.offset-md-7{margin-left:58.33333333%}.offset-md-8{margin-left:66.66666667%}.offset-md-9{margin-left:75%}.offset-md-10{margin-left:83.33333333%}.offset-md-11{margin-left:91.66666667%}.g-md-0,.gx-md-0{--bs-gutter-x:0}.g-md-0,.gy-md-0{--bs-gutter-y:0}.g-md-1,.gx-md-1{--bs-gutter-x:0.25rem}.g-md-1,.gy-md-1{--bs-gutter-y:0.25rem}.g-md-2,.gx-md-2{--bs-gutter-x:0.5rem}.g-md-2,.gy-md-2{--bs-gutter-y:0.5rem}.g-md-3,.gx-md-3{--bs-gutter-x:1rem}.g-md-3,.gy-md-3{--bs-gutter-y:1rem}.g-md-4,.gx-md-4{--bs-gutter-x:1.5rem}.g-md-4,.gy-md-4{--bs-gutter-y:1.5rem}.g-md-5,.gx-md-5{--bs-gutter-x:3rem}.g-md-5,.gy-md-5{--bs-gutter-y:3rem}}@media (min-width:992px){.col-lg{flex:1 0 0%}.row-cols-lg-auto>*{flex:0 0 auto;width:auto}.row-cols-lg-1>*{flex:0 0 auto;width:100%}.row-cols-lg-2>*{flex:0 0 auto;width:50%}.row-cols-lg-3>*{flex:0 0 auto;width:33.3333333333%}.row-cols-lg-4>*{flex:0 0 auto;width:25%}.row-cols-lg-5>*{flex:0 0 auto;width:20%}.row-cols-lg-6>*{flex:0 0 auto;width:16.6666666667%}.col-lg-auto{flex:0 0 auto;width:auto}.col-lg-1{flex:0 0 auto;width:8.33333333%}.col-lg-2{flex:0 0 auto;width:16.66666667%}.col-lg-3{flex:0 0 auto;width:25%}.col-lg-4{flex:0 0 auto;width:33.33333333%}.col-lg-5{flex:0 0 auto;width:41.66666667%}.col-lg-6{flex:0 0 auto;width:50%}.col-lg-7{flex:0 0 auto;width:58.33333333%}.col-lg-8{flex:0 0 auto;width:66.66666667%}.col-lg-9{flex:0 0 auto;width:75%}.col-lg-10{flex:0 0 auto;width:83.33333333%}.col-lg-11{flex:0 0 auto;width:91.66666667%}.col-lg-12{flex:0 0 auto;width:100%}.offset-lg-0{margin-left:0}.offset-lg-1{margin-left:8.33333333%}.offset-lg-2{margin-left:16.66666667%}.offset-lg-3{margin-left:25%}.offset-lg-4{margin-left:33.33333333%}.offset-lg-5{margin-left:41.66666667%}.offset-lg-6{margin-left:50%}.offset-lg-7{margin-left:58.33333333%}.offset-lg-8{margin-left:66.66666667%}.offset-lg-9{margin-left:75%}.offset-lg-10{margin-left:83.33333333%}.offset-lg-11{margin-left:91.66666667%}.g-lg-0,.gx-lg-0{--bs-gutter-x:0}.g-lg-0,.gy-lg-0{--bs-gutter-y:0}.g-lg-1,.gx-lg-1{--bs-gutter-x:0.25rem}.g-lg-1,.gy-lg-1{--bs-gutter-y:0.25rem}.g-lg-2,.gx-lg-2{--bs-gutter-x:0.5rem}.g-lg-2,.gy-lg-2{--bs-gutter-y:0.5rem}.g-lg-3,.gx-lg-3{--bs-gutter-x:1rem}.g-lg-3,.gy-lg-3{--bs-gutter-y:1rem}.g-lg-4,.gx-lg-4{--bs-gutter-x:1.5rem}.g-lg-4,.gy-lg-4{--bs-gutter-y:1.5rem}.g-lg-5,.gx-lg-5{--bs-gutter-x:3rem}.g-lg-5,.gy-lg-5{--bs-gutter-y:3rem}}@media (min-width:1200px){.col-xl{flex:1 0 0%}.row-cols-xl-auto>*{flex:0 0 auto;width:auto}.row-cols-xl-1>*{flex:0 0 auto;width:100%}.row-cols-xl-2>*{flex:0 0 auto;width:50%}.row-cols-xl-3>*{flex:0 0 auto;width:33.3333333333%}.row-cols-xl-4>*{flex:0 0 auto;width:25%}.row-cols-xl-5>*{flex:0 0 auto;width:20%}.row-cols-xl-6>*{flex:0 0 auto;width:16.6666666667%}.col-xl-auto{flex:0 0 auto;width:auto}.col-xl-1{flex:0 0 auto;width:8.33333333%}.col-xl-2{flex:0 0 auto;width:16.66666667%}.col-xl-3{flex:0 0 auto;width:25%}.col-xl-4{flex:0 0 auto;width:33.33333333%}.col-xl-5{flex:0 0 auto;width:41.66666667%}.col-xl-6{flex:0 0 auto;width:50%}.col-xl-7{flex:0 0 auto;width:58.33333333%}.col-xl-8{flex:0 0 auto;width:66.66666667%}.col-xl-9{flex:0 0 auto;width:75%}.col-xl-10{flex:0 0 auto;width:83.33333333%}.col-xl-11{flex:0 0 auto;width:91.66666667%}.col-xl-12{flex:0 0 auto;width:100%}.offset-xl-0{margin-left:0}.offset-xl-1{margin-left:8.33333333%}.offset-xl-2{margin-left:16.66666667%}.offset-xl-3{margin-left:25%}.offset-xl-4{margin-left:33.33333333%}.offset-xl-5{margin-left:41.66666667%}.offset-xl-6{margin-left:50%}.offset-xl-7{margin-left:58.33333333%}.offset-xl-8{margin-left:66.66666667%}.offset-xl-9{margin-left:75%}.offset-xl-10{margin-left:83.33333333%}.offset-xl-11{margin-left:91.66666667%}.g-xl-0,.gx-xl-0{--bs-gutter-x:0}.g-xl-0,.gy-xl-0{--bs-gutter-y:0}.g-xl-1,.gx-xl-1{--bs-gutter-x:0.25rem}.g-xl-1,.gy-xl-1{--bs-gutter-y:0.25rem}.g-xl-2,.gx-xl-2{--bs-gutter-x:0.5rem}.g-xl-2,.gy-xl-2{--bs-gutter-y:0.5rem}.g-xl-3,.gx-xl-3{--bs-gutter-x:1rem}.g-xl-3,.gy-xl-3{--bs-gutter-y:1rem}.g-xl-4,.gx-xl-4{--bs-gutter-x:1.5rem}.g-xl-4,.gy-xl-4{--bs-gutter-y:1.5rem}.g-xl-5,.gx-xl-5{--bs-gutter-x:3rem}.g-xl-5,.gy-xl-5{--bs-gutter-y:3rem}}@media (min-width:1400px){.col-xxl{flex:1 0 0%}.row-cols-xxl-auto>*{flex:0 0 auto;width:auto}.row-cols-xxl-1>*{flex:0 0 auto;width:100%}.row-cols-xxl-2>*{flex:0 0 auto;width:50%}.row-cols-xxl-3>*{flex:0 0 auto;width:33.3333333333%}.row-cols-xxl-4>*{flex:0 0 auto;width:25%}.row-cols-xxl-5>*{flex:0 0 auto;width:20%}.row-cols-xxl-6>*{flex:0 0 auto;width:16.6666666667%}.col-xxl-auto{flex:0 0 auto;width:auto}.col-xxl-1{flex:0 0 auto;width:8.33333333%}.col-xxl-2{flex:0 0 auto;width:16.66666667%}.col-xxl-3{flex:0 0 auto;width:25%}.col-xxl-4{flex:0 0 auto;width:33.33333333%}.col-xxl-5{flex:0 0 auto;width:41.66666667%}.col-xxl-6{flex:0 0 auto;width:50%}.col-xxl-7{flex:0 0 auto;width:58.33333333%}.col-xxl-8{flex:0 0 auto;width:66.66666667%}.col-xxl-9{flex:0 0 auto;width:75%}.col-xxl-10{flex:0 0 auto;width:83.33333333%}.col-xxl-11{flex:0 0 auto;width:91.66666667%}.col-xxl-12{flex:0 0 auto;width:100%}.offset-xxl-0{margin-left:0}.offset-xxl-1{margin-left:8.33333333%}.offset-xxl-2{margin-left:16.66666667%}.offset-xxl-3{margin-left:25%}.offset-xxl-4{margin-left:33.33333333%}.offset-xxl-5{margin-left:41.66666667%}.offset-xxl-6{margin-left:50%}.offset-xxl-7{margin-left:58.33333333%}.offset-xxl-8{margin-left:66.66666667%}.offset-xxl-9{margin-left:75%}.offset-xxl-10{margin-left:83.33333333%}.offset-xxl-11{margin-left:91.66666667%}.g-xxl-0,.gx-xxl-0{--bs-gutter-x:0}.g-xxl-0,.gy-xxl-0{--bs-gutter-y:0}.g-xxl-1,.gx-xxl-1{--bs-gutter-x:0.25rem}.g-xxl-1,.gy-xxl-1{--bs-gutter-y:0.25rem}.g-xxl-2,.gx-xxl-2{--bs-gutter-x:0.5rem}.g-xxl-2,.gy-xxl-2{--bs-gutter-y:0.5rem}.g-xxl-3,.gx-xxl-3{--bs-gutter-x:1rem}.g-xxl-3,.gy-xxl-3{--bs-gutter-y:1rem}.g-xxl-4,.gx-xxl-4{--bs-gutter-x:1.5rem}.g-xxl-4,.gy-xxl-4{--bs-gutter-y:1.5rem}.g-xxl-5,.gx-xxl-5{--bs-gutter-x:3rem}.g-xxl-5,.gy-xxl-5{--bs-gutter-y:3rem}}.table{--bs-table-bg:transparent;--bs-table-accent-bg:transparent;--bs-table-striped-color:#212529;--bs-table-striped-bg:rgba(0, 0, 0, 0.05);--bs-table-active-color:#212529;--bs-table-active-bg:rgba(0, 0, 0, 0.1);--bs-table-hover-color:#212529;--bs-table-hover-bg:rgba(0, 0, 0, 0.075);width:100%;margin-bottom:1rem;color:#212529;vertical-align:top;border-color:#dee2e6}.table>:not(caption)>*>*{padding:.5rem .5rem;background-color:var(--bs-table-bg);border-bottom-width:1px;box-shadow:inset 0 0 0 9999px var(--bs-table-accent-bg)}.table>tbody{vertical-align:inherit}.table>thead{vertical-align:bottom}.table>:not(:first-child){border-top:2px solid currentColor}.caption-top{caption-side:top}.table-sm>:not(caption)>*>*{padding:.25rem .25rem}.table-bordered>:not(caption)>*{border-width:1px 0}.table-bordered>:not(caption)>*>*{border-width:0 1px}.table-borderless>:not(caption)>*>*{border-bottom-width:0}.table-borderless>:not(:first-child){border-top-width:0}.table-striped>tbody>tr:nth-of-type(odd)>*{--bs-table-accent-bg:var(--bs-table-striped-bg);color:var(--bs-table-striped-color)}.table-active{--bs-table-accent-bg:var(--bs-table-active-bg);color:var(--bs-table-active-color)}.table-hover>tbody>tr:hover>*{--bs-table-accent-bg:var(--bs-table-hover-bg);color:var(--bs-table-hover-color)}.table-primary{--bs-table-bg:#cfe2ff;--bs-table-striped-bg:#c5d7f2;--bs-table-striped-color:#000;--bs-table-active-bg:#bacbe6;--bs-table-active-color:#000;--bs-table-hover-bg:#bfd1ec;--bs-table-hover-color:#000;color:#000;border-color:#bacbe6}.table-secondary{--bs-table-bg:#e2e3e5;--bs-table-striped-bg:#d7d8da;--bs-table-striped-color:#000;--bs-table-active-bg:#cbccce;--bs-table-active-color:#000;--bs-table-hover-bg:#d1d2d4;--bs-table-hover-color:#000;color:#000;border-color:#cbccce}.table-success{--bs-table-bg:#d1e7dd;--bs-table-striped-bg:#c7dbd2;--bs-table-striped-color:#000;--bs-table-active-bg:#bcd0c7;--bs-table-active-color:#000;--bs-table-hover-bg:#c1d6cc;--bs-table-hover-color:#000;color:#000;border-color:#bcd0c7}.table-info{--bs-table-bg:#cff4fc;--bs-table-striped-bg:#c5e8ef;--bs-table-striped-color:#000;--bs-table-active-bg:#badce3;--bs-table-active-color:#000;--bs-table-hover-bg:#bfe2e9;--bs-table-hover-color:#000;color:#000;border-color:#badce3}.table-warning{--bs-table-bg:#fff3cd;--bs-table-striped-bg:#f2e7c3;--bs-table-striped-color:#000;--bs-table-active-bg:#e6dbb9;--bs-table-active-color:#000;--bs-table-hover-bg:#ece1be;--bs-table-hover-color:#000;color:#000;border-color:#e6dbb9}.table-danger{--bs-table-bg:#f8d7da;--bs-table-striped-bg:#eccccf;--bs-table-striped-color:#000;--bs-table-active-bg:#dfc2c4;--bs-table-active-color:#000;--bs-table-hover-bg:#e5c7ca;--bs-table-hover-color:#000;color:#000;border-color:#dfc2c4}.table-light{--bs-table-bg:#f8f9fa;--bs-table-striped-bg:#ecedee;--bs-table-striped-color:#000;--bs-table-active-bg:#dfe0e1;--bs-table-active-color:#000;--bs-table-hover-bg:#e5e6e7;--bs-table-hover-color:#000;color:#000;border-color:#dfe0e1}.table-dark{--bs-table-bg:#212529;--bs-table-striped-bg:#2c3034;--bs-table-striped-color:#fff;--bs-table-active-bg:#373b3e;--bs-table-active-color:#fff;--bs-table-hover-bg:#323539;--bs-table-hover-color:#fff;color:#fff;border-color:#373b3e}.table-responsive{overflow-x:auto;-webkit-overflow-scrolling:touch}@media (max-width:575.98px){.table-responsive-sm{overflow-x:auto;-webkit-overflow-scrolling:touch}}@media (max-width:767.98px){.table-responsive-md{overflow-x:auto;-webkit-overflow-scrolling:touch}}@media (max-width:991.98px){.table-responsive-lg{overflow-x:auto;-webkit-overflow-scrolling:touch}}@media (max-width:1199.98px){.table-responsive-xl{overflow-x:auto;-webkit-overflow-scrolling:touch}}@media (max-width:1399.98px){.table-responsive-xxl{overflow-x:auto;-webkit-overflow-scrolling:touch}}.form-label{margin-bottom:.5rem}.col-form-label{padding-top:calc(.375rem + 1px);padding-bottom:calc(.375rem + 1px);margin-bottom:0;font-size:inherit;line-height:1.5}.col-form-label-lg{padding-top:calc(.5rem + 1px);padding-bottom:calc(.5rem + 1px);font-size:1.25rem}.col-form-label-sm{padding-top:calc(.25rem + 1px);padding-bottom:calc(.25rem + 1px);font-size:.875rem}.form-text{margin-top:.25rem;font-size:.875em;color:#6c757d}.form-control{display:block;width:100%;padding:.375rem .75rem;font-size:1rem;font-weight:400;line-height:1.5;color:#212529;background-color:#fff;background-clip:padding-box;border:1px solid #ced4da;-webkit-appearance:none;-moz-appearance:none;appearance:none;border-radius:.25rem;transition:border-color .15s ease-in-out,box-shadow .15s ease-in-out}@media (prefers-reduced-motion:reduce){.form-control{transition:none}}.form-control[type=file]{overflow:hidden}.form-control[type=file]:not(:disabled):not([readonly]){cursor:pointer}.form-control:focus{color:#212529;background-color:#fff;border-color:#86b7fe;outline:0;box-shadow:0 0 0 .25rem rgba(13,110,253,.25)}.form-control::-webkit-date-and-time-value{height:1.5em}.form-control::-moz-placeholder{color:#6c757d;opacity:1}.form-control::placeholder{color:#6c757d;opacity:1}.form-control:disabled,.form-control[readonly]{background-color:#e9ecef;opacity:1}.form-control::-webkit-file-upload-button{padding:.375rem .75rem;margin:-.375rem -.75rem;-webkit-margin-end:.75rem;margin-inline-end:.75rem;color:#212529;background-color:#e9ecef;pointer-events:none;border-color:inherit;border-style:solid;border-width:0;border-inline-end-width:1px;border-radius:0;-webkit-transition:color .15s ease-in-out,background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out;transition:color .15s ease-in-out,background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out}.form-control::file-selector-button{padding:.375rem .75rem;margin:-.375rem -.75rem;-webkit-margin-end:.75rem;margin-inline-end:.75rem;color:#212529;background-color:#e9ecef;pointer-events:none;border-color:inherit;border-style:solid;border-width:0;border-inline-end-width:1px;border-radius:0;transition:color .15s ease-in-out,background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out}@media (prefers-reduced-motion:reduce){.form-control::-webkit-file-upload-button{-webkit-transition:none;transition:none}.form-control::file-selector-button{transition:none}}.form-control:hover:not(:disabled):not([readonly])::-webkit-file-upload-button{background-color:#dde0e3}.form-control:hover:not(:disabled):not([readonly])::file-selector-button{background-color:#dde0e3}.form-control::-webkit-file-upload-button{padding:.375rem .75rem;margin:-.375rem -.75rem;-webkit-margin-end:.75rem;margin-inline-end:.75rem;color:#212529;background-color:#e9ecef;pointer-events:none;border-color:inherit;border-style:solid;border-width:0;border-inline-end-width:1px;border-radius:0;-webkit-transition:color .15s ease-in-out,background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out;transition:color .15s ease-in-out,background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out}@media (prefers-reduced-motion:reduce){.form-control::-webkit-file-upload-button{-webkit-transition:none;transition:none}}.form-control:hover:not(:disabled):not([readonly])::-webkit-file-upload-button{background-color:#dde0e3}.form-control-plaintext{display:block;width:100%;padding:.375rem 0;margin-bottom:0;line-height:1.5;color:#212529;background-color:transparent;border:solid transparent;border-width:1px 0}.form-control-plaintext.form-control-lg,.form-control-plaintext.form-control-sm{padding-right:0;padding-left:0}.form-control-sm{min-height:calc(1.5em + .5rem + 2px);padding:.25rem .5rem;font-size:.875rem;border-radius:.2rem}.form-control-sm::-webkit-file-upload-button{padding:.25rem .5rem;margin:-.25rem -.5rem;-webkit-margin-end:.5rem;margin-inline-end:.5rem}.form-control-sm::file-selector-button{padding:.25rem .5rem;margin:-.25rem -.5rem;-webkit-margin-end:.5rem;margin-inline-end:.5rem}.form-control-sm::-webkit-file-upload-button{padding:.25rem .5rem;margin:-.25rem -.5rem;-webkit-margin-end:.5rem;margin-inline-end:.5rem}.form-control-lg{min-height:calc(1.5em + 1rem + 2px);padding:.5rem 1rem;font-size:1.25rem;border-radius:.3rem}.form-control-lg::-webkit-file-upload-button{padding:.5rem 1rem;margin:-.5rem -1rem;-webkit-margin-end:1rem;margin-inline-end:1rem}.form-control-lg::file-selector-button{padding:.5rem 1rem;margin:-.5rem -1rem;-webkit-margin-end:1rem;margin-inline-end:1rem}.form-control-lg::-webkit-file-upload-button{padding:.5rem 1rem;margin:-.5rem -1rem;-webkit-margin-end:1rem;margin-inline-end:1rem}textarea.form-control{min-height:calc(1.5em + .75rem + 2px)}textarea.form-control-sm{min-height:calc(1.5em + .5rem + 2px)}textarea.form-control-lg{min-height:calc(1.5em + 1rem + 2px)}.form-control-color{width:3rem;height:auto;padding:.375rem}.form-control-color:not(:disabled):not([readonly]){cursor:pointer}.form-control-color::-moz-color-swatch{height:1.5em;border-radius:.25rem}.form-control-color::-webkit-color-swatch{height:1.5em;border-radius:.25rem}.form-select{display:block;width:100%;padding:.375rem 2.25rem .375rem .75rem;-moz-padding-start:calc(0.75rem - 3px);font-size:1rem;font-weight:400;line-height:1.5;color:#212529;background-color:#fff;background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3e%3cpath fill='none' stroke='%23343a40' stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M2 5l6 6 6-6'/%3e%3c/svg%3e");background-repeat:no-repeat;background-position:right .75rem center;background-size:16px 12px;border:1px solid #ced4da;border-radius:.25rem;transition:border-color .15s ease-in-out,box-shadow .15s ease-in-out;-webkit-appearance:none;-moz-appearance:none;appearance:none}@media (prefers-reduced-motion:reduce){.form-select{transition:none}}.form-select:focus{border-color:#86b7fe;outline:0;box-shadow:0 0 0 .25rem rgba(13,110,253,.25)}.form-select[multiple],.form-select[size]:not([size="1"]){padding-right:.75rem;background-image:none}.form-select:disabled{background-color:#e9ecef}.form-select:-moz-focusring{color:transparent;text-shadow:0 0 0 #212529}.form-select-sm{padding-top:.25rem;padding-bottom:.25rem;padding-left:.5rem;font-size:.875rem;border-radius:.2rem}.form-select-lg{padding-top:.5rem;padding-bottom:.5rem;padding-left:1rem;font-size:1.25rem;border-radius:.3rem}.form-check{display:block;min-height:1.5rem;padding-left:1.5em;margin-bottom:.125rem}.form-check .form-check-input{float:left;margin-left:-1.5em}.form-check-input{width:1em;height:1em;margin-top:.25em;vertical-align:top;background-color:#fff;background-repeat:no-repeat;background-position:center;background-size:contain;border:1px solid rgba(0,0,0,.25);-webkit-appearance:none;-moz-appearance:none;appearance:none;-webkit-print-color-adjust:exact;color-adjust:exact}.form-check-input[type=checkbox]{border-radius:.25em}.form-check-input[type=radio]{border-radius:50%}.form-check-input:active{filter:brightness(90%)}.form-check-input:focus{border-color:#86b7fe;outline:0;box-shadow:0 0 0 .25rem rgba(13,110,253,.25)}.form-check-input:checked{background-color:#0d6efd;border-color:#0d6efd}.form-check-input:checked[type=checkbox]{background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 20 20'%3e%3cpath fill='none' stroke='%23fff' stroke-linecap='round' stroke-linejoin='round' stroke-width='3' d='M6 10l3 3l6-6'/%3e%3c/svg%3e")}.form-check-input:checked[type=radio]{background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='-4 -4 8 8'%3e%3ccircle r='2' fill='%23fff'/%3e%3c/svg%3e")}.form-check-input[type=checkbox]:indeterminate{background-color:#0d6efd;border-color:#0d6efd;background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 20 20'%3e%3cpath fill='none' stroke='%23fff' stroke-linecap='round' stroke-linejoin='round' stroke-width='3' d='M6 10h8'/%3e%3c/svg%3e")}.form-check-input:disabled{pointer-events:none;filter:none;opacity:.5}.form-check-input:disabled~.form-check-label,.form-check-input[disabled]~.form-check-label{opacity:.5}.form-switch{padding-left:2.5em}.form-switch .form-check-input{width:2em;margin-left:-2.5em;background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='-4 -4 8 8'%3e%3ccircle r='3' fill='rgba%280, 0, 0, 0.25%29'/%3e%3c/svg%3e");background-position:left center;border-radius:2em;transition:background-position .15s ease-in-out}@media (prefers-reduced-motion:reduce){.form-switch .form-check-input{transition:none}}.form-switch .form-check-input:focus{background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='-4 -4 8 8'%3e%3ccircle r='3' fill='%2386b7fe'/%3e%3c/svg%3e")}.form-switch .form-check-input:checked{background-position:right center;background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='-4 -4 8 8'%3e%3ccircle r='3' fill='%23fff'/%3e%3c/svg%3e")}.form-check-inline{display:inline-block;margin-right:1rem}.btn-check{position:absolute;clip:rect(0,0,0,0);pointer-events:none}.btn-check:disabled+.btn,.btn-check[disabled]+.btn{pointer-events:none;filter:none;opacity:.65}.form-range{width:100%;height:1.5rem;padding:0;background-color:transparent;-webkit-appearance:none;-moz-appearance:none;appearance:none}.form-range:focus{outline:0}.form-range:focus::-webkit-slider-thumb{box-shadow:0 0 0 1px #fff,0 0 0 .25rem rgba(13,110,253,.25)}.form-range:focus::-moz-range-thumb{box-shadow:0 0 0 1px #fff,0 0 0 .25rem rgba(13,110,253,.25)}.form-range::-moz-focus-outer{border:0}.form-range::-webkit-slider-thumb{width:1rem;height:1rem;margin-top:-.25rem;background-color:#0d6efd;border:0;border-radius:1rem;-webkit-transition:background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out;transition:background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out;-webkit-appearance:none;appearance:none}@media (prefers-reduced-motion:reduce){.form-range::-webkit-slider-thumb{-webkit-transition:none;transition:none}}.form-range::-webkit-slider-thumb:active{background-color:#b6d4fe}.form-range::-webkit-slider-runnable-track{width:100%;height:.5rem;color:transparent;cursor:pointer;background-color:#dee2e6;border-color:transparent;border-radius:1rem}.form-range::-moz-range-thumb{width:1rem;height:1rem;background-color:#0d6efd;border:0;border-radius:1rem;-moz-transition:background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out;transition:background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out;-moz-appearance:none;appearance:none}@media (prefers-reduced-motion:reduce){.form-range::-moz-range-thumb{-moz-transition:none;transition:none}}.form-range::-moz-range-thumb:active{background-color:#b6d4fe}.form-range::-moz-range-track{width:100%;height:.5rem;color:transparent;cursor:pointer;background-color:#dee2e6;border-color:transparent;border-radius:1rem}.form-range:disabled{pointer-events:none}.form-range:disabled::-webkit-slider-thumb{background-color:#adb5bd}.form-range:disabled::-moz-range-thumb{background-color:#adb5bd}.form-floating{position:relative}.form-floating>.form-control,.form-floating>.form-select{height:calc(3.5rem + 2px);line-height:1.25}.form-floating>label{position:absolute;top:0;left:0;height:100%;padding:1rem .75rem;pointer-events:none;border:1px solid transparent;transform-origin:0 0;transition:opacity .1s ease-in-out,transform .1s ease-in-out}@media (prefers-reduced-motion:reduce){.form-floating>label{transition:none}}.form-floating>.form-control{padding:1rem .75rem}.form-floating>.form-control::-moz-placeholder{color:transparent}.form-floating>.form-control::placeholder{color:transparent}.form-floating>.form-control:not(:-moz-placeholder-shown){padding-top:1.625rem;padding-bottom:.625rem}.form-floating>.form-control:focus,.form-floating>.form-control:not(:placeholder-shown){padding-top:1.625rem;padding-bottom:.625rem}.form-floating>.form-control:-webkit-autofill{padding-top:1.625rem;padding-bottom:.625rem}.form-floating>.form-select{padding-top:1.625rem;padding-bottom:.625rem}.form-floating>.form-control:not(:-moz-placeholder-shown)~label{opacity:.65;transform:scale(.85) translateY(-.5rem) translateX(.15rem)}.form-floating>.form-control:focus~label,.form-floating>.form-control:not(:placeholder-shown)~label,.form-floating>.form-select~label{opacity:.65;transform:scale(.85) translateY(-.5rem) translateX(.15rem)}.form-floating>.form-control:-webkit-autofill~label{opacity:.65;transform:scale(.85) translateY(-.5rem) translateX(.15rem)}.input-group{position:relative;display:flex;flex-wrap:wrap;align-items:stretch;width:100%}.input-group>.form-control,.input-group>.form-select{position:relative;flex:1 1 auto;width:1%;min-width:0}.input-group>.form-control:focus,.input-group>.form-select:focus{z-index:3}.input-group .btn{position:relative;z-index:2}.input-group .btn:focus{z-index:3}.input-group-text{display:flex;align-items:center;padding:.375rem .75rem;font-size:1rem;font-weight:400;line-height:1.5;color:#212529;text-align:center;white-space:nowrap;background-color:#e9ecef;border:1px solid #ced4da;border-radius:.25rem}.input-group-lg>.btn,.input-group-lg>.form-control,.input-group-lg>.form-select,.input-group-lg>.input-group-text{padding:.5rem 1rem;font-size:1.25rem;border-radius:.3rem}.input-group-sm>.btn,.input-group-sm>.form-control,.input-group-sm>.form-select,.input-group-sm>.input-group-text{padding:.25rem .5rem;font-size:.875rem;border-radius:.2rem}.input-group-lg>.form-select,.input-group-sm>.form-select{padding-right:3rem}.input-group:not(.has-validation)>.dropdown-toggle:nth-last-child(n+3),.input-group:not(.has-validation)>:not(:last-child):not(.dropdown-toggle):not(.dropdown-menu){border-top-right-radius:0;border-bottom-right-radius:0}.input-group.has-validation>.dropdown-toggle:nth-last-child(n+4),.input-group.has-validation>:nth-last-child(n+3):not(.dropdown-toggle):not(.dropdown-menu){border-top-right-radius:0;border-bottom-right-radius:0}.input-group>:not(:first-child):not(.dropdown-menu):not(.valid-tooltip):not(.valid-feedback):not(.invalid-tooltip):not(.invalid-feedback){margin-left:-1px;border-top-left-radius:0;border-bottom-left-radius:0}.valid-feedback{display:none;width:100%;margin-top:.25rem;font-size:.875em;color:#198754}.valid-tooltip{position:absolute;top:100%;z-index:5;display:none;max-width:100%;padding:.25rem .5rem;margin-top:.1rem;font-size:.875rem;color:#fff;background-color:rgba(25,135,84,.9);border-radius:.25rem}.is-valid~.valid-feedback,.is-valid~.valid-tooltip,.was-validated :valid~.valid-feedback,.was-validated :valid~.valid-tooltip{display:block}.form-control.is-valid,.was-validated .form-control:valid{border-color:#198754;padding-right:calc(1.5em + .75rem);background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 8 8'%3e%3cpath fill='%23198754' d='M2.3 6.73L.6 4.53c-.4-1.04.46-1.4 1.1-.8l1.1 1.4 3.4-3.8c.6-.63 1.6-.27 1.2.7l-4 4.6c-.43.5-.8.4-1.1.1z'/%3e%3c/svg%3e");background-repeat:no-repeat;background-position:right calc(.375em + .1875rem) center;background-size:calc(.75em + .375rem) calc(.75em + .375rem)}.form-control.is-valid:focus,.was-validated .form-control:valid:focus{border-color:#198754;box-shadow:0 0 0 .25rem rgba(25,135,84,.25)}.was-validated textarea.form-control:valid,textarea.form-control.is-valid{padding-right:calc(1.5em + .75rem);background-position:top calc(.375em + .1875rem) right calc(.375em + .1875rem)}.form-select.is-valid,.was-validated .form-select:valid{border-color:#198754}.form-select.is-valid:not([multiple]):not([size]),.form-select.is-valid:not([multiple])[size="1"],.was-validated .form-select:valid:not([multiple]):not([size]),.was-validated .form-select:valid:not([multiple])[size="1"]{padding-right:4.125rem;background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3e%3cpath fill='none' stroke='%23343a40' stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M2 5l6 6 6-6'/%3e%3c/svg%3e"),url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 8 8'%3e%3cpath fill='%23198754' d='M2.3 6.73L.6 4.53c-.4-1.04.46-1.4 1.1-.8l1.1 1.4 3.4-3.8c.6-.63 1.6-.27 1.2.7l-4 4.6c-.43.5-.8.4-1.1.1z'/%3e%3c/svg%3e");background-position:right .75rem center,center right 2.25rem;background-size:16px 12px,calc(.75em + .375rem) calc(.75em + .375rem)}.form-select.is-valid:focus,.was-validated .form-select:valid:focus{border-color:#198754;box-shadow:0 0 0 .25rem rgba(25,135,84,.25)}.form-check-input.is-valid,.was-validated .form-check-input:valid{border-color:#198754}.form-check-input.is-valid:checked,.was-validated .form-check-input:valid:checked{background-color:#198754}.form-check-input.is-valid:focus,.was-validated .form-check-input:valid:focus{box-shadow:0 0 0 .25rem rgba(25,135,84,.25)}.form-check-input.is-valid~.form-check-label,.was-validated .form-check-input:valid~.form-check-label{color:#198754}.form-check-inline .form-check-input~.valid-feedback{margin-left:.5em}.input-group .form-control.is-valid,.input-group .form-select.is-valid,.was-validated .input-group .form-control:valid,.was-validated .input-group .form-select:valid{z-index:1}.input-group .form-control.is-valid:focus,.input-group .form-select.is-valid:focus,.was-validated .input-group .form-control:valid:focus,.was-validated .input-group .form-select:valid:focus{z-index:3}.invalid-feedback{display:none;width:100%;margin-top:.25rem;font-size:.875em;color:#dc3545}.invalid-tooltip{position:absolute;top:100%;z-index:5;display:none;max-width:100%;padding:.25rem .5rem;margin-top:.1rem;font-size:.875rem;color:#fff;background-color:rgba(220,53,69,.9);border-radius:.25rem}.is-invalid~.invalid-feedback,.is-invalid~.invalid-tooltip,.was-validated :invalid~.invalid-feedback,.was-validated :invalid~.invalid-tooltip{display:block}.form-control.is-invalid,.was-validated .form-control:invalid{border-color:#dc3545;padding-right:calc(1.5em + .75rem);background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12' width='12' height='12' fill='none' stroke='%23dc3545'%3e%3ccircle cx='6' cy='6' r='4.5'/%3e%3cpath stroke-linejoin='round' d='M5.8 3.6h.4L6 6.5z'/%3e%3ccircle cx='6' cy='8.2' r='.6' fill='%23dc3545' stroke='none'/%3e%3c/svg%3e");background-repeat:no-repeat;background-position:right calc(.375em + .1875rem) center;background-size:calc(.75em + .375rem) calc(.75em + .375rem)}.form-control.is-invalid:focus,.was-validated .form-control:invalid:focus{border-color:#dc3545;box-shadow:0 0 0 .25rem rgba(220,53,69,.25)}.was-validated textarea.form-control:invalid,textarea.form-control.is-invalid{padding-right:calc(1.5em + .75rem);background-position:top calc(.375em + .1875rem) right calc(.375em + .1875rem)}.form-select.is-invalid,.was-validated .form-select:invalid{border-color:#dc3545}.form-select.is-invalid:not([multiple]):not([size]),.form-select.is-invalid:not([multiple])[size="1"],.was-validated .form-select:invalid:not([multiple]):not([size]),.was-validated .form-select:invalid:not([multiple])[size="1"]{padding-right:4.125rem;background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3e%3cpath fill='none' stroke='%23343a40' stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M2 5l6 6 6-6'/%3e%3c/svg%3e"),url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12' width='12' height='12' fill='none' stroke='%23dc3545'%3e%3ccircle cx='6' cy='6' r='4.5'/%3e%3cpath stroke-linejoin='round' d='M5.8 3.6h.4L6 6.5z'/%3e%3ccircle cx='6' cy='8.2' r='.6' fill='%23dc3545' stroke='none'/%3e%3c/svg%3e");background-position:right .75rem center,center right 2.25rem;background-size:16px 12px,calc(.75em + .375rem) calc(.75em + .375rem)}.form-select.is-invalid:focus,.was-validated .form-select:invalid:focus{border-color:#dc3545;box-shadow:0 0 0 .25rem rgba(220,53,69,.25)}.form-check-input.is-invalid,.was-validated .form-check-input:invalid{border-color:#dc3545}.form-check-input.is-invalid:checked,.was-validated .form-check-input:invalid:checked{background-color:#dc3545}.form-check-input.is-invalid:focus,.was-validated .form-check-input:invalid:focus{box-shadow:0 0 0 .25rem rgba(220,53,69,.25)}.form-check-input.is-invalid~.form-check-label,.was-validated .form-check-input:invalid~.form-check-label{color:#dc3545}.form-check-inline .form-check-input~.invalid-feedback{margin-left:.5em}.input-group .form-control.is-invalid,.input-group .form-select.is-invalid,.was-validated .input-group .form-control:invalid,.was-validated .input-group .form-select:invalid{z-index:2}.input-group .form-control.is-invalid:focus,.input-group .form-select.is-invalid:focus,.was-validated .input-group .form-control:invalid:focus,.was-validated .input-group .form-select:invalid:focus{z-index:3}.btn{display:inline-block;font-weight:400;line-height:1.5;color:#212529;text-align:center;text-decoration:none;vertical-align:middle;cursor:pointer;-webkit-user-select:none;-moz-user-select:none;user-select:none;background-color:transparent;border:1px solid transparent;padding:.375rem .75rem;font-size:1rem;border-radius:.25rem;transition:color .15s ease-in-out,background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out}@media (prefers-reduced-motion:reduce){.btn{transition:none}}.btn:hover{color:#212529}.btn-check:focus+.btn,.btn:focus{outline:0;box-shadow:0 0 0 .25rem rgba(13,110,253,.25)}.btn.disabled,.btn:disabled,fieldset:disabled .btn{pointer-events:none;opacity:.65}.btn-primary{color:#fff;background-color:#0d6efd;border-color:#0d6efd}.btn-primary:hover{color:#fff;background-color:#0b5ed7;border-color:#0a58ca}.btn-check:focus+.btn-primary,.btn-primary:focus{color:#fff;background-color:#0b5ed7;border-color:#0a58ca;box-shadow:0 0 0 .25rem rgba(49,132,253,.5)}.btn-check:active+.btn-primary,.btn-check:checked+.btn-primary,.btn-primary.active,.btn-primary:active,.show>.btn-primary.dropdown-toggle{color:#fff;background-color:#0a58ca;border-color:#0a53be}.btn-check:active+.btn-primary:focus,.btn-check:checked+.btn-primary:focus,.btn-primary.active:focus,.btn-primary:active:focus,.show>.btn-primary.dropdown-toggle:focus{box-shadow:0 0 0 .25rem rgba(49,132,253,.5)}.btn-primary.disabled,.btn-primary:disabled{color:#fff;background-color:#0d6efd;border-color:#0d6efd}.btn-secondary{color:#fff;background-color:#6c757d;border-color:#6c757d}.btn-secondary:hover{color:#fff;background-color:#5c636a;border-color:#565e64}.btn-check:focus+.btn-secondary,.btn-secondary:focus{color:#fff;background-color:#5c636a;border-color:#565e64;box-shadow:0 0 0 .25rem rgba(130,138,145,.5)}.btn-check:active+.btn-secondary,.btn-check:checked+.btn-secondary,.btn-secondary.active,.btn-secondary:active,.show>.btn-secondary.dropdown-toggle{color:#fff;background-color:#565e64;border-color:#51585e}.btn-check:active+.btn-secondary:focus,.btn-check:checked+.btn-secondary:focus,.btn-secondary.active:focus,.btn-secondary:active:focus,.show>.btn-secondary.dropdown-toggle:focus{box-shadow:0 0 0 .25rem rgba(130,138,145,.5)}.btn-secondary.disabled,.btn-secondary:disabled{color:#fff;background-color:#6c757d;border-color:#6c757d}.btn-success{color:#fff;background-color:#198754;border-color:#198754}.btn-success:hover{color:#fff;background-color:#157347;border-color:#146c43}.btn-check:focus+.btn-success,.btn-success:focus{color:#fff;background-color:#157347;border-color:#146c43;box-shadow:0 0 0 .25rem rgba(60,153,110,.5)}.btn-check:active+.btn-success,.btn-check:checked+.btn-success,.btn-success.active,.btn-success:active,.show>.btn-success.dropdown-toggle{color:#fff;background-color:#146c43;border-color:#13653f}.btn-check:active+.btn-success:focus,.btn-check:checked+.btn-success:focus,.btn-success.active:focus,.btn-success:active:focus,.show>.btn-success.dropdown-toggle:focus{box-shadow:0 0 0 .25rem rgba(60,153,110,.5)}.btn-success.disabled,.btn-success:disabled{color:#fff;background-color:#198754;border-color:#198754}.btn-info{color:#000;background-color:#0dcaf0;border-color:#0dcaf0}.btn-info:hover{color:#000;background-color:#31d2f2;border-color:#25cff2}.btn-check:focus+.btn-info,.btn-info:focus{color:#000;background-color:#31d2f2;border-color:#25cff2;box-shadow:0 0 0 .25rem rgba(11,172,204,.5)}.btn-check:active+.btn-info,.btn-check:checked+.btn-info,.btn-info.active,.btn-info:active,.show>.btn-info.dropdown-toggle{color:#000;background-color:#3dd5f3;border-color:#25cff2}.btn-check:active+.btn-info:focus,.btn-check:checked+.btn-info:focus,.btn-info.active:focus,.btn-info:active:focus,.show>.btn-info.dropdown-toggle:focus{box-shadow:0 0 0 .25rem rgba(11,172,204,.5)}.btn-info.disabled,.btn-info:disabled{color:#000;background-color:#0dcaf0;border-color:#0dcaf0}.btn-warning{color:#000;background-color:#ffc107;border-color:#ffc107}.btn-warning:hover{color:#000;background-color:#ffca2c;border-color:#ffc720}.btn-check:focus+.btn-warning,.btn-warning:focus{color:#000;background-color:#ffca2c;border-color:#ffc720;box-shadow:0 0 0 .25rem rgba(217,164,6,.5)}.btn-check:active+.btn-warning,.btn-check:checked+.btn-warning,.btn-warning.active,.btn-warning:active,.show>.btn-warning.dropdown-toggle{color:#000;background-color:#ffcd39;border-color:#ffc720}.btn-check:active+.btn-warning:focus,.btn-check:checked+.btn-warning:focus,.btn-warning.active:focus,.btn-warning:active:focus,.show>.btn-warning.dropdown-toggle:focus{box-shadow:0 0 0 .25rem rgba(217,164,6,.5)}.btn-warning.disabled,.btn-warning:disabled{color:#000;background-color:#ffc107;border-color:#ffc107}.btn-danger{color:#fff;background-color:#dc3545;border-color:#dc3545}.btn-danger:hover{color:#fff;background-color:#bb2d3b;border-color:#b02a37}.btn-check:focus+.btn-danger,.btn-danger:focus{color:#fff;background-color:#bb2d3b;border-color:#b02a37;box-shadow:0 0 0 .25rem rgba(225,83,97,.5)}.btn-check:active+.btn-danger,.btn-check:checked+.btn-danger,.btn-danger.active,.btn-danger:active,.show>.btn-danger.dropdown-toggle{color:#fff;background-color:#b02a37;border-color:#a52834}.btn-check:active+.btn-danger:focus,.btn-check:checked+.btn-danger:focus,.btn-danger.active:focus,.btn-danger:active:focus,.show>.btn-danger.dropdown-toggle:focus{box-shadow:0 0 0 .25rem rgba(225,83,97,.5)}.btn-danger.disabled,.btn-danger:disabled{color:#fff;background-color:#dc3545;border-color:#dc3545}.btn-light{color:#000;background-color:#f8f9fa;border-color:#f8f9fa}.btn-light:hover{color:#000;background-color:#f9fafb;border-color:#f9fafb}.btn-check:focus+.btn-light,.btn-light:focus{color:#000;background-color:#f9fafb;border-color:#f9fafb;box-shadow:0 0 0 .25rem rgba(211,212,213,.5)}.btn-check:active+.btn-light,.btn-check:checked+.btn-light,.btn-light.active,.btn-light:active,.show>.btn-light.dropdown-toggle{color:#000;background-color:#f9fafb;border-color:#f9fafb}.btn-check:active+.btn-light:focus,.btn-check:checked+.btn-light:focus,.btn-light.active:focus,.btn-light:active:focus,.show>.btn-light.dropdown-toggle:focus{box-shadow:0 0 0 .25rem rgba(211,212,213,.5)}.btn-light.disabled,.btn-light:disabled{color:#000;background-color:#f8f9fa;border-color:#f8f9fa}.btn-dark{color:#fff;background-color:#212529;border-color:#212529}.btn-dark:hover{color:#fff;background-color:#1c1f23;border-color:#1a1e21}.btn-check:focus+.btn-dark,.btn-dark:focus{color:#fff;background-color:#1c1f23;border-color:#1a1e21;box-shadow:0 0 0 .25rem rgba(66,70,73,.5)}.btn-check:active+.btn-dark,.btn-check:checked+.btn-dark,.btn-dark.active,.btn-dark:active,.show>.btn-dark.dropdown-toggle{color:#fff;background-color:#1a1e21;border-color:#191c1f}.btn-check:active+.btn-dark:focus,.btn-check:checked+.btn-dark:focus,.btn-dark.active:focus,.btn-dark:active:focus,.show>.btn-dark.dropdown-toggle:focus{box-shadow:0 0 0 .25rem rgba(66,70,73,.5)}.btn-dark.disabled,.btn-dark:disabled{color:#fff;background-color:#212529;border-color:#212529}.btn-outline-primary{color:#0d6efd;border-color:#0d6efd}.btn-outline-primary:hover{color:#fff;background-color:#0d6efd;border-color:#0d6efd}.btn-check:focus+.btn-outline-primary,.btn-outline-primary:focus{box-shadow:0 0 0 .25rem rgba(13,110,253,.5)}.btn-check:active+.btn-outline-primary,.btn-check:checked+.btn-outline-primary,.btn-outline-primary.active,.btn-outline-primary.dropdown-toggle.show,.btn-outline-primary:active{color:#fff;background-color:#0d6efd;border-color:#0d6efd}.btn-check:active+.btn-outline-primary:focus,.btn-check:checked+.btn-outline-primary:focus,.btn-outline-primary.active:focus,.btn-outline-primary.dropdown-toggle.show:focus,.btn-outline-primary:active:focus{box-shadow:0 0 0 .25rem rgba(13,110,253,.5)}.btn-outline-primary.disabled,.btn-outline-primary:disabled{color:#0d6efd;background-color:transparent}.btn-outline-secondary{color:#6c757d;border-color:#6c757d}.btn-outline-secondary:hover{color:#fff;background-color:#6c757d;border-color:#6c757d}.btn-check:focus+.btn-outline-secondary,.btn-outline-secondary:focus{box-shadow:0 0 0 .25rem rgba(108,117,125,.5)}.btn-check:active+.btn-outline-secondary,.btn-check:checked+.btn-outline-secondary,.btn-outline-secondary.active,.btn-outline-secondary.dropdown-toggle.show,.btn-outline-secondary:active{color:#fff;background-color:#6c757d;border-color:#6c757d}.btn-check:active+.btn-outline-secondary:focus,.btn-check:checked+.btn-outline-secondary:focus,.btn-outline-secondary.active:focus,.btn-outline-secondary.dropdown-toggle.show:focus,.btn-outline-secondary:active:focus{box-shadow:0 0 0 .25rem rgba(108,117,125,.5)}.btn-outline-secondary.disabled,.btn-outline-secondary:disabled{color:#6c757d;background-color:transparent}.btn-outline-success{color:#198754;border-color:#198754}.btn-outline-success:hover{color:#fff;background-color:#198754;border-color:#198754}.btn-check:focus+.btn-outline-success,.btn-outline-success:focus{box-shadow:0 0 0 .25rem rgba(25,135,84,.5)}.btn-check:active+.btn-outline-success,.btn-check:checked+.btn-outline-success,.btn-outline-success.active,.btn-outline-success.dropdown-toggle.show,.btn-outline-success:active{color:#fff;background-color:#198754;border-color:#198754}.btn-check:active+.btn-outline-success:focus,.btn-check:checked+.btn-outline-success:focus,.btn-outline-success.active:focus,.btn-outline-success.dropdown-toggle.show:focus,.btn-outline-success:active:focus{box-shadow:0 0 0 .25rem rgba(25,135,84,.5)}.btn-outline-success.disabled,.btn-outline-success:disabled{color:#198754;background-color:transparent}.btn-outline-info{color:#0dcaf0;border-color:#0dcaf0}.btn-outline-info:hover{color:#000;background-color:#0dcaf0;border-color:#0dcaf0}.btn-check:focus+.btn-outline-info,.btn-outline-info:focus{box-shadow:0 0 0 .25rem rgba(13,202,240,.5)}.btn-check:active+.btn-outline-info,.btn-check:checked+.btn-outline-info,.btn-outline-info.active,.btn-outline-info.dropdown-toggle.show,.btn-outline-info:active{color:#000;background-color:#0dcaf0;border-color:#0dcaf0}.btn-check:active+.btn-outline-info:focus,.btn-check:checked+.btn-outline-info:focus,.btn-outline-info.active:focus,.btn-outline-info.dropdown-toggle.show:focus,.btn-outline-info:active:focus{box-shadow:0 0 0 .25rem rgba(13,202,240,.5)}.btn-outline-info.disabled,.btn-outline-info:disabled{color:#0dcaf0;background-color:transparent}.btn-outline-warning{color:#ffc107;border-color:#ffc107}.btn-outline-warning:hover{color:#000;background-color:#ffc107;border-color:#ffc107}.btn-check:focus+.btn-outline-warning,.btn-outline-warning:focus{box-shadow:0 0 0 .25rem rgba(255,193,7,.5)}.btn-check:active+.btn-outline-warning,.btn-check:checked+.btn-outline-warning,.btn-outline-warning.active,.btn-outline-warning.dropdown-toggle.show,.btn-outline-warning:active{color:#000;background-color:#ffc107;border-color:#ffc107}.btn-check:active+.btn-outline-warning:focus,.btn-check:checked+.btn-outline-warning:focus,.btn-outline-warning.active:focus,.btn-outline-warning.dropdown-toggle.show:focus,.btn-outline-warning:active:focus{box-shadow:0 0 0 .25rem rgba(255,193,7,.5)}.btn-outline-warning.disabled,.btn-outline-warning:disabled{color:#ffc107;background-color:transparent}.btn-outline-danger{color:#dc3545;border-color:#dc3545}.btn-outline-danger:hover{color:#fff;background-color:#dc3545;border-color:#dc3545}.btn-check:focus+.btn-outline-danger,.btn-outline-danger:focus{box-shadow:0 0 0 .25rem rgba(220,53,69,.5)}.btn-check:active+.btn-outline-danger,.btn-check:checked+.btn-outline-danger,.btn-outline-danger.active,.btn-outline-danger.dropdown-toggle.show,.btn-outline-danger:active{color:#fff;background-color:#dc3545;border-color:#dc3545}.btn-check:active+.btn-outline-danger:focus,.btn-check:checked+.btn-outline-danger:focus,.btn-outline-danger.active:focus,.btn-outline-danger.dropdown-toggle.show:focus,.btn-outline-danger:active:focus{box-shadow:0 0 0 .25rem rgba(220,53,69,.5)}.btn-outline-danger.disabled,.btn-outline-danger:disabled{color:#dc3545;background-color:transparent}.btn-outline-light{color:#f8f9fa;border-color:#f8f9fa}.btn-outline-light:hover{color:#000;background-color:#f8f9fa;border-color:#f8f9fa}.btn-check:focus+.btn-outline-light,.btn-outline-light:focus{box-shadow:0 0 0 .25rem rgba(248,249,250,.5)}.btn-check:active+.btn-outline-light,.btn-check:checked+.btn-outline-light,.btn-outline-light.active,.btn-outline-light.dropdown-toggle.show,.btn-outline-light:active{color:#000;background-color:#f8f9fa;border-color:#f8f9fa}.btn-check:active+.btn-outline-light:focus,.btn-check:checked+.btn-outline-light:focus,.btn-outline-light.active:focus,.btn-outline-light.dropdown-toggle.show:focus,.btn-outline-light:active:focus{box-shadow:0 0 0 .25rem rgba(248,249,250,.5)}.btn-outline-light.disabled,.btn-outline-light:disabled{color:#f8f9fa;background-color:transparent}.btn-outline-dark{color:#212529;border-color:#212529}.btn-outline-dark:hover{color:#fff;background-color:#212529;border-color:#212529}.btn-check:focus+.btn-outline-dark,.btn-outline-dark:focus{box-shadow:0 0 0 .25rem rgba(33,37,41,.5)}.btn-check:active+.btn-outline-dark,.btn-check:checked+.btn-outline-dark,.btn-outline-dark.active,.btn-outline-dark.dropdown-toggle.show,.btn-outline-dark:active{color:#fff;background-color:#212529;border-color:#212529}.btn-check:active+.btn-outline-dark:focus,.btn-check:checked+.btn-outline-dark:focus,.btn-outline-dark.active:focus,.btn-outline-dark.dropdown-toggle.show:focus,.btn-outline-dark:active:focus{box-shadow:0 0 0 .25rem rgba(33,37,41,.5)}.btn-outline-dark.disabled,.btn-outline-dark:disabled{color:#212529;background-color:transparent}.btn-link{font-weight:400;color:#0d6efd;text-decoration:underline}.btn-link:hover{color:#0a58ca}.btn-link.disabled,.btn-link:disabled{color:#6c757d}.btn-group-lg>.btn,.btn-lg{padding:.5rem 1rem;font-size:1.25rem;border-radius:.3rem}.btn-group-sm>.btn,.btn-sm{padding:.25rem .5rem;font-size:.875rem;border-radius:.2rem}.fade{transition:opacity .15s linear}@media (prefers-reduced-motion:reduce){.fade{transition:none}}.fade:not(.show){opacity:0}.collapse:not(.show){display:none}.collapsing{height:0;overflow:hidden;transition:height .35s ease}@media (prefers-reduced-motion:reduce){.collapsing{transition:none}}.collapsing.collapse-horizontal{width:0;height:auto;transition:width .35s ease}@media (prefers-reduced-motion:reduce){.collapsing.collapse-horizontal{transition:none}}.dropdown,.dropend,.dropstart,.dropup{position:relative}.dropdown-toggle{white-space:nowrap}.dropdown-toggle::after{display:inline-block;margin-left:.255em;vertical-align:.255em;content:"";border-top:.3em solid;border-right:.3em solid transparent;border-bottom:0;border-left:.3em solid transparent}.dropdown-toggle:empty::after{margin-left:0}.dropdown-menu{position:absolute;z-index:1000;display:none;min-width:10rem;padding:.5rem 0;margin:0;font-size:1rem;color:#212529;text-align:left;list-style:none;background-color:#fff;background-clip:padding-box;border:1px solid rgba(0,0,0,.15);border-radius:.25rem}.dropdown-menu[data-bs-popper]{top:100%;left:0;margin-top:.125rem}.dropdown-menu-start{--bs-position:start}.dropdown-menu-start[data-bs-popper]{right:auto;left:0}.dropdown-menu-end{--bs-position:end}.dropdown-menu-end[data-bs-popper]{right:0;left:auto}@media (min-width:576px){.dropdown-menu-sm-start{--bs-position:start}.dropdown-menu-sm-start[data-bs-popper]{right:auto;left:0}.dropdown-menu-sm-end{--bs-position:end}.dropdown-menu-sm-end[data-bs-popper]{right:0;left:auto}}@media (min-width:768px){.dropdown-menu-md-start{--bs-position:start}.dropdown-menu-md-start[data-bs-popper]{right:auto;left:0}.dropdown-menu-md-end{--bs-position:end}.dropdown-menu-md-end[data-bs-popper]{right:0;left:auto}}@media (min-width:992px){.dropdown-menu-lg-start{--bs-position:start}.dropdown-menu-lg-start[data-bs-popper]{right:auto;left:0}.dropdown-menu-lg-end{--bs-position:end}.dropdown-menu-lg-end[data-bs-popper]{right:0;left:auto}}@media (min-width:1200px){.dropdown-menu-xl-start{--bs-position:start}.dropdown-menu-xl-start[data-bs-popper]{right:auto;left:0}.dropdown-menu-xl-end{--bs-position:end}.dropdown-menu-xl-end[data-bs-popper]{right:0;left:auto}}@media (min-width:1400px){.dropdown-menu-xxl-start{--bs-position:start}.dropdown-menu-xxl-start[data-bs-popper]{right:auto;left:0}.dropdown-menu-xxl-end{--bs-position:end}.dropdown-menu-xxl-end[data-bs-popper]{right:0;left:auto}}.dropup .dropdown-menu[data-bs-popper]{top:auto;bottom:100%;margin-top:0;margin-bottom:.125rem}.dropup .dropdown-toggle::after{display:inline-block;margin-left:.255em;vertical-align:.255em;content:"";border-top:0;border-right:.3em solid transparent;border-bottom:.3em solid;border-left:.3em solid transparent}.dropup .dropdown-toggle:empty::after{margin-left:0}.dropend .dropdown-menu[data-bs-popper]{top:0;right:auto;left:100%;margin-top:0;margin-left:.125rem}.dropend .dropdown-toggle::after{display:inline-block;margin-left:.255em;vertical-align:.255em;content:"";border-top:.3em solid transparent;border-right:0;border-bottom:.3em solid transparent;border-left:.3em solid}.dropend .dropdown-toggle:empty::after{margin-left:0}.dropend .dropdown-toggle::after{vertical-align:0}.dropstart .dropdown-menu[data-bs-popper]{top:0;right:100%;left:auto;margin-top:0;margin-right:.125rem}.dropstart .dropdown-toggle::after{display:inline-block;margin-left:.255em;vertical-align:.255em;content:""}.dropstart .dropdown-toggle::after{display:none}.dropstart .dropdown-toggle::before{display:inline-block;margin-right:.255em;vertical-align:.255em;content:"";border-top:.3em solid transparent;border-right:.3em solid;border-bottom:.3em solid transparent}.dropstart .dropdown-toggle:empty::after{margin-left:0}.dropstart .dropdown-toggle::before{vertical-align:0}.dropdown-divider{height:0;margin:.5rem 0;overflow:hidden;border-top:1px solid rgba(0,0,0,.15)}.dropdown-item{display:block;width:100%;padding:.25rem 1rem;clear:both;font-weight:400;color:#212529;text-align:inherit;text-decoration:none;white-space:nowrap;background-color:transparent;border:0}.dropdown-item:focus,.dropdown-item:hover{color:#1e2125;background-color:#e9ecef}.dropdown-item.active,.dropdown-item:active{color:#fff;text-decoration:none;background-color:#0d6efd}.dropdown-item.disabled,.dropdown-item:disabled{color:#adb5bd;pointer-events:none;background-color:transparent}.dropdown-menu.show{display:block}.dropdown-header{display:block;padding:.5rem 1rem;margin-bottom:0;font-size:.875rem;color:#6c757d;white-space:nowrap}.dropdown-item-text{display:block;padding:.25rem 1rem;color:#212529}.dropdown-menu-dark{color:#dee2e6;background-color:#343a40;border-color:rgba(0,0,0,.15)}.dropdown-menu-dark .dropdown-item{color:#dee2e6}.dropdown-menu-dark .dropdown-item:focus,.dropdown-menu-dark .dropdown-item:hover{color:#fff;background-color:rgba(255,255,255,.15)}.dropdown-menu-dark .dropdown-item.active,.dropdown-menu-dark .dropdown-item:active{color:#fff;background-color:#0d6efd}.dropdown-menu-dark .dropdown-item.disabled,.dropdown-menu-dark .dropdown-item:disabled{color:#adb5bd}.dropdown-menu-dark .dropdown-divider{border-color:rgba(0,0,0,.15)}.dropdown-menu-dark .dropdown-item-text{color:#dee2e6}.dropdown-menu-dark .dropdown-header{color:#adb5bd}.btn-group,.btn-group-vertical{position:relative;display:inline-flex;vertical-align:middle}.btn-group-vertical>.btn,.btn-group>.btn{position:relative;flex:1 1 auto}.btn-group-vertical>.btn-check:checked+.btn,.btn-group-vertical>.btn-check:focus+.btn,.btn-group-vertical>.btn.active,.btn-group-vertical>.btn:active,.btn-group-vertical>.btn:focus,.btn-group-vertical>.btn:hover,.btn-group>.btn-check:checked+.btn,.btn-group>.btn-check:focus+.btn,.btn-group>.btn.active,.btn-group>.btn:active,.btn-group>.btn:focus,.btn-group>.btn:hover{z-index:1}.btn-toolbar{display:flex;flex-wrap:wrap;justify-content:flex-start}.btn-toolbar .input-group{width:auto}.btn-group>.btn-group:not(:first-child),.btn-group>.btn:not(:first-child){margin-left:-1px}.btn-group>.btn-group:not(:last-child)>.btn,.btn-group>.btn:not(:last-child):not(.dropdown-toggle){border-top-right-radius:0;border-bottom-right-radius:0}.btn-group>.btn-group:not(:first-child)>.btn,.btn-group>.btn:nth-child(n+3),.btn-group>:not(.btn-check)+.btn{border-top-left-radius:0;border-bottom-left-radius:0}.dropdown-toggle-split{padding-right:.5625rem;padding-left:.5625rem}.dropdown-toggle-split::after,.dropend .dropdown-toggle-split::after,.dropup .dropdown-toggle-split::after{margin-left:0}.dropstart .dropdown-toggle-split::before{margin-right:0}.btn-group-sm>.btn+.dropdown-toggle-split,.btn-sm+.dropdown-toggle-split{padding-right:.375rem;padding-left:.375rem}.btn-group-lg>.btn+.dropdown-toggle-split,.btn-lg+.dropdown-toggle-split{padding-right:.75rem;padding-left:.75rem}.btn-group-vertical{flex-direction:column;align-items:flex-start;justify-content:center}.btn-group-vertical>.btn,.btn-group-vertical>.btn-group{width:100%}.btn-group-vertical>.btn-group:not(:first-child),.btn-group-vertical>.btn:not(:first-child){margin-top:-1px}.btn-group-vertical>.btn-group:not(:last-child)>.btn,.btn-group-vertical>.btn:not(:last-child):not(.dropdown-toggle){border-bottom-right-radius:0;border-bottom-left-radius:0}.btn-group-vertical>.btn-group:not(:first-child)>.btn,.btn-group-vertical>.btn~.btn{border-top-left-radius:0;border-top-right-radius:0}.nav{display:flex;flex-wrap:wrap;padding-left:0;margin-bottom:0;list-style:none}.nav-link{display:block;padding:.5rem 1rem;color:#0d6efd;text-decoration:none;transition:color .15s ease-in-out,background-color .15s ease-in-out,border-color .15s ease-in-out}@media (prefers-reduced-motion:reduce){.nav-link{transition:none}}.nav-link:focus,.nav-link:hover{color:#0a58ca}.nav-link.disabled{color:#6c757d;pointer-events:none;cursor:default}.nav-tabs{border-bottom:1px solid #dee2e6}.nav-tabs .nav-link{margin-bottom:-1px;background:0 0;border:1px solid transparent;border-top-left-radius:.25rem;border-top-right-radius:.25rem}.nav-tabs .nav-link:focus,.nav-tabs .nav-link:hover{border-color:#e9ecef #e9ecef #dee2e6;isolation:isolate}.nav-tabs .nav-link.disabled{color:#6c757d;background-color:transparent;border-color:transparent}.nav-tabs .nav-item.show .nav-link,.nav-tabs .nav-link.active{color:#495057;background-color:#fff;border-color:#dee2e6 #dee2e6 #fff}.nav-tabs .dropdown-menu{margin-top:-1px;border-top-left-radius:0;border-top-right-radius:0}.nav-pills .nav-link{background:0 0;border:0;border-radius:.25rem}.nav-pills .nav-link.active,.nav-pills .show>.nav-link{color:#fff;background-color:#0d6efd}.nav-fill .nav-item,.nav-fill>.nav-link{flex:1 1 auto;text-align:center}.nav-justified .nav-item,.nav-justified>.nav-link{flex-basis:0;flex-grow:1;text-align:center}.nav-fill .nav-item .nav-link,.nav-justified .nav-item .nav-link{width:100%}.tab-content>.tab-pane{display:none}.tab-content>.active{display:block}.navbar{position:relative;display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;padding-top:.5rem;padding-bottom:.5rem}.navbar>.container,.navbar>.container-fluid,.navbar>.container-lg,.navbar>.container-md,.navbar>.container-sm,.navbar>.container-xl,.navbar>.container-xxl{display:flex;flex-wrap:inherit;align-items:center;justify-content:space-between}.navbar-brand{padding-top:.3125rem;padding-bottom:.3125rem;margin-right:1rem;font-size:1.25rem;text-decoration:none;white-space:nowrap}.navbar-nav{display:flex;flex-direction:column;padding-left:0;margin-bottom:0;list-style:none}.navbar-nav .nav-link{padding-right:0;padding-left:0}.navbar-nav .dropdown-menu{position:static}.navbar-text{padding-top:.5rem;padding-bottom:.5rem}.navbar-collapse{flex-basis:100%;flex-grow:1;align-items:center}.navbar-toggler{padding:.25rem .75rem;font-size:1.25rem;line-height:1;background-color:transparent;border:1px solid transparent;border-radius:.25rem;transition:box-shadow .15s ease-in-out}@media (prefers-reduced-motion:reduce){.navbar-toggler{transition:none}}.navbar-toggler:hover{text-decoration:none}.navbar-toggler:focus{text-decoration:none;outline:0;box-shadow:0 0 0 .25rem}.navbar-toggler-icon{display:inline-block;width:1.5em;height:1.5em;vertical-align:middle;background-repeat:no-repeat;background-position:center;background-size:100%}.navbar-nav-scroll{max-height:var(--bs-scroll-height,75vh);overflow-y:auto}@media (min-width:576px){.navbar-expand-sm{flex-wrap:nowrap;justify-content:flex-start}.navbar-expand-sm .navbar-nav{flex-direction:row}.navbar-expand-sm .navbar-nav .dropdown-menu{position:absolute}.navbar-expand-sm .navbar-nav .nav-link{padding-right:.5rem;padding-left:.5rem}.navbar-expand-sm .navbar-nav-scroll{overflow:visible}.navbar-expand-sm .navbar-collapse{display:flex!important;flex-basis:auto}.navbar-expand-sm .navbar-toggler{display:none}.navbar-expand-sm .offcanvas-header{display:none}.navbar-expand-sm .offcanvas{position:inherit;bottom:0;z-index:1000;flex-grow:1;visibility:visible!important;background-color:transparent;border-right:0;border-left:0;transition:none;transform:none}.navbar-expand-sm .offcanvas-bottom,.navbar-expand-sm .offcanvas-top{height:auto;border-top:0;border-bottom:0}.navbar-expand-sm .offcanvas-body{display:flex;flex-grow:0;padding:0;overflow-y:visible}}@media (min-width:768px){.navbar-expand-md{flex-wrap:nowrap;justify-content:flex-start}.navbar-expand-md .navbar-nav{flex-direction:row}.navbar-expand-md .navbar-nav .dropdown-menu{position:absolute}.navbar-expand-md .navbar-nav .nav-link{padding-right:.5rem;padding-left:.5rem}.navbar-expand-md .navbar-nav-scroll{overflow:visible}.navbar-expand-md .navbar-collapse{display:flex!important;flex-basis:auto}.navbar-expand-md .navbar-toggler{display:none}.navbar-expand-md .offcanvas-header{display:none}.navbar-expand-md .offcanvas{position:inherit;bottom:0;z-index:1000;flex-grow:1;visibility:visible!important;background-color:transparent;border-right:0;border-left:0;transition:none;transform:none}.navbar-expand-md .offcanvas-bottom,.navbar-expand-md .offcanvas-top{height:auto;border-top:0;border-bottom:0}.navbar-expand-md .offcanvas-body{display:flex;flex-grow:0;padding:0;overflow-y:visible}}@media (min-width:992px){.navbar-expand-lg{flex-wrap:nowrap;justify-content:flex-start}.navbar-expand-lg .navbar-nav{flex-direction:row}.navbar-expand-lg .navbar-nav .dropdown-menu{position:absolute}.navbar-expand-lg .navbar-nav .nav-link{padding-right:.5rem;padding-left:.5rem}.navbar-expand-lg .navbar-nav-scroll{overflow:visible}.navbar-expand-lg .navbar-collapse{display:flex!important;flex-basis:auto}.navbar-expand-lg .navbar-toggler{display:none}.navbar-expand-lg .offcanvas-header{display:none}.navbar-expand-lg .offcanvas{position:inherit;bottom:0;z-index:1000;flex-grow:1;visibility:visible!important;background-color:transparent;border-right:0;border-left:0;transition:none;transform:none}.navbar-expand-lg .offcanvas-bottom,.navbar-expand-lg .offcanvas-top{height:auto;border-top:0;border-bottom:0}.navbar-expand-lg .offcanvas-body{display:flex;flex-grow:0;padding:0;overflow-y:visible}}@media (min-width:1200px){.navbar-expand-xl{flex-wrap:nowrap;justify-content:flex-start}.navbar-expand-xl .navbar-nav{flex-direction:row}.navbar-expand-xl .navbar-nav .dropdown-menu{position:absolute}.navbar-expand-xl .navbar-nav .nav-link{padding-right:.5rem;padding-left:.5rem}.navbar-expand-xl .navbar-nav-scroll{overflow:visible}.navbar-expand-xl .navbar-collapse{display:flex!important;flex-basis:auto}.navbar-expand-xl .navbar-toggler{display:none}.navbar-expand-xl .offcanvas-header{display:none}.navbar-expand-xl .offcanvas{position:inherit;bottom:0;z-index:1000;flex-grow:1;visibility:visible!important;background-color:transparent;border-right:0;border-left:0;transition:none;transform:none}.navbar-expand-xl .offcanvas-bottom,.navbar-expand-xl .offcanvas-top{height:auto;border-top:0;border-bottom:0}.navbar-expand-xl .offcanvas-body{display:flex;flex-grow:0;padding:0;overflow-y:visible}}@media (min-width:1400px){.navbar-expand-xxl{flex-wrap:nowrap;justify-content:flex-start}.navbar-expand-xxl .navbar-nav{flex-direction:row}.navbar-expand-xxl .navbar-nav .dropdown-menu{position:absolute}.navbar-expand-xxl .navbar-nav .nav-link{padding-right:.5rem;padding-left:.5rem}.navbar-expand-xxl .navbar-nav-scroll{overflow:visible}.navbar-expand-xxl .navbar-collapse{display:flex!important;flex-basis:auto}.navbar-expand-xxl .navbar-toggler{display:none}.navbar-expand-xxl .offcanvas-header{display:none}.navbar-expand-xxl .offcanvas{position:inherit;bottom:0;z-index:1000;flex-grow:1;visibility:visible!important;background-color:transparent;border-right:0;border-left:0;transition:none;transform:none}.navbar-expand-xxl .offcanvas-bottom,.navbar-expand-xxl .offcanvas-top{height:auto;border-top:0;border-bottom:0}.navbar-expand-xxl .offcanvas-body{display:flex;flex-grow:0;padding:0;overflow-y:visible}}.navbar-expand{flex-wrap:nowrap;justify-content:flex-start}.navbar-expand .navbar-nav{flex-direction:row}.navbar-expand .navbar-nav .dropdown-menu{position:absolute}.navbar-expand .navbar-nav .nav-link{padding-right:.5rem;padding-left:.5rem}.navbar-expand .navbar-nav-scroll{overflow:visible}.navbar-expand .navbar-collapse{display:flex!important;flex-basis:auto}.navbar-expand .navbar-toggler{display:none}.navbar-expand .offcanvas-header{display:none}.navbar-expand .offcanvas{position:inherit;bottom:0;z-index:1000;flex-grow:1;visibility:visible!important;background-color:transparent;border-right:0;border-left:0;transition:none;transform:none}.navbar-expand .offcanvas-bottom,.navbar-expand .offcanvas-top{height:auto;border-top:0;border-bottom:0}.navbar-expand .offcanvas-body{display:flex;flex-grow:0;padding:0;overflow-y:visible}.navbar-light .navbar-brand{color:rgba(0,0,0,.9)}.navbar-light .navbar-brand:focus,.navbar-light .navbar-brand:hover{color:rgba(0,0,0,.9)}.navbar-light .navbar-nav .nav-link{color:rgba(0,0,0,.55)}.navbar-light .navbar-nav .nav-link:focus,.navbar-light .navbar-nav .nav-link:hover{color:rgba(0,0,0,.7)}.navbar-light .navbar-nav .nav-link.disabled{color:rgba(0,0,0,.3)}.navbar-light .navbar-nav .nav-link.active,.navbar-light .navbar-nav .show>.nav-link{color:rgba(0,0,0,.9)}.navbar-light .navbar-toggler{color:rgba(0,0,0,.55);border-color:rgba(0,0,0,.1)}.navbar-light .navbar-toggler-icon{background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 30 30'%3e%3cpath stroke='rgba%280, 0, 0, 0.55%29' stroke-linecap='round' stroke-miterlimit='10' stroke-width='2' d='M4 7h22M4 15h22M4 23h22'/%3e%3c/svg%3e")}.navbar-light .navbar-text{color:rgba(0,0,0,.55)}.navbar-light .navbar-text a,.navbar-light .navbar-text a:focus,.navbar-light .navbar-text a:hover{color:rgba(0,0,0,.9)}.navbar-dark .navbar-brand{color:#fff}.navbar-dark .navbar-brand:focus,.navbar-dark .navbar-brand:hover{color:#fff}.navbar-dark .navbar-nav .nav-link{color:rgba(255,255,255,.55)}.navbar-dark .navbar-nav .nav-link:focus,.navbar-dark .navbar-nav .nav-link:hover{color:rgba(255,255,255,.75)}.navbar-dark .navbar-nav .nav-link.disabled{color:rgba(255,255,255,.25)}.navbar-dark .navbar-nav .nav-link.active,.navbar-dark .navbar-nav .show>.nav-link{color:#fff}.navbar-dark .navbar-toggler{color:rgba(255,255,255,.55);border-color:rgba(255,255,255,.1)}.navbar-dark .navbar-toggler-icon{background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 30 30'%3e%3cpath stroke='rgba%28255, 255, 255, 0.55%29' stroke-linecap='round' stroke-miterlimit='10' stroke-width='2' d='M4 7h22M4 15h22M4 23h22'/%3e%3c/svg%3e")}.navbar-dark .navbar-text{color:rgba(255,255,255,.55)}.navbar-dark .navbar-text a,.navbar-dark .navbar-text a:focus,.navbar-dark .navbar-text a:hover{color:#fff}.card{position:relative;display:flex;flex-direction:column;min-width:0;word-wrap:break-word;background-color:#fff;background-clip:border-box;border:1px solid rgba(0,0,0,.125);border-radius:.25rem}.card>hr{margin-right:0;margin-left:0}.card>.list-group{border-top:inherit;border-bottom:inherit}.card>.list-group:first-child{border-top-width:0;border-top-left-radius:calc(.25rem - 1px);border-top-right-radius:calc(.25rem - 1px)}.card>.list-group:last-child{border-bottom-width:0;border-bottom-right-radius:calc(.25rem - 1px);border-bottom-left-radius:calc(.25rem - 1px)}.card>.card-header+.list-group,.card>.list-group+.card-footer{border-top:0}.card-body{flex:1 1 auto;padding:1rem 1rem}.card-title{margin-bottom:.5rem}.card-subtitle{margin-top:-.25rem;margin-bottom:0}.card-text:last-child{margin-bottom:0}.card-link+.card-link{margin-left:1rem}.card-header{padding:.5rem 1rem;margin-bottom:0;background-color:rgba(0,0,0,.03);border-bottom:1px solid rgba(0,0,0,.125)}.card-header:first-child{border-radius:calc(.25rem - 1px) calc(.25rem - 1px) 0 0}.card-footer{padding:.5rem 1rem;background-color:rgba(0,0,0,.03);border-top:1px solid rgba(0,0,0,.125)}.card-footer:last-child{border-radius:0 0 calc(.25rem - 1px) calc(.25rem - 1px)}.card-header-tabs{margin-right:-.5rem;margin-bottom:-.5rem;margin-left:-.5rem;border-bottom:0}.card-header-pills{margin-right:-.5rem;margin-left:-.5rem}.card-img-overlay{position:absolute;top:0;right:0;bottom:0;left:0;padding:1rem;border-radius:calc(.25rem - 1px)}.card-img,.card-img-bottom,.card-img-top{width:100%}.card-img,.card-img-top{border-top-left-radius:calc(.25rem - 1px);border-top-right-radius:calc(.25rem - 1px)}.card-img,.card-img-bottom{border-bottom-right-radius:calc(.25rem - 1px);border-bottom-left-radius:calc(.25rem - 1px)}.card-group>.card{margin-bottom:.75rem}@media (min-width:576px){.card-group{display:flex;flex-flow:row wrap}.card-group>.card{flex:1 0 0%;margin-bottom:0}.card-group>.card+.card{margin-left:0;border-left:0}.card-group>.card:not(:last-child){border-top-right-radius:0;border-bottom-right-radius:0}.card-group>.card:not(:last-child) .card-header,.card-group>.card:not(:last-child) .card-img-top{border-top-right-radius:0}.card-group>.card:not(:last-child) .card-footer,.card-group>.card:not(:last-child) .card-img-bottom{border-bottom-right-radius:0}.card-group>.card:not(:first-child){border-top-left-radius:0;border-bottom-left-radius:0}.card-group>.card:not(:first-child) .card-header,.card-group>.card:not(:first-child) .card-img-top{border-top-left-radius:0}.card-group>.card:not(:first-child) .card-footer,.card-group>.card:not(:first-child) .card-img-bottom{border-bottom-left-radius:0}}.accordion-button{position:relative;display:flex;align-items:center;width:100%;padding:1rem 1.25rem;font-size:1rem;color:#212529;text-align:left;background-color:#fff;border:0;border-radius:0;overflow-anchor:none;transition:color .15s ease-in-out,background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out,border-radius .15s ease}@media (prefers-reduced-motion:reduce){.accordion-button{transition:none}}.accordion-button:not(.collapsed){color:#0c63e4;background-color:#e7f1ff;box-shadow:inset 0 -1px 0 rgba(0,0,0,.125)}.accordion-button:not(.collapsed)::after{background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='%230c63e4'%3e%3cpath fill-rule='evenodd' d='M1.646 4.646a.5.5 0 0 1 .708 0L8 10.293l5.646-5.647a.5.5 0 0 1 .708.708l-6 6a.5.5 0 0 1-.708 0l-6-6a.5.5 0 0 1 0-.708z'/%3e%3c/svg%3e");transform:rotate(-180deg)}.accordion-button::after{flex-shrink:0;width:1.25rem;height:1.25rem;margin-left:auto;content:"";background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='%23212529'%3e%3cpath fill-rule='evenodd' d='M1.646 4.646a.5.5 0 0 1 .708 0L8 10.293l5.646-5.647a.5.5 0 0 1 .708.708l-6 6a.5.5 0 0 1-.708 0l-6-6a.5.5 0 0 1 0-.708z'/%3e%3c/svg%3e");background-repeat:no-repeat;background-size:1.25rem;transition:transform .2s ease-in-out}@media (prefers-reduced-motion:reduce){.accordion-button::after{transition:none}}.accordion-button:hover{z-index:2}.accordion-button:focus{z-index:3;border-color:#86b7fe;outline:0;box-shadow:0 0 0 .25rem rgba(13,110,253,.25)}.accordion-header{margin-bottom:0}.accordion-item{background-color:#fff;border:1px solid rgba(0,0,0,.125)}.accordion-item:first-of-type{border-top-left-radius:.25rem;border-top-right-radius:.25rem}.accordion-item:first-of-type .accordion-button{border-top-left-radius:calc(.25rem - 1px);border-top-right-radius:calc(.25rem - 1px)}.accordion-item:not(:first-of-type){border-top:0}.accordion-item:last-of-type{border-bottom-right-radius:.25rem;border-bottom-left-radius:.25rem}.accordion-item:last-of-type .accordion-button.collapsed{border-bottom-right-radius:calc(.25rem - 1px);border-bottom-left-radius:calc(.25rem - 1px)}.accordion-item:last-of-type .accordion-collapse{border-bottom-right-radius:.25rem;border-bottom-left-radius:.25rem}.accordion-body{padding:1rem 1.25rem}.accordion-flush .accordion-collapse{border-width:0}.accordion-flush .accordion-item{border-right:0;border-left:0;border-radius:0}.accordion-flush .accordion-item:first-child{border-top:0}.accordion-flush .accordion-item:last-child{border-bottom:0}.accordion-flush .accordion-item .accordion-button{border-radius:0}.breadcrumb{display:flex;flex-wrap:wrap;padding:0 0;margin-bottom:1rem;list-style:none}.breadcrumb-item+.breadcrumb-item{padding-left:.5rem}.breadcrumb-item+.breadcrumb-item::before{float:left;padding-right:.5rem;color:#6c757d;content:var(--bs-breadcrumb-divider, "/")}.breadcrumb-item.active{color:#6c757d}.pagination{display:flex;padding-left:0;list-style:none}.page-link{position:relative;display:block;color:#0d6efd;text-decoration:none;background-color:#fff;border:1px solid #dee2e6;transition:color .15s ease-in-out,background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out}@media (prefers-reduced-motion:reduce){.page-link{transition:none}}.page-link:hover{z-index:2;color:#0a58ca;background-color:#e9ecef;border-color:#dee2e6}.page-link:focus{z-index:3;color:#0a58ca;background-color:#e9ecef;outline:0;box-shadow:0 0 0 .25rem rgba(13,110,253,.25)}.page-item:not(:first-child) .page-link{margin-left:-1px}.page-item.active .page-link{z-index:3;color:#fff;background-color:#0d6efd;border-color:#0d6efd}.page-item.disabled .page-link{color:#6c757d;pointer-events:none;background-color:#fff;border-color:#dee2e6}.page-link{padding:.375rem .75rem}.page-item:first-child .page-link{border-top-left-radius:.25rem;border-bottom-left-radius:.25rem}.page-item:last-child .page-link{border-top-right-radius:.25rem;border-bottom-right-radius:.25rem}.pagination-lg .page-link{padding:.75rem 1.5rem;font-size:1.25rem}.pagination-lg .page-item:first-child .page-link{border-top-left-radius:.3rem;border-bottom-left-radius:.3rem}.pagination-lg .page-item:last-child .page-link{border-top-right-radius:.3rem;border-bottom-right-radius:.3rem}.pagination-sm .page-link{padding:.25rem .5rem;font-size:.875rem}.pagination-sm .page-item:first-child .page-link{border-top-left-radius:.2rem;border-bottom-left-radius:.2rem}.pagination-sm .page-item:last-child .page-link{border-top-right-radius:.2rem;border-bottom-right-radius:.2rem}.badge{display:inline-block;padding:.35em .65em;font-size:.75em;font-weight:700;line-height:1;color:#fff;text-align:center;white-space:nowrap;vertical-align:baseline;border-radius:.25rem}.badge:empty{display:none}.btn .badge{position:relative;top:-1px}.alert{position:relative;padding:1rem 1rem;margin-bottom:1rem;border:1px solid transparent;border-radius:.25rem}.alert-heading{color:inherit}.alert-link{font-weight:700}.alert-dismissible{padding-right:3rem}.alert-dismissible .btn-close{position:absolute;top:0;right:0;z-index:2;padding:1.25rem 1rem}.alert-primary{color:#084298;background-color:#cfe2ff;border-color:#b6d4fe}.alert-primary .alert-link{color:#06357a}.alert-secondary{color:#41464b;background-color:#e2e3e5;border-color:#d3d6d8}.alert-secondary .alert-link{color:#34383c}.alert-success{color:#0f5132;background-color:#d1e7dd;border-color:#badbcc}.alert-success .alert-link{color:#0c4128}.alert-info{color:#055160;background-color:#cff4fc;border-color:#b6effb}.alert-info .alert-link{color:#04414d}.alert-warning{color:#664d03;background-color:#fff3cd;border-color:#ffecb5}.alert-warning .alert-link{color:#523e02}.alert-danger{color:#842029;background-color:#f8d7da;border-color:#f5c2c7}.alert-danger .alert-link{color:#6a1a21}.alert-light{color:#636464;background-color:#fefefe;border-color:#fdfdfe}.alert-light .alert-link{color:#4f5050}.alert-dark{color:#141619;background-color:#d3d3d4;border-color:#bcbebf}.alert-dark .alert-link{color:#101214}@-webkit-keyframes progress-bar-stripes{0%{background-position-x:1rem}}@keyframes progress-bar-stripes{0%{background-position-x:1rem}}.progress{display:flex;height:1rem;overflow:hidden;font-size:.75rem;background-color:#e9ecef;border-radius:.25rem}.progress-bar{display:flex;flex-direction:column;justify-content:center;overflow:hidden;color:#fff;text-align:center;white-space:nowrap;background-color:#0d6efd;transition:width .6s ease}@media (prefers-reduced-motion:reduce){.progress-bar{transition:none}}.progress-bar-striped{background-image:linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-size:1rem 1rem}.progress-bar-animated{-webkit-animation:1s linear infinite progress-bar-stripes;animation:1s linear infinite progress-bar-stripes}@media (prefers-reduced-motion:reduce){.progress-bar-animated{-webkit-animation:none;animation:none}}.list-group{display:flex;flex-direction:column;padding-left:0;margin-bottom:0;border-radius:.25rem}.list-group-numbered{list-style-type:none;counter-reset:section}.list-group-numbered>li::before{content:counters(section, ".") ". ";counter-increment:section}.list-group-item-action{width:100%;color:#495057;text-align:inherit}.list-group-item-action:focus,.list-group-item-action:hover{z-index:1;color:#495057;text-decoration:none;background-color:#f8f9fa}.list-group-item-action:active{color:#212529;background-color:#e9ecef}.list-group-item{position:relative;display:block;padding:.5rem 1rem;color:#212529;text-decoration:none;background-color:#fff;border:1px solid rgba(0,0,0,.125)}.list-group-item:first-child{border-top-left-radius:inherit;border-top-right-radius:inherit}.list-group-item:last-child{border-bottom-right-radius:inherit;border-bottom-left-radius:inherit}.list-group-item.disabled,.list-group-item:disabled{color:#6c757d;pointer-events:none;background-color:#fff}.list-group-item.active{z-index:2;color:#fff;background-color:#0d6efd;border-color:#0d6efd}.list-group-item+.list-group-item{border-top-width:0}.list-group-item+.list-group-item.active{margin-top:-1px;border-top-width:1px}.list-group-horizontal{flex-direction:row}.list-group-horizontal>.list-group-item:first-child{border-bottom-left-radius:.25rem;border-top-right-radius:0}.list-group-horizontal>.list-group-item:last-child{border-top-right-radius:.25rem;border-bottom-left-radius:0}.list-group-horizontal>.list-group-item.active{margin-top:0}.list-group-horizontal>.list-group-item+.list-group-item{border-top-width:1px;border-left-width:0}.list-group-horizontal>.list-group-item+.list-group-item.active{margin-left:-1px;border-left-width:1px}@media (min-width:576px){.list-group-horizontal-sm{flex-direction:row}.list-group-horizontal-sm>.list-group-item:first-child{border-bottom-left-radius:.25rem;border-top-right-radius:0}.list-group-horizontal-sm>.list-group-item:last-child{border-top-right-radius:.25rem;border-bottom-left-radius:0}.list-group-horizontal-sm>.list-group-item.active{margin-top:0}.list-group-horizontal-sm>.list-group-item+.list-group-item{border-top-width:1px;border-left-width:0}.list-group-horizontal-sm>.list-group-item+.list-group-item.active{margin-left:-1px;border-left-width:1px}}@media (min-width:768px){.list-group-horizontal-md{flex-direction:row}.list-group-horizontal-md>.list-group-item:first-child{border-bottom-left-radius:.25rem;border-top-right-radius:0}.list-group-horizontal-md>.list-group-item:last-child{border-top-right-radius:.25rem;border-bottom-left-radius:0}.list-group-horizontal-md>.list-group-item.active{margin-top:0}.list-group-horizontal-md>.list-group-item+.list-group-item{border-top-width:1px;border-left-width:0}.list-group-horizontal-md>.list-group-item+.list-group-item.active{margin-left:-1px;border-left-width:1px}}@media (min-width:992px){.list-group-horizontal-lg{flex-direction:row}.list-group-horizontal-lg>.list-group-item:first-child{border-bottom-left-radius:.25rem;border-top-right-radius:0}.list-group-horizontal-lg>.list-group-item:last-child{border-top-right-radius:.25rem;border-bottom-left-radius:0}.list-group-horizontal-lg>.list-group-item.active{margin-top:0}.list-group-horizontal-lg>.list-group-item+.list-group-item{border-top-width:1px;border-left-width:0}.list-group-horizontal-lg>.list-group-item+.list-group-item.active{margin-left:-1px;border-left-width:1px}}@media (min-width:1200px){.list-group-horizontal-xl{flex-direction:row}.list-group-horizontal-xl>.list-group-item:first-child{border-bottom-left-radius:.25rem;border-top-right-radius:0}.list-group-horizontal-xl>.list-group-item:last-child{border-top-right-radius:.25rem;border-bottom-left-radius:0}.list-group-horizontal-xl>.list-group-item.active{margin-top:0}.list-group-horizontal-xl>.list-group-item+.list-group-item{border-top-width:1px;border-left-width:0}.list-group-horizontal-xl>.list-group-item+.list-group-item.active{margin-left:-1px;border-left-width:1px}}@media (min-width:1400px){.list-group-horizontal-xxl{flex-direction:row}.list-group-horizontal-xxl>.list-group-item:first-child{border-bottom-left-radius:.25rem;border-top-right-radius:0}.list-group-horizontal-xxl>.list-group-item:last-child{border-top-right-radius:.25rem;border-bottom-left-radius:0}.list-group-horizontal-xxl>.list-group-item.active{margin-top:0}.list-group-horizontal-xxl>.list-group-item+.list-group-item{border-top-width:1px;border-left-width:0}.list-group-horizontal-xxl>.list-group-item+.list-group-item.active{margin-left:-1px;border-left-width:1px}}.list-group-flush{border-radius:0}.list-group-flush>.list-group-item{border-width:0 0 1px}.list-group-flush>.list-group-item:last-child{border-bottom-width:0}.list-group-item-primary{color:#084298;background-color:#cfe2ff}.list-group-item-primary.list-group-item-action:focus,.list-group-item-primary.list-group-item-action:hover{color:#084298;background-color:#bacbe6}.list-group-item-primary.list-group-item-action.active{color:#fff;background-color:#084298;border-color:#084298}.list-group-item-secondary{color:#41464b;background-color:#e2e3e5}.list-group-item-secondary.list-group-item-action:focus,.list-group-item-secondary.list-group-item-action:hover{color:#41464b;background-color:#cbccce}.list-group-item-secondary.list-group-item-action.active{color:#fff;background-color:#41464b;border-color:#41464b}.list-group-item-success{color:#0f5132;background-color:#d1e7dd}.list-group-item-success.list-group-item-action:focus,.list-group-item-success.list-group-item-action:hover{color:#0f5132;background-color:#bcd0c7}.list-group-item-success.list-group-item-action.active{color:#fff;background-color:#0f5132;border-color:#0f5132}.list-group-item-info{color:#055160;background-color:#cff4fc}.list-group-item-info.list-group-item-action:focus,.list-group-item-info.list-group-item-action:hover{color:#055160;background-color:#badce3}.list-group-item-info.list-group-item-action.active{color:#fff;background-color:#055160;border-color:#055160}.list-group-item-warning{color:#664d03;background-color:#fff3cd}.list-group-item-warning.list-group-item-action:focus,.list-group-item-warning.list-group-item-action:hover{color:#664d03;background-color:#e6dbb9}.list-group-item-warning.list-group-item-action.active{color:#fff;background-color:#664d03;border-color:#664d03}.list-group-item-danger{color:#842029;background-color:#f8d7da}.list-group-item-danger.list-group-item-action:focus,.list-group-item-danger.list-group-item-action:hover{color:#842029;background-color:#dfc2c4}.list-group-item-danger.list-group-item-action.active{color:#fff;background-color:#842029;border-color:#842029}.list-group-item-light{color:#636464;background-color:#fefefe}.list-group-item-light.list-group-item-action:focus,.list-group-item-light.list-group-item-action:hover{color:#636464;background-color:#e5e5e5}.list-group-item-light.list-group-item-action.active{color:#fff;background-color:#636464;border-color:#636464}.list-group-item-dark{color:#141619;background-color:#d3d3d4}.list-group-item-dark.list-group-item-action:focus,.list-group-item-dark.list-group-item-action:hover{color:#141619;background-color:#bebebf}.list-group-item-dark.list-group-item-action.active{color:#fff;background-color:#141619;border-color:#141619}.btn-close{box-sizing:content-box;width:1em;height:1em;padding:.25em .25em;color:#000;background:transparent url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='%23000'%3e%3cpath d='M.293.293a1 1 0 011.414 0L8 6.586 14.293.293a1 1 0 111.414 1.414L9.414 8l6.293 6.293a1 1 0 01-1.414 1.414L8 9.414l-6.293 6.293a1 1 0 01-1.414-1.414L6.586 8 .293 1.707a1 1 0 010-1.414z'/%3e%3c/svg%3e") center/1em auto no-repeat;border:0;border-radius:.25rem;opacity:.5}.btn-close:hover{color:#000;text-decoration:none;opacity:.75}.btn-close:focus{outline:0;box-shadow:0 0 0 .25rem rgba(13,110,253,.25);opacity:1}.btn-close.disabled,.btn-close:disabled{pointer-events:none;-webkit-user-select:none;-moz-user-select:none;user-select:none;opacity:.25}.btn-close-white{filter:invert(1) grayscale(100%) brightness(200%)}.toast{width:350px;max-width:100%;font-size:.875rem;pointer-events:auto;background-color:rgba(255,255,255,.85);background-clip:padding-box;border:1px solid rgba(0,0,0,.1);box-shadow:0 .5rem 1rem rgba(0,0,0,.15);border-radius:.25rem}.toast.showing{opacity:0}.toast:not(.show){display:none}.toast-container{width:-webkit-max-content;width:-moz-max-content;width:max-content;max-width:100%;pointer-events:none}.toast-container>:not(:last-child){margin-bottom:.75rem}.toast-header{display:flex;align-items:center;padding:.5rem .75rem;color:#6c757d;background-color:rgba(255,255,255,.85);background-clip:padding-box;border-bottom:1px solid rgba(0,0,0,.05);border-top-left-radius:calc(.25rem - 1px);border-top-right-radius:calc(.25rem - 1px)}.toast-header .btn-close{margin-right:-.375rem;margin-left:.75rem}.toast-body{padding:.75rem;word-wrap:break-word}.modal{position:fixed;top:0;left:0;z-index:1055;display:none;width:100%;height:100%;overflow-x:hidden;overflow-y:auto;outline:0}.modal-dialog{position:relative;width:auto;margin:.5rem;pointer-events:none}.modal.fade .modal-dialog{transition:transform .3s ease-out;transform:translate(0,-50px)}@media (prefers-reduced-motion:reduce){.modal.fade .modal-dialog{transition:none}}.modal.show .modal-dialog{transform:none}.modal.modal-static .modal-dialog{transform:scale(1.02)}.modal-dialog-scrollable{height:calc(100% - 1rem)}.modal-dialog-scrollable .modal-content{max-height:100%;overflow:hidden}.modal-dialog-scrollable .modal-body{overflow-y:auto}.modal-dialog-centered{display:flex;align-items:center;min-height:calc(100% - 1rem)}.modal-content{position:relative;display:flex;flex-direction:column;width:100%;pointer-events:auto;background-color:#fff;background-clip:padding-box;border:1px solid rgba(0,0,0,.2);border-radius:.3rem;outline:0}.modal-backdrop{position:fixed;top:0;left:0;z-index:1050;width:100vw;height:100vh;background-color:#000}.modal-backdrop.fade{opacity:0}.modal-backdrop.show{opacity:.5}.modal-header{display:flex;flex-shrink:0;align-items:center;justify-content:space-between;padding:1rem 1rem;border-bottom:1px solid #dee2e6;border-top-left-radius:calc(.3rem - 1px);border-top-right-radius:calc(.3rem - 1px)}.modal-header .btn-close{padding:.5rem .5rem;margin:-.5rem -.5rem -.5rem auto}.modal-title{margin-bottom:0;line-height:1.5}.modal-body{position:relative;flex:1 1 auto;padding:1rem}.modal-footer{display:flex;flex-wrap:wrap;flex-shrink:0;align-items:center;justify-content:flex-end;padding:.75rem;border-top:1px solid #dee2e6;border-bottom-right-radius:calc(.3rem - 1px);border-bottom-left-radius:calc(.3rem - 1px)}.modal-footer>*{margin:.25rem}@media (min-width:576px){.modal-dialog{max-width:500px;margin:1.75rem auto}.modal-dialog-scrollable{height:calc(100% - 3.5rem)}.modal-dialog-centered{min-height:calc(100% - 3.5rem)}.modal-sm{max-width:300px}}@media (min-width:992px){.modal-lg,.modal-xl{max-width:800px}}@media (min-width:1200px){.modal-xl{max-width:1140px}}.modal-fullscreen{width:100vw;max-width:none;height:100%;margin:0}.modal-fullscreen .modal-content{height:100%;border:0;border-radius:0}.modal-fullscreen .modal-header{border-radius:0}.modal-fullscreen .modal-body{overflow-y:auto}.modal-fullscreen .modal-footer{border-radius:0}@media (max-width:575.98px){.modal-fullscreen-sm-down{width:100vw;max-width:none;height:100%;margin:0}.modal-fullscreen-sm-down .modal-content{height:100%;border:0;border-radius:0}.modal-fullscreen-sm-down .modal-header{border-radius:0}.modal-fullscreen-sm-down .modal-body{overflow-y:auto}.modal-fullscreen-sm-down .modal-footer{border-radius:0}}@media (max-width:767.98px){.modal-fullscreen-md-down{width:100vw;max-width:none;height:100%;margin:0}.modal-fullscreen-md-down .modal-content{height:100%;border:0;border-radius:0}.modal-fullscreen-md-down .modal-header{border-radius:0}.modal-fullscreen-md-down .modal-body{overflow-y:auto}.modal-fullscreen-md-down .modal-footer{border-radius:0}}@media (max-width:991.98px){.modal-fullscreen-lg-down{width:100vw;max-width:none;height:100%;margin:0}.modal-fullscreen-lg-down .modal-content{height:100%;border:0;border-radius:0}.modal-fullscreen-lg-down .modal-header{border-radius:0}.modal-fullscreen-lg-down .modal-body{overflow-y:auto}.modal-fullscreen-lg-down .modal-footer{border-radius:0}}@media (max-width:1199.98px){.modal-fullscreen-xl-down{width:100vw;max-width:none;height:100%;margin:0}.modal-fullscreen-xl-down .modal-content{height:100%;border:0;border-radius:0}.modal-fullscreen-xl-down .modal-header{border-radius:0}.modal-fullscreen-xl-down .modal-body{overflow-y:auto}.modal-fullscreen-xl-down .modal-footer{border-radius:0}}@media (max-width:1399.98px){.modal-fullscreen-xxl-down{width:100vw;max-width:none;height:100%;margin:0}.modal-fullscreen-xxl-down .modal-content{height:100%;border:0;border-radius:0}.modal-fullscreen-xxl-down .modal-header{border-radius:0}.modal-fullscreen-xxl-down .modal-body{overflow-y:auto}.modal-fullscreen-xxl-down .modal-footer{border-radius:0}}.tooltip{position:absolute;z-index:1080;display:block;margin:0;font-family:var(--bs-font-sans-serif);font-style:normal;font-weight:400;line-height:1.5;text-align:left;text-align:start;text-decoration:none;text-shadow:none;text-transform:none;letter-spacing:normal;word-break:normal;word-spacing:normal;white-space:normal;line-break:auto;font-size:.875rem;word-wrap:break-word;opacity:0}.tooltip.show{opacity:.9}.tooltip .tooltip-arrow{position:absolute;display:block;width:.8rem;height:.4rem}.tooltip .tooltip-arrow::before{position:absolute;content:"";border-color:transparent;border-style:solid}.bs-tooltip-auto[data-popper-placement^=top],.bs-tooltip-top{padding:.4rem 0}.bs-tooltip-auto[data-popper-placement^=top] .tooltip-arrow,.bs-tooltip-top .tooltip-arrow{bottom:0}.bs-tooltip-auto[data-popper-placement^=top] .tooltip-arrow::before,.bs-tooltip-top .tooltip-arrow::before{top:-1px;border-width:.4rem .4rem 0;border-top-color:#000}.bs-tooltip-auto[data-popper-placement^=right],.bs-tooltip-end{padding:0 .4rem}.bs-tooltip-auto[data-popper-placement^=right] .tooltip-arrow,.bs-tooltip-end .tooltip-arrow{left:0;width:.4rem;height:.8rem}.bs-tooltip-auto[data-popper-placement^=right] .tooltip-arrow::before,.bs-tooltip-end .tooltip-arrow::before{right:-1px;border-width:.4rem .4rem .4rem 0;border-right-color:#000}.bs-tooltip-auto[data-popper-placement^=bottom],.bs-tooltip-bottom{padding:.4rem 0}.bs-tooltip-auto[data-popper-placement^=bottom] .tooltip-arrow,.bs-tooltip-bottom .tooltip-arrow{top:0}.bs-tooltip-auto[data-popper-placement^=bottom] .tooltip-arrow::before,.bs-tooltip-bottom .tooltip-arrow::before{bottom:-1px;border-width:0 .4rem .4rem;border-bottom-color:#000}.bs-tooltip-auto[data-popper-placement^=left],.bs-tooltip-start{padding:0 .4rem}.bs-tooltip-auto[data-popper-placement^=left] .tooltip-arrow,.bs-tooltip-start .tooltip-arrow{right:0;width:.4rem;height:.8rem}.bs-tooltip-auto[data-popper-placement^=left] .tooltip-arrow::before,.bs-tooltip-start .tooltip-arrow::before{left:-1px;border-width:.4rem 0 .4rem .4rem;border-left-color:#000}.tooltip-inner{max-width:200px;padding:.25rem .5rem;color:#fff;text-align:center;background-color:#000;border-radius:.25rem}.popover{position:absolute;top:0;left:0;z-index:1070;display:block;max-width:276px;font-family:var(--bs-font-sans-serif);font-style:normal;font-weight:400;line-height:1.5;text-align:left;text-align:start;text-decoration:none;text-shadow:none;text-transform:none;letter-spacing:normal;word-break:normal;word-spacing:normal;white-space:normal;line-break:auto;font-size:.875rem;word-wrap:break-word;background-color:#fff;background-clip:padding-box;border:1px solid rgba(0,0,0,.2);border-radius:.3rem}.popover .popover-arrow{position:absolute;display:block;width:1rem;height:.5rem}.popover .popover-arrow::after,.popover .popover-arrow::before{position:absolute;display:block;content:"";border-color:transparent;border-style:solid}.bs-popover-auto[data-popper-placement^=top]>.popover-arrow,.bs-popover-top>.popover-arrow{bottom:calc(-.5rem - 1px)}.bs-popover-auto[data-popper-placement^=top]>.popover-arrow::before,.bs-popover-top>.popover-arrow::before{bottom:0;border-width:.5rem .5rem 0;border-top-color:rgba(0,0,0,.25)}.bs-popover-auto[data-popper-placement^=top]>.popover-arrow::after,.bs-popover-top>.popover-arrow::after{bottom:1px;border-width:.5rem .5rem 0;border-top-color:#fff}.bs-popover-auto[data-popper-placement^=right]>.popover-arrow,.bs-popover-end>.popover-arrow{left:calc(-.5rem - 1px);width:.5rem;height:1rem}.bs-popover-auto[data-popper-placement^=right]>.popover-arrow::before,.bs-popover-end>.popover-arrow::before{left:0;border-width:.5rem .5rem .5rem 0;border-right-color:rgba(0,0,0,.25)}.bs-popover-auto[data-popper-placement^=right]>.popover-arrow::after,.bs-popover-end>.popover-arrow::after{left:1px;border-width:.5rem .5rem .5rem 0;border-right-color:#fff}.bs-popover-auto[data-popper-placement^=bottom]>.popover-arrow,.bs-popover-bottom>.popover-arrow{top:calc(-.5rem - 1px)}.bs-popover-auto[data-popper-placement^=bottom]>.popover-arrow::before,.bs-popover-bottom>.popover-arrow::before{top:0;border-width:0 .5rem .5rem .5rem;border-bottom-color:rgba(0,0,0,.25)}.bs-popover-auto[data-popper-placement^=bottom]>.popover-arrow::after,.bs-popover-bottom>.popover-arrow::after{top:1px;border-width:0 .5rem .5rem .5rem;border-bottom-color:#fff}.bs-popover-auto[data-popper-placement^=bottom] .popover-header::before,.bs-popover-bottom .popover-header::before{position:absolute;top:0;left:50%;display:block;width:1rem;margin-left:-.5rem;content:"";border-bottom:1px solid #f0f0f0}.bs-popover-auto[data-popper-placement^=left]>.popover-arrow,.bs-popover-start>.popover-arrow{right:calc(-.5rem - 1px);width:.5rem;height:1rem}.bs-popover-auto[data-popper-placement^=left]>.popover-arrow::before,.bs-popover-start>.popover-arrow::before{right:0;border-width:.5rem 0 .5rem .5rem;border-left-color:rgba(0,0,0,.25)}.bs-popover-auto[data-popper-placement^=left]>.popover-arrow::after,.bs-popover-start>.popover-arrow::after{right:1px;border-width:.5rem 0 .5rem .5rem;border-left-color:#fff}.popover-header{padding:.5rem 1rem;margin-bottom:0;font-size:1rem;background-color:#f0f0f0;border-bottom:1px solid rgba(0,0,0,.2);border-top-left-radius:calc(.3rem - 1px);border-top-right-radius:calc(.3rem - 1px)}.popover-header:empty{display:none}.popover-body{padding:1rem 1rem;color:#212529}.carousel{position:relative}.carousel.pointer-event{touch-action:pan-y}.carousel-inner{position:relative;width:100%;overflow:hidden}.carousel-inner::after{display:block;clear:both;content:""}.carousel-item{position:relative;display:none;float:left;width:100%;margin-right:-100%;-webkit-backface-visibility:hidden;backface-visibility:hidden;transition:transform .6s ease-in-out}@media (prefers-reduced-motion:reduce){.carousel-item{transition:none}}.carousel-item-next,.carousel-item-prev,.carousel-item.active{display:block}.active.carousel-item-end,.carousel-item-next:not(.carousel-item-start){transform:translateX(100%)}.active.carousel-item-start,.carousel-item-prev:not(.carousel-item-end){transform:translateX(-100%)}.carousel-fade .carousel-item{opacity:0;transition-property:opacity;transform:none}.carousel-fade .carousel-item-next.carousel-item-start,.carousel-fade .carousel-item-prev.carousel-item-end,.carousel-fade .carousel-item.active{z-index:1;opacity:1}.carousel-fade .active.carousel-item-end,.carousel-fade .active.carousel-item-start{z-index:0;opacity:0;transition:opacity 0s .6s}@media (prefers-reduced-motion:reduce){.carousel-fade .active.carousel-item-end,.carousel-fade .active.carousel-item-start{transition:none}}.carousel-control-next,.carousel-control-prev{position:absolute;top:0;bottom:0;z-index:1;display:flex;align-items:center;justify-content:center;width:15%;padding:0;color:#fff;text-align:center;background:0 0;border:0;opacity:.5;transition:opacity .15s ease}@media (prefers-reduced-motion:reduce){.carousel-control-next,.carousel-control-prev{transition:none}}.carousel-control-next:focus,.carousel-control-next:hover,.carousel-control-prev:focus,.carousel-control-prev:hover{color:#fff;text-decoration:none;outline:0;opacity:.9}.carousel-control-prev{left:0}.carousel-control-next{right:0}.carousel-control-next-icon,.carousel-control-prev-icon{display:inline-block;width:2rem;height:2rem;background-repeat:no-repeat;background-position:50%;background-size:100% 100%}.carousel-control-prev-icon{background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='%23fff'%3e%3cpath d='M11.354 1.646a.5.5 0 0 1 0 .708L5.707 8l5.647 5.646a.5.5 0 0 1-.708.708l-6-6a.5.5 0 0 1 0-.708l6-6a.5.5 0 0 1 .708 0z'/%3e%3c/svg%3e")}.carousel-control-next-icon{background-image:url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='%23fff'%3e%3cpath d='M4.646 1.646a.5.5 0 0 1 .708 0l6 6a.5.5 0 0 1 0 .708l-6 6a.5.5 0 0 1-.708-.708L10.293 8 4.646 2.354a.5.5 0 0 1 0-.708z'/%3e%3c/svg%3e")}.carousel-indicators{position:absolute;right:0;bottom:0;left:0;z-index:2;display:flex;justify-content:center;padding:0;margin-right:15%;margin-bottom:1rem;margin-left:15%;list-style:none}.carousel-indicators [data-bs-target]{box-sizing:content-box;flex:0 1 auto;width:30px;height:3px;padding:0;margin-right:3px;margin-left:3px;text-indent:-999px;cursor:pointer;background-color:#fff;background-clip:padding-box;border:0;border-top:10px solid transparent;border-bottom:10px solid transparent;opacity:.5;transition:opacity .6s ease}@media (prefers-reduced-motion:reduce){.carousel-indicators [data-bs-target]{transition:none}}.carousel-indicators .active{opacity:1}.carousel-caption{position:absolute;right:15%;bottom:1.25rem;left:15%;padding-top:1.25rem;padding-bottom:1.25rem;color:#fff;text-align:center}.carousel-dark .carousel-control-next-icon,.carousel-dark .carousel-control-prev-icon{filter:invert(1) grayscale(100)}.carousel-dark .carousel-indicators [data-bs-target]{background-color:#000}.carousel-dark .carousel-caption{color:#000}@-webkit-keyframes spinner-border{to{transform:rotate(360deg)}}@keyframes spinner-border{to{transform:rotate(360deg)}}.spinner-border{display:inline-block;width:2rem;height:2rem;vertical-align:-.125em;border:.25em solid currentColor;border-right-color:transparent;border-radius:50%;-webkit-animation:.75s linear infinite spinner-border;animation:.75s linear infinite spinner-border}.spinner-border-sm{width:1rem;height:1rem;border-width:.2em}@-webkit-keyframes spinner-grow{0%{transform:scale(0)}50%{opacity:1;transform:none}}@keyframes spinner-grow{0%{transform:scale(0)}50%{opacity:1;transform:none}}.spinner-grow{display:inline-block;width:2rem;height:2rem;vertical-align:-.125em;background-color:currentColor;border-radius:50%;opacity:0;-webkit-animation:.75s linear infinite spinner-grow;animation:.75s linear infinite spinner-grow}.spinner-grow-sm{width:1rem;height:1rem}@media (prefers-reduced-motion:reduce){.spinner-border,.spinner-grow{-webkit-animation-duration:1.5s;animation-duration:1.5s}}.offcanvas{position:fixed;bottom:0;z-index:1045;display:flex;flex-direction:column;max-width:100%;visibility:hidden;background-color:#fff;background-clip:padding-box;outline:0;transition:transform .3s ease-in-out}@media (prefers-reduced-motion:reduce){.offcanvas{transition:none}}.offcanvas-backdrop{position:fixed;top:0;left:0;z-index:1040;width:100vw;height:100vh;background-color:#000}.offcanvas-backdrop.fade{opacity:0}.offcanvas-backdrop.show{opacity:.5}.offcanvas-header{display:flex;align-items:center;justify-content:space-between;padding:1rem 1rem}.offcanvas-header .btn-close{padding:.5rem .5rem;margin-top:-.5rem;margin-right:-.5rem;margin-bottom:-.5rem}.offcanvas-title{margin-bottom:0;line-height:1.5}.offcanvas-body{flex-grow:1;padding:1rem 1rem;overflow-y:auto}.offcanvas-start{top:0;left:0;width:400px;border-right:1px solid rgba(0,0,0,.2);transform:translateX(-100%)}.offcanvas-end{top:0;right:0;width:400px;border-left:1px solid rgba(0,0,0,.2);transform:translateX(100%)}.offcanvas-top{top:0;right:0;left:0;height:30vh;max-height:100%;border-bottom:1px solid rgba(0,0,0,.2);transform:translateY(-100%)}.offcanvas-bottom{right:0;left:0;height:30vh;max-height:100%;border-top:1px solid rgba(0,0,0,.2);transform:translateY(100%)}.offcanvas.show{transform:none}.placeholder{display:inline-block;min-height:1em;vertical-align:middle;cursor:wait;background-color:currentColor;opacity:.5}.placeholder.btn::before{display:inline-block;content:""}.placeholder-xs{min-height:.6em}.placeholder-sm{min-height:.8em}.placeholder-lg{min-height:1.2em}.placeholder-glow .placeholder{-webkit-animation:placeholder-glow 2s ease-in-out infinite;animation:placeholder-glow 2s ease-in-out infinite}@-webkit-keyframes placeholder-glow{50%{opacity:.2}}@keyframes placeholder-glow{50%{opacity:.2}}.placeholder-wave{-webkit-mask-image:linear-gradient(130deg,#000 55%,rgba(0,0,0,0.8) 75%,#000 95%);mask-image:linear-gradient(130deg,#000 55%,rgba(0,0,0,0.8) 75%,#000 95%);-webkit-mask-size:200% 100%;mask-size:200% 100%;-webkit-animation:placeholder-wave 2s linear infinite;animation:placeholder-wave 2s linear infinite}@-webkit-keyframes placeholder-wave{100%{-webkit-mask-position:-200% 0%;mask-position:-200% 0%}}@keyframes placeholder-wave{100%{-webkit-mask-position:-200% 0%;mask-position:-200% 0%}}.clearfix::after{display:block;clear:both;content:""}.link-primary{color:#0d6efd}.link-primary:focus,.link-primary:hover{color:#0a58ca}.link-secondary{color:#6c757d}.link-secondary:focus,.link-secondary:hover{color:#565e64}.link-success{color:#198754}.link-success:focus,.link-success:hover{color:#146c43}.link-info{color:#0dcaf0}.link-info:focus,.link-info:hover{color:#3dd5f3}.link-warning{color:#ffc107}.link-warning:focus,.link-warning:hover{color:#ffcd39}.link-danger{color:#dc3545}.link-danger:focus,.link-danger:hover{color:#b02a37}.link-light{color:#f8f9fa}.link-light:focus,.link-light:hover{color:#f9fafb}.link-dark{color:#212529}.link-dark:focus,.link-dark:hover{color:#1a1e21}.ratio{position:relative;width:100%}.ratio::before{display:block;padding-top:var(--bs-aspect-ratio);content:""}.ratio>*{position:absolute;top:0;left:0;width:100%;height:100%}.ratio-1x1{--bs-aspect-ratio:100%}.ratio-4x3{--bs-aspect-ratio:75%}.ratio-16x9{--bs-aspect-ratio:56.25%}.ratio-21x9{--bs-aspect-ratio:42.8571428571%}.fixed-top{position:fixed;top:0;right:0;left:0;z-index:1030}.fixed-bottom{position:fixed;right:0;bottom:0;left:0;z-index:1030}.sticky-top{position:-webkit-sticky;position:sticky;top:0;z-index:1020}@media (min-width:576px){.sticky-sm-top{position:-webkit-sticky;position:sticky;top:0;z-index:1020}}@media (min-width:768px){.sticky-md-top{position:-webkit-sticky;position:sticky;top:0;z-index:1020}}@media (min-width:992px){.sticky-lg-top{position:-webkit-sticky;position:sticky;top:0;z-index:1020}}@media (min-width:1200px){.sticky-xl-top{position:-webkit-sticky;position:sticky;top:0;z-index:1020}}@media (min-width:1400px){.sticky-xxl-top{position:-webkit-sticky;position:sticky;top:0;z-index:1020}}.hstack{display:flex;flex-direction:row;align-items:center;align-self:stretch}.vstack{display:flex;flex:1 1 auto;flex-direction:column;align-self:stretch}.visually-hidden,.visually-hidden-focusable:not(:focus):not(:focus-within){position:absolute!important;width:1px!important;height:1px!important;padding:0!important;margin:-1px!important;overflow:hidden!important;clip:rect(0,0,0,0)!important;white-space:nowrap!important;border:0!important}.stretched-link::after{position:absolute;top:0;right:0;bottom:0;left:0;z-index:1;content:""}.text-truncate{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.vr{display:inline-block;align-self:stretch;width:1px;min-height:1em;background-color:currentColor;opacity:.25}.align-baseline{vertical-align:baseline!important}.align-top{vertical-align:top!important}.align-middle{vertical-align:middle!important}.align-bottom{vertical-align:bottom!important}.align-text-bottom{vertical-align:text-bottom!important}.align-text-top{vertical-align:text-top!important}.float-start{float:left!important}.float-end{float:right!important}.float-none{float:none!important}.opacity-0{opacity:0!important}.opacity-25{opacity:.25!important}.opacity-50{opacity:.5!important}.opacity-75{opacity:.75!important}.opacity-100{opacity:1!important}.overflow-auto{overflow:auto!important}.overflow-hidden{overflow:hidden!important}.overflow-visible{overflow:visible!important}.overflow-scroll{overflow:scroll!important}.d-inline{display:inline!important}.d-inline-block{display:inline-block!important}.d-block{display:block!important}.d-grid{display:grid!important}.d-table{display:table!important}.d-table-row{display:table-row!important}.d-table-cell{display:table-cell!important}.d-flex{display:flex!important}.d-inline-flex{display:inline-flex!important}.d-none{display:none!important}.shadow{box-shadow:0 .5rem 1rem rgba(0,0,0,.15)!important}.shadow-sm{box-shadow:0 .125rem .25rem rgba(0,0,0,.075)!important}.shadow-lg{box-shadow:0 1rem 3rem rgba(0,0,0,.175)!important}.shadow-none{box-shadow:none!important}.position-static{position:static!important}.position-relative{position:relative!important}.position-absolute{position:absolute!important}.position-fixed{position:fixed!important}.position-sticky{position:-webkit-sticky!important;position:sticky!important}.top-0{top:0!important}.top-50{top:50%!important}.top-100{top:100%!important}.bottom-0{bottom:0!important}.bottom-50{bottom:50%!important}.bottom-100{bottom:100%!important}.start-0{left:0!important}.start-50{left:50%!important}.start-100{left:100%!important}.end-0{right:0!important}.end-50{right:50%!important}.end-100{right:100%!important}.translate-middle{transform:translate(-50%,-50%)!important}.translate-middle-x{transform:translateX(-50%)!important}.translate-middle-y{transform:translateY(-50%)!important}.border{border:1px solid #dee2e6!important}.border-0{border:0!important}.border-top{border-top:1px solid #dee2e6!important}.border-top-0{border-top:0!important}.border-end{border-right:1px solid #dee2e6!important}.border-end-0{border-right:0!important}.border-bottom{border-bottom:1px solid #dee2e6!important}.border-bottom-0{border-bottom:0!important}.border-start{border-left:1px solid #dee2e6!important}.border-start-0{border-left:0!important}.border-primary{border-color:#0d6efd!important}.border-secondary{border-color:#6c757d!important}.border-success{border-color:#198754!important}.border-info{border-color:#0dcaf0!important}.border-warning{border-color:#ffc107!important}.border-danger{border-color:#dc3545!important}.border-light{border-color:#f8f9fa!important}.border-dark{border-color:#212529!important}.border-white{border-color:#fff!important}.border-1{border-width:1px!important}.border-2{border-width:2px!important}.border-3{border-width:3px!important}.border-4{border-width:4px!important}.border-5{border-width:5px!important}.w-25{width:25%!important}.w-50{width:50%!important}.w-75{width:75%!important}.w-100{width:100%!important}.w-auto{width:auto!important}.mw-100{max-width:100%!important}.vw-100{width:100vw!important}.min-vw-100{min-width:100vw!important}.h-25{height:25%!important}.h-50{height:50%!important}.h-75{height:75%!important}.h-100{height:100%!important}.h-auto{height:auto!important}.mh-100{max-height:100%!important}.vh-100{height:100vh!important}.min-vh-100{min-height:100vh!important}.flex-fill{flex:1 1 auto!important}.flex-row{flex-direction:row!important}.flex-column{flex-direction:column!important}.flex-row-reverse{flex-direction:row-reverse!important}.flex-column-reverse{flex-direction:column-reverse!important}.flex-grow-0{flex-grow:0!important}.flex-grow-1{flex-grow:1!important}.flex-shrink-0{flex-shrink:0!important}.flex-shrink-1{flex-shrink:1!important}.flex-wrap{flex-wrap:wrap!important}.flex-nowrap{flex-wrap:nowrap!important}.flex-wrap-reverse{flex-wrap:wrap-reverse!important}.gap-0{gap:0!important}.gap-1{gap:.25rem!important}.gap-2{gap:.5rem!important}.gap-3{gap:1rem!important}.gap-4{gap:1.5rem!important}.gap-5{gap:3rem!important}.justify-content-start{justify-content:flex-start!important}.justify-content-end{justify-content:flex-end!important}.justify-content-center{justify-content:center!important}.justify-content-between{justify-content:space-between!important}.justify-content-around{justify-content:space-around!important}.justify-content-evenly{justify-content:space-evenly!important}.align-items-start{align-items:flex-start!important}.align-items-end{align-items:flex-end!important}.align-items-center{align-items:center!important}.align-items-baseline{align-items:baseline!important}.align-items-stretch{align-items:stretch!important}.align-content-start{align-content:flex-start!important}.align-content-end{align-content:flex-end!important}.align-content-center{align-content:center!important}.align-content-between{align-content:space-between!important}.align-content-around{align-content:space-around!important}.align-content-stretch{align-content:stretch!important}.align-self-auto{align-self:auto!important}.align-self-start{align-self:flex-start!important}.align-self-end{align-self:flex-end!important}.align-self-center{align-self:center!important}.align-self-baseline{align-self:baseline!important}.align-self-stretch{align-self:stretch!important}.order-first{order:-1!important}.order-0{order:0!important}.order-1{order:1!important}.order-2{order:2!important}.order-3{order:3!important}.order-4{order:4!important}.order-5{order:5!important}.order-last{order:6!important}.m-0{margin:0!important}.m-1{margin:.25rem!important}.m-2{margin:.5rem!important}.m-3{margin:1rem!important}.m-4{margin:1.5rem!important}.m-5{margin:3rem!important}.m-auto{margin:auto!important}.mx-0{margin-right:0!important;margin-left:0!important}.mx-1{margin-right:.25rem!important;margin-left:.25rem!important}.mx-2{margin-right:.5rem!important;margin-left:.5rem!important}.mx-3{margin-right:1rem!important;margin-left:1rem!important}.mx-4{margin-right:1.5rem!important;margin-left:1.5rem!important}.mx-5{margin-right:3rem!important;margin-left:3rem!important}.mx-auto{margin-right:auto!important;margin-left:auto!important}.my-0{margin-top:0!important;margin-bottom:0!important}.my-1{margin-top:.25rem!important;margin-bottom:.25rem!important}.my-2{margin-top:.5rem!important;margin-bottom:.5rem!important}.my-3{margin-top:1rem!important;margin-bottom:1rem!important}.my-4{margin-top:1.5rem!important;margin-bottom:1.5rem!important}.my-5{margin-top:3rem!important;margin-bottom:3rem!important}.my-auto{margin-top:auto!important;margin-bottom:auto!important}.mt-0{margin-top:0!important}.mt-1{margin-top:.25rem!important}.mt-2{margin-top:.5rem!important}.mt-3{margin-top:1rem!important}.mt-4{margin-top:1.5rem!important}.mt-5{margin-top:3rem!important}.mt-auto{margin-top:auto!important}.me-0{margin-right:0!important}.me-1{margin-right:.25rem!important}.me-2{margin-right:.5rem!important}.me-3{margin-right:1rem!important}.me-4{margin-right:1.5rem!important}.me-5{margin-right:3rem!important}.me-auto{margin-right:auto!important}.mb-0{margin-bottom:0!important}.mb-1{margin-bottom:.25rem!important}.mb-2{margin-bottom:.5rem!important}.mb-3{margin-bottom:1rem!important}.mb-4{margin-bottom:1.5rem!important}.mb-5{margin-bottom:3rem!important}.mb-auto{margin-bottom:auto!important}.ms-0{margin-left:0!important}.ms-1{margin-left:.25rem!important}.ms-2{margin-left:.5rem!important}.ms-3{margin-left:1rem!important}.ms-4{margin-left:1.5rem!important}.ms-5{margin-left:3rem!important}.ms-auto{margin-left:auto!important}.p-0{padding:0!important}.p-1{padding:.25rem!important}.p-2{padding:.5rem!important}.p-3{padding:1rem!important}.p-4{padding:1.5rem!important}.p-5{padding:3rem!important}.px-0{padding-right:0!important;padding-left:0!important}.px-1{padding-right:.25rem!important;padding-left:.25rem!important}.px-2{padding-right:.5rem!important;padding-left:.5rem!important}.px-3{padding-right:1rem!important;padding-left:1rem!important}.px-4{padding-right:1.5rem!important;padding-left:1.5rem!important}.px-5{padding-right:3rem!important;padding-left:3rem!important}.py-0{padding-top:0!important;padding-bottom:0!important}.py-1{padding-top:.25rem!important;padding-bottom:.25rem!important}.py-2{padding-top:.5rem!important;padding-bottom:.5rem!important}.py-3{padding-top:1rem!important;padding-bottom:1rem!important}.py-4{padding-top:1.5rem!important;padding-bottom:1.5rem!important}.py-5{padding-top:3rem!important;padding-bottom:3rem!important}.pt-0{padding-top:0!important}.pt-1{padding-top:.25rem!important}.pt-2{padding-top:.5rem!important}.pt-3{padding-top:1rem!important}.pt-4{padding-top:1.5rem!important}.pt-5{padding-top:3rem!important}.pe-0{padding-right:0!important}.pe-1{padding-right:.25rem!important}.pe-2{padding-right:.5rem!important}.pe-3{padding-right:1rem!important}.pe-4{padding-right:1.5rem!important}.pe-5{padding-right:3rem!important}.pb-0{padding-bottom:0!important}.pb-1{padding-bottom:.25rem!important}.pb-2{padding-bottom:.5rem!important}.pb-3{padding-bottom:1rem!important}.pb-4{padding-bottom:1.5rem!important}.pb-5{padding-bottom:3rem!important}.ps-0{padding-left:0!important}.ps-1{padding-left:.25rem!important}.ps-2{padding-left:.5rem!important}.ps-3{padding-left:1rem!important}.ps-4{padding-left:1.5rem!important}.ps-5{padding-left:3rem!important}.font-monospace{font-family:var(--bs-font-monospace)!important}.fs-1{font-size:calc(1.375rem + 1.5vw)!important}.fs-2{font-size:calc(1.325rem + .9vw)!important}.fs-3{font-size:calc(1.3rem + .6vw)!important}.fs-4{font-size:calc(1.275rem + .3vw)!important}.fs-5{font-size:1.25rem!important}.fs-6{font-size:1rem!important}.fst-italic{font-style:italic!important}.fst-normal{font-style:normal!important}.fw-light{font-weight:300!important}.fw-lighter{font-weight:lighter!important}.fw-normal{font-weight:400!important}.fw-bold{font-weight:700!important}.fw-bolder{font-weight:bolder!important}.lh-1{line-height:1!important}.lh-sm{line-height:1.25!important}.lh-base{line-height:1.5!important}.lh-lg{line-height:2!important}.text-start{text-align:left!important}.text-end{text-align:right!important}.text-center{text-align:center!important}.text-decoration-none{text-decoration:none!important}.text-decoration-underline{text-decoration:underline!important}.text-decoration-line-through{text-decoration:line-through!important}.text-lowercase{text-transform:lowercase!important}.text-uppercase{text-transform:uppercase!important}.text-capitalize{text-transform:capitalize!important}.text-wrap{white-space:normal!important}.text-nowrap{white-space:nowrap!important}.text-break{word-wrap:break-word!important;word-break:break-word!important}.text-primary{--bs-text-opacity:1;color:rgba(var(--bs-primary-rgb),var(--bs-text-opacity))!important}.text-secondary{--bs-text-opacity:1;color:rgba(var(--bs-secondary-rgb),var(--bs-text-opacity))!important}.text-success{--bs-text-opacity:1;color:rgba(var(--bs-success-rgb),var(--bs-text-opacity))!important}.text-info{--bs-text-opacity:1;color:rgba(var(--bs-info-rgb),var(--bs-text-opacity))!important}.text-warning{--bs-text-opacity:1;color:rgba(var(--bs-warning-rgb),var(--bs-text-opacity))!important}.text-danger{--bs-text-opacity:1;color:rgba(var(--bs-danger-rgb),var(--bs-text-opacity))!important}.text-light{--bs-text-opacity:1;color:rgba(var(--bs-light-rgb),var(--bs-text-opacity))!important}.text-dark{--bs-text-opacity:1;color:rgba(var(--bs-dark-rgb),var(--bs-text-opacity))!important}.text-black{--bs-text-opacity:1;color:rgba(var(--bs-black-rgb),var(--bs-text-opacity))!important}.text-white{--bs-text-opacity:1;color:rgba(var(--bs-white-rgb),var(--bs-text-opacity))!important}.text-body{--bs-text-opacity:1;color:rgba(var(--bs-body-color-rgb),var(--bs-text-opacity))!important}.text-muted{--bs-text-opacity:1;color:#6c757d!important}.text-black-50{--bs-text-opacity:1;color:rgba(0,0,0,.5)!important}.text-white-50{--bs-text-opacity:1;color:rgba(255,255,255,.5)!important}.text-reset{--bs-text-opacity:1;color:inherit!important}.text-opacity-25{--bs-text-opacity:0.25}.text-opacity-50{--bs-text-opacity:0.5}.text-opacity-75{--bs-text-opacity:0.75}.text-opacity-100{--bs-text-opacity:1}.bg-primary{--bs-bg-opacity:1;background-color:rgba(var(--bs-primary-rgb),var(--bs-bg-opacity))!important}.bg-secondary{--bs-bg-opacity:1;background-color:rgba(var(--bs-secondary-rgb),var(--bs-bg-opacity))!important}.bg-success{--bs-bg-opacity:1;background-color:rgba(var(--bs-success-rgb),var(--bs-bg-opacity))!important}.bg-info{--bs-bg-opacity:1;background-color:rgba(var(--bs-info-rgb),var(--bs-bg-opacity))!important}.bg-warning{--bs-bg-opacity:1;background-color:rgba(var(--bs-warning-rgb),var(--bs-bg-opacity))!important}.bg-danger{--bs-bg-opacity:1;background-color:rgba(var(--bs-danger-rgb),var(--bs-bg-opacity))!important}.bg-light{--bs-bg-opacity:1;background-color:rgba(var(--bs-light-rgb),var(--bs-bg-opacity))!important}.bg-dark{--bs-bg-opacity:1;background-color:rgba(var(--bs-dark-rgb),var(--bs-bg-opacity))!important}.bg-black{--bs-bg-opacity:1;background-color:rgba(var(--bs-black-rgb),var(--bs-bg-opacity))!important}.bg-white{--bs-bg-opacity:1;background-color:rgba(var(--bs-white-rgb),var(--bs-bg-opacity))!important}.bg-body{--bs-bg-opacity:1;background-color:rgba(var(--bs-body-bg-rgb),var(--bs-bg-opacity))!important}.bg-transparent{--bs-bg-opacity:1;background-color:transparent!important}.bg-opacity-10{--bs-bg-opacity:0.1}.bg-opacity-25{--bs-bg-opacity:0.25}.bg-opacity-50{--bs-bg-opacity:0.5}.bg-opacity-75{--bs-bg-opacity:0.75}.bg-opacity-100{--bs-bg-opacity:1}.bg-gradient{background-image:var(--bs-gradient)!important}.user-select-all{-webkit-user-select:all!important;-moz-user-select:all!important;user-select:all!important}.user-select-auto{-webkit-user-select:auto!important;-moz-user-select:auto!important;user-select:auto!important}.user-select-none{-webkit-user-select:none!important;-moz-user-select:none!important;user-select:none!important}.pe-none{pointer-events:none!important}.pe-auto{pointer-events:auto!important}.rounded{border-radius:.25rem!important}.rounded-0{border-radius:0!important}.rounded-1{border-radius:.2rem!important}.rounded-2{border-radius:.25rem!important}.rounded-3{border-radius:.3rem!important}.rounded-circle{border-radius:50%!important}.rounded-pill{border-radius:50rem!important}.rounded-top{border-top-left-radius:.25rem!important;border-top-right-radius:.25rem!important}.rounded-end{border-top-right-radius:.25rem!important;border-bottom-right-radius:.25rem!important}.rounded-bottom{border-bottom-right-radius:.25rem!important;border-bottom-left-radius:.25rem!important}.rounded-start{border-bottom-left-radius:.25rem!important;border-top-left-radius:.25rem!important}.visible{visibility:visible!important}.invisible{visibility:hidden!important}@media (min-width:576px){.float-sm-start{float:left!important}.float-sm-end{float:right!important}.float-sm-none{float:none!important}.d-sm-inline{display:inline!important}.d-sm-inline-block{display:inline-block!important}.d-sm-block{display:block!important}.d-sm-grid{display:grid!important}.d-sm-table{display:table!important}.d-sm-table-row{display:table-row!important}.d-sm-table-cell{display:table-cell!important}.d-sm-flex{display:flex!important}.d-sm-inline-flex{display:inline-flex!important}.d-sm-none{display:none!important}.flex-sm-fill{flex:1 1 auto!important}.flex-sm-row{flex-direction:row!important}.flex-sm-column{flex-direction:column!important}.flex-sm-row-reverse{flex-direction:row-reverse!important}.flex-sm-column-reverse{flex-direction:column-reverse!important}.flex-sm-grow-0{flex-grow:0!important}.flex-sm-grow-1{flex-grow:1!important}.flex-sm-shrink-0{flex-shrink:0!important}.flex-sm-shrink-1{flex-shrink:1!important}.flex-sm-wrap{flex-wrap:wrap!important}.flex-sm-nowrap{flex-wrap:nowrap!important}.flex-sm-wrap-reverse{flex-wrap:wrap-reverse!important}.gap-sm-0{gap:0!important}.gap-sm-1{gap:.25rem!important}.gap-sm-2{gap:.5rem!important}.gap-sm-3{gap:1rem!important}.gap-sm-4{gap:1.5rem!important}.gap-sm-5{gap:3rem!important}.justify-content-sm-start{justify-content:flex-start!important}.justify-content-sm-end{justify-content:flex-end!important}.justify-content-sm-center{justify-content:center!important}.justify-content-sm-between{justify-content:space-between!important}.justify-content-sm-around{justify-content:space-around!important}.justify-content-sm-evenly{justify-content:space-evenly!important}.align-items-sm-start{align-items:flex-start!important}.align-items-sm-end{align-items:flex-end!important}.align-items-sm-center{align-items:center!important}.align-items-sm-baseline{align-items:baseline!important}.align-items-sm-stretch{align-items:stretch!important}.align-content-sm-start{align-content:flex-start!important}.align-content-sm-end{align-content:flex-end!important}.align-content-sm-center{align-content:center!important}.align-content-sm-between{align-content:space-between!important}.align-content-sm-around{align-content:space-around!important}.align-content-sm-stretch{align-content:stretch!important}.align-self-sm-auto{align-self:auto!important}.align-self-sm-start{align-self:flex-start!important}.align-self-sm-end{align-self:flex-end!important}.align-self-sm-center{align-self:center!important}.align-self-sm-baseline{align-self:baseline!important}.align-self-sm-stretch{align-self:stretch!important}.order-sm-first{order:-1!important}.order-sm-0{order:0!important}.order-sm-1{order:1!important}.order-sm-2{order:2!important}.order-sm-3{order:3!important}.order-sm-4{order:4!important}.order-sm-5{order:5!important}.order-sm-last{order:6!important}.m-sm-0{margin:0!important}.m-sm-1{margin:.25rem!important}.m-sm-2{margin:.5rem!important}.m-sm-3{margin:1rem!important}.m-sm-4{margin:1.5rem!important}.m-sm-5{margin:3rem!important}.m-sm-auto{margin:auto!important}.mx-sm-0{margin-right:0!important;margin-left:0!important}.mx-sm-1{margin-right:.25rem!important;margin-left:.25rem!important}.mx-sm-2{margin-right:.5rem!important;margin-left:.5rem!important}.mx-sm-3{margin-right:1rem!important;margin-left:1rem!important}.mx-sm-4{margin-right:1.5rem!important;margin-left:1.5rem!important}.mx-sm-5{margin-right:3rem!important;margin-left:3rem!important}.mx-sm-auto{margin-right:auto!important;margin-left:auto!important}.my-sm-0{margin-top:0!important;margin-bottom:0!important}.my-sm-1{margin-top:.25rem!important;margin-bottom:.25rem!important}.my-sm-2{margin-top:.5rem!important;margin-bottom:.5rem!important}.my-sm-3{margin-top:1rem!important;margin-bottom:1rem!important}.my-sm-4{margin-top:1.5rem!important;margin-bottom:1.5rem!important}.my-sm-5{margin-top:3rem!important;margin-bottom:3rem!important}.my-sm-auto{margin-top:auto!important;margin-bottom:auto!important}.mt-sm-0{margin-top:0!important}.mt-sm-1{margin-top:.25rem!important}.mt-sm-2{margin-top:.5rem!important}.mt-sm-3{margin-top:1rem!important}.mt-sm-4{margin-top:1.5rem!important}.mt-sm-5{margin-top:3rem!important}.mt-sm-auto{margin-top:auto!important}.me-sm-0{margin-right:0!important}.me-sm-1{margin-right:.25rem!important}.me-sm-2{margin-right:.5rem!important}.me-sm-3{margin-right:1rem!important}.me-sm-4{margin-right:1.5rem!important}.me-sm-5{margin-right:3rem!important}.me-sm-auto{margin-right:auto!important}.mb-sm-0{margin-bottom:0!important}.mb-sm-1{margin-bottom:.25rem!important}.mb-sm-2{margin-bottom:.5rem!important}.mb-sm-3{margin-bottom:1rem!important}.mb-sm-4{margin-bottom:1.5rem!important}.mb-sm-5{margin-bottom:3rem!important}.mb-sm-auto{margin-bottom:auto!important}.ms-sm-0{margin-left:0!important}.ms-sm-1{margin-left:.25rem!important}.ms-sm-2{margin-left:.5rem!important}.ms-sm-3{margin-left:1rem!important}.ms-sm-4{margin-left:1.5rem!important}.ms-sm-5{margin-left:3rem!important}.ms-sm-auto{margin-left:auto!important}.p-sm-0{padding:0!important}.p-sm-1{padding:.25rem!important}.p-sm-2{padding:.5rem!important}.p-sm-3{padding:1rem!important}.p-sm-4{padding:1.5rem!important}.p-sm-5{padding:3rem!important}.px-sm-0{padding-right:0!important;padding-left:0!important}.px-sm-1{padding-right:.25rem!important;padding-left:.25rem!important}.px-sm-2{padding-right:.5rem!important;padding-left:.5rem!important}.px-sm-3{padding-right:1rem!important;padding-left:1rem!important}.px-sm-4{padding-right:1.5rem!important;padding-left:1.5rem!important}.px-sm-5{padding-right:3rem!important;padding-left:3rem!important}.py-sm-0{padding-top:0!important;padding-bottom:0!important}.py-sm-1{padding-top:.25rem!important;padding-bottom:.25rem!important}.py-sm-2{padding-top:.5rem!important;padding-bottom:.5rem!important}.py-sm-3{padding-top:1rem!important;padding-bottom:1rem!important}.py-sm-4{padding-top:1.5rem!important;padding-bottom:1.5rem!important}.py-sm-5{padding-top:3rem!important;padding-bottom:3rem!important}.pt-sm-0{padding-top:0!important}.pt-sm-1{padding-top:.25rem!important}.pt-sm-2{padding-top:.5rem!important}.pt-sm-3{padding-top:1rem!important}.pt-sm-4{padding-top:1.5rem!important}.pt-sm-5{padding-top:3rem!important}.pe-sm-0{padding-right:0!important}.pe-sm-1{padding-right:.25rem!important}.pe-sm-2{padding-right:.5rem!important}.pe-sm-3{padding-right:1rem!important}.pe-sm-4{padding-right:1.5rem!important}.pe-sm-5{padding-right:3rem!important}.pb-sm-0{padding-bottom:0!important}.pb-sm-1{padding-bottom:.25rem!important}.pb-sm-2{padding-bottom:.5rem!important}.pb-sm-3{padding-bottom:1rem!important}.pb-sm-4{padding-bottom:1.5rem!important}.pb-sm-5{padding-bottom:3rem!important}.ps-sm-0{padding-left:0!important}.ps-sm-1{padding-left:.25rem!important}.ps-sm-2{padding-left:.5rem!important}.ps-sm-3{padding-left:1rem!important}.ps-sm-4{padding-left:1.5rem!important}.ps-sm-5{padding-left:3rem!important}.text-sm-start{text-align:left!important}.text-sm-end{text-align:right!important}.text-sm-center{text-align:center!important}}@media (min-width:768px){.float-md-start{float:left!important}.float-md-end{float:right!important}.float-md-none{float:none!important}.d-md-inline{display:inline!important}.d-md-inline-block{display:inline-block!important}.d-md-block{display:block!important}.d-md-grid{display:grid!important}.d-md-table{display:table!important}.d-md-table-row{display:table-row!important}.d-md-table-cell{display:table-cell!important}.d-md-flex{display:flex!important}.d-md-inline-flex{display:inline-flex!important}.d-md-none{display:none!important}.flex-md-fill{flex:1 1 auto!important}.flex-md-row{flex-direction:row!important}.flex-md-column{flex-direction:column!important}.flex-md-row-reverse{flex-direction:row-reverse!important}.flex-md-column-reverse{flex-direction:column-reverse!important}.flex-md-grow-0{flex-grow:0!important}.flex-md-grow-1{flex-grow:1!important}.flex-md-shrink-0{flex-shrink:0!important}.flex-md-shrink-1{flex-shrink:1!important}.flex-md-wrap{flex-wrap:wrap!important}.flex-md-nowrap{flex-wrap:nowrap!important}.flex-md-wrap-reverse{flex-wrap:wrap-reverse!important}.gap-md-0{gap:0!important}.gap-md-1{gap:.25rem!important}.gap-md-2{gap:.5rem!important}.gap-md-3{gap:1rem!important}.gap-md-4{gap:1.5rem!important}.gap-md-5{gap:3rem!important}.justify-content-md-start{justify-content:flex-start!important}.justify-content-md-end{justify-content:flex-end!important}.justify-content-md-center{justify-content:center!important}.justify-content-md-between{justify-content:space-between!important}.justify-content-md-around{justify-content:space-around!important}.justify-content-md-evenly{justify-content:space-evenly!important}.align-items-md-start{align-items:flex-start!important}.align-items-md-end{align-items:flex-end!important}.align-items-md-center{align-items:center!important}.align-items-md-baseline{align-items:baseline!important}.align-items-md-stretch{align-items:stretch!important}.align-content-md-start{align-content:flex-start!important}.align-content-md-end{align-content:flex-end!important}.align-content-md-center{align-content:center!important}.align-content-md-between{align-content:space-between!important}.align-content-md-around{align-content:space-around!important}.align-content-md-stretch{align-content:stretch!important}.align-self-md-auto{align-self:auto!important}.align-self-md-start{align-self:flex-start!important}.align-self-md-end{align-self:flex-end!important}.align-self-md-center{align-self:center!important}.align-self-md-baseline{align-self:baseline!important}.align-self-md-stretch{align-self:stretch!important}.order-md-first{order:-1!important}.order-md-0{order:0!important}.order-md-1{order:1!important}.order-md-2{order:2!important}.order-md-3{order:3!important}.order-md-4{order:4!important}.order-md-5{order:5!important}.order-md-last{order:6!important}.m-md-0{margin:0!important}.m-md-1{margin:.25rem!important}.m-md-2{margin:.5rem!important}.m-md-3{margin:1rem!important}.m-md-4{margin:1.5rem!important}.m-md-5{margin:3rem!important}.m-md-auto{margin:auto!important}.mx-md-0{margin-right:0!important;margin-left:0!important}.mx-md-1{margin-right:.25rem!important;margin-left:.25rem!important}.mx-md-2{margin-right:.5rem!important;margin-left:.5rem!important}.mx-md-3{margin-right:1rem!important;margin-left:1rem!important}.mx-md-4{margin-right:1.5rem!important;margin-left:1.5rem!important}.mx-md-5{margin-right:3rem!important;margin-left:3rem!important}.mx-md-auto{margin-right:auto!important;margin-left:auto!important}.my-md-0{margin-top:0!important;margin-bottom:0!important}.my-md-1{margin-top:.25rem!important;margin-bottom:.25rem!important}.my-md-2{margin-top:.5rem!important;margin-bottom:.5rem!important}.my-md-3{margin-top:1rem!important;margin-bottom:1rem!important}.my-md-4{margin-top:1.5rem!important;margin-bottom:1.5rem!important}.my-md-5{margin-top:3rem!important;margin-bottom:3rem!important}.my-md-auto{margin-top:auto!important;margin-bottom:auto!important}.mt-md-0{margin-top:0!important}.mt-md-1{margin-top:.25rem!important}.mt-md-2{margin-top:.5rem!important}.mt-md-3{margin-top:1rem!important}.mt-md-4{margin-top:1.5rem!important}.mt-md-5{margin-top:3rem!important}.mt-md-auto{margin-top:auto!important}.me-md-0{margin-right:0!important}.me-md-1{margin-right:.25rem!important}.me-md-2{margin-right:.5rem!important}.me-md-3{margin-right:1rem!important}.me-md-4{margin-right:1.5rem!important}.me-md-5{margin-right:3rem!important}.me-md-auto{margin-right:auto!important}.mb-md-0{margin-bottom:0!important}.mb-md-1{margin-bottom:.25rem!important}.mb-md-2{margin-bottom:.5rem!important}.mb-md-3{margin-bottom:1rem!important}.mb-md-4{margin-bottom:1.5rem!important}.mb-md-5{margin-bottom:3rem!important}.mb-md-auto{margin-bottom:auto!important}.ms-md-0{margin-left:0!important}.ms-md-1{margin-left:.25rem!important}.ms-md-2{margin-left:.5rem!important}.ms-md-3{margin-left:1rem!important}.ms-md-4{margin-left:1.5rem!important}.ms-md-5{margin-left:3rem!important}.ms-md-auto{margin-left:auto!important}.p-md-0{padding:0!important}.p-md-1{padding:.25rem!important}.p-md-2{padding:.5rem!important}.p-md-3{padding:1rem!important}.p-md-4{padding:1.5rem!important}.p-md-5{padding:3rem!important}.px-md-0{padding-right:0!important;padding-left:0!important}.px-md-1{padding-right:.25rem!important;padding-left:.25rem!important}.px-md-2{padding-right:.5rem!important;padding-left:.5rem!important}.px-md-3{padding-right:1rem!important;padding-left:1rem!important}.px-md-4{padding-right:1.5rem!important;padding-left:1.5rem!important}.px-md-5{padding-right:3rem!important;padding-left:3rem!important}.py-md-0{padding-top:0!important;padding-bottom:0!important}.py-md-1{padding-top:.25rem!important;padding-bottom:.25rem!important}.py-md-2{padding-top:.5rem!important;padding-bottom:.5rem!important}.py-md-3{padding-top:1rem!important;padding-bottom:1rem!important}.py-md-4{padding-top:1.5rem!important;padding-bottom:1.5rem!important}.py-md-5{padding-top:3rem!important;padding-bottom:3rem!important}.pt-md-0{padding-top:0!important}.pt-md-1{padding-top:.25rem!important}.pt-md-2{padding-top:.5rem!important}.pt-md-3{padding-top:1rem!important}.pt-md-4{padding-top:1.5rem!important}.pt-md-5{padding-top:3rem!important}.pe-md-0{padding-right:0!important}.pe-md-1{padding-right:.25rem!important}.pe-md-2{padding-right:.5rem!important}.pe-md-3{padding-right:1rem!important}.pe-md-4{padding-right:1.5rem!important}.pe-md-5{padding-right:3rem!important}.pb-md-0{padding-bottom:0!important}.pb-md-1{padding-bottom:.25rem!important}.pb-md-2{padding-bottom:.5rem!important}.pb-md-3{padding-bottom:1rem!important}.pb-md-4{padding-bottom:1.5rem!important}.pb-md-5{padding-bottom:3rem!important}.ps-md-0{padding-left:0!important}.ps-md-1{padding-left:.25rem!important}.ps-md-2{padding-left:.5rem!important}.ps-md-3{padding-left:1rem!important}.ps-md-4{padding-left:1.5rem!important}.ps-md-5{padding-left:3rem!important}.text-md-start{text-align:left!important}.text-md-end{text-align:right!important}.text-md-center{text-align:center!important}}@media (min-width:992px){.float-lg-start{float:left!important}.float-lg-end{float:right!important}.float-lg-none{float:none!important}.d-lg-inline{display:inline!important}.d-lg-inline-block{display:inline-block!important}.d-lg-block{display:block!important}.d-lg-grid{display:grid!important}.d-lg-table{display:table!important}.d-lg-table-row{display:table-row!important}.d-lg-table-cell{display:table-cell!important}.d-lg-flex{display:flex!important}.d-lg-inline-flex{display:inline-flex!important}.d-lg-none{display:none!important}.flex-lg-fill{flex:1 1 auto!important}.flex-lg-row{flex-direction:row!important}.flex-lg-column{flex-direction:column!important}.flex-lg-row-reverse{flex-direction:row-reverse!important}.flex-lg-column-reverse{flex-direction:column-reverse!important}.flex-lg-grow-0{flex-grow:0!important}.flex-lg-grow-1{flex-grow:1!important}.flex-lg-shrink-0{flex-shrink:0!important}.flex-lg-shrink-1{flex-shrink:1!important}.flex-lg-wrap{flex-wrap:wrap!important}.flex-lg-nowrap{flex-wrap:nowrap!important}.flex-lg-wrap-reverse{flex-wrap:wrap-reverse!important}.gap-lg-0{gap:0!important}.gap-lg-1{gap:.25rem!important}.gap-lg-2{gap:.5rem!important}.gap-lg-3{gap:1rem!important}.gap-lg-4{gap:1.5rem!important}.gap-lg-5{gap:3rem!important}.justify-content-lg-start{justify-content:flex-start!important}.justify-content-lg-end{justify-content:flex-end!important}.justify-content-lg-center{justify-content:center!important}.justify-content-lg-between{justify-content:space-between!important}.justify-content-lg-around{justify-content:space-around!important}.justify-content-lg-evenly{justify-content:space-evenly!important}.align-items-lg-start{align-items:flex-start!important}.align-items-lg-end{align-items:flex-end!important}.align-items-lg-center{align-items:center!important}.align-items-lg-baseline{align-items:baseline!important}.align-items-lg-stretch{align-items:stretch!important}.align-content-lg-start{align-content:flex-start!important}.align-content-lg-end{align-content:flex-end!important}.align-content-lg-center{align-content:center!important}.align-content-lg-between{align-content:space-between!important}.align-content-lg-around{align-content:space-around!important}.align-content-lg-stretch{align-content:stretch!important}.align-self-lg-auto{align-self:auto!important}.align-self-lg-start{align-self:flex-start!important}.align-self-lg-end{align-self:flex-end!important}.align-self-lg-center{align-self:center!important}.align-self-lg-baseline{align-self:baseline!important}.align-self-lg-stretch{align-self:stretch!important}.order-lg-first{order:-1!important}.order-lg-0{order:0!important}.order-lg-1{order:1!important}.order-lg-2{order:2!important}.order-lg-3{order:3!important}.order-lg-4{order:4!important}.order-lg-5{order:5!important}.order-lg-last{order:6!important}.m-lg-0{margin:0!important}.m-lg-1{margin:.25rem!important}.m-lg-2{margin:.5rem!important}.m-lg-3{margin:1rem!important}.m-lg-4{margin:1.5rem!important}.m-lg-5{margin:3rem!important}.m-lg-auto{margin:auto!important}.mx-lg-0{margin-right:0!important;margin-left:0!important}.mx-lg-1{margin-right:.25rem!important;margin-left:.25rem!important}.mx-lg-2{margin-right:.5rem!important;margin-left:.5rem!important}.mx-lg-3{margin-right:1rem!important;margin-left:1rem!important}.mx-lg-4{margin-right:1.5rem!important;margin-left:1.5rem!important}.mx-lg-5{margin-right:3rem!important;margin-left:3rem!important}.mx-lg-auto{margin-right:auto!important;margin-left:auto!important}.my-lg-0{margin-top:0!important;margin-bottom:0!important}.my-lg-1{margin-top:.25rem!important;margin-bottom:.25rem!important}.my-lg-2{margin-top:.5rem!important;margin-bottom:.5rem!important}.my-lg-3{margin-top:1rem!important;margin-bottom:1rem!important}.my-lg-4{margin-top:1.5rem!important;margin-bottom:1.5rem!important}.my-lg-5{margin-top:3rem!important;margin-bottom:3rem!important}.my-lg-auto{margin-top:auto!important;margin-bottom:auto!important}.mt-lg-0{margin-top:0!important}.mt-lg-1{margin-top:.25rem!important}.mt-lg-2{margin-top:.5rem!important}.mt-lg-3{margin-top:1rem!important}.mt-lg-4{margin-top:1.5rem!important}.mt-lg-5{margin-top:3rem!important}.mt-lg-auto{margin-top:auto!important}.me-lg-0{margin-right:0!important}.me-lg-1{margin-right:.25rem!important}.me-lg-2{margin-right:.5rem!important}.me-lg-3{margin-right:1rem!important}.me-lg-4{margin-right:1.5rem!important}.me-lg-5{margin-right:3rem!important}.me-lg-auto{margin-right:auto!important}.mb-lg-0{margin-bottom:0!important}.mb-lg-1{margin-bottom:.25rem!important}.mb-lg-2{margin-bottom:.5rem!important}.mb-lg-3{margin-bottom:1rem!important}.mb-lg-4{margin-bottom:1.5rem!important}.mb-lg-5{margin-bottom:3rem!important}.mb-lg-auto{margin-bottom:auto!important}.ms-lg-0{margin-left:0!important}.ms-lg-1{margin-left:.25rem!important}.ms-lg-2{margin-left:.5rem!important}.ms-lg-3{margin-left:1rem!important}.ms-lg-4{margin-left:1.5rem!important}.ms-lg-5{margin-left:3rem!important}.ms-lg-auto{margin-left:auto!important}.p-lg-0{padding:0!important}.p-lg-1{padding:.25rem!important}.p-lg-2{padding:.5rem!important}.p-lg-3{padding:1rem!important}.p-lg-4{padding:1.5rem!important}.p-lg-5{padding:3rem!important}.px-lg-0{padding-right:0!important;padding-left:0!important}.px-lg-1{padding-right:.25rem!important;padding-left:.25rem!important}.px-lg-2{padding-right:.5rem!important;padding-left:.5rem!important}.px-lg-3{padding-right:1rem!important;padding-left:1rem!important}.px-lg-4{padding-right:1.5rem!important;padding-left:1.5rem!important}.px-lg-5{padding-right:3rem!important;padding-left:3rem!important}.py-lg-0{padding-top:0!important;padding-bottom:0!important}.py-lg-1{padding-top:.25rem!important;padding-bottom:.25rem!important}.py-lg-2{padding-top:.5rem!important;padding-bottom:.5rem!important}.py-lg-3{padding-top:1rem!important;padding-bottom:1rem!important}.py-lg-4{padding-top:1.5rem!important;padding-bottom:1.5rem!important}.py-lg-5{padding-top:3rem!important;padding-bottom:3rem!important}.pt-lg-0{padding-top:0!important}.pt-lg-1{padding-top:.25rem!important}.pt-lg-2{padding-top:.5rem!important}.pt-lg-3{padding-top:1rem!important}.pt-lg-4{padding-top:1.5rem!important}.pt-lg-5{padding-top:3rem!important}.pe-lg-0{padding-right:0!important}.pe-lg-1{padding-right:.25rem!important}.pe-lg-2{padding-right:.5rem!important}.pe-lg-3{padding-right:1rem!important}.pe-lg-4{padding-right:1.5rem!important}.pe-lg-5{padding-right:3rem!important}.pb-lg-0{padding-bottom:0!important}.pb-lg-1{padding-bottom:.25rem!important}.pb-lg-2{padding-bottom:.5rem!important}.pb-lg-3{padding-bottom:1rem!important}.pb-lg-4{padding-bottom:1.5rem!important}.pb-lg-5{padding-bottom:3rem!important}.ps-lg-0{padding-left:0!important}.ps-lg-1{padding-left:.25rem!important}.ps-lg-2{padding-left:.5rem!important}.ps-lg-3{padding-left:1rem!important}.ps-lg-4{padding-left:1.5rem!important}.ps-lg-5{padding-left:3rem!important}.text-lg-start{text-align:left!important}.text-lg-end{text-align:right!important}.text-lg-center{text-align:center!important}}@media (min-width:1200px){.float-xl-start{float:left!important}.float-xl-end{float:right!important}.float-xl-none{float:none!important}.d-xl-inline{display:inline!important}.d-xl-inline-block{display:inline-block!important}.d-xl-block{display:block!important}.d-xl-grid{display:grid!important}.d-xl-table{display:table!important}.d-xl-table-row{display:table-row!important}.d-xl-table-cell{display:table-cell!important}.d-xl-flex{display:flex!important}.d-xl-inline-flex{display:inline-flex!important}.d-xl-none{display:none!important}.flex-xl-fill{flex:1 1 auto!important}.flex-xl-row{flex-direction:row!important}.flex-xl-column{flex-direction:column!important}.flex-xl-row-reverse{flex-direction:row-reverse!important}.flex-xl-column-reverse{flex-direction:column-reverse!important}.flex-xl-grow-0{flex-grow:0!important}.flex-xl-grow-1{flex-grow:1!important}.flex-xl-shrink-0{flex-shrink:0!important}.flex-xl-shrink-1{flex-shrink:1!important}.flex-xl-wrap{flex-wrap:wrap!important}.flex-xl-nowrap{flex-wrap:nowrap!important}.flex-xl-wrap-reverse{flex-wrap:wrap-reverse!important}.gap-xl-0{gap:0!important}.gap-xl-1{gap:.25rem!important}.gap-xl-2{gap:.5rem!important}.gap-xl-3{gap:1rem!important}.gap-xl-4{gap:1.5rem!important}.gap-xl-5{gap:3rem!important}.justify-content-xl-start{justify-content:flex-start!important}.justify-content-xl-end{justify-content:flex-end!important}.justify-content-xl-center{justify-content:center!important}.justify-content-xl-between{justify-content:space-between!important}.justify-content-xl-around{justify-content:space-around!important}.justify-content-xl-evenly{justify-content:space-evenly!important}.align-items-xl-start{align-items:flex-start!important}.align-items-xl-end{align-items:flex-end!important}.align-items-xl-center{align-items:center!important}.align-items-xl-baseline{align-items:baseline!important}.align-items-xl-stretch{align-items:stretch!important}.align-content-xl-start{align-content:flex-start!important}.align-content-xl-end{align-content:flex-end!important}.align-content-xl-center{align-content:center!important}.align-content-xl-between{align-content:space-between!important}.align-content-xl-around{align-content:space-around!important}.align-content-xl-stretch{align-content:stretch!important}.align-self-xl-auto{align-self:auto!important}.align-self-xl-start{align-self:flex-start!important}.align-self-xl-end{align-self:flex-end!important}.align-self-xl-center{align-self:center!important}.align-self-xl-baseline{align-self:baseline!important}.align-self-xl-stretch{align-self:stretch!important}.order-xl-first{order:-1!important}.order-xl-0{order:0!important}.order-xl-1{order:1!important}.order-xl-2{order:2!important}.order-xl-3{order:3!important}.order-xl-4{order:4!important}.order-xl-5{order:5!important}.order-xl-last{order:6!important}.m-xl-0{margin:0!important}.m-xl-1{margin:.25rem!important}.m-xl-2{margin:.5rem!important}.m-xl-3{margin:1rem!important}.m-xl-4{margin:1.5rem!important}.m-xl-5{margin:3rem!important}.m-xl-auto{margin:auto!important}.mx-xl-0{margin-right:0!important;margin-left:0!important}.mx-xl-1{margin-right:.25rem!important;margin-left:.25rem!important}.mx-xl-2{margin-right:.5rem!important;margin-left:.5rem!important}.mx-xl-3{margin-right:1rem!important;margin-left:1rem!important}.mx-xl-4{margin-right:1.5rem!important;margin-left:1.5rem!important}.mx-xl-5{margin-right:3rem!important;margin-left:3rem!important}.mx-xl-auto{margin-right:auto!important;margin-left:auto!important}.my-xl-0{margin-top:0!important;margin-bottom:0!important}.my-xl-1{margin-top:.25rem!important;margin-bottom:.25rem!important}.my-xl-2{margin-top:.5rem!important;margin-bottom:.5rem!important}.my-xl-3{margin-top:1rem!important;margin-bottom:1rem!important}.my-xl-4{margin-top:1.5rem!important;margin-bottom:1.5rem!important}.my-xl-5{margin-top:3rem!important;margin-bottom:3rem!important}.my-xl-auto{margin-top:auto!important;margin-bottom:auto!important}.mt-xl-0{margin-top:0!important}.mt-xl-1{margin-top:.25rem!important}.mt-xl-2{margin-top:.5rem!important}.mt-xl-3{margin-top:1rem!important}.mt-xl-4{margin-top:1.5rem!important}.mt-xl-5{margin-top:3rem!important}.mt-xl-auto{margin-top:auto!important}.me-xl-0{margin-right:0!important}.me-xl-1{margin-right:.25rem!important}.me-xl-2{margin-right:.5rem!important}.me-xl-3{margin-right:1rem!important}.me-xl-4{margin-right:1.5rem!important}.me-xl-5{margin-right:3rem!important}.me-xl-auto{margin-right:auto!important}.mb-xl-0{margin-bottom:0!important}.mb-xl-1{margin-bottom:.25rem!important}.mb-xl-2{margin-bottom:.5rem!important}.mb-xl-3{margin-bottom:1rem!important}.mb-xl-4{margin-bottom:1.5rem!important}.mb-xl-5{margin-bottom:3rem!important}.mb-xl-auto{margin-bottom:auto!important}.ms-xl-0{margin-left:0!important}.ms-xl-1{margin-left:.25rem!important}.ms-xl-2{margin-left:.5rem!important}.ms-xl-3{margin-left:1rem!important}.ms-xl-4{margin-left:1.5rem!important}.ms-xl-5{margin-left:3rem!important}.ms-xl-auto{margin-left:auto!important}.p-xl-0{padding:0!important}.p-xl-1{padding:.25rem!important}.p-xl-2{padding:.5rem!important}.p-xl-3{padding:1rem!important}.p-xl-4{padding:1.5rem!important}.p-xl-5{padding:3rem!important}.px-xl-0{padding-right:0!important;padding-left:0!important}.px-xl-1{padding-right:.25rem!important;padding-left:.25rem!important}.px-xl-2{padding-right:.5rem!important;padding-left:.5rem!important}.px-xl-3{padding-right:1rem!important;padding-left:1rem!important}.px-xl-4{padding-right:1.5rem!important;padding-left:1.5rem!important}.px-xl-5{padding-right:3rem!important;padding-left:3rem!important}.py-xl-0{padding-top:0!important;padding-bottom:0!important}.py-xl-1{padding-top:.25rem!important;padding-bottom:.25rem!important}.py-xl-2{padding-top:.5rem!important;padding-bottom:.5rem!important}.py-xl-3{padding-top:1rem!important;padding-bottom:1rem!important}.py-xl-4{padding-top:1.5rem!important;padding-bottom:1.5rem!important}.py-xl-5{padding-top:3rem!important;padding-bottom:3rem!important}.pt-xl-0{padding-top:0!important}.pt-xl-1{padding-top:.25rem!important}.pt-xl-2{padding-top:.5rem!important}.pt-xl-3{padding-top:1rem!important}.pt-xl-4{padding-top:1.5rem!important}.pt-xl-5{padding-top:3rem!important}.pe-xl-0{padding-right:0!important}.pe-xl-1{padding-right:.25rem!important}.pe-xl-2{padding-right:.5rem!important}.pe-xl-3{padding-right:1rem!important}.pe-xl-4{padding-right:1.5rem!important}.pe-xl-5{padding-right:3rem!important}.pb-xl-0{padding-bottom:0!important}.pb-xl-1{padding-bottom:.25rem!important}.pb-xl-2{padding-bottom:.5rem!important}.pb-xl-3{padding-bottom:1rem!important}.pb-xl-4{padding-bottom:1.5rem!important}.pb-xl-5{padding-bottom:3rem!important}.ps-xl-0{padding-left:0!important}.ps-xl-1{padding-left:.25rem!important}.ps-xl-2{padding-left:.5rem!important}.ps-xl-3{padding-left:1rem!important}.ps-xl-4{padding-left:1.5rem!important}.ps-xl-5{padding-left:3rem!important}.text-xl-start{text-align:left!important}.text-xl-end{text-align:right!important}.text-xl-center{text-align:center!important}}@media (min-width:1400px){.float-xxl-start{float:left!important}.float-xxl-end{float:right!important}.float-xxl-none{float:none!important}.d-xxl-inline{display:inline!important}.d-xxl-inline-block{display:inline-block!important}.d-xxl-block{display:block!important}.d-xxl-grid{display:grid!important}.d-xxl-table{display:table!important}.d-xxl-table-row{display:table-row!important}.d-xxl-table-cell{display:table-cell!important}.d-xxl-flex{display:flex!important}.d-xxl-inline-flex{display:inline-flex!important}.d-xxl-none{display:none!important}.flex-xxl-fill{flex:1 1 auto!important}.flex-xxl-row{flex-direction:row!important}.flex-xxl-column{flex-direction:column!important}.flex-xxl-row-reverse{flex-direction:row-reverse!important}.flex-xxl-column-reverse{flex-direction:column-reverse!important}.flex-xxl-grow-0{flex-grow:0!important}.flex-xxl-grow-1{flex-grow:1!important}.flex-xxl-shrink-0{flex-shrink:0!important}.flex-xxl-shrink-1{flex-shrink:1!important}.flex-xxl-wrap{flex-wrap:wrap!important}.flex-xxl-nowrap{flex-wrap:nowrap!important}.flex-xxl-wrap-reverse{flex-wrap:wrap-reverse!important}.gap-xxl-0{gap:0!important}.gap-xxl-1{gap:.25rem!important}.gap-xxl-2{gap:.5rem!important}.gap-xxl-3{gap:1rem!important}.gap-xxl-4{gap:1.5rem!important}.gap-xxl-5{gap:3rem!important}.justify-content-xxl-start{justify-content:flex-start!important}.justify-content-xxl-end{justify-content:flex-end!important}.justify-content-xxl-center{justify-content:center!important}.justify-content-xxl-between{justify-content:space-between!important}.justify-content-xxl-around{justify-content:space-around!important}.justify-content-xxl-evenly{justify-content:space-evenly!important}.align-items-xxl-start{align-items:flex-start!important}.align-items-xxl-end{align-items:flex-end!important}.align-items-xxl-center{align-items:center!important}.align-items-xxl-baseline{align-items:baseline!important}.align-items-xxl-stretch{align-items:stretch!important}.align-content-xxl-start{align-content:flex-start!important}.align-content-xxl-end{align-content:flex-end!important}.align-content-xxl-center{align-content:center!important}.align-content-xxl-between{align-content:space-between!important}.align-content-xxl-around{align-content:space-around!important}.align-content-xxl-stretch{align-content:stretch!important}.align-self-xxl-auto{align-self:auto!important}.align-self-xxl-start{align-self:flex-start!important}.align-self-xxl-end{align-self:flex-end!important}.align-self-xxl-center{align-self:center!important}.align-self-xxl-baseline{align-self:baseline!important}.align-self-xxl-stretch{align-self:stretch!important}.order-xxl-first{order:-1!important}.order-xxl-0{order:0!important}.order-xxl-1{order:1!important}.order-xxl-2{order:2!important}.order-xxl-3{order:3!important}.order-xxl-4{order:4!important}.order-xxl-5{order:5!important}.order-xxl-last{order:6!important}.m-xxl-0{margin:0!important}.m-xxl-1{margin:.25rem!important}.m-xxl-2{margin:.5rem!important}.m-xxl-3{margin:1rem!important}.m-xxl-4{margin:1.5rem!important}.m-xxl-5{margin:3rem!important}.m-xxl-auto{margin:auto!important}.mx-xxl-0{margin-right:0!important;margin-left:0!important}.mx-xxl-1{margin-right:.25rem!important;margin-left:.25rem!important}.mx-xxl-2{margin-right:.5rem!important;margin-left:.5rem!important}.mx-xxl-3{margin-right:1rem!important;margin-left:1rem!important}.mx-xxl-4{margin-right:1.5rem!important;margin-left:1.5rem!important}.mx-xxl-5{margin-right:3rem!important;margin-left:3rem!important}.mx-xxl-auto{margin-right:auto!important;margin-left:auto!important}.my-xxl-0{margin-top:0!important;margin-bottom:0!important}.my-xxl-1{margin-top:.25rem!important;margin-bottom:.25rem!important}.my-xxl-2{margin-top:.5rem!important;margin-bottom:.5rem!important}.my-xxl-3{margin-top:1rem!important;margin-bottom:1rem!important}.my-xxl-4{margin-top:1.5rem!important;margin-bottom:1.5rem!important}.my-xxl-5{margin-top:3rem!important;margin-bottom:3rem!important}.my-xxl-auto{margin-top:auto!important;margin-bottom:auto!important}.mt-xxl-0{margin-top:0!important}.mt-xxl-1{margin-top:.25rem!important}.mt-xxl-2{margin-top:.5rem!important}.mt-xxl-3{margin-top:1rem!important}.mt-xxl-4{margin-top:1.5rem!important}.mt-xxl-5{margin-top:3rem!important}.mt-xxl-auto{margin-top:auto!important}.me-xxl-0{margin-right:0!important}.me-xxl-1{margin-right:.25rem!important}.me-xxl-2{margin-right:.5rem!important}.me-xxl-3{margin-right:1rem!important}.me-xxl-4{margin-right:1.5rem!important}.me-xxl-5{margin-right:3rem!important}.me-xxl-auto{margin-right:auto!important}.mb-xxl-0{margin-bottom:0!important}.mb-xxl-1{margin-bottom:.25rem!important}.mb-xxl-2{margin-bottom:.5rem!important}.mb-xxl-3{margin-bottom:1rem!important}.mb-xxl-4{margin-bottom:1.5rem!important}.mb-xxl-5{margin-bottom:3rem!important}.mb-xxl-auto{margin-bottom:auto!important}.ms-xxl-0{margin-left:0!important}.ms-xxl-1{margin-left:.25rem!important}.ms-xxl-2{margin-left:.5rem!important}.ms-xxl-3{margin-left:1rem!important}.ms-xxl-4{margin-left:1.5rem!important}.ms-xxl-5{margin-left:3rem!important}.ms-xxl-auto{margin-left:auto!important}.p-xxl-0{padding:0!important}.p-xxl-1{padding:.25rem!important}.p-xxl-2{padding:.5rem!important}.p-xxl-3{padding:1rem!important}.p-xxl-4{padding:1.5rem!important}.p-xxl-5{padding:3rem!important}.px-xxl-0{padding-right:0!important;padding-left:0!important}.px-xxl-1{padding-right:.25rem!important;padding-left:.25rem!important}.px-xxl-2{padding-right:.5rem!important;padding-left:.5rem!important}.px-xxl-3{padding-right:1rem!important;padding-left:1rem!important}.px-xxl-4{padding-right:1.5rem!important;padding-left:1.5rem!important}.px-xxl-5{padding-right:3rem!important;padding-left:3rem!important}.py-xxl-0{padding-top:0!important;padding-bottom:0!important}.py-xxl-1{padding-top:.25rem!important;padding-bottom:.25rem!important}.py-xxl-2{padding-top:.5rem!important;padding-bottom:.5rem!important}.py-xxl-3{padding-top:1rem!important;padding-bottom:1rem!important}.py-xxl-4{padding-top:1.5rem!important;padding-bottom:1.5rem!important}.py-xxl-5{padding-top:3rem!important;padding-bottom:3rem!important}.pt-xxl-0{padding-top:0!important}.pt-xxl-1{padding-top:.25rem!important}.pt-xxl-2{padding-top:.5rem!important}.pt-xxl-3{padding-top:1rem!important}.pt-xxl-4{padding-top:1.5rem!important}.pt-xxl-5{padding-top:3rem!important}.pe-xxl-0{padding-right:0!important}.pe-xxl-1{padding-right:.25rem!important}.pe-xxl-2{padding-right:.5rem!important}.pe-xxl-3{padding-right:1rem!important}.pe-xxl-4{padding-right:1.5rem!important}.pe-xxl-5{padding-right:3rem!important}.pb-xxl-0{padding-bottom:0!important}.pb-xxl-1{padding-bottom:.25rem!important}.pb-xxl-2{padding-bottom:.5rem!important}.pb-xxl-3{padding-bottom:1rem!important}.pb-xxl-4{padding-bottom:1.5rem!important}.pb-xxl-5{padding-bottom:3rem!important}.ps-xxl-0{padding-left:0!important}.ps-xxl-1{padding-left:.25rem!important}.ps-xxl-2{padding-left:.5rem!important}.ps-xxl-3{padding-left:1rem!important}.ps-xxl-4{padding-left:1.5rem!important}.ps-xxl-5{padding-left:3rem!important}.text-xxl-start{text-align:left!important}.text-xxl-end{text-align:right!important}.text-xxl-center{text-align:center!important}}@media (min-width:1200px){.fs-1{font-size:2.5rem!important}.fs-2{font-size:2rem!important}.fs-3{font-size:1.75rem!important}.fs-4{font-size:1.5rem!important}}@media print{.d-print-inline{display:inline!important}.d-print-inline-block{display:inline-block!important}.d-print-block{display:block!important}.d-print-grid{display:grid!important}.d-print-table{display:table!important}.d-print-table-row{display:table-row!important}.d-print-table-cell{display:table-cell!important}.d-print-flex{display:flex!important}.d-print-inline-flex{display:inline-flex!important}.d-print-none{display:none!important}}
/*# sourceMappingURL=bootstrap.min.css.map */
</style><title>_ReportTitle_</title></head>
<body><div class="container theme-showcase" role="main"><div class="p-5 mb-4 bg-light rounded-3 d-print-block"><h2 class="display-5 fw-bold d-print-block">_ReportTitle_</h2><p>_ReportDescription_</p></div>_ReportBody_</div></body></html>
"@
}
function New-BootstrapAlert {
    <#
        .SYNOPSIS
            Creates a new HTML div that uses the Bootstrap alert class
        .DESCRIPTION
            Creates a new HTML div that uses the Bootstrap alert class
        .OUTPUTS
            A string wih the HTML code for the div
        .EXAMPLE
            New-BootstrapAlert -Text 'blah'

            This example returns the following string:
            '<div class="alert alert-info"><strong>Info!</strong> blah</div>'
    #>
    [CmdletBinding()]
    param(
        #The HTML element to apply the Bootstrap column to
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [string[]]$Text,

        [Parameter(
            Position = 1
        )]
        [string]$Class = 'Info'
    )
    begin{}
    process{
        ForEach ($String in $Text) {
            #"<div class=`"alert alert-$($Class.ToLower())`"><strong>$Class!</strong> $String</div>"
            "<div class=`"alert alert-$($Class.ToLower())`">$String</div>"
        }
    }
    end{}

}
function New-BootstrapColumn {
    <#
        .SYNOPSIS
            Wraps HTML elements in a Bootstrap column of the specified width
        .DESCRIPTION
            Creates a Bootstrap container which contains a row which contains a column of the specified width
        .OUTPUTS
            A string wih the code for the Bootstrap container
        .EXAMPLE
            New-BootstrapColumn -Html '<h1>Heading</h1>'

            This example returns the following string:
            '<div class="container"><div class="row justify-content-md-center"><div class="col col-lg-12"><h1>Heading</h1></div></div></div>'
    #>
    [OutputType([System.String])]
    [CmdletBinding()]
    param(
        #The HTML element to apply the Bootstrap column to
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [System.String[]]$Html,

        [Parameter(
            Position = 1
        )]
        [Int]$Width = 12
    )
    begin {
        $NewHtml = "<div class=`"container`"><div class=`"row justify-content-md-center`">"
    }
    process {
        ForEach ($OldHtml in $Html) {
            $NewHtml = "$NewHtml<div class=`"col col-lg-$Width`">$OldHtml</div>"
        }
    }
    end {
        $NewHtml = "$NewHtml</div></div>"
        return $NewHtml
    }
}
function New-BootstrapDiv {
    <#
        .SYNOPSIS
            Creates a new HTML div that uses the Bootstrap alert class
        .DESCRIPTION
            Creates a new HTML div that uses the Bootstrap alert class
        .OUTPUTS
            A string wih the HTML code for the div
        .EXAMPLE
            New-BootstrapAlert -Text 'blah'

            This example returns the following string:
            '<div class="alert alert-info"><strong>Info!</strong> blah</div>'
    #>
    [CmdletBinding()]
    param(
        #The HTML element to apply the Bootstrap column to
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [string[]]$Text,

        [Parameter(
            Position = 1
        )]
        [string]$Class = 'h-100 p-1 bg-light border rounded-3'
    )
    begin{}
    process{
        ForEach ($String in $Text) {
            #"<div class=`"alert alert-$($Class.ToLower())`"><strong>$Class!</strong> $String</div>"
            "<div class=`"alert alert-$($Class.ToLower())`">$String</div>"
        }
    }
    end{}

}
function New-BootstrapDivWithHeading {
    param (
        [string]$HeadingText,
        [uint16]$HeadingLevel = 5,
        [string]$Content,
        [hashtable]$HeadingsAndContent
    )

    if ($PSBoundParameters.ContainsKey('HeadingsAndContent')) {
        [string]$Text = ForEach ($Key in $HeadingsAndContent.Keys) {
            (New-HtmlHeading $Key -Level $HeadingLevel) +
            $HeadingsAndContent[$Key]
        }
    } else {
        $Text = (New-HtmlHeading $HeadingText -Level $HeadingLevel) +
        $Content
    }

    New-BootstrapDiv -Text $Text
}
function New-BootstrapGrid {
    <#
        .SYNOPSIS
            Wraps HTML elements in a Bootstrap column of the specified width
        .DESCRIPTION
            Creates a Bootstrap container which contains a row which contains a column of the specified width
        .OUTPUTS
            A string wih the code for the Bootstrap container
        .EXAMPLE
            New-BootstrapColumn -Html '<h1>Heading</h1>'

            This example returns the following string:
            '<div class="container"><div class="row justify-content-md-center"><div class="col col-lg-12"><h1>Heading</h1></div></div></div>'
    #>
    [CmdletBinding()]
    param(
        #The HTML element to apply the Bootstrap column to
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [System.String[]]$Html,

        [string]$Justify = 'Center'
    )
    begin{
        $String = @()
        [decimal]$ExactWidth = 12 / ($Html | Measure-Object).Count
        [int]$Width = [Math]::Floor($ExactWidth)
        $String += "<div class=`"container`"><div class=`"row justify-content-md-$($Justify.ToLower())`">"
    }
    process{
        ForEach ($OldHtml in $Html) {
            $String += "<div class=`"col col-lg-$Width`">$OldHtml</div>"
        }
    }
    end{
        $String += "</div></div>"
        $String -join ''
    }

}
Function New-BootstrapList {
    <#
        .SYNOPSIS
            Upgrade a boring HTML unordered list to a fancy Bootstrap list group
        .DESCRIPTION
            Applies the Bootstrap 'table table-striped' class to an HTML table
        .OUTPUTS
            A string wih the code for the Bootstrap table
        .EXAMPLE
            New-BootstrapTable -HtmlTable '<table><tr><th>Name</th><th>Id</th></tr><tr><td>ALMon</td><td>5540</td></tr></table>'

            This example returns the following string:
            '<table class="table table-striped"><tr><th>Name</th><th>Id</th></tr><tr><td>ALMon</td><td>5540</td></tr></table>'
        .NOTES
            Author: Jeremy La Camera
            Last Updated: 11/6/2016
    #>
    [CmdletBinding()]
    param(
        #The HTML table to apply the Bootstrap striped table CSS class to
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [System.String[]]$HtmlTable
    )
    begin{}
    process{
        ForEach ($Table in $HtmlTable) {
            [String]$NewTable = $Table -replace '<table>','<table class="table table-striped">'
            Write-Output $NewTable
        }
    }
    end{}
}
function New-BootstrapPanel {
    <#
        .SYNOPSIS
            Wraps HTML elements in a Bootstrap column of the specified width
        .DESCRIPTION
            Creates a Bootstrap container which contains a row which contains a column of the specified width
        .OUTPUTS
            A string wih the code for the Bootstrap container
        .EXAMPLE
            New-BootstrapColumn -Html '<h1>Heading</h1>'

            This example returns the following string:
            '<div class="container"><div class="row justify-content-md-center"><div class="col col-lg-12"><h1>Heading</h1></div></div></div>'
    #>
    [CmdletBinding()]
    param(
        #The HTML element to apply the Bootstrap column to
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [System.String[]]$Html,

        [string]$Class = 'default',

        [string]$Heading,

        [string]$Footer
    )
    begin{
        $String = @()
        $String += "<div class=`"panel panel-$($Class.ToLower())`">"
        if ($Heading) {
            $String += "<div class=`"panel-heading`">$Heading</div>"
        }
    }
    process{
        ForEach ($OldHtml in $Html) {
            $String += "<div class=`"panel-body`">$OldHtml</div>"
        }
    }
    end{
        if ($Footer) {
            $String += "<div class=`"panel-footer`">$Footer</div>"
        }
        $String += "</div>"
        $String -join ''
    }

}
function New-BootstrapReport {
    <#
        .SYNOPSIS
            Build a new Bootstrap report based on an HTML template
        .DESCRIPTION
            Inserts the specified title, description, and body into the HTML report template
        .OUTPUTS
            Outputs a complete HTML report as a string
        .EXAMPLE
            New-BootstrapReport -Title 'ReportTitle' -Description 'This is the report description' -Body 'This is the body of the report'
        .NOTES
            Author: Jeremy La Camera
            Last Updated: 11/6/2016
    #>
    [CmdletBinding()]
    param(
        #Title of the report (displayed at the top)
        [String]$Title,

        #Description of the report (displayed below the Title)
        [String]$Description,

        #Body of the report (tables, list groups, etc.)
        [String[]]$Body,

        #The path to the HTML report template that includes the Boostrap CSS
        [String]$TemplatePath = "$PSScriptRoot\data\Templates\ReportTemplate.html"
    )
    begin {
        if ($PSBoundParameters.ContainsKey('TemplatePath')) {
            [String]$Report = Get-Content $TemplatePath
            if ($null -eq $Report) { Write-Host "$TemplatePath not loaded. Failure. Error." }
        } else {
            [String]$Report = Get-BootstrapTemplate
        }
    }
    process {

        # Turn URLs into hyperlinks
        $URLs = ($Body | Select-String -Pattern 'http[s]?:\/\/[^\s\"\<\>\#\%\{\}\|\\\^\~\[\]\`]*' -AllMatches).Matches.Value | Sort-Object -Unique
        foreach ($URL in $URLs) {
            if ($URL.Length -gt 50) {
                $Body = $Body.Replace($URL, "<a href=$URL>$($URL[0..46] -join '')...</a>")
            } else {
                $Body = $Body.Replace($URL, "<a href=$URL>$URL</a>")
            }
        }


        $Report = $Report -replace '_ReportTitle_', $Title
        $Report = $Report -replace '_ReportDescription_', $Description
        $Report = $Report -replace '_ReportBody_', $Body

    }
    end {
        Write-Output $Report
    }
}
Function New-BootstrapTable {
    <#
        .SYNOPSIS
            Upgrade a boring HTML table to a fancy Bootstrap table
        .DESCRIPTION
            Applies the Bootstrap 'table table-striped' class to an HTML table
        .OUTPUTS
            A string wih the code for the Bootstrap table
        .EXAMPLE
            New-BootstrapTable -HtmlTable '<table><tr><th>Name</th><th>Id</th></tr><tr><td>ALMon</td><td>5540</td></tr></table>'

            This example returns the following string:
            '<table class="table table-striped"><tr><th>Name</th><th>Id</th></tr><tr><td>ALMon</td><td>5540</td></tr></table>'
        .NOTES
            Author: Jeremy La Camera
            Last Updated: 11/6/2016
    #>
    [CmdletBinding()]
    param(
        #The HTML table to apply the Bootstrap striped table CSS class to
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [System.String[]]$HtmlTable
    )
    begin{}
    process{
        ForEach ($Table in $HtmlTable) {
            [String]$NewTable = $Table -replace '<table>','<table class="table table-striped">'
            Write-Output $NewTable
        }
    }
    end{}
}
function New-HtmlAnchor{
    <#
        .SYNOPSIS
            Build a new HTML anchor
        .DESCRIPTION
            Inserts the specified HTML element into an HTML anchor with the specified name
        .OUTPUTS
            Outputs the heading as a string
        .EXAMPLE
            New-HtmlAnchor -Element "<h1>SampleHeader</h1>" -Name "AnchorToSampleHeader"
    #>
    [CmdletBinding()]
    param(

        #The text of the heading
        [Parameter(
            Position=0,
            ValueFromPipeline=$true,
            Mandatory=$true
        )]
        [String[]]$Element,

        #The heading level to generate (New-HtmlHeading can create h1, h2, h3, h4, h5, or h6 tags)
        [Parameter(Mandatory)]
        [String]$Name

    )
    begin{}
    process{
        Write-Output "<h$Level>$Text</h$Level>"
    }
    end{}
}
function New-HtmlHeading{
    <#
        .SYNOPSIS
            Build a new HTML heading
        .DESCRIPTION
            Inserts the specified text into an HTML heading of the specified level
        .OUTPUTS
            Outputs the heading as a string
        .EXAMPLE
            New-HtmlHeading -Text 'Example Heading'
    #>
    [CmdletBinding()]
    param(

        #The text of the heading
        [Parameter(
            Position=0,
            ValueFromPipeline=$True
        )]
        [String[]]$Text,

        #The heading level to generate (New-HtmlHeading can create h1, h2, h3, h4, h5, or h6 tags)
        [ValidateRange(1,6)]
        [Int16]$Level = 1

    )
    begin{}
    process{
        Write-Output "<h$Level>$Text</h$Level>"
    }
    end{}
}
function New-HtmlParagraph {
    <#
        .SYNOPSIS
            Build a new HTML heading
        .DESCRIPTION
            Inserts the specified text into an HTML heading of the specified level
        .OUTPUTS
            Outputs the heading as a string
        .EXAMPLE
            New-HtmlHeading -Text 'Example Heading'
    #>
    [CmdletBinding()]
    param(

        #The text of the heading
        [Parameter(
            Position=0,
            ValueFromPipeline=$True
        )]
        [String[]]$Text,

        #The heading level to generate (New-HtmlHeading can create h1, h2, h3, h4, h5, or h6 tags)
        [ValidateRange(1,6)]
        [Int16]$Level = 1

    )
    begin{}
    process{
        Write-Output "<h$Level>$Text</h$Level>"
    }
    end{}
}
<#
# Add any custom C# classes as usable (exported) types
$CSharpFiles = Get-ChildItem -Path "$PSScriptRoot\*.cs"
ForEach ($ThisFile in $CSharpFiles) {
    Add-Type -Path $ThisFile.FullName -ErrorAction Stop
}
#>

# Definition of Module 'Permission' is below

function Expand-Folder {

    # Expand a folder path into the paths of its subfolders

    param (

        # Path to return along, with the paths to its subfolders
        $Folder,

        <#
        How many levels of subfolder to enumerate

            Set to 0 to ignore all subfolders

            Set to -1 (default) to recurse infinitely

            Set to any whole number to enumerate that many levels
        #>
        $LevelsOfSubfolders,

        # Number of asynchronous threads to use
        [uint16]$ThreadCount = ((Get-CimInstance -ClassName CIM_Processor | Measure-Object -Sum -Property NumberOfLogicalProcessors).Sum),

        # Will be sent to the Type parameter of Write-LogMsg in the PsLogMessage module
        [string]$DebugOutputStream = 'Silent',

        # Hostname to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$TodaysHostname = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Hashtable of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    $LogParams = @{
        LogMsgCache  = $LogMsgCache
        ThisHostname = $TodaysHostname
        Type         = $DebugOutputStream
        WhoAmI       = $WhoAmI
    }

    if ($ThreadCount -eq 1 -or @($Folder).Count -eq 1) {

        $i = 0
        ForEach ($ThisFolder in $Folder) {
            $PercentComplete = $i / $Folder.Count
            Write-Progress -Activity "Get-Subfolder" -CurrentOperation $ThisFolder -PercentComplete $PercentComplete
            $i++
            $Subfolders = $null
            $Subfolders = Get-Subfolder -TargetPath $ThisFolder -FolderRecursionDepth $LevelsOfSubfolders -ErrorAction Continue
            Write-LogMsg @LogParams -Text "# Folders (including parent): $($Subfolders.Count + 1) for '$ThisFolder'"
            $Subfolders
        }
        Write-Progress -Activity "Get-Subfolder" -Completed

    } else {

        $GetSubfolder = @{
            Command           = 'Get-Subfolder'
            InputObject       = $Folder
            InputParameter    = 'TargetPath'
            DebugOutputStream = $DebugOutputStream
            TodaysHostname    = $TodaysHostname
            WhoAmI            = $WhoAmI
            LogMsgCache       = $LogMsgCache
            Threads           = $ThreadCount
        }
        Split-Thread @GetSubfolder

    }
}
function Format-TimeSpan {
    param (
        [timespan]$TimeSpan,
        [string[]]$UnitsToResolve = @('day', 'hour', 'minute', 'second', 'millisecond')
    )
    $StringBuilder = [System.Text.StringBuilder]::new()
    $aUnitWithAValueHasBeenFound = $false
    foreach ($Unit in $UnitsToResolve) {
        if ($TimeSpan."$Unit`s") {
            if ($aUnitWithAValueHasBeenFound) {
                $null = $StringBuilder.Append(", ")
            }
            $aUnitWithAValueHasBeenFound = $true

            if ($TimeSpan."$Unit`s" -eq 1) {
                $null = $StringBuilder.Append("$($TimeSpan."$Unit`s") $Unit")
            } else {
                $null = $StringBuilder.Append("$($TimeSpan."$Unit`s") $Unit`s")
            }
        }
    }
    $StringBuilder.ToString()
}
function Get-FolderAccessList {
    param (

        # Path to the item whose permissions to export (inherited ACEs will be included)
        $Folder,

        # Path to the subfolders whose permissions to report (inherited ACEs will be skipped)
        $Subfolder,

        # Number of asynchronous threads to use
        [uint16]$ThreadCount = ((Get-CimInstance -ClassName CIM_Processor | Measure-Object -Sum -Property NumberOfLogicalProcessors).Sum),

        # Will be sent to the Type parameter of Write-LogMsg in the PsLogMessage module
        [string]$DebugOutputStream = 'Silent',

        # Hostname to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$TodaysHostname = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Hashtable of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    $LogParams = @{
        LogMsgCache  = $LogMsgCache
        ThisHostname = $TodaysHostname
        Type         = $DebugOutputStream
        WhoAmI       = $WhoAmI
    }

    # We expect a small number of folders and a large number of subfolders
    # We will multithread the subfolders but not the folders
    # Multithreading overhead actually hurts performance for such a fast operation (Get-FolderAce) on a small number of items
    $i = 0
    ForEach ($ThisFolder in $Folder) {
        $PercentComplete = $i / $Folder.Count
        Write-Progress -Activity "Get-FolderAce -IncludeInherited" -CurrentOperation $ThisFolder -PercentComplete $PercentComplete
        $i++
        Get-FolderAce -LiteralPath $ThisFolder -IncludeInherited
    }
    Write-Progress -Activity "Get-FolderAce -IncludeInherited" -Completed

    if ($ThreadCount -eq 1) {

        $i = 0
        ForEach ($ThisFolder in $Subfolder) {
            $PercentComplete = $i / $Subfolder.Count
            Write-Progress -Activity "Get-FolderAce" -CurrentOperation $ThisFolder -PercentComplete $PercentComplete
            $i++
            Get-FolderAce -LiteralPath $ThisFolder
        }
        Write-Progress -Activity "Get-FolderAce" -Completed

    } else {

        $GetFolderAce = @{
            Command           = 'Get-FolderAce'
            InputObject       = $Subfolder
            InputParameter    = 'LiteralPath'
            DebugOutputStream = $DebugOutputStream
            TodaysHostname    = $TodaysHostname
            WhoAmI            = $WhoAmI
            LogMsgCache       = $LogMsgCache
            Threads           = $ThreadCount
        }
        Split-Thread @GetFolderAce

    }
}
function Get-FolderPermissionsBlock {
    param (
        $FolderPermissions,

        # Regular expressions matching names of Users or Groups to exclude from the Html report
        [string[]]$ExcludeAccount,

        $ExcludeEmptyGroups,

        <#
        Domain(s) to ignore (they will be removed from the username)

        Intended when a user has matching SamAccountNames in multiple domains but you only want them to appear once on the report.

        Can also be used to remove all domains simply for brevity in the report.
        #>
        [string[]]$IgnoreDomain

    )

    $ShortestFolderPath = $ThisFolder.Name |
    Sort-Object |
    Select-Object -First 1

    ForEach ($ThisFolder in $FolderPermissions) {

        $ThisHeading = New-HtmlHeading "Accounts with access to $($ThisFolder.Name)" -Level 5

        $Leaf = $ThisFolder.Name | Split-Path -Parent | Split-Path -Leaf -ErrorAction SilentlyContinue

        if ($Leaf) {
            $ParentLeaf = $Leaf
        } else {
            $ParentLeaf = $ThisFolder.Name | Split-Path -Parent
        }
        if ('' -ne $ParentLeaf) {
            if (($ThisFolder.Group.FolderInheritanceEnabled | Select-Object -First 1) -eq $true) {
                if ($ThisFolder.Name -eq $ShortestFolderPath) {
                    $ThisSubHeading = "Inherited permissions from the parent folder ($ParentLeaf) are included. This folder can only be accessed by the users listed below:"
                } else {
                    $ThisSubHeading = "Accounts with access to the parent folder and subfolders ($ParentLeaf) can access this folder. So can any users listed below:"
                }
            } else {
                $ThisSubHeading = "Accounts with access to the parent folder and subfolders ($ParentLeaf) cannot access this folder unless they are listed below:"
            }
        } else {
            $ThisSubHeading = "This is the top-level folder. It can only be accessed by the users listed below:"
        }

        $FilteredAccounts = $ThisFolder.Group |
        Group-Object -Property Account |
        # Skip the accounts we need to skip
        Where-Object -FilterScript {
            ![bool]$(
                ForEach ($RegEx in $ExcludeAccount) {
                    if ($_.Name -match $RegEx) {
                        $true
                    }
                }
            )
        }

        # Exclude groups with members (the group will be reflected on the report with its members)
        $FilteredAccounts = $FilteredAccounts |
        Where-Object -FilterScript {
            -not (
                $_.Group.SchemaClassName -contains 'group' -and
                $null -eq $_.Group.IdentityReference
            )
        }

        if ($ExcludeEmptyGroups) {
            $FilteredAccounts = $FilteredAccounts |
            Where-Object -FilterScript {
                # Eliminate empty groups (not useful to see in the middle of a list of users/job titles/departments/etc).
                $_.Group.SchemaClassName -notcontains 'group'
            }
        }

        $ThisTable = $FilteredAccounts |
        Select-Object -Property @{Label = 'Account'; Expression = { $_.Name } },
        @{Label = 'Access'; Expression = { ($_.Group | Sort-Object -Property IdentityReference -Unique).Access -join ' ; ' } },
        @{Label = 'Due to Membership In'; Expression = {
                $GroupString = ($_.Group.IdentityReference | Sort-Object -Unique) -join ' ; '
                ForEach ($IgnoreThisDomain in $IgnoreDomain) {
                    $GroupString = $GroupString -replace "$IgnoreThisDomain\\", ''
                }
                $GroupString
            }
        },
        @{Label = 'Name'; Expression = { $_.Group.Name | Sort-Object -Unique } },
        @{Label = 'Department'; Expression = { $_.Group.Department | Sort-Object -Unique } },
        @{Label = 'Title'; Expression = { $_.Group.Title | Sort-Object -Unique } } |
        Sort-Object -Property Name |
        ConvertTo-Html -Fragment |
        New-BootstrapTable

        New-BootstrapDiv -Text ($ThisHeading + $ThisSubHeading + $ThisTable)
    }
}
function Get-FolderTableHeader {
    param ($LevelsOfSubfolders)

    switch ($LevelsOfSubfolders ) {
        0 {
            'Includes the target folder only (option to report on subfolders was declined)'
        }
        -1 {
            'Includes the target folder and all subfolders with unique permissions'
        }
        default {
            "Includes the target folder and $LevelsOfSubfolders levels of subfolders with unique permissions"
        }
    }
}
function Get-HtmlBody {
    param (
        $FolderList,
        $HtmlFolderPermissions,
        $ReportFooter,
        $HtmlFileList,
        $LogDir,
        $HtmlExclusions
    )
    $StringBuilder = [System.Text.StringBuilder]::new()
    $null = $StringBuilder.Append((New-HtmlHeading "Folders with Permissions in This Report" -Level 3))
    $null = $StringBuilder.Append($FolderList)
    $null = $StringBuilder.Append((New-HtmlHeading "Accounts Included in Those Permissions" -Level 3))
    $HtmlFolderPermissions |
    ForEach-Object {
        $null = $StringBuilder.Append($_)
    }
    if ($HtmlExclusions) {
        $null = $StringBuilder.Append((New-HtmlHeading "Exclusions from This Report" -Level 3))
        $null = $StringBuilder.Append($HtmlExclusions)
    }
    $null = $StringBuilder.Append((New-HtmlHeading "Files Generated" -Level 3))
    $null = $StringBuilder.Append($HtmlFileList)
    $null = $StringBuilder.Append($ReportFooter)
    $StringBuilder.ToString()
}
function Get-HtmlReportFooter {
    param (
        # Stopwatch that was started when report generation began
        [System.Diagnostics.Stopwatch]$StopWatch,

        # NT Account caption (CONTOSO\User) of the account running this function
        [string]$WhoAmI = (whoami.EXE),

        <#
        FQDN of the computer running this function

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        [uint64]$ItemCount,

        [uint64]$TotalBytes,

        [string]$ReportInstanceId

    )
    $null = $StopWatch.Stop()
    $FinishTime = Get-Date
    $StartTime = $FinishTime.AddTicks(-$StopWatch.ElapsedTicks)
    $TimeZoneName = Get-TimeZoneName -Time $FinishTime
    $Duration = Format-TimeSpan -TimeSpan $StopWatch.Elapsed
    if ($TotalBytes) {
        $Size = " ($($TotalBytes / 1TB) TiB"
    }
    $Text = @"
Report generated by $WhoAmI on $ThisFQDN starting at $StartTime and ending at $FinishTime $TimeZoneName<br />
Processed permissions for $ItemCount items$Size in $Duration<br />
Report instance: $ReportInstanceId
"@
    New-BootstrapAlert -Class Light -Text $Text
}
function Get-PrtgXmlSensorOutput {
    param (
        $NtfsIssues
    )

    $Channels = [System.Collections.Generic.List[string]]::new()


    # Build our XML output formatted for PRTG.
    $ChannelParams = @{
        MaxError   = 0.5
        Channel    = 'Folders with inheritance disabled'
        Value      = ($NtfsIssues.FoldersWithBrokenInheritance | Measure-Object).Count
        CustomUnit = 'folders'
    }
    Format-PrtgXmlResult @ChannelParams |
    ForEach-Object { $null = $Channels.Add($_) }

    $ChannelParams = @{
        MaxError   = 0.5
        Channel    = 'ACEs for groups breaking naming convention'
        Value      = ($NtfsIssues.NonCompliantGroups | Measure-Object).Count
        CustomUnit = 'ACEs'
    }
    Format-PrtgXmlResult @ChannelParams |
    ForEach-Object { $null = $Channels.Add($_) }

    $ChannelParams = @{
        MaxError   = 0.5
        Channel    = 'ACEs for users instead of groups'
        Value      = ($NtfsIssues.UserACEs | Measure-Object).Count
        CustomUnit = 'ACEs'
    }
    Format-PrtgXmlResult @ChannelParams |
    ForEach-Object { $null = $Channels.Add($_) }


    $ChannelParams = @{
        MaxError   = 0.5
        Channel    = 'ACEs for unresolvable SIDs'
        Value      = ($NtfsIssues.SIDsToCleanup | Measure-Object).Count
        CustomUnit = 'ACEs'
    }
    Format-PrtgXmlResult @ChannelParams |
    ForEach-Object { $null = $Channels.Add($_) }


    $ChannelParams = @{
        MaxError   = 0.5
        Channel    = "Folders with 'CREATOR OWNER' access"
        Value      = ($NtfsIssues.FoldersWithCreatorOwner | Measure-Object).Count
        CustomUnit = 'folders'
    }
    Format-PrtgXmlResult @ChannelParams |
    ForEach-Object { $null = $Channels.Add($_) }

    Format-PrtgXmlSensorOutput -PrtgXmlResult $Channels -IssueDetected:$($NtfsIssues.IssueDetected)

}
function Get-ReportDescription {
    param ($LevelsOfSubfolders)

    switch ($LevelsOfSubfolders ) {
        0 {
            'Does not include permissions on subfolders (option was declined)'
        }
        -1 {
            'Includes all subfolders with unique permissions (including ∞ levels of subfolders)'
        }
        default {
            "Includes all subfolders with unique permissions (down to $LevelsOfSubfolders levels of subfolders)"
        }
    }
}
function Get-TimeZoneName {
    param (
        [datetime]$Time,
        [Microsoft.Management.Infrastructure.CimInstance]$TimeZone = (Get-CimInstance -ClassName Win32_TimeZone)
    )
    if ($Time.IsDaylightSavingTime()) {
        return $TimeZone.DaylightName
    } else {
        return $TimeZone.StandardName
    }
}
function Select-FolderTableProperty {
    param (
        $InputObject
    )
    $InputObject | Select-Object -Property @{
        Label      = 'Folder'
        Expression = { $_.Name }
    },
    @{
        Label      = 'Inheritance'
        Expression = { $_.Group.FolderInheritanceEnabled | Select-Object -First 1 }
    }
}
function Select-UniqueAccountPermission {

    param (

        # Objects output from Format-SecurityPrincipal ... | Group-Object -Property User
        [Parameter(ValueFromPipeline)]
        $AccountPermission,

        <#
        Domain(s) to ignore (they will be removed from the username)

        Intended when a user has matching SamAccountNames in multiple domains but you only want them to appear once on the report.

        Can also be used to remove all domains simply for brevity in the report.
        #>
        [string[]]$IgnoreDomain,

        # Hashtable will be used to deduplicate
        $KnownUsers = [hashtable]::Synchronized(@{})

    )
    process {

        ForEach ($ThisUser in $AccountPermission) {

            $ShortName = $ThisUser.Name
            ForEach ($IgnoreThisDomain in $IgnoreDomain) {
                $ShortName = $ShortName -replace "^$IgnoreThisDomain\\", ''
            }

            $ThisKnownUser = $null
            $ThisKnownUser = $KnownUsers[$ShortName]
            if ($null -eq $ThisKnownUser) {
                $KnownUsers[$ShortName] = [pscustomobject]@{
                    'Count' = $ThisUser.Group.Count
                    'Name'  = $ShortName
                    'Group' = $ThisUser.Group
                }
            } else {
                $KnownUsers[$ShortName] = [pscustomobject]@{
                    'Count' = $ThisKnownUser.Group.Count + $ThisUser.Group.Count
                    'Name'  = $ShortName
                    'Group' = $ThisKnownUser.Group + $ThisUser.Group
                }
            }
        }

    }
    end {
        $KnownUsers.Values
    }

}
function Update-CaptionCapitalization {
    # As of 2022-08-31 this function is still not implemented...need to rethink
    param (
        [string]$ThisHostName,
        [hashtable]$Win32AccountsByCaption
    )
    $NewDictionary = [hashtable]::Synchronized(@{})
    $Win32AccountsByCaption.Keys |
    ForEach-Object {
        $Object = $Win32AccountsByCaption[$_]
        $NewKey = $_ -replace "^$ThisHostname\\$ThisHostname\\", "$ThisHostname\$ThisHostname\"
        $NewKey = $NewKey -replace "^$ThisHostname\\", "$ThisHostname\"
        $NewDictionary[$NewKey] = $Object
    }
    return $NewDictionary
}

# Add any custom C# classes as usable (exported) types
$CSharpFiles = Get-ChildItem -Path "$PSScriptRoot\*.cs"
ForEach ($ThisFile in $CSharpFiles) {
    Add-Type -Path $ThisFile.FullName -ErrorAction Stop
}

#----------------[ Logging ]----------------

    $StopWatch = [System.Diagnostics.Stopwatch]::new()
    $null = $StopWatch.Start()
    $ReportInstanceId = [guid]::NewGuid().ToString()
    $OutputDir = New-DatedSubfolder -Root $OutputDir -Suffix "_$ReportInstanceId"
    $TranscriptFile = "$OutputDir\PowerShellTranscript.log"
    Start-Transcript $TranscriptFile *>$null
    Write-Information $TranscriptFile

    #----------------[ Declarations ]----------------

    $CsvFilePath1 = "$OutputDir\1-AccessControlEntries.csv"
    $CsvFilePath2 = "$OutputDir\2-AccessControlEntriesWithResolvedIdentityReferences.csv"
    $CsvFilePath3 = "$OutputDir\3-AccessControlEntriesWithResolvedAndExpandedIdentityReferences.csv"
    $ReportFile = "$OutputDir\PermissionsReport.htm"
    $XmlFile = "$OutputDir\PrtgSensorResult.xml"
    $LogFile = "$OutputDir\Export-Permission.log"
    $DirectoryEntryCache = [hashtable]::Synchronized(@{})
    $IdentityReferenceCache = [hashtable]::Synchronized(@{})
    $Win32AccountsBySID = [hashtable]::Synchronized(@{})
    $Win32AccountsByCaption = [hashtable]::Synchronized(@{})
    $DomainsBySID = [hashtable]::Synchronized(@{})
    $DomainsByNetbios = [hashtable]::Synchronized(@{})
    $DomainsByFqdn = [hashtable]::Synchronized(@{})
    $LogMsgCache = [hashtable]::Synchronized(@{})
    $Permissions = $null
    $ResolvedFolderTargets = [System.Collections.Generic.List[string]]::new()
    $SecurityPrincipals = $null
    $FormattedSecurityPrincipals = $null
    $UniqueAccountPermissions = $null
    $FolderPermissions = $null

    # Get the hostname of the computer running the script
    $ThisHostname = HOSTNAME.EXE

    # Get the NTAccount caption of the user running the script
    $WhoAmI = whoami.exe

    # Prepare the cache of log-related variables to pass to various functions
    $LoggingParams = @{
        ThisHostname = $ThisHostname
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    # Fix the capitalization in the all-lowercase output from whoami.exe
    $WhoAmI = Get-CurrentWhoAmI @LoggingParams

    # Update the cache with the corrected capitalization
    $LoggingParams['WhoAmI'] = $WhoAmI

    # Create an additional cache specifically for Write-LogMsg
    $LogParams = @{
        ThisHostname = $ThisHostname
        Type         = 'Debug'
        LogMsgCache  = $LogMsgCache
        WhoAmI       = $WhoAmI
    }

    # These 3 events already happened but we will log them now that we have the correct capitalization of the user
    Write-LogMsg @LogParams -Text "& HOSTNAME.EXE"
    Write-LogMsg @LogParams -Text "& whoami.exe"
    Write-LogMsg @LogParams -Text "Get-CurrentWhoAmI"

    Write-LogMsg @LogParams -Text "ConvertTo-DnsFqdn"
    $ThisFqdn = ConvertTo-DnsFqdn -ComputerName $ThisHostName @LoggingParams

    Write-LogMsg @LogParams -Text "Get-ReportDescription -LevelsOfSubfolders $SubfolderLevels"
    $ReportDescription = Get-ReportDescription -LevelsOfSubfolders $SubfolderLevels

    Write-LogMsg @LogParams -Text "Get-FolderTableHeader -LevelsOfSubfolders $SubfolderLevels"
    $FolderTableHeader = Get-FolderTableHeader -LevelsOfSubfolders $SubfolderLevels

    Write-LogMsg @LogParams -Text "Get-TrustedDomain"
    $TrustedDomains = Get-TrustedDomain @LoggingParams

}

process {

    #----------------[ Main Execution ]---------------

    ForEach ($ThisTargetPath in $TargetPath) {

        # Resolve each target path to all of its associated UNC paths (including all DFS folder targets)
        Write-LogMsg @LogParams -Text "Resolve-Folder -FolderPath '$ThisTargetPath'"
        $null = $ResolvedFolderTargets.AddRange([string[]](Resolve-Folder -FolderPath $ThisTargetPath))

    }

}

end {

    # Expand each resolved folder path into the paths of its subfolders
    Write-LogMsg @LogParams -Text "Expand-Folder -Folder @('$($ResolvedFolderTargets -join "',")') -LevelsOfSubfolders $SubfolderLevels"
    $Subfolders = Expand-Folder -Folder $ResolvedFolderTargets -LevelsOfSubfolders $SubfolderLevels -ThreadCount $ThreadCount @LoggingParams

    # Get the relevant Access Control Entries for each folder and subfolder
    Write-LogMsg @LogParams -Text "Get-FolderAccessList -FolderTargets @('$($Subfolders -join "',")')"
    $Permissions = Get-FolderAccessList -Folder $ResolvedFolderTargets -Subfolder $Subfolders -ThreadCount $ThreadCount @LoggingParams

    # Save a CSV of the raw NTFS ACEs, showing non-inherited ACEs only except for the root folder $TargetPath
    $Permissions |
    Select-Object -Property @{
        Label      = 'Path'
        Expression = { $_.SourceAccessList.Path }
    }, IdentityReference, AccessControlType, FileSystemRights, IsInherited, PropagationFlags, InheritanceFlags |
    Export-Csv -NoTypeInformation -LiteralPath $CsvFilePath1

    Write-Information $CsvFilePath1

    # This prevents threads that start near the same time from finding the cache empty and attempting costly operations to populate it
    # This prevents repetitive queries to the same directory servers

    # Identify server names from the item paths
    $UniqueServerNames = [System.Collections.Generic.List[[string]]]::new()
    $null = $UniqueServerNames.Add($ThisFqdn)

    $Permissions.SourceAccessList.Path |
    ForEach-Object {
        $null = $UniqueServerNames.Add((Find-ServerNameInPath -LiteralPath $_))
    }

    # Add the discovered domains to our list of known ADSI server name
    $TrustedDomains |
    ForEach-Object {
        $null = $UniqueServerNames.Add($_.DomainFqdn)
    }

    # Deduplicate our list of known ADSI server names
    $UniqueServerNames = $UniqueServerNames |
    Sort-Object -Unique

    # Populate six caches:
    # Three caches of known ADSI directory servers
    # The first cache is keyed on domain SID (e.g. S-1-5-2)
    # The second cache is keyed on domain FQDN (e.g. ad.contoso.com)
    # The first cache is keyed on domain NetBIOS name (e.g. CONTOSO)
    # Two caches of known Win32_Account instances
    # The first cache is keyed on SID (e.g. S-1-5-2)
    # The second cache is keyed on the Caption (NT Account name e.g. CONTOSO\user1)
    # Also populate a cache of DirectoryEntry objects for any domains that have them
    if ($ThreadCount -eq 1) {
        $GetAdsiServerParams = @{
            Win32AccountsBySID     = $Win32AccountsBySID
            Win32AccountsByCaption = $Win32AccountsByCaption
            DirectoryEntryCache    = $DirectoryEntryCache
            DomainsByFqdn          = $DomainsByFqdn
            DomainsByNetbios       = $DomainsByNetbios
            DomainsBySid           = $DomainsBySid
            ThisHostName           = $ThisHostName
            ThisFqdn               = $ThisFqdn
            WhoAmI                 = $WhoAmI
            LogMsgCache            = $LogMsgCache
        }

        $UniqueServerNames |
        ForEach-Object {
            Write-LogMsg @LogParams -Text "Get-AdsiServer -Fqdn '$_'"
            $null = Get-AdsiServer @GetAdsiServerParams -Fqdn $_
        }

    } else {
        $GetAdsiServerParams = @{
            Command        = 'Get-AdsiServer'
            InputObject    = $UniqueServerNames
            InputParameter = 'Fqdn'
            TodaysHostname = $ThisHostname
            WhoAmI         = $WhoAmI
            LogMsgCache    = $LogMsgCache
            Timeout        = 600
            Threads        = $ThreadCount
            AddParam       = @{
                Win32AccountsBySID     = $Win32AccountsBySID
                Win32AccountsByCaption = $Win32AccountsByCaption
                DirectoryEntryCache    = $DirectoryEntryCache
                DomainsByFqdn          = $DomainsByFqdn
                DomainsByNetbios       = $DomainsByNetbios
                DomainsBySid           = $DomainsBySid
                ThisHostName           = $ThisHostName
                ThisFqdn               = $ThisFqdn
                WhoAmI                 = $WhoAmI
                LogMsgCache            = $LogMsgCache
            }
        }
        Write-LogMsg @LogParams -Text "Split-Thread -Command 'Get-AdsiServer' -InputParameter AdsiServer -InputObject @('$($UniqueServerNames -join "',")')"
        $null = Split-Thread @GetAdsiServerParams
    }

    # Resolve the IdentityReference in each Access Control Entry (e.g. CONTOSO\user1, or a SID) to their associated SIDs/Names
    # The resolved name will include the domain name (or local computer name for local accounts)
    if ($ThreadCount -eq 1) {
        $ResolveAceParams = @{
            DirectoryEntryCache    = $DirectoryEntryCache
            Win32AccountsBySID     = $Win32AccountsBySID
            Win32AccountsByCaption = $Win32AccountsByCaption
            DomainsBySID           = $DomainsBySID
            DomainsByNetbios       = $DomainsByNetbios
            DomainsByFqdn          = $DomainsByFqdn
            ThisHostName           = $ThisHostName
            ThisFqdn               = $ThisFqdn
            WhoAmI                 = $WhoAmI
            LogMsgCache            = $LogMsgCache
        }

        $PermissionsWithResolvedIdentityReferences = $Permissions |
        ForEach-Object {
            $ResolveAceParams['InputObject'] = $_
            Write-LogMsg @LogParams -Text "Resolve-Ace -InputObject $($_.IdentityReference)"
            Resolve-Ace3 @ResolveAceParams
        }

    } else {
        $ResolveAceParams = @{
            Command              = 'Resolve-Ace3'
            InputObject          = $Permissions
            InputParameter       = 'InputObject'
            ObjectStringProperty = 'IdentityReference'
            TodaysHostname       = $ThisHostname
            #DebugOutputStream = 'Debug'
            WhoAmI               = $WhoAmI
            LogMsgCache          = $LogMsgCache
            Threads              = $ThreadCount
            AddParam             = @{
                DirectoryEntryCache    = $DirectoryEntryCache
                Win32AccountsBySID     = $Win32AccountsBySID
                Win32AccountsByCaption = $Win32AccountsByCaption
                DomainsBySID           = $DomainsBySID
                DomainsByNetbios       = $DomainsByNetbios
                DomainsByFqdn          = $DomainsByFqdn
                ThisHostName           = $ThisHostName
                ThisFqdn               = $ThisFqdn
                WhoAmI                 = $WhoAmI
                LogMsgCache            = $LogMsgCache
            }
        }
        Write-LogMsg @LogParams -Text "Split-Thread -Command 'Resolve-Ace' -InputParameter InputObject -InputObject `$Permissions -ObjectStringProperty 'IdentityReference' -DebugOutputStream 'Debug'"
        $PermissionsWithResolvedIdentityReferences = Split-Thread @ResolveAceParams
    }

    # Save a CSV report of the resolved identity references
    $PermissionsWithResolvedIdentityReferences |
    Select-Object -Property @{
        Label      = 'Path'
        Expression = { $_.SourceAccessList.Path }
    }, * |
    Export-Csv -NoTypeInformation -LiteralPath $CsvFilePath2

    Write-Information $CsvFilePath2

    # Group the Access Control Entries by their resolved identity references
    # This avoids repeat ADSI lookups for the same security principal
    $GroupedIdentities = $PermissionsWithResolvedIdentityReferences |
    Group-Object -Property IdentityReferenceResolved

    # Use ADSI to collect more information about each resolved identity reference
    if ($ThreadCount -eq 1) {
        $ExpandIdentityReferenceParams = @{
            DirectoryEntryCache    = $DirectoryEntryCache
            IdentityReferenceCache = $IdentityReferenceCache
            DomainsBySID           = $DomainsBySID
            DomainsByNetbios       = $DomainsByNetbios
            DomainsByFqdn          = $DomainsByFqdn
            ThisHostName           = $ThisHostName
            ThisFqdn               = $ThisFqdn
            WhoAmI                 = $WhoAmI
            LogMsgCache            = $LogMsgCache
        }
        if ($NoGroupMembers) {
            $ExpandIdentityReferenceParams['NoGroupMembers'] = $true
        }
        $SecurityPrincipals = $GroupedIdentities |
        ForEach-Object {
            $ExpandIdentityReferenceParams['AccessControlEntry'] = $_
            Write-LogMsg @LogParams -Text "Expand-IdentityReference -AccessControlEntry $($_.Name)"
            Expand-IdentityReference @ExpandIdentityReferenceParams
        }

    } else {
        $ExpandIdentityReferenceParams = @{
            Command              = 'Expand-IdentityReference'
            InputObject          = $GroupedIdentities
            InputParameter       = 'AccessControlEntry'
            TodaysHostname       = $ThisHostname
            WhoAmI               = $WhoAmI
            LogMsgCache          = $LogMsgCache
            Threads              = $ThreadCount
            AddParam             = @{
                DirectoryEntryCache    = $DirectoryEntryCache
                IdentityReferenceCache = $IdentityReferenceCache
                DomainsBySID           = $DomainsBySID
                DomainsByNetbios       = $DomainsByNetbios
                DomainsByFqdn          = $DomainsByFqdn
                ThisHostName           = $ThisHostName
                ThisFqdn               = $ThisFqdn
                WhoAmI                 = $WhoAmI
                LogMsgCache            = $LogMsgCache
            }
            ObjectStringProperty = 'Name'
        }
        if ($NoGroupMembers) {
            $ExpandIdentityReferenceParams['AddSwitch'] = 'NoGroupMembers'
        }
        Write-LogMsg @LogParams -Text "Split-Thread -Command 'Expand-IdentityReference' -InputParameter 'AccessControlEntry' -InputObject `$GroupedIdentities"
        $SecurityPrincipals = Split-Thread @ExpandIdentityReferenceParams
    }

    # Format Security Principals (distinguish group members from users directly listed in the NTFS DACLs)
    if ($ThreadCount -eq 1) {

        $FormattedSecurityPrincipals = $SecurityPrincipals |
        ForEach-Object {
            Write-LogMsg @LogParams -Text "Format-SecurityPrincipal -SecurityPrincipal $($_.Name)"
            Format-SecurityPrincipal -SecurityPrincipal $_
        }

    } else {
        $FormatSecurityPrincipalParams = @{
            Command              = 'Format-SecurityPrincipal'
            InputObject          = $SecurityPrincipals
            InputParameter       = 'SecurityPrincipal'
            Timeout              = 1200
            ObjectStringProperty = 'Name'
            TodaysHostname       = $ThisHostname
            WhoAmI               = $WhoAmI
            LogMsgCache          = $LogMsgCache
            Threads              = $ThreadCount
        }
        Write-LogMsg @LogParams -Text "Split-Thread -Command 'Format-SecurityPrincipal' -InputParameter 'SecurityPrincipal' -InputObject `$SecurityPrincipals -ObjectStringProperty 'Name'"
        $FormattedSecurityPrincipals = Split-Thread @FormatSecurityPrincipalParams
    }

    # Expand the collection of security principals from Format-SecurityPrincipal
    # back into a collection of access control entries (one per ACE per principal)
    if ($ThreadCount -eq 1) {

        $ExpandedAccountPermissions = $FormattedSecurityPrincipals |
        ForEach-Object {
            Write-LogMsg @LogParams -Text "Expand-AccountPermission -AccountPermission $($_.Name)"
            Expand-AccountPermission -AccountPermission $_
        }

    } else {
        $ExpandAccountPermissionParams = @{
            Command              = 'Expand-AccountPermission'
            InputObject          = $FormattedSecurityPrincipals
            InputParameter       = 'AccountPermission'
            TodaysHostname       = $ThisHostname
            ObjectStringProperty = 'Name'
            Timeout              = 1200
            Threads              = $ThreadCount
            AddParam             = @{
                WhoAmI      = $WhoAmI
                LogMsgCache = $LogMsgCache
            }
        }
        Write-LogMsg @LogParams -Text "Split-Thread -Command 'Expand-AccountPermission' -InputParameter 'AccountPermission' -InputObject `$FormattedSecurityPrincipals -ObjectStringProperty 'Name'"
        $ExpandedAccountPermissions = Split-Thread @ExpandAccountPermissionParams
    }

    # Save a CSV report of the expanded account permissions
    #ToDo: Expand DirectoryEntry objects in the DirectoryEntry and Members properties
    Write-LogMsg @LogParams -Text "`$ExpandedAccountPermissions |"
    Write-LogMsg @LogParams -Text "`Select-Object -Property @{ Label = 'SourceAclPath'; Expression = { `$_.ACESourceAccessList.Path } }, * |"
    Write-LogMsg @LogParams -Text "Export-Csv -NoTypeInformation -LiteralPath '$CsvFilePath'"

    $ExpandedAccountPermissions |
    Export-Csv -NoTypeInformation -LiteralPath $CsvFilePath3

    Write-Information $CsvFilePath3

    #$Accounts = $FormattedSecurityPrincipals |
    $Accounts = $ExpandedAccountPermissions |
    Group-Object -Property User

    # Filter out domain names we do not want on the report
    # This can be done when the domain is always the same and doesn't need to be displayed
    # This can also be done to ensure accounts only appear once on the report if they exist in multiple domains
    $IgnoreDomainString = "@('$($IgnoreDomain -join "',")')"
    Write-LogMsg @LogParams -Text "`$UniqueAccountPermissions = Select-UniqueAccountPermission -AccountPermission `$Accounts -IgnoreDomain $IgnoreDomainString"
    $UniqueAccountPermissions = Select-UniqueAccountPermission -AccountPermission $Accounts -IgnoreDomain $IgnoreDomain

    # Group the account permissions back into folder permissions for the report
    Write-LogMsg @LogParams -Text "Format-FolderPermission -UserPermission `$UniqueAccountPermissions | Group Folder | Sort Name"

    $FolderPermissions = Format-FolderPermission -UserPermission $UniqueAccountPermissions |
    Group-Object -Property Folder |
    Sort-Object -Property Name


    # Convert the folder permissions to an HTML table
    $GetFolderPermissionsBlock = @{
        FolderPermissions  = $FolderPermissions
        ExcludeAccount     = $ExcludeAccount
        ExcludeEmptyGroups = $ExcludeEmptyGroups
        IgnoreDomain       = $IgnoreDomain
    }
    Write-LogMsg @LogParams -Text "Get-FolderPermissionsBlock @GetFolderPermissionsBlock"
    $HtmlFolderPermissions = Get-FolderPermissionsBlock @GetFolderPermissionsBlock

    ##Commented the two lines below because actually keeping semicolons means it copy/pastes better into Excel
    ### Convert-ToHtml will not expand in-line HTML
    ### So replace the placeholders (semicolons) with HTML line breaks now, after Convert-ToHtml has already run
    ##$HtmlFolderPermissions = $HtmlFolderPermissions -replace ' ; ','<br>'

    $TargetPathString = $TargetPath -join '<br />'
    Write-LogMsg @LogParams -Text "New-BootstrapAlert -Class Dark -Text '$TargetPathString'"
    $ReportDescription = "$(New-BootstrapAlert -Class Dark -Text $TargetPathString) $ReportDescription"

    # Convert the folder list to an HTML table
    Write-LogMsg @LogParams -Text "Select-FolderTableProperty -InputObject `$FolderPermissions | ConvertTo-Html -Fragment | New-BootstrapTable"

    $HtmlTableOfFolders = Select-FolderTableProperty -InputObject $FolderPermissions |
    ConvertTo-Html -Fragment |
    New-BootstrapTable

    Write-LogMsg @LogParams -Text "New-BootstrapDivWithHeading -HeadingText '$FolderTableHeader' -Content `$HtmlTableOfFolders"
    $FolderList = New-BootstrapDivWithHeading -HeadingText $FolderTableHeader -Content $HtmlTableOfFolders

    $HeadingText = 'Accounts Excluded by Regular Expression'
    if ($ExcludeAccount) {
        $ListGroup = $ExcludeAccount |
        ConvertTo-HtmlList |
        ConvertTo-BootstrapListGroup

        $Description = 'Accounts matching these regular expressions were excluded from the report.'
        Write-LogMsg @LogParams -Text "New-BootstrapDivWithHeading -HeadingText '$HeadingText' -Content `"`$Description`$ListGroup`""
        $HtmlRegExExclusions = New-BootstrapDivWithHeading -HeadingText $HeadingText -Content "$Description$ListGroup"
    } else {
        $Description = 'No accounts were excluded based on regular expressions.'
        $HtmlRegExExclusions = $Description
        $HtmlRegExExclusions = New-BootstrapDivWithHeading -HeadingText $HeadingText -Content $Description
    }

    $HeadingText = 'Accounts Excluded by Class'
    if ($ExcludeAccountClass) {
        $ListGroup = $ExcludeAccountClass |
        ConvertTo-HtmlList |
        ConvertTo-BootstrapListGroup

        $Description = 'Accounts whose objectClass property is in this list were excluded from the report.'
        $HtmlClassExclusions = New-BootstrapDivWithHeading -HeadingText $HeadingText -Content "$Description$ListGroup"
    } else {
        $Description = 'No accounts were excluded based on objectClass.'
        $HtmlClassExclusions = New-BootstrapDivWithHeading -HeadingText $HeadingText -Content $Description
    }

    $HeadingText = 'Domains Ignored'
    if ($IgnoreDomain) {
        $ListGroup = $IgnoreDomain |
        ConvertTo-HtmlList |
        ConvertTo-BootstrapListGroup

        $Description = 'Accounts from these domains are listed in the report without their domain.'
        $HtmlIgnoredDomains = New-BootstrapDivWithHeading -HeadingText $HeadingText -Content "$Description$ListGroup"
    } else {
        $Description = 'No domains were ignored. All accounts have their domain listed.'
        $HtmlIgnoredDomains = New-BootstrapDivWithHeading -HeadingText $HeadingText -Content $Description
    }

    $HeadingText = 'Group Members'
    if ($NoGroupMembers) {
        $Description = 'Group members were excluded from the report.<br />Only accounts directly from the ACLs are included in the report.'
    } else {
        $Description = 'No accounts were excluded based on group membership.'
    }
    $HtmlExcludedGroupMembers = New-BootstrapDivWithHeading -HeadingText $HeadingText -Content $Description

    Write-LogMsg @LogParams -Text "New-BootstrapColumn -Html '`$HtmlExcludedGroupMembers`$HtmlClassExclusions',`$HtmlIgnoredDomains`$HtmlRegExExclusions"
    $ExclusionsDiv = New-BootstrapColumn -Html "$HtmlExcludedGroupMembers$HtmlClassExclusions", "$HtmlIgnoredDomains$HtmlRegExExclusions" -Width 6

    $HtmlListOfReports = $CsvFilePath1, $CsvFilePath2, $CsvFilePath3, $XmlFile, $ReportFile |
    Split-Path -Leaf |
    ConvertTo-HtmlList |
    ConvertTo-BootstrapListGroup

    $HtmlListOfLogs = $TranscriptFile, $LogFile |
    Split-Path -Leaf |
    ConvertTo-HtmlList |
    ConvertTo-BootstrapListGroup

    $HtmlReportsHeading = New-HtmlHeading -Text 'Reports' -Level 6
    $HtmlLogsHeading = New-HtmlHeading -Text 'Logs' -Level 6
    Write-LogMsg @LogParams -Text "New-BootstrapColumn -Html '`$HtmlReportsHeading`$HtmlListOfReports',`$HtmlLogsHeading`$HtmlListOfLogs"
    $FileListColumns = New-BootstrapColumn -Html "$HtmlReportsHeading$HtmlListOfReports", "$HtmlLogsHeading$HtmlListOfLogs" -Width 6

    #$HtmlOutputDir = New-HtmlHeading -Text $OutputDir -Level 6
    $HtmlOutputDir = New-BootstrapAlert -Text $OutputDir -Class 'secondary'
    Write-LogMsg @LogParams -Text "New-BootstrapDivWithHeading -HeadingText 'Output Folder:' -Content `$FileListColumns"
    $FileList = New-BootstrapDivWithHeading -HeadingText "Output Folder:" -Content "$HtmlOutputDir$FileListColumns"

    Write-LogMsg @LogParams -Text "Get-ReportFooter -StopWatch `$StopWatch -ReportInstanceId '$ReportInstanceId' -WhoAmI '$WhoAmI' -ThisFqdn '$ThisFqdn'"
    $ReportFooter = Get-HtmlReportFooter -StopWatch $StopWatch -ReportInstanceId $ReportInstanceId -WhoAmI $WhoAmI -ThisFqdn $ThisFqdn -ItemCount ($Subfolders.Count + $ResolvedFolderTargets.Count)

    Write-LogMsg @LogParams -Text "Get-HtmlBody -FolderList `$FolderList -HtmlFolderPermissions `$HtmlFolderPermissions"
    [string]$Body = Get-HtmlBody -FolderList $FolderList -HtmlFolderPermissions $HtmlFolderPermissions -HtmlExclusions $ExclusionsDiv -HtmlFileList $FileList -ReportFooter $ReportFooter

    $ReportParameters = @{
        Title       = $Title
        Description = $ReportDescription
        Body        = $Body
    }
    Write-LogMsg @LogParams -Text "New-BootstrapReport @ReportParameters"
    $Report = New-BootstrapReport @ReportParameters

    # Save the Html report
    $null = Set-Content -LiteralPath $ReportFile -Value $Report

    # Output the name of the report file to the Information stream
    Write-Information $ReportFile

    # Report common issues with NTFS permissions (formatted as XML for PRTG)
    # ToDo: Users with ownership
    $NtfsIssueParams = @{
        FolderPermissions     = $FolderPermissions
        UserPermissions       = $Accounts
        GroupNamingConvention = $GroupNamingConvention
    }
    Write-LogMsg @LogParams -Text "New-NtfsAclIssueReport @NtfsIssueParams"
    $NtfsIssues = New-NtfsAclIssueReport @NtfsIssueParams

    # Format the information as a custom XML sensor for Paessler PRTG Network Monitor
    Write-LogMsg @LogParams -Text "Get-PrtgXmlSensorOutput -NtfsIssues `$NtfsIssues"
    $XMLOutput = Get-PrtgXmlSensorOutput -NtfsIssues $NtfsIssues

    # Save the result of the custom XML sensor for Paessler PRTG Network Monitor
    $null = Set-Content -LiteralPath $XmlFile -Value $XMLOutput

    # Output the name of the report file to the Information stream
    Write-Information $XmlFile

    # Send the XML to a PRTG Custom XML Push sensor for tracking
    $PrtgSensorParams = @{
        XmlOutput          = $XMLOutput
        PrtgProbe          = $PrtgProbe
        PrtgSensorProtocol = $PrtgSensorProtocol
        PrtgSensorPort     = $PrtgSensorPort
        PrtgSensorToken    = $PrtgSensorToken
    }
    Write-LogMsg @LogParams -Text "Send-PrtgXmlSensorOutput @PrtgSensorParams"
    Send-PrtgXmlSensorOutput @PrtgSensorParams

    # Open the HTML report file (useful only interactively)
    if ($OpenReportAtEnd) {
        Invoke-Item $ReportFile
    }

    $LogMsgCache.Values |
    Sort-Object -Property Timestamp |
    Export-Csv -Delimiter "`t" -NoTypeInformation -LiteralPath $LogFile

    Stop-Transcript  *>$null

    # Output the XML so the script can be directly used as a PRTG sensor
    # Caution: This use may be a problem for a PRTG probe because of how long the script can run on large folders/domains
    # Recommendation: Specify the appropriate parameters to run this as a PRTG push sensor instead
    return $XMLOutput

}
