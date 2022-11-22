
function ConvertTo-SimpleProperty {
    <#
    .SYNOPSIS
        Convert a (possibly complex) property of a DirectoryEntry to a simple one.
    .DESCRIPTION
        `ConvertTo-SimpleProperty` Determines the type of property and then converts it to a string value
    #>
    [CmdletBinding()]
    param (
        # The DirectoryEntry object
        [Parameter(
        )]
        [Object]$InputObject,

        # The name of the property to convert
        [Parameter(
        )]
        [string]$Property,

        # The "reference hashtable" to add the property to after conversion
        [Parameter(
        )]
        [hashtable]$PropertyDictionary = @{},

        # Add a prefix to the key added to PropertyDictionary
        [Parameter(
        )]
        [string]$Prefix
    )

    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"

    }
    process {
        <#------------------------------------------------------------------
          The item we actually want to process is $InputObject.$Property
          so ensure they are both defined
        ------------------------------------------------------------------#>
        if (([string]::IsNullorEmpty($Property)) -or ($null -eq $InputObject)) {
            throw 'An InputObject and Property are required'
        } else {
            $Value = $InputObject.$Property
        }

        <#------------------------------------------------------------------
          The main logic of this function depends on knowing the Type
          of object.  Before we enter the switch statement, ensure we
          have a useable type to work with.

          Ensure the GetType method exists to avoid this error:
          The following exception occurred while retrieving
          member "GetType": "Not implemented"
        ------------------------------------------------------------------#>
        [string]$Type = $null
        if ($null -ne $Value) {
            if (Get-Member -InputObject $Value -Name GetType) {
                [string]$Type = $Value.GetType().FullName
            } else {
                # The only scenario we've encountered where the GetType() method does not exist is DirectoryEntry
                # objects from the WinNT provider
                # Force the type to 'System.DirectoryServices.DirectoryEntry'
                [string]$Type = 'System.DirectoryServices.DirectoryEntry'
            }
        }
        Write-Debug "  Converting $Prefix$Property of type $Type to a Simple property"
        <#------------------------------------------------------------------
          This is essentially a FactoryMethod pattern
          determine the type and based on that, call out to a specific
          converter to do the work
        ------------------------------------------------------------------#>
        switch ($Type) {
            'System.DirectoryServices.DirectoryEntry' {
                $PropertyDictionary["$Prefix$Property"] = ConvertFrom-DirectoryEntry -DirectoryEntry $Value
            }
            'System.DirectoryServices.PropertyCollection' {
                $ThisObject = @{}
                <#------------------------------------------------------------------
                 There is an edge case where
                 - A DirectoryEntry has a SchemaEntry property
                   - which is a DirectoryEntry
                     - which has a Properties property
                       - which is a System.DirectoryServices.PropertyCollection
                but throws the following error to the Success stream (not the error
                stream, so it is hard to catch):
                format-default : The entry properties cannot be enumerated. Consider
                using the entry schema to determine what properties are available.
                + CategoryInfo : NotSpecified: (:) [format-default],
                            NotSupportedException
                + FullyQualifiedErrorId : System.NotSupportedException,
                            Microsoft.PowerShell.Commands.FormatDefaultCommand


                To catch the error we will redirect the Success Stream to the Error
                Stream.
                Then if the Exception type matches, we will use the `continue`
                 keyword to break out of the current switch statement
                ------------------------------------------------------------------#>

                try {
                    $Value 1>2
                } catch [System.NotSupportedException] {
                    continue
                }

                foreach ($ThisProperty in $Value.Keys) {
                    $ThisPropertyString = ConvertFrom-PropertyValueCollectionToString -PropertyValueCollection $Value[$ThisProperty]
                    $ThisObject[$ThisProperty] = $ThisPropertyString
                    <#------------------------------------------------------------------
                     Because we are adding the values to the "top-level" dictionary,
                     it makes more sense to leave this here rather than move it to a
                     separate function
                    ------------------------------------------------------------------#>
                    $PropertyDictionary["$Prefix$ThisProperty"] = $ThisPropertyString

                }
                $PropertyDictionary["$Prefix$Property"] = [PSCustomObject]$ThisObject
                continue
            }
            'System.DirectoryServices.PropertyValueCollection' {
                $PropertyDictionary["$Prefix$Property"] = ConvertFrom-PropertyValueCollectionToString -PropertyValueCollection $Value
                continue
            }
            'System.Object[]' {
                $PropertyDictionary["$Prefix$Property"] = $Value
                continue
            }
            'System.Object' {
                $PropertyDictionary["$Prefix$Property"] = $Value
                continue
            }
            'System.DirectoryServices.SearchResult' {
                $PropertyDictionary["$Prefix$Property"] = ConvertFrom-SearchResult -SearchResult $Value
                continue
            }
            'System.DirectoryServices.ResultPropertyCollection' {
                $ThisObject = @{}
                Write-Debug '  Converting each value in Collection'
                foreach ($ThisProperty in $Value.Keys) {
                    Write-Debug "   $ThisProperty"
                    if ([string]::IsNullorEmpty($Value[$ThisProperty])) {
                        $ThisPropertyString = ''
                    } else {
                        Write-Debug "    - Getting String from $($Value[$ThisProperty])"
                        $ThisPropertyString = ConvertFrom-ResultPropertyValueCollectionToString -ResultPropertyValueCollection $Value[$ThisProperty]
                    }
                    $ThisObject[$ThisProperty] = $ThisPropertyString

                    $PropertyDictionary["$Prefix$ThisProperty"] = $ThisPropertyString

                }
                $PropertyDictionary["$Prefix$Property"] = [PSCustomObject]$ThisObject
                continue
            }
            'System.DirectoryServices.ResultPropertyValueCollection' {
                $PropertyDictionary["$Prefix$Property"] = ConvertFrom-ResultPropertyValueCollectionToString -ResultPropertyValueCollection $Value
                continue
            }
            'System.Management.Automation.PSCustomObject' {
                $PropertyDictionary["$Prefix$Property"] = $Value
                continue
            }
            'System.Collections.Hashtable' {
                $PropertyDictionary["$Prefix$Property"] = [PSCustomObject]$Value
                continue
            }
            'System.Byte[]' {
                $PropertyDictionary["$Prefix$Property"] = ConvertTo-DecStringRepresentation -ByteArray $Value
            }
            default {
                <#
                By default we will just let most types get cast as a string
                Includes but not limited to:
                    $null (because GetType is not implemented)
                    System.String
                    System.Boolean
            #>
                $PropertyDictionary["$Prefix$Property"] = "$Value"
                continue
            }
        }

    }
    end {
        $PropertyDictionary
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
