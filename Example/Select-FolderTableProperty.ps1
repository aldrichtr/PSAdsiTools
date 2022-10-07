function Select-FolderTableProperty {
    param (
        $InputObject
    )
    $InputObject | Select-Object -Property @{
        Label      = 'Folder'
        Expression = { $_.Name }
    },
    @{
        Label      = 'Inheritance'
        Expression = { $_.Group.FolderInheritanceEnabled | Select-Object -First 1 }
    }
}
