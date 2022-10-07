function Find-ServerNameInPath {
    <#
        .SYNOPSIS
        Parse a literal path to find its server
        .DESCRIPTION
        Currently only supports local file paths or UNC paths
        .INPUTS
        None. Pipeline input is not accepted.
        .OUTPUTS
        [System.String] representing the name of the server that was extracted from the path
        .EXAMPLE
        Find-ServerNameInPath -LiteralPath 'C:\Test'

        Return the hostname of the local computer because a local filepath was used
        .EXAMPLE
        Find-ServerNameInPath -LiteralPath '\\server123\Test\'

        Return server123 because a UNC path for a folder shared on server123 was used
    #>
    [OutputType([System.String])]
    param (
        [string]$LiteralPath
    )
    if ($LiteralPath -match '[A-Za-z]\:\\' -or $null -eq $LiteralPath -or '' -eq $LiteralPath) {
        # For local file paths, the "server" is the local computer. Assume the same for null paths.
        hostname
    } else {
        # Otherwise it must be a UNC path, so the server is the first non-empty string between backwhacks (\)
        $ThisServer = $LiteralPath -split '\\' |
        Where-Object -FilterScript { $_ -ne '' } |
        Select-Object -First 1

        $ThisServer -replace '\?', (hostname)
    }
}
