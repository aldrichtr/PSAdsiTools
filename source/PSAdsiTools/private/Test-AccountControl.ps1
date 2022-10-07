Function Test-AccountControl {
    <#
    .SYNOPSIS
        Test the Account Control Flag
    .DESCRIPTION
        This is intended to be a private function that public functions like
        Test-CloExempt can use.
    .EXAMPLE
        Test-AccountControl SMARTCARD_REQUIRED $user.Properties.useraccountcontrol
    #>
    [CmdletBinding()]
    param(
        # AdAcountControl flag to test
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [ADAccountControl]$Flag,

        # UserAccountControl property
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 1
        )]
        [Object]$Control
    )

    [AdAccountControl]$Account = $Control

    $Account.HasFlag($Flag)
}
