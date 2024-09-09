# Yamautomate.IAM
Creates an AD User and assigns Teams Phone number.
Based on: [```Yamautomate.Core```](https://github.com/yamautomate/Yamautomate.Core)

## Limitations and assumptions
- Single forrest Domains only
- Assumes Hybrid Identities

## Prereqs
- Required Modules:
  - ```Yamautomate.Core``` installed
  - ```MicrosoftTeams``` installed
  - ```ActiveDirectory``` is installed
- Network line of sight to a Domain Controller
- Account Operator role in AD or higher
- Certificate that permits Access to an Azure App Registration is installed
  - AppRegistration needs role ```Teams Administrator```
  - AppRegistration needs permissions ```Organization.Read.All``` 

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
    
 
## Generating a new sample config
```powershell
New-YcIAMSampleConfig
Sample configuration created successfully at C:\Users\%USERNAME%\.yc\YcIAMSampleConfig.json
```
This creates a new config value with placeholder values for you to edit in the directory ```C:\Users\%USERNAME%\.yc\```

## Creating a new User
```powershell
Import-Module "Yamautomate.IAM"
New-YcAdUser -firstname "Hampisa" -lastname "Tester71" -location "CH" -department "Technologies" -team "QE" -phoneNumber "+41791901245" -jobTitle "Tester" -manager "yanik.maurer" -PathToConfig "C:\temp\IdGov-NewAdUser-Config.json" -LogEnabled $true
```

## Assigning a Teams Phone number to a User
```powershell
Import-Module "Yamautomate.IAM"
New-YcAdUser -firstname "Hampisa" -lastname "Tester71" -location "CH" -department "Technologies" -team "QE" -phoneNumber "+41791901245" -jobTitle "Tester" -manager "yanik.maurer" -PathToConfig "C:\temp\IdGov-NewAdUser-Config.json" -LogEnabled $true
```
