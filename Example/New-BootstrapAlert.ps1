function New-BootstrapAlert {
    <#
        .SYNOPSIS
            Creates a new HTML div that uses the Bootstrap alert class
        .DESCRIPTION
            Creates a new HTML div that uses the Bootstrap alert class
        .OUTPUTS
            A string wih the HTML code for the div
        .EXAMPLE
            New-BootstrapAlert -Text 'blah'

            This example returns the following string:
            '<div class="alert alert-info"><strong>Info!</strong> blah</div>'
    #>
    [CmdletBinding()]
    param(
        #The HTML element to apply the Bootstrap column to
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [string[]]$Text,

        [Parameter(
            Position = 1
        )]
        [string]$Class = 'Info'
    )
    begin{}
    process{
        ForEach ($String in $Text) {
            #"<div class=`"alert alert-$($Class.ToLower())`"><strong>$Class!</strong> $String</div>"
            "<div class=`"alert alert-$($Class.ToLower())`">$String</div>"
        }
    }
    end{}

}
