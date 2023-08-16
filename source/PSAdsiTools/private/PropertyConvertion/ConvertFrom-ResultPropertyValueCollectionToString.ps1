
using namespace System.DirectoryServices

function ConvertFrom-ResultPropertyValueCollectionToString {
    <#
    .SYNOPSIS
        Convert a ResultPropertyValueCollection to a string
    .DESCRIPTION
    .   For each property in a DirectoryEntry, convert its corresponding PropertyValueCollection to a string
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0,
            ValueFromPipeline
        )]
        [ResultPropertyValueCollection]$ResultPropertyValueCollection
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
            Write-Output -NoEnumerate -InputObject $collection
        }
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
