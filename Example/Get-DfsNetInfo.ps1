Function Get-DfsNetInfo {
    # Wrapper for the NetDfsGetInfo([string]) method in the lmdfs.h header in NetApi32.dll for Distributed File Systems
    [CmdletBinding()]
    Param (

        [PSCredential]$Credentials,

        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({
                Test-Path -LiteralPath $_ -PathType Container
            })]
        [String[]]$FolderPath

    )

    Process {

        foreach ($ThisFolderPath in $FolderPath) {

            $Split = $ThisFolderPath -split '\\'
            $ServerOrDomain = $Split[0]
            $DfsNamespace = $Split[1]
            $DfsLink = ""
            $Remainder = ""

            <#
            # Use the NetDfsGetInfo method instead as it does not filter out disabled folder targets
            # But it does not work
            #>
            #[NetApi32Dll]::NetDfsGetClientInfo($ThisFolderPath)

            #[NetApi32Dll]::NetDfsEnum($ThisFolderPath)

            [NetApi32Dll]::NetDfsGetInfo($ThisFolderPath)

        }

    }

}
