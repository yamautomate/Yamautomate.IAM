# Yamautomate.IAM
Creates an AD User and assigns Teams Phone number.
Based on: [```Yamautomate.Core```](https://github.com/yamautomate/Yamautomate.Core)

## Limitations and assumptions
- Assumes username notation of "firstname.lastname"
- No logic if two users with same name exist

## Prereqs

### For ```New-YcIAMAdUser```
- PowerShell Module ```Yamautomate.Core``` installed
- PowerShell Module ```ActiveDirectory``` is installed
- Network line of sight to a Domain Controller
- Account Operator role in AD or higher
### For ```New-YcIAMTeamsPhoneNumberAssignment```
- PowerShell Module ```MicrosoftTeams``` installed
- Certificate that permits Access to an Azure App Registration is installed (for non interactive authentication)
  - AppRegistration needs role ```Teams Administrator```
  - AppRegistration needs permissions ```Organization.Read.All```
### For ```New-YcIAMWelcomeLetterFromTemplate```
-  [```DocumentFormat.OpenXml```](https://www.nuget.org/packages/DocumentFormat.OpenXml/) .DLL in  ```lib\``` folder of installation path
-  [```DocumentFormat.OpenXml.Framework```](https://www.nuget.org/packages/DocumentFormat.OpenXml.Framework) .DLL in  ```lib\``` folder of installation path

The required Version depends your OS and targeted .NET Framework. Prebundled comes ```v3.1.0``` 
## How it works
```Yamautomate.IAM``` uses a configuration file to define the beheaviour of how the AD User will be created. When the function is executed, it retrieves the settings from the config file and creates the AD User accordingly.

## What you can configure in the config
- For ActiveDirectory
  - The ```OU``` the users shall be created in
  - The ```rawDomainName``` (without .TLD)
  - ```SecondarySMTPAlias``` defines if you want to add an SMTP Alias for another .TLD (additionally, add .com as ```proxyAddress```)
  - ```makeSecondary```defines the one .TLD you want to add as secondary SMPT Alias
  - ```SwapWith``` defines the .TLD to add as second SMTP Alias if the primary email already matches ```makeSecondary```
  - ```SetOfficeIpPhone``` defines if the location-specific ```Phone``` shall be written to the ```IpPhone``` property
  - ```NewUserEnabled``` defines if the AD User is enabled upon creation
  - ```ChangePasswordAtLogon``` defines if the AD User needs to change password upon next login.
    
- Locations (ActiveDirectory related)
  - A location object in the .JSON config is used to define several locations and their properties
  - You can define as many locations as you want
  - The functions within ```Yamautomate.IAM``` use the suffix after ```Location-``` to lookup the values of the location the user is in.
  - When calling a function from ```Yamautomate.IAM``` specify the ```-Location``` parameter to match the defined location as per your config (If you have ```Location-DE``` specify ```-Location "DE"```)     
  - A location in the config defines the following:
    - ```Street```
    - ```City```
    - ```ZIPCode```
    - ```Country```
    - ```Phone```
    - ```TopLevelDomain```

 - TeamsPhone settings
   -  ```AzureAppRegistrationClientId``` defines the clientId to an Application Registration that has needed permissions as per requierments table above
   -  ```CertificateThumprint``` defines the thumbprint of the certificate used to connect to an Application Registration
   -  ```PolicyName``` defines the name of the voice policy that shall be assigned





# How-To
## Initial Setup
### For ```New-YcAdUser```
1. Connect to ```YOUR-SERVER``` via ```mstsc.exe```
2. Launch a PowerShell as Administrator (only needed for initial run to setup LogSources)
3. If the Core Module is not installed, install it via ```Install-Module Yamautomate.Core```
4. If the IAM Module is not installed, install it via ```Install-Module Yamautomate.IAM```
5. Import the module ```Yamautomate.IAM``` running ```Import-Module Yamautomate.IAM```
6. Grab the config or created a sample config in ```C:\Temp\```
7. Adjust the config values if needed


### For ```New-YcTeamsPhoneNumberAssignment```
1. Create an Azure Application Registration in Azure
    - Provide the role ```Teams.Administrator``` to the created Application Registration
    - Provide the API Permission ```Organization.Read.All``` to the created Application Registration
    - Note down the ```ClientID``` of the created Application Registration 
5. On ```YOUR-SERVER``` launch a PowerShell session as Administrator
   - Import the module ```Yamautomate.IAM``` running ```Import-Module Yamautomate.IAM```
   - Create a new self-signed certificate using ```New-YcSelfSignedCertForAppReg -subject "TeamsAdministration" -validForYears 2```
   - Install the certificate by double-clicking it
8. Back in the Azure Portal, upload the created certificate to the created App Registration in step 1.
9. Back on ```YOUR-SERVER``` In the config, adjust ```CertificateThumprint``` and ```AzureAppRegistrationClientId``` to match the created Certificate and AppId

## Create a new User
```powershell
New-YcIAMAdUser -firstname "Hans" -lastname "Test" -location "CH" -department "HR" -team "APAC" -phoneNumber "+41XXXXXX" -jobTitle "HR Manager" -manager "john.doe" -PathToConfig "C:\temp\YcIAMSampleConfig.json" -LogEnabled $true
```

## Assign a Teams Phone number to a User
```powershell
New-YcIAMTeamsPhoneNumberAssignment -firstname "Hans" -lastname "Test" -location "CH" -phoneNumber "+41XXXXXX" -PathToConfig "YcIAMSampleConfig.json" -LogEnabled $true
```

## Generate a new sample config
```powershell
New-YcIAMSampleConfig
```
This creates a new config value with placeholder values for you to edit in the directory ```C:\Users\%USERNAME%\.yc\```

## Generate a Welcome letter based on a template
This example assumes you have a ```Template.docx``` at ```C:\Temp\```. This document has the following keywords that need to be replaced:
- EMAIL (handled by default behaviour)
- INITPASS (handled by default behaviour)
- FIRSTNAME (handled by default behaviour)
- LASTNAME (handled by default behaviour)
- LOBAPP1USR (can be appended using ```-CustomPlaceholders``` parameter)
- LOBAPP1PWD (can be appended using ```-CustomPlaceholders``` parameter)

Lets create a Welcome letter for Hans Test, joining in Switzerland:
```powershell
New-YcIAMWelcomeLetterFromTemplate -templatePath C:\Temp\Template.docx -FirstName "Yanik" -LastName "Maurer" -InitialPassword "GTZZKJ" -location "CH" -PathToConfig "C:\temp\YcIAM-Config.json" -CustomPlaceholders @{ 'LOBAPP1USR' = 'YMAURER'; 'LOBAPP1PWD' = 'JaneDoe1873!' }
```
