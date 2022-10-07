Function ConvertTo-BootstrapListGroup {
    <#
        .SYNOPSIS
            Upgrade a boring HTML list to a fancy Bootstrap list group
        .DESCRIPTION
            Applies the Bootstrap 'list-group' CSS class to an HTML list
            Applies the Bootstrap 'list-group-item' CSS class to each list item
        .OUTPUTS
            A string wih the code for the Bootstrap list
        .EXAMPLE
            1,2,3 |
            ConvertTo-HtmlList |
            ConvertTo-BootstrapListGroup

            This example returns the following string:
            '<ul class ="list-group"><li class ="list-group-item>1</li><li class ="list-group-item>2</li><li class ="list-group-item>3</li></ul>'
    #>
    [OutputType([System.String])]
    [CmdletBinding()]
    param(
        #The HTML table to apply the Bootstrap striped table CSS class to
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [System.String[]]$HtmlList
    )
    process {
        ForEach ($List in $HtmlList) {

            $List -replace
            '<ul>', '<ul class="list-group">' -replace
            '<ol>', '<ol class="list-group">' -replace
            '<li>', '<li class ="list-group-item">'

        }
    }
}
