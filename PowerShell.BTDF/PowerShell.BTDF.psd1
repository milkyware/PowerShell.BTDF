@{
    RootModule = 'PowerShell.BTDF'
    ModuleVersion = '1.0'
    # CompatiblePSEditions = @()
    GUID = 'dbc92e85-05da-43a3-8005-e6b41b24322c'
    Author = 'MilkyWare'
    CompanyName = 'MilkyWare'
    Copyright = '(c) 2017 MilkyWare. All rights reserved.'
    Description = 'Functions to deploy BizTalk apps packaged using BTDF'
    RequiredAssemblies = @("Microsoft.BizTalk.ExplorerOM"
        "Microsoft.BizTalk.Operations"
        "SSOSettingsFileReader")
    FunctionsToExport = @("Clean-BTDFEnvironment",
        "Deploy-BTDFApplication",
        "Install-BTDFApplication",
        "Read-SSO",
        "Read-SSOInt32",
        "Read-SSOString")
    # List of all files packaged with this module
    # FileList = @()
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('ALM',
                'BizTalk',
                'BizTalk Deployment Framework',
                'BTDF',
                'Deploy',
                'MultiServer')
            # A URL to the main website for this project.
            # ProjectUri = ''
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''
}