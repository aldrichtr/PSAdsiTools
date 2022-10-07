
function Get-ADComputer {
    <#
    .SYNOPSIS
        Get the specified computers from AD
    #>
    [CmdletBinding()]
    param(
        # Optionally provide the Computer 'name' to search
        [Parameter(
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [string[]]$ComputerName = '*'
    )
    begin {}
    process {
        if ($null -ne $PSItem) {
            try {
                $computer = Search-ADSI -Property 'name' -Value $PSItem -Class 'computer'
            }
            catch {
                throw ("An error occured getting the computer {0}`t{1}`n{2}" -f $Path, $Error.GetType(), $Error.ToString())
            }
        }
    }
    end {}
}
