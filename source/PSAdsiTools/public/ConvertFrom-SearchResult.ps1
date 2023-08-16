
using namespace System.DirectoryServices

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
        [SearchResult[]]$SearchResult
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
            Write-Debug "  Extracting properties of this $($result.GetType().FullName)"

            $resultProperties = $result |
                Select-Object -Property *

            $resultNoteProperties = $resultProperties |
                Get-Member -MemberType Property, CodeProperty, ScriptProperty, NoteProperty

            $resultObject = @{
                PSTypeName = 'ADSI.SearchResult'
            }

            Write-Debug '  Converting all the keys in the Properties table'
            foreach ($key in $result.properties.Keys) {
                Write-Debug "   - ${key}:"
                $options = @{
                    InputObject        = $result.properties
                    Property           = $key
                    PropertyDictionary = $resultObject
                }
                $resultObject = ConvertTo-SimpleProperty @options
                Write-Debug "     - now SearchResult contains $($resultObject.Keys -join ', ')"
            }

            # We will allow any existing properties to override members of the ResultPropertyCollection
            foreach ($prop in $resultNoteProperties) {
                if (-not($prop.Name -like 'properties')) {
                    $options = @{
                        InputObject        = $resultProperties
                        Property           = $prop.Name
                        PropertyDictionary = $resultObject
                    }
                    $resultObject = ConvertTo-SimpleProperty @options
                }
            }

            if ($null -ne $resultObject.useraccountcontrol) {
                $uac = $resultObject.useraccountcontrol
                $resultObject['AccountDisabled']      = $uac | Test-AccountDisabled
                $resultObject['AccountLocked']        = $uac | Test-AccountLockout
                $resultObject['PasswordExpired']      = $uac | Test-PasswordExpired
                $resultObject['PasswordNotRequired']  = $uac | Test-PasswordNotRequired
                $resultObject['PasswordNeverExpires'] = $uac | Test-PasswordNeverExpires
            }
            [PSCustomObject]$resultObject
        }
    }
}
