using namespace System.Diagnostics.CodeAnalysis

[SuppressMessage('PSAvoidUsingWriteHost', '')]
param(
)

$sourceModules = Get-ChildItem -Path .\source -Directory

Write-Host -Object 'Load Source Module Script' -ForegroundColor Blue

foreach ($module in $sourceModules) {
    Write-Host -Object "Unloading any $($module.Name) modules  " -ForegroundColor DarkGray -NoNewline
    Remove-Module $module.Name -ErrorAction SilentlyContinue
    Write-Host -Object 'Done' -ForegroundColor DarkGreen

    Write-Host -Object 'Loading  module from the source directory  ' -ForegroundColor DarkGray -NoNewline
    Import-Module $module.FullName -Force
    Write-Host -Object 'Done' -ForegroundColor DarkGreen

    $loaded = Get-Module $module.Name
    Write-Host -Object "$($loaded.Name) version $($loaded.Version) loaded from $($loaded.Path)"
}
