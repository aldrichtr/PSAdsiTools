
function Test-WorkstationTrustAccountType {
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
        $UserAccountControl | Test-AccountControl -Flag WORKSTATION_TRUST_ACCOUNT
    }
    end {
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
