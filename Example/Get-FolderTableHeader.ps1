function Get-FolderTableHeader {
    param ($LevelsOfSubfolders)

    switch ($LevelsOfSubfolders ) {
        0 {
            'Includes the target folder only (option to report on subfolders was declined)'
        }
        -1 {
            'Includes the target folder and all subfolders with unique permissions'
        }
        default {
            "Includes the target folder and $LevelsOfSubfolders levels of subfolders with unique permissions"
        }
    }
}
