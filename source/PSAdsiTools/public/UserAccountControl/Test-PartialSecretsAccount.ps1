
function Test-PartialSecretsAccount {
    [CmdletBinding()]
    param(
        # UserAccountControl field
        [Parameter(
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [int32]$UserAccountControl
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        $UserAccountControl | Test-AccountControl -Flag PARTIAL_SECRETS_ACCOUNT
    }
    end {
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
