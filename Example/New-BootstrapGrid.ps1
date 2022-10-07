function New-BootstrapGrid {
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
    [CmdletBinding()]
    param(
        #The HTML element to apply the Bootstrap column to
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [System.String[]]$Html,

        [string]$Justify = 'Center'
    )
    begin{
        $String = @()
        [decimal]$ExactWidth = 12 / ($Html | Measure-Object).Count
        [int]$Width = [Math]::Floor($ExactWidth)
        $String += "<div class=`"container`"><div class=`"row justify-content-md-$($Justify.ToLower())`">"
    }
    process{
        ForEach ($OldHtml in $Html) {
            $String += "<div class=`"col col-lg-$Width`">$OldHtml</div>"
        }
    }
    end{
        $String += "</div></div>"
        $String -join ''
    }

}
