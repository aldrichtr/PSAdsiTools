
function Get-ADGroupMember {
    [CmdletBinding()]
    param(
        # The group to list members of
        [Parameter(
            ValueFromPipeline
        )]
        [System.DirectoryServices.SearchResult]$Group,

        # Optionally recurse into nested groups, resolving to accounts
        [Parameter(
        )]
        [switch]$Recurse,

        # Hide the progress output
        [Parameter(
        )]
        [switch]$Quiet
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        Write-Debug "  looking for members of group '$($Group.Properties.name)'"
        foreach ($record in $Group.Properties.member) {
            Write-Debug "   found $record"
            $member = Search-ADSI -Property 'distinguishedname' -Value $record
            if($null -ne $member) {
                if ($Recurse) {
                    if ($member.properties.objectclass -contains 'group') {
                        Get-ADGroupMember -Group $member -Recurse:$Recurse
                    } else {
                        $member.GetDirectoryEntry() | Write-Output
                    }
                } else {
                    $member.GetDirectoryEntry() | Write-Output
                }
            }
        }
    }
    end {
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
