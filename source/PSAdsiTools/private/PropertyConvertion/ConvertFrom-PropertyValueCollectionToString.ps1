
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
    [CmdletBinding()]
    param (
        # The PropertyValueCollection
        [Parameter(
            Position = 0,
            ValueFromPipeline
        )]
        [System.DirectoryServices.PropertyValueCollection]$PropertyValueCollection
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        $SubType = & { $PropertyValueCollection.Value.GetType().FullName } 2>$null
        switch ($SubType) {
            'System.Byte[]' { ConvertTo-DecStringRepresentation -ByteArray $PropertyValueCollection.Value }
            default { "$($PropertyValueCollection.Value)" }
        }
    }
    end {
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
