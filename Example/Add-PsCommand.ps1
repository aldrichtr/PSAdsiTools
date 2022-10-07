function Add-PsCommand {

    <#
    .Synopsis
        Add a command to a [System.Management.Automation.PowerShell] instance
    .Description
        Used by Invoke-Thread
        Uses AddScript() or AddStatement() and AddCommand() depending on the command
    .EXAMPLE
        [powershell]::Create() | Add-PsCommand -Command 'Write-Output'

        Add a command by sending a Cmdlet name to the -Command parameter
    #>

    param(

        # Powershell interface to add the Command to
        [Parameter(ValueFromPipeline = $true)]
        [powershell[]]$PowershellInterface,

        <#
        Command to add to the Powershell interface
        This can be a scriptblock object, or a string that specifies a:
            Alias
            Function (the name of the function)
            ExternalScript (the path to the .ps1 file)
            All, Application, Cmdlet, Configuration, Filter, or Script
        #>
        [Parameter(Position = 0)]
        $Command,

        # Output from Get-PsCommandInfo
        # Optional, to improve performance if it will be re-used for multiple calls of Add-PsCommand
        [pscustomobject]$CommandInfo,

        # Add Commands rather than their definitions
        [switch]$Force,

        # Will be sent to the Type parameter of Write-LogMsg in the PsLogMessage module
        [string]$DebugOutputStream = 'Silent',

        # Hostname to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$TodaysHostname = (HOSTNAME.EXE),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Hashtable of log messages for Write-LogMsg (can be thread-safe if a synchronized hashtable is provided)
        [hashtable]$LogMsgCache = $Global:LogMessages

    )

    begin {

        $LogParams = @{
            LogMsgCache  = $LogMsgCache
            ThisHostname = $TodaysHostname
            Type         = $DebugOutputStream
            WhoAmI       = $WhoAmI
        }

        $CommandInfoParams = @{
            DebugOutputStream = $DebugOutputStream
            TodaysHostname    = $TodaysHostname
            WhoAmI            = $WhoAmI
            LogMsgCache       = $LogMsgCache
        }

        if ($CommandInfo -eq $null) {
            $CommandInfo = Get-PsCommandInfo @CommandInfoParams -Command $Command
        }

    }
    process {

        ForEach ($ThisPowershell in $PowershellInterface) {

            switch ($CommandInfo.CommandType) {

                'Alias' {
                    # Resolve the alias to its command and start from the beginning with that command.
                    $CommandInfo = Get-PsCommandInfo @CommandInfoParams -Command $CommandInfo.CommandInfo.Definition
                    $null = Add-PsCommand @CommandInfoParams -Command $CommandInfo.CommandInfo.Definition -CommandInfo $CommandInfo -PowershellInterface $ThisPowerShell
                }
                'Function' {

                    if ($Force) {
                        Write-LogMsg @LogParams -Text " # Adding command '$Command' of type '$($CommandInfo.CommandType)' (treating it as a command instead of a Function because -Force was used)"
                        # If the type is All, Application, Cmdlet, Configuration, Filter, or Script then run the command as-is
                        Write-LogMsg @LogParams -Text "`$PowershellInterface.AddStatement().AddCommand('$Command')"
                        $null = $ThisPowershell.AddStatement().AddCommand($Command)
                    } else {
                        # Add the definitions of the function
                        # BUG: Look at the definition of Get-Member for example, it is not in a ScriptModule so its definition is not PowerShell code
                        [string]$ThisFunction = "function $($CommandInfo.CommandInfo.Name) {`r`n$($CommandInfo.CommandInfo.Definition)`r`n}"
                        Write-LogMsg @LogParams -Text " # Adding Script (the Definition of a Function, `$CommandInfo.CommandInfo.Definition not expanded below for brevity)"
                        ##Write-LogMsg @LogParams -Text "`$PowershellInterface.AddScript('function $($CommandInfo.CommandInfo.Name) { `$CommandInfo.CommandInfo.Definition }')"
                        Write-LogMsg @LogParams -Text "`$PowershellInterface.AddScript('$ThisFunction')"
                        $null = $ThisPowershell.AddScript($ThisFunction)
                    }
                }
                'ExternalScript' {
                    Write-LogMsg @LogParams -Text " # Adding Script (the ScriptBlock of an ExternalScript, `$CommandInfo.ScriptBlock not expanded below for brevity)"
                    ##Write-LogMsg @LogParams -Text "`$PowershellInterface.AddScript(`"`$(`$CommandInfo.ScriptBlock)`") # "
                    Write-LogMsg @LogParams -Text "`$PowershellInterface.AddScript('$($CommandInfo.ScriptBlock)')"
                    $null = $ThisPowershell.AddScript($CommandInfo.ScriptBlock)
                }
                'ScriptBlock' {
                    Write-LogMsg @LogParams -Text " # Adding Script (a ScriptBlock, not expanded below for brevity)"
                    ##Write-LogMsg @LogParams -Text "`$PowershellInterface.AddScript(`"`$Command`")
                    Write-LogMsg @LogParams -Text "`$PowershellInterface.AddScript('$Command')"
                    $null = $ThisPowershell.AddScript($Command)
                }
                default {
                    Write-LogMsg @LogParams -Text " # Adding command '$Command' of type '$($CommandInfo.CommandType)'"
                    # If the type is All, Application, Cmdlet, Configuration, Filter, or Script then run the command as-is
                    Write-LogMsg @LogParams -Text "`$PowershellInterface.AddStatement().AddCommand('$Command')"
                    $null = $ThisPowershell.AddStatement().AddCommand($Command)
                }

            }
        }
    }
}
