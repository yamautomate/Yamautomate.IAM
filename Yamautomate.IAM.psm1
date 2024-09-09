Function New-YcAdUser {
    param (
        [Parameter(Mandatory=$true)] [string]$firstname,
        [Parameter(Mandatory=$true)] [string]$lastname,
        [Parameter(Mandatory=$true)] [string]$location,
        [Parameter(Mandatory=$true)] [string]$department,
        [Parameter(Mandatory=$true)] [string]$team,
        [Parameter(Mandatory=$true)] [string]$phoneNumber,
        [Parameter(Mandatory=$true)] [string]$jobTitle,
        [Parameter(Mandatory=$true)] [string]$manager,
        [Parameter(Mandatory=$false)][string]$PathToConfig = "$env:USERPROFILE\.yc\YcIAMSampleConfig.json",
        [Parameter(Mandatory=$false)][string]$EventLogSource,
        [Parameter(Mandatory=$false)][bool]$LogEnabled = $true
    )
    #Check for required modules 
    try {
        $requiredModules = @("ActiveDirectory")
        Get-YcRequiredModules -moduleNames $requiredModules -ErrorAction Stop
    }
    catch {
        throw ("Could not import needed modules. Aborting. Error Details: "+$_.Exception.Message)
    }
    
    #Import config and map values to variables
    try {
        $config = Get-Content -raw -Path $PathToConfig | ConvertFrom-Json -ErrorAction Stop

        $locationForLookup = "Location-"+$location
        $Street = $config.$locationForLookup.Street
        $City = $config.$locationForLookup.City
        $ZIPCode = $config.$locationForLookup.ZIPCode
        $Country = $config.$locationForLookup.Country
        $CountryPhone = $config.$locationForLookup.Phone
        $TopLevelDomain = $config.$locationForLookup.TopLevelDomain
        $OU = $config.ActiveDirectory.OU
        $rawDomainName = $config.ActiveDirectory.rawDomainName
        $SwapDomainsForEmailAlias = $config.ActiveDirectory.SecondarySMTPAlias
        $SetOfficeIpPhone = $config.ActiveDirectory.SetOfficeIpPhone
        $strUserEnabled = $config.ActiveDirectory.NewUserEnabled
        $strChangePasswordAtLogon = $config.ActiveDirectory.ChangePasswordAtLogon

        #Initialize Booleans with default values
        $PathToLogFile = "$env:USERPROFILE\.yc"
        [bool]$ChangePasswordAtLogon = $false
        [bool]$UserEnabled = $false
        [bool]$LogToEventLog = $false
        [bool]$LogToLogFile = $false
        [bool]$LogToOutput = $false
        [bool]$LogToHost = $true
    }
    catch {
        throw ("Could not grab contents of ConfigFile. Aborting. Error Details: "+$_.Exception.Message)
    }

    #Grab values from config if Log is enabled
    If ($LogEnabled) 
    {
         $strLogToEventLog = $config.EventLogging.LogToEventlog
         $strLogToLogFile = $config.EventLogging.LogToLogFile
         $strLogToOutput = $config.EventLogging.LogToOutput
         $strLogToHost = $config.EventLogging.LogToHost
         $strPathToLogFile = $config.EventLogging.PathToLogFile

         if ($strPathToLogFile)
         {
            $PathToLogFile = $strPathToLogFile
         }
         else {
            $PathToLogFile = "$env:USERPROFILE\.yc"
         }
 
         If ($strLogToEventLog -eq "true")
         {
             [bool]$LogToEventLog = $true
         }
 
         if ($strLogToLogFile -eq "true")
         {
             [bool]$LogToLogFile = $true
         }
 
         if ($strLogToOutput -eq "true")
         {
             [bool]$LogToOutput = $true
         }
 
         if ($strLogToHost -eq "true")
         {
             [bool]$LogToHost = $true
         }
    }

    #Make sure there is a Event Source we can post among
    If (!($EventLogSource))
    {
        $EventLogSource = $config.EventLogging.NameOfEventSource
        If (!($EventLogSource) -or $EventLogSource -eq " ")
        {
            $EventLogSource = "Yc.IAM-New-AdUser"
        }
    }

    # Construct the user’s full name and username with the location TLD
    $displayName = "$firstname $lastname"
    $samAccountName = "$firstname.$lastname"
    $primaryEmail = "$firstname.$lastname@$rawDomainname$TopLevelDomain"

    Write-YcLogMessage ("Primary E-Mail Address for new User is: "+$primaryEmail) -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile

    # Create the Active Directory user
    try {
            #Create Random Password
            $InitialPw = New-YcRandomPassword -length 14

            If ($StrUserEnabled -eq "true")
            {
                [bool]$UserEnabled = $true
            }

            If ($strChangePasswordAtLogon -eq "true")
            {
                [bool]$ChangePasswordAtLogon = $true
            }

            New-ADUser `
            -GivenName $firstname `
            -Surname $lastname `
            -Name $displayName `
            -SamAccountName $samAccountName `
            -UserPrincipalName $primaryEmail `
            -Path $OU `
            -Division $team `
            -OfficePhone $phoneNumber `
            -Title $jobTitle `
            -Department $department `
            -DisplayName $displayName `
            -StreetAddress $Street `
            -City $City `
            -PostalCode $ZIPCode `
            -Country $Country `
            -Enabled $UserEnabled `
            -AccountPassword (ConvertTo-SecureString $InitialPw -AsPlainText -Force) `
            -ChangePasswordAtLogon $ChangePasswordAtLogon `
            -EmailAddress $primaryEmail

            Write-YcLogMessage ("Successfully created new AD User: "+$samAccountName) -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile
    }
    catch {
        Write-YcLogMessage ("Could not create AD User. Aborting. Error Details: "+$_.Exception.Message) Error -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile
        throw ("Could not create AD User. Aborting. Error Details: "+$_.Exception.Message)
    }

    # Add organization tab information
    try {
        Set-ADUser -Identity $samAccountName -Title $jobTitle -Department $department -Manager $manager
        Write-YcLogMessage ("Successfully set organizational info on new AD User: "+$samAccountName) -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile
    }
    catch {
        Write-YcLogMessage ("Could not set organization tab info on AD User. Aborting. Error Details: "+$_.Exception.Message) -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile
        throw ("Could not set organization tab info  on AD User. Aborting. Error Details: "+$_.Exception.Message)
    }

    #Do we need to add second SMTP Alias?
    if ($SwapDomainsForEmailAlias -eq "true") {
        Write-YcLogMessage ("SecondarySMTPAlias is enabled.") -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile
        $secondaryEmailTLD = $config.ActiveDirectory.MakeSecondary

        if ($secondaryEmailTLD -eq $TopLevelDomain)
        {
            $secondaryEmailTLD = $config.ActiveDirectory.SwapWith
        }

        $secondaryEmail = "$firstname.$lastname@$rawDomainname$secondaryEmailTLD"
        Write-YcLogMessage ("SecondarySMTPAlias is: "+$secondaryEmail) -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost

        $proxyAddresses = @("SMTP:$primaryEmail", "smtp:$secondaryEmail")

        # Add proxy addresses to the user
        try {
            Set-ADUser -Identity $samAccountName -Add @{proxyAddresses=$proxyAddresses}
            Write-YcLogMessage ("Successfully set proxy addresses on new AD User: "+$samAccountName) -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile
        }
        catch {
            Write-YcLogMessage ("Could not set proxy address on AD User. Aborting. Error Details: "+$_.Exception.Message) Error -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile
            throw ("Could not set proxy address on AD User. Aborting. Error Details: "+$_.Exception.Message)
        }
    }

    #Wp we need to set country-specific main phone number
    if ($SetOfficeIpPhone -eq "true")
    {
        try {
            Set-ADUser -Identity $samAccountName -Replace @{ipPhone=$CountryPhone}
            Write-YcLogMessage ("Successfully set Ip Phone on: "+$samAccountName) -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile
        }
        catch {
            Write-YcLogMessage ("Could not set country-specific main phone number on AD User. Aborting. Error Details: "+$_.Exception.Message) Error -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile
            throw ("Could not set country-specific main phone number on AD User. Aborting. Error Details: "+$_.Exception.Message)
        }
    }

    return $InitialPw
}
Function New-YcTeamsPhoneNumberAssignment {
    param (
        [Parameter(Mandatory=$true)] [string]$phoneNumber,
        [Parameter(Mandatory=$true)] [string]$firstname,
        [Parameter(Mandatory=$true)] [string]$lastname,
        [Parameter(Mandatory=$false)][string]$PathToConfig = "$env:USERPROFILE\.yc\NewAdUser-Config.json",
        [Parameter(Mandatory=$false)][string]$EventLogSource,
        [Parameter(Mandatory=$false)][bool]$LogEnabled = $true
    )

    #Check for required modules 
    try {
        $requiredModules = @("MicIAMrosoftTeams")
        Get-YcRequiredModules -moduleNames $requiredModules -ErrorAction Stop
    }
    catch {
        throw ("Could not import needed modules. Aborting. Error Details: "+$_.Exception.Message)
    }

    #Import config and map values to variables
    try {
        $config = Get-Content -raw -Path $PathToConfig | ConvertFrom-Json -ErrorAction Stop
        $locationForLookup = "Location-"+$location
        $TopLevelDomain = $config.$locationForLookup.TopLevelDomain
        $CertificateThumbprint = $config.TeamsPhone.CertificateThumbprint
        $tenantId = $config.TeamsPhone.tenantId
        $appId = $config.TeamsPhone.AzureAppRegistrationClientId
        $rawDomainName = $config.ActiveDirectory.rawDomainName
        $policyname = $config.TeamsPhone.PolicyName 

        $identity = $firstname+"."+$lastname+"@"+$rawDomainName+$TopLevelDomain 

    }
    catch {
        throw ("Could not grab contents of ConfigFile. Aborting. Error Details: "+$_.Exception.Message)
    }

    #Initialize Logging vars
    [bool]$LogToEventLog = $false
    [bool]$LogToLogFile = $false
    [bool]$LogToOutput = $false
    [bool]$LogToHost = $true


    #Grab values from config if Log is enabled
    If ($LogEnabled) 
    {
            $strLogToEventLog = $config.EventLogging.LogToEventlog
            $strLogToLogFile = $config.EventLogging.LogToLogFile
            $strLogToOutput = $config.EventLogging.LogToOutput
            $strLogToHost = $config.EventLogging.LogToHost
    
            If ($strLogToEventLog -eq "true")
            {
                [bool]$LogToEventLog = $true
            }
    
            if ($strLogToLogFile -eq "true")
            {
                [bool]$LogToLogFile = $true
            }
    
            if ($strLogToOutput -eq "true")
            {
                [bool]$LogToOutput = $true
            }
    
            if ($strLogToHost -eq "true")
            {
                [bool]$LogToHost = $true
            }
    }

    #Make sure there is a Event Source we can post among
    If (!($EventLogSource))
    {
        $EventLogSource = $config.EventLogging.NameOfEventSource
        If (!($EventLogSource) -or $EventLogSource -eq " ")
        {
            $EventLogSource = "Yc.IAM-New-AdUser"
        }
    }

    try {
        Connect-MicrosoftTeams -TenantId $tenantId -Certificate $CertificateThumbprint -ApplicationId $appId
        Write-YcLogMessage ("Successfully connected to Teams Online using Certificate.") -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost
    }
    catch {
        Write-YcLogMessage ("Could not connect to Teams. Aborting. Error Details: "+$_.Exception.Message) Error -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $false
        throw ("Could not connect to Teams. Aborting. Error Details: "+$_.Exception.Message)
    }

    try {
        Write-YcLogMessage ("Trying to assign policy: "+$policyname+" to user: "+$identity) -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost

        Set-CsPhoneNumberAssignment -Identity $identity -PhoneNumber $phoneNumber -PhoneNumberType DirectRouting
        Grant-CsOnlineVoiceRoutingPolicy -Identity $identity -PolicyName $policyname 
        Grant-CsTeamsUpgradePolicy -Identity $identity -PolicyName UpgradeToTeams

        Write-YcLogMessage ("Successfully assigned policy: "+$policyname+" to user: "+$identity) -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost
    }
    catch {
        Write-YcLogMessage ("Could not connect to assign phoneNumber. Aborting. Error Details: "+$_.Exception.Message) Error -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $false
        throw ("Could not connect to assign phoneNumber. Aborting. Error Details: "+$_.Exception.Message)
    }
    finally {
        Disconnect-MicrosoftTeams 
    }
}

function New-YcIAMSampleConfig {
    <#
    .SYNOPSIS
    The New-YcIAMSampleConfig function creates a sample configuration file at a specified path.

    .DESCRIPTION
    The New-YcIAMSampleConfig function takes an optional path parameter to specify where to create a sample configuration file. 
    It defines a sample configuration as a PowerShell hashtable, converts it to a JSON string, and writes it to the specified path. 
    The configuration includes sections for event logging, Azure Key Vault, Azure General, API settings, solution settings, and notifications.

    .PARAMETER ConfigPath
    The ConfigPath parameter is an optional string specifying the directory where the configuration file will be created. If not specified, 
    it defaults to `$env:USERPROFILE\.yc\YcIAMSampleConfig.json`.

    .INPUTS
    The function does not accept any pipeline input.

    .OUTPUTS
    The function writes a sample configuration file to the specified path and logs a success message.

    .EXAMPLE
    The following example shows how to create a sample configuration file:

    PS> New-YcIAMSampleConfig -ConfigPath "C:\Configs"
    # Creates the file at C:\Configs\.yc\YcIAMSampleConfig.json
    #>

    param (
        [Parameter(Mandatory=$false, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath = "$env:USERPROFILE"
    )

    # Define the full path where the config file will be created
    $FullPath = Join-Path -Path $ConfigPath -ChildPath ".yc\YcIAMSampleConfig.json"

    # Create the configuration template
    $configTemplate = [YcIAMConfigTemplate]::new()

    # Convert the hashtable to a JSON string
    $jsonConfig = $configTemplate.ToJson()

    # Check if the directory exists, and create it if not
    If (!(Test-Path (Split-Path $FullPath -Parent))) {
        New-Item -Path (Split-Path $FullPath -Parent) -ItemType Directory -Force
    }

    # Write the JSON string to the specified file path
    Set-Content -Path $FullPath -Value $jsonConfig -Force

    # Output a success message
    $OutputMessage = "New-YcIAMSampleConfig @ "+(Get-Date)+": Sample configuration created successfully at "+$FullPath
    Write-Host $OutputMessage -ForegroundColor Green
}

class YcIAMConfigTemplate {
   
    # Constructor
    YcIAMConfigTemplate() {}

    # Method to convert the class to a hashtable
    [hashtable] ToHashtable() {
        return [ordered]@{
            "EventLogging" = @(
                @{
                    "LogToEventlog" = "true"
                    "LogToLogFile" = "true"
                    "LogToOutput" = "true"
                    "LogToHost" = "true"
                    "NameOfEventSource" = "YcIAM"
                    "PathToLogFile" = "C:\Temp\"
                }
            )
            "AzureGeneral" = @(
                @{
                    "tenantId" = "********-****-****-****-************"
                }
            )
            "ActiveDirectory" = @(
                @{
                    "OU" = ""
                    "rawDomainName" = "domainname"
                    "SecondarySMTPAlias" = "true"
                    "MakeSecondary" = ".com"
                    "SwapWith" = ".ch"
                    "SetOfficeIpPhone" = "true"
                    "NewUserEnabled" = "true"
                    "ChangePasswordAtLogon" = "true"
                }
            )
            "TeamsPhone" = @(
                @{
                    "AzureAppRegistrationClientId" = "********-****-****-****-************"
                    "CertificateThumbprint" = "***************************"
                    "PolicyName" = "********"
                }
            )
            "Location-CH" = @(
                @{
                    "Street" = "******"
                    "City" = "*****"
                    "ZIPCode" = "*****"
                    "Country" = "**"
                    "Phone" = "+**********"
                    "TopLevelDomain" = ".**"
                }
            )
            "Location-DE" = @(
                @{
                    "Street" = "******"
                    "City" = "*****"
                    "ZIPCode" = "*****"
                    "Country" = "**"
                    "Phone" = "+**********"
                    "TopLevelDomain" = ".**"
                }
            )
            "Location-US" = @(
                @{
                    "Street" = "******"
                    "City" = "*****"
                    "ZIPCode" = "*****"
                    "Country" = "**"
                    "Phone" = "+**********"
                    "TopLevelDomain" = ".**"
                }
            )
            "Notifications" = @(
                @{
                    "SendReportEmailTo" = "*****@domain.com"
                    "SendReportEmailFrom" = "*****@domain.com"
                    "AzureAppRegistrationClientId" = "*******-****-****-****-************"
                    "AzureAppRegistrationClientSecretCredentialName" = "********"
                }
            )
        }
    }

    # Method to convert the class to a JSON string
    [string] ToJson() {
        $config = $this.ToHashtable()
        return $config | ConvertTo-Json -Depth 4
    }
}
