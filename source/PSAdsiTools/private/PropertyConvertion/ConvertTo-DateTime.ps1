
Function ConvertTo-DateTime {
    <#
    .SYNOPSIS
        Take whatever the weird System.__ComObject date is and make it useful
    #>
    [CmdletBinding()]
    param(
        # The date field from an ADSI query
        [parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [Object]$Field
    )

    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
        <#! If an expiration date was never set on an object, it has the value
          of 9223372036854775807
        #>
        [int64]$NEVER_EXPIRES = 9223372036854775807
    }
    process {
        if ($Field -eq $NEVER_EXPIRES) {
            $date = 'Never'
        } else {
            try {
                $d = [adsi]'LDAP://'
            } catch {
                throw "couldn't connect to directory for conversion functions"
            }
            Write-Debug "Field is $($Field.GetType())`n$($Field | Format-Custom | Out-String)"
            if ($Field.Count -gt 0) {
                Write-Debug "  Field is an array of $($Field.Count)"
            }

            if ($null -ne $Field[0]) {
                $value = $Field[0]
            } elseif ($null -ne $Field) {
                $value = $Field
            }

            if ($value -is [System.Int64]) {
                try {
                    $date = [datetime]::FromFileTime([Int64]::Parse($value))
                } catch {
                    throw "couldn't extract datetime from field '$value' `n$_"
                }
            } else {
                try {
                    $int64val = $d.ConvertLargeIntegerToInt64($value)
                    if ($null -ne $int64val) {
                        $date = [datetime]::FromFileTime($int64val)
                    }
                } catch {
                    throw 'could not convert value to a date'
                }
            }
        }
    }
    end {
        $date
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }

}
