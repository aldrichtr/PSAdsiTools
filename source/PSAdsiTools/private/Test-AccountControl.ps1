Function Test-AccountControl {
    <#
    .SYNOPSIS
        Test the Account Control Flag
    .DESCRIPTION
        This is intended to be a private function that public functions like
        Test-CloExempt can use.
    .EXAMPLE
        Test-AccountControl $user.Properties.useraccountcontrol SMARTCARD_REQUIRED
    .EXAMPLE
        $user | Test-AccountControl SMARTCARD_REQUIRED
    #>
    [CmdletBinding()]
    param(
        # UserAccountControl property
        [Parameter(
            Position = 0,
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [Int32]$UserAccountControl,

        # AdAcountControl flag to test
        [Parameter(
            Mandatory
        )]
        [ADAccountControl]$Flag
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        ([AdAccountControl]$UserAccountControl).HasFlag($Flag)
    }
    end {
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
