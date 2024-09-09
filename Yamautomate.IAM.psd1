@{
    ModuleVersion = '1.0.2.3'
    GUID = 'bf93a78b-e608-4ceb-98ea-e96da66ef864'
    Author = 'Yanik Maurer'
    PowerShellVersion = '5.1'
    RootModule = 'Yamautomate.IAM.psm1'
    FunctionsToExport = @('New-YcAdUser', 'New-YcTeamsPhoneNumberAssignment', 'New-YcIAMSampleConfig', 'New-YcIAMWelcomeLetterFromTemplate')
    Description = 'Creates AD Users and assign Teams Phone Numbers.'
    RequiredModules = @(
        @{
            ModuleName = 'Yamautomate.Core'
            ModuleVersion = '1.0.6.5'
        }
    )
    RequiredAssemblies = @(
    "lib\DocumentFormat.OpenXml.dll",
    "lib\DocumentFormat.OpenXml.Framework.dll"
    )
}
