Function ConvertTo-HtmlReport {
    [CmdletBinding()]
    param(
        # LogonDetails object
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object]
        $LogonDetails
    )
    New-HTML -TitleText "Account Report for $($LogonDetails.Results.Name.Display) : $($LogonDetails.Date) " -FilePath "$PSScriptRoot\Report.html" {
        New-HTMLSection -CanCollapse  -HeaderText 'Account' {

            New-HTMLTable -DataTable $LogonDetails.Results.Name
        }
    }
}
