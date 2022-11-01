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
    ),

    [Parameter()]
    [switch]$CodeCov = (
        property CodeCov $false
    ),

    [Parameter()]
    [switch]$SkipDependencyCheck = (
        property SkipDependencyCheck $false
    )

)

begin {
    Import-Module BuildTool -ErrorAction SilentlyContinue

    foreach ($file in Get-Command *.ib.tasks -Module BuildTool) { . $file }
    <#------------------------------------------------------------------
      Load any customizations from the .build directory
    ------------------------------------------------------------------#>
    # a task file defines a function used to create build task types
    Get-ChildItem -Path '.build' -Filter '*.task.ps1' | ForEach-Object {
        . $_.FullName
    }
    Get-ChildItem -Path '.build' -Filter '*.build.ps1' | ForEach-Object {
        . $_.FullName
    }
    <#------------------------------------------------------------------
      This alias allows you to call another task from within another task
      without having to re-invoke invoke-build.  That way all of the state
      and properties is preserved.
      Example
      if ($config.Foo -eq 1) {call update_foo}
     #! it is definitely messing with the internals a bit which is not
     #! recommended
    ------------------------------------------------------------------#>
    Set-Alias call *Task

}
process {
    Enter-Build {
        $param_paths = @(
            'Source',
            'Staging',
            'Tests',
            'Artifact',
            'Docs'
        )

        $param_sources = @(
            'enum',
            'classes',
            'private',
            'public'
        )

        $BuildInfo = property BuildInfo @{
            ProjectName = (Get-Item $BuildRoot).BaseName
            Modules     = @{}
        }

        <#------------------------------------------------------------------
          Find the manifests in the source directory
        ------------------------------------------------------------------#>
        $options = @{
            Path    = $Source
            Recurse = $true
            Filter  = '*.psd1'
        }
        $mod_count = 0

        foreach ($mod in (Get-ChildItem @options)) {
            $info = Import-Psd $mod
            if (($info.Keys -notcontains 'PrivateData') -and
               ($info.Keys -notcontains 'GUID')) {
                continue
            }
            try {
                $mod_count++
                $mod_info = @{}
                $mod_info['Index'] = $mod_count
                $mod_info['Name'] = $mod.BaseName
                $mod_info['Version'] = $info.ModuleVersion
                $mod_info['NestedModules'] = $info.NestedModules
                $mod_info['Data'] = $info.PrivateData.PSData
                $mod_info['Paths'] = $param_paths
                $mod_info['SourceDirectories'] = $param_sources
                $mod_info['Manifest'] = $mod.Name

                foreach ($param in $param_paths) {
                    $mod_info[$param] = Join-Path (property $param) $mod.BaseName
                }

                if ($info.PrivateData.PSData.ContainsKey('Namespace')) {
                    $mod_info['Namespace'] = $info.PrivateData.PSData.Namespace
                }

                if (-not([string]::IsNullOrEmpty($info.RootModule))) {
                    $mod_info['Module'] = $info.RootModule
                    if (($info.RootModule -replace '\.psm1') -match $mod.BaseName) {
                        $match_root = $true
                    } else {
                        $match_root = $false
                    }
                }

                if ($info.NestedModules.Count -gt 0) {
                    $has_nested = $true
                } else {
                    $has_nested = $false
                }

                if ($match_root) {
                    if ($has_nested) {
                        $mod_info['Type'] = 'RootWithNested'
                    } else {
                        $mod_info['Type'] = 'RootOnly'
                    }
                } else {
                    if ($has_nested) {
                        $mod_info['Type'] = 'NestedOnly'
                    } else {
                        $mod_info['Type'] = 'Unknown'
                    }
                }

                $BuildInfo.Modules[$mod.BaseName] = $mod_info
            } catch {
                throw "$mod found but could not get module info`n$_"
            }
        }
        Remove-Variable param_paths, param_sources, mod_info, match_root, has_nested, mod_count
    }
    Set-BuildHeader {
        param($Path)
        if ($task.InvocationInfo.ScriptName -like '*workflow.build.ps1') {
            Write-Build Cyan "$('-' * 80)"
            Write-Build Cyan "Begin Task: $($Task.Name.ToUpper() -replace '_', ' ')" (Get-BuildSynopsis $Task)
        }
    }
    Set-BuildFooter {
        param($Path)
        if ($task.InvocationInfo.ScriptName -like '*workflow.build.ps1') {
            Write-Build Cyan "$('-' * 80)"
        }
    }
}
end {
}
