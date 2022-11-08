@{
    RootModule        = 'PSAdsiTools.psm1'
    ModuleVersion     = '0.1.6.0'
    GUID              = 'bda38d23-247c-4241-9806-4bcc2423aaa7'
    Author            = 'Timothy Aldrich'
    CompanyName       = 'aldrichtr'
    Copyright         = '(c) Timothy R. Aldrich All rights reserved.'
    Description       = 'ActiveDirectory administration using ADSI vice RSAT'
    FunctionsToExport = '*'
    VariablesToExport = '*'
    AliasesToExport   = '*'
    FileList          = @(
        'PSAdsiTools.psd1'
        'PSAdsiTools.psm1'
    )
    PrivateData       = @{
        PSData = @{
            Tags         = @('ActiveDirectory', 'ADSI')
            LicenseUri   = 'https://github.com/aldrichtr/PSAdsiTools/blob/main/LICENSE.md'
            ProjectUri   = 'https://github.com/aldrichtr/PSAdsiTools'
            ReleaseNotes = ''
        }
    }
}
