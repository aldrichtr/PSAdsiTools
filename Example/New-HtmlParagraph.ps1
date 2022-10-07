function New-HtmlParagraph {
    <#
        .SYNOPSIS
            Build a new HTML heading
        .DESCRIPTION
            Inserts the specified text into an HTML heading of the specified level
        .OUTPUTS
            Outputs the heading as a string
        .EXAMPLE
            New-HtmlHeading -Text 'Example Heading'
    #>
    [CmdletBinding()]
    param(

        #The text of the heading
        [Parameter(
            Position=0,
            ValueFromPipeline=$True
        )]
        [String[]]$Text,

        #The heading level to generate (New-HtmlHeading can create h1, h2, h3, h4, h5, or h6 tags)
        [ValidateRange(1,6)]
        [Int16]$Level = 1

    )
    begin{}
    process{
        Write-Output "<h$Level>$Text</h$Level>"
    }
    end{}
}
