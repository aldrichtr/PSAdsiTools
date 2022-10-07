function New-HtmlAnchor{
    <#
        .SYNOPSIS
            Build a new HTML anchor
        .DESCRIPTION
            Inserts the specified HTML element into an HTML anchor with the specified name
        .OUTPUTS
            Outputs the heading as a string
        .EXAMPLE
            New-HtmlAnchor -Element "<h1>SampleHeader</h1>" -Name "AnchorToSampleHeader"
    #>
    [CmdletBinding()]
    param(

        #The text of the heading
        [Parameter(
            Position=0,
            ValueFromPipeline=$true,
            Mandatory=$true
        )]
        [String[]]$Element,

        #The heading level to generate (New-HtmlHeading can create h1, h2, h3, h4, h5, or h6 tags)
        [Parameter(Mandatory)]
        [String]$Name

    )
    begin{}
    process{
        Write-Output "<h$Level>$Text</h$Level>"
    }
    end{}
}
