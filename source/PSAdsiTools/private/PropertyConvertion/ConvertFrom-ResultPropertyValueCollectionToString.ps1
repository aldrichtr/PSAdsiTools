
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
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0,
            ValueFromPipeline
        )]
        [System.DirectoryServices.ResultPropertyValueCollection]$ResultPropertyValueCollection
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
        $collection = @()
    }
    process {
        foreach ($value in $ResultPropertyValueCollection) {
            switch ($value.GetType()) {
                 'System.Byte[]' {
                    $collection += ConvertTo-DecStringRepresentation -ByteArray $value
                 }
                'long' {
                    $collection += ConvertTo-DateTime $value
                }
                Default {
                    $collection += $value
                }
            }
        }
    }
    end {
        if ($collection.Count -eq 1) {
            $collection[0] | Write-Output
        } else {
            $collection | Write-Output -NoEnumerate
        }
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
