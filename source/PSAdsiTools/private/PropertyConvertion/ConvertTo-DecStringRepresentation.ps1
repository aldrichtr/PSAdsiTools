function ConvertTo-DecStringRepresentation {
    <#
        .SYNOPSIS
        Convert a byte array to a string representation of its decimal format
        .DESCRIPTION
        Uses the custom format operator -f to format each byte as a string decimal representation
        .INPUTS
        [System.Byte[]]$ByteArray
        .OUTPUTS
        [System.String] Array of strings representing the byte array's decimal values
        .EXAMPLE
        ConvertTo-DecStringRepresentation -ByteArray $Bytes

        Convert the binary SID $Bytes to a decimal string representation
    #>
    [OutputType([System.String])]
    param (
        # Byte array. Often the binary format of an objectSid or LoginHours
        [byte[]]$ByteArray
    )

    $ByteArray
    | ForEach-Object { '{0}' -f $_ }
}
