
function Convert-SecurityIdentifier {
    <#
    .SYNOPSIS
        Convert a Security Identifier (SID) from a string to a Byte Array or from a Byte array to a string
    #>
    [CmdletBinding(
        DefaultParameterSetName = 'toString'
    )]
    param(
        # The SID data (objectSid) stored in AD
        [Parameter(
            ParameterSetName = 'toString',
            Position = 0,
            ValueFromPipeline
        )]
        [System.Byte[]]$Byte,

        # The string representation of the SID
        [Parameter(
            ParameterSetName = 'toByte',
            Position = 0,
            ValueFromPipeline
        )]
        [string]$String
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        try{

            if ($PSBoundParameters.ContainsKey('Byte')) {
                Write-Debug '  Converting ByteArray to Security Identifier String'
                $sid = [System.Security.Principal.SecurityIdentifier]::new($Byte, 0)
                $sid.ToString() | Write-Output
            }
            elseif ($PSBoundParameters.ContainsKey('String')) {
                $sid = New-Object System.Security.Principal.SecurityIdentifier ($String)
                $c = New-Object 'byte[]' $sid.BinaryLength
                $sid.GetBinaryForm($c, 0) | Write-Output
            }
            else {
                throw "No Security Identifier was given to convert"
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    end {
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
