
function ConvertFrom-SearchResult {
    <#
    .SYNOPSIS
        Convert a SearchResult to a PSCustomObject
    .DESCRIPTION
        Recursively convert every property into a string, or a PSCustomObject (whose properties are all strings, or
        more PSCustomObjects) This obfuscates the troublesome ResultPropertyCollection and
        ResultPropertyValueCollection and Hashtable aspects of working with ADSI searches
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0,
            ValueFromPipeline
        )]
        [System.DirectoryServices.SearchResult[]]$SearchResult
    )

    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        foreach ($result in $SearchResult) {
            <#------------------------------------------------------------------
              1.  Get all properties from the DirectoryEntry
            ------------------------------------------------------------------#>

            # This will pull out all of the properties, because they aren't all available
            # unless we do this
            Write-Debug "  Extracting properties of this $($result.GetType())"

            $result_properties = $result |
            Select-Object -Property *

            $result_note_properties = $result_properties |
            Get-Member -MemberType Property, CodeProperty, ScriptProperty, NoteProperty

            $search_result = @{
                PSTypeName = 'ADSI.SearchResult'
            }

            Write-Debug "  Converting all the keys in the Properties table"
            foreach ($key in $result.properties.Keys) {
                Write-Debug "   - ${key}:"
                $options = @{
                    InputObject = $result.properties
                    Property  = $key
                    PropertyDictionary = $search_result
                }
                $search_result = ConvertTo-SimpleProperty @options
                Write-Debug "     - now SearchResult contains $($search_result.Keys -join ', ')"
            }

<#            # We will allow any existing properties to override members of the ResultPropertyCollection
            foreach ($prop in $result_note_properties) {
                $options = @{
                    InputObject = $result_properties
                    Property  = $prop.Name
                    PropertyDictionary = $search_result
                }
                $search_result = ConvertTo-SimpleProperty @options
            }
#>
            if ($null -ne $search_result.useraccountcontrol) {
                $uac = $search_result.useraccountcontrol
                $search_result['AccountDisabled'] = $uac | Test-AccountDisabled
                $search_result['AccountLocked'] = $uac | Test-AccountLockout
                $search_result['PasswordExpired'] = $uac | Test-PasswordExpired
                $search_result['PasswordNotRequired'] = $uac | Test-PasswordNotRequired
                $search_result['PasswordNeverExpires'] = $uac | Test-PasswordNeverExpires
            }
            [PSCustomObject]$search_result
        }
    }
}
