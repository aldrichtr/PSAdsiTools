function Get-HtmlBody {
    param (
        $FolderList,
        $HtmlFolderPermissions,
        $ReportFooter,
        $HtmlFileList,
        $LogDir,
        $HtmlExclusions
    )
    $StringBuilder = [System.Text.StringBuilder]::new()
    $null = $StringBuilder.Append((New-HtmlHeading "Folders with Permissions in This Report" -Level 3))
    $null = $StringBuilder.Append($FolderList)
    $null = $StringBuilder.Append((New-HtmlHeading "Accounts Included in Those Permissions" -Level 3))
    $HtmlFolderPermissions |
    ForEach-Object {
        $null = $StringBuilder.Append($_)
    }
    if ($HtmlExclusions) {
        $null = $StringBuilder.Append((New-HtmlHeading "Exclusions from This Report" -Level 3))
        $null = $StringBuilder.Append($HtmlExclusions)
    }
    $null = $StringBuilder.Append((New-HtmlHeading "Files Generated" -Level 3))
    $null = $StringBuilder.Append($HtmlFileList)
    $null = $StringBuilder.Append($ReportFooter)
    $StringBuilder.ToString()
}
