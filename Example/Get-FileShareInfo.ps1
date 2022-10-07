function Get-FileShareInfo {
    # Get the corresponding local file path for DFS folder targets (which are UNC paths)
    param (

        [Parameter(ValueFromPipeline)]
        [psobject[]]$ServerAndShare

    )

    process {

        # State 6 notes that the DFS path is online and active
        #$DFS = $DfsNetClientInfo #| Where-Object -FilterScript { $_.State -eq 6 }

        ForEach ($DFS in $ServerAndShare) {

            $SessionParams = @{
                #Credential = $Credentials
                ComputerName  = $DFS.ServerName
                SessionOption = New-CimSessionOption -Protocol Dcom
            }
            $CimParams = @{
                CimSession = New-CimSession @SessionParams
                ClassName  = 'Win32_Share'
            }

            $ShareName = ($DFS.ShareName -split '\\')[0]
            $ShareLocalPath = Get-CimInstance @CimParams |
            Where-Object Name -EQ $ShareName
            $LocalPath = $DFS.ShareName -replace [regex]::Escape("$ShareName\"), $ShareLocalPath.Path

            $DFS | Add-Member -PassThru -NotePropertyMembers @{
                #DfsPath = $DFS.DfsPath
                FolderTarget = "$($DFS.ServerName)\$($DFS.ShareName)\$($DFS.DfsPath -replace [regex]::Escape($DFS.ShareName))"
                #DfsState = $DFS.State
                #ServerName = $DFS.ServerName
                #ShareName = $DFS.ShareName
                LocalPath    = $LocalPath
            }

        }

    }

}
