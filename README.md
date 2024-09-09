# Yamautomate.IAM
Creates an AD User and assigns Teams Phone number. 
Based on: [```Yamautomate.Core```](https://github.com/yamautomate/Yamautomate.Core)

## Prereqs
- Required Modules:
  - ```Yamautomate.Core``` installed
  - ```MicrosoftTeams``` installed
  - ```ActiveDirectory``` is installed
- Config.json (Filled out with needed parameters)
- Network line of sight to a Domain Controller
- Account Operator role in AD or higher
- Certificate that permits Access to AppRegistration is installed
  - AppReg needs role ```Teams Administrator```
  - AppReg needs permissions ```Orgnization.Read.All``` 

## Creating a new User
```powershell
#Creating AD User
Import-Module "Yamautomate.IAM"
New-YcAdUser -firstname "Hampisa" -lastname "Tester71" -location "US" -department "IT" -team "Applications" -phoneNumber "+41XXXXX" -jobTitle "Tester" -manager "yanik.maurer" -PathToConfig "C:\temp\IdGov-NewAdUser-Config.json" -LogEnabled $true
```

## Generating a new sample config
```powershell
New-YcIAMSampleConfig
New-YcIAMSampleConfig @ 09/09/2024 12:44:11: Sample configuration created successfully at C:\Users\%USERNAME%\.yc\YcIAMSampleConfig.js
on
```
This creates a new config value with placeholder values for you to edit in the directory ```C:\Users\%USERNAME%\.yc\```

