
function ConvertFrom-AdsiPath {
    [CmdletBinding()]
    param(
        # The AdsPath (LDAP) path of the object
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [Alias('adspath')]
        [string[]]$Path
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
    process {
        Write-Debug "  Converting path $Path"
        if ($Path -match '^\[?(?<type>\w+)\]?:\/\/') {
            $type = $Matches[1]
            Write-Debug "   Found type $type"
            $Path = $Path -replace "\[?$type\]?:\/\/", ''
            Write-Debug "   Removing type Path is now $Path"
        } else {
            Write-Debug "  No type found setting type to 'TEXT'"
            $type = 'TEXT'
        }

        #! Negative Lookbehind regex
        #! match ',' but not '\,'
        $fields = [System.Collections.ArrayList]::new($Path -split '(?<!\\),')

        $name = $fields[0]

        $fields.Remove($name)
        $name = $name -replace '^\w+=', ''
        Write-Debug "  Found $($fields.Count) fields.`n $($fields -join '\n')"

        $common_name = @($fields | Where-Object { $_ -imatch '^cn=' }) -join '/'
        Write-Debug "    Common Names = $common_name"
        $common_name = $common_name -ireplace 'cn=', ''
        Write-Debug "    Removing cn= : $common_name"

        $org_unit = @($fields | Where-Object { $_ -imatch '^ou=' }) -join '/'
        Write-Debug "    Org Units = $org_unit"
        $org_unit = $org_unit -ireplace 'ou=', ''
        Write-Debug "    Removing ou= : $org_unit"

        $dom_comp = @($fields | Where-Object { $_ -imatch '^dc=' } ) -join '.'
        Write-Debug "    Domain Components = $dom_comp"
        $dom_comp = $dom_comp -ireplace 'dc=', ''
        Write-Debug "    Removing dc= : $dom_comp"

        $obj_path = [PSCustomObject]@{
            PSTypeName = 'Adsi.Path'
            Name = $name
            Type = $type
            CommonName = $common_name
            OrganizationalUnit = $org_unit
            DomainComponent = $dom_comp
        }

        $obj_path | Write-Output
}
end {
    Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
}
}
