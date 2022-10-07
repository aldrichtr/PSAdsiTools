$import_options = @{
    Path        = $PSScriptRoot
    Filter      = "*.ps1"
    Recurse     = $true
    ErrorAction = "Stop"
}

try {
    Get-ChildItem @import_options | ForEach-Object {
        . $_.FullName
    }
}
catch {
    throw "Error occurred during the dot sourcing of module .ps1 files: $_"
}
