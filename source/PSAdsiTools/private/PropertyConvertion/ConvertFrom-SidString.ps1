function ConvertFrom-SidString {
    #[OutputType([System.Security.Principal.NTAccount])]
    param (
        [string]$SID
    )
    #[System.Security.Principal.SecurityIdentifier]::new($SID)
    # Only works if SID is in the current domain...otherwise SID not found
    Get-DirectoryEntry -DirectoryPath "LDAP://<SID=$SID>"
}
