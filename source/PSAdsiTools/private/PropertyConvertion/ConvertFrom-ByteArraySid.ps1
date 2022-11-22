
Function ConvertFrom-ByteArraySid {
    <#
    .SYNOPSIS
        Convert an objectSid field (Byte Array) to a string
    .EXAMPLE
        $user_sid = $account.objectSid | ConvertFrom-ByteArraySid

    #>
    [CmdletBinding()]
    param(
        # The SID data (objectSid) stored in AD
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromRemainingArguments
        )]
        [System.Byte[]]$Byte
    )
    try {
        Write-Debug "  Converting ByteArray to Security Identifier"
        $sid = [System.Security.Principal.SecurityIdentifier]::new($Byte,0)
        $sid.ToString() | Write-Output
    }
    catch {
        throw "An error occured converting objectSid to string`n$_"
    }
}
