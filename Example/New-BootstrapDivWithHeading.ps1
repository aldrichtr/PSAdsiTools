function New-BootstrapDivWithHeading {
    param (
        [string]$HeadingText,
        [uint16]$HeadingLevel = 5,
        [string]$Content,
        [hashtable]$HeadingsAndContent
    )

    if ($PSBoundParameters.ContainsKey('HeadingsAndContent')) {
        [string]$Text = ForEach ($Key in $HeadingsAndContent.Keys) {
            (New-HtmlHeading $Key -Level $HeadingLevel) +
            $HeadingsAndContent[$Key]
        }
    } else {
        $Text = (New-HtmlHeading $HeadingText -Level $HeadingLevel) +
        $Content
    }

    New-BootstrapDiv -Text $Text
}
