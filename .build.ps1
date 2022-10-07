param(
    [Parameter()]
    [string]$Source = (
        property Source "$BuildRoot\source"
    ),

    [Parameter()]
    [string]$Staging = (
        property Staging "$BuildRoot\stage"
    ),

    [Parameter()]
    [string]$Tests = (
        property Tests "$BuildRoot\tests"
    ),

    [Parameter()]
    [string]$Artifact = (
        property Artifact "$BuildRoot\out"
    ),

    [Parameter()]
    [string]$Docs = (
        property Docs "$BuildRoot\docs"
    )

)


Enter-Build {
    $BuildInfo = property BuildInfo @{
        ProjectName = (Get-Item $BuildRoot).BaseName
        Modules = @{}
    }

    $options = @{
        Path = $Source
        Recurse = $true
        Filter  = "*.psd1"
    }
    foreach ($mod in (Get-ChildItem @options)) {
        try {
            $BuildInfo.Modules[$mod.BaseName] = @{
                Name = $mod.BaseName
                Info = Import-Psd $mod
            }
            foreach ($param in @(
                'Source',
                'Staging',
                'Tests',
                'Artifact',
                'Docs'
            )) {
                $BuildInfo.Modules[$mod.BaseName][$param] = Join-Path (property $param) $mod.BaseName
            }
        }
        catch {
            throw "$mod found but could not get module info`n$_"
        }
        Write-Build DarkBlue "  Loaded configuration"
#        Write-Build DarkBlue " $($BuildInfo | ConvertTo-Psd -Indent 2 | Out-String)"
    }
}

task Reload {
    foreach ($key in $BuildInfo.Modules.Keys) {
        $config = $BuildInfo.Modules[$key]
        Write-Build DarkBlue "  Removing $($config.Name) Module"
        Remove-Module $config.Name -Force -ErrorAction SilentlyContinue
        Write-Build DarkBlue "  Importing $($config.Source) Module"
        Import-Module $config.Source -Force
    }
}

task Build { Write-Build DarkGray "Build task"}
