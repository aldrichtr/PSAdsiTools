
Function ConvertTo-StringSID {
    <#
    .SYNOPSIS
        Convert an objectSid field (Byte Array) to a string
    .EXAMPLE
        $user_sid = $account.objectSid | ConvertTo-StringSID

    #>
    [CmdletBinding()]
    param(
        # The SID data (objectSid) stored in AD
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromRemainingArguments = $true
        )]
        [System.Byte[]]
        $Byte
    )
    try {
        $sid = [System.Security.Principal.SecurityIdentifier]::new($Byte,0)
    }
    catch {
        throw "An error occured converting objectSid to string`n$_"
    }
    $sid.ToString()
}
