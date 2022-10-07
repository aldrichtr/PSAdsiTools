
function ConvertFrom-DirectoryEntry {
    <#
    .SYNOPSIS
        Convert a DirectoryEntry to a PSCustomObject
    .DESCRIPTION
        Recursively convert every property into a string, or a PSCustomObject (whose properties are all strings, or
        more PSCustomObjects) This obfuscates the troublesome PropertyCollection and PropertyValueCollection and
        Hashtable aspects of working with ADSI
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0,
            ValueFromPipeline
        )]
        [System.DirectoryServices.DirectoryEntry[]]$DirectoryEntry
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        foreach ($entry in $DirectoryEntry) {
            <#------------------------------------------------------------------
              1.  Get all properties from the DirectoryEntry
            ------------------------------------------------------------------#>

            # This will pull out all of the properties, because they aren't all available
            # unless we do this
            Write-Debug "  Extracting properties of this $($entry.GetType())"
            $entry_properties = $entry | Select-Object -Property *

            # Now just the properties that we can read
            Write-Debug "   Getting member properties"
            $entry_note_properties = $entry_properties |
                Get-Member -MemberType Property, CodeProperty, ScriptProperty, NoteProperty

            $directory_entry = @{
                PSTypeName = 'ADSI.DirectoryEntry'
            }

            foreach ($prop in $entry_note_properties) {
                <# Conversion functions need:
                   - the original object (InputObject)
                   - the property we are converting (Property)
                   - the hashtable we are adding it to. (PropertyDictionary)
                     - this is functionally equivelant to passing the hash in "by reference".  The conversion
                       functions take it as input, add to it, and then return the updated object
                #>
                Write-Debug "$('.' * 80)`n   Converting $($prop.Name)"
                $options = @{
                    InputObject        = $entry_properties
                    Property           = $prop.Name
                    PropertyDictionary = $directory_entry

                }
                $directory_entry = ConvertTo-SimpleProperty @options
            }

            [PSCustomObject]$directory_entry | Write-Output
        }
    }
    end {
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
