function New-BootstrapColumn {
    <#
        .SYNOPSIS
            Wraps HTML elements in a Bootstrap column of the specified width
        .DESCRIPTION
            Creates a Bootstrap container which contains a row which contains a column of the specified width
        .OUTPUTS
            A string wih the code for the Bootstrap container
        .EXAMPLE
            New-BootstrapColumn -Html '<h1>Heading</h1>'

            This example returns the following string:
            '<div class="container"><div class="row justify-content-md-center"><div class="col col-lg-12"><h1>Heading</h1></div></div></div>'
    #>
    [OutputType([System.String])]
    [CmdletBinding()]
    param(
        #The HTML element to apply the Bootstrap column to
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [System.String[]]$Html,

        [Parameter(
            Position = 1
        )]
        [Int]$Width = 12
    )
    begin {
        $NewHtml = "<div class=`"container`"><div class=`"row justify-content-md-center`">"
    }
    process {
        ForEach ($OldHtml in $Html) {
            $NewHtml = "$NewHtml<div class=`"col col-lg-$Width`">$OldHtml</div>"
        }
    }
    end {
        $NewHtml = "$NewHtml</div></div>"
        return $NewHtml
    }
}
