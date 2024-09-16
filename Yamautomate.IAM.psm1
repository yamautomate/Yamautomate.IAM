Function New-YcIAMAdUser {
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
    #Requires -Modules @{ModuleName='Yamautomate.Core';ModuleVersion='1.0.6.4'}
    <#
    #Requires -Modules @{ModuleName='ActiveDirectory';ModuleVersion='1.0.1.0'}
    #>
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

    Write-YcLogMessage ("---------------------------------------------------------------") -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile

    return $InitialPw
}
Function New-YcIAMTeamsPhoneNumberAssignment {
    param (
        [Parameter(Mandatory=$true)] [string]$phoneNumber,
        [Parameter(Mandatory=$true)] [string]$firstname,
        [Parameter(Mandatory=$true)] [string]$lastname,
        [Parameter(Mandatory=$true)] [string]$location,
        [Parameter(Mandatory=$false)][string]$PathToConfig = "$env:USERPROFILE\.yc\YcIAMSampleConfig.json",
        [Parameter(Mandatory=$false)][string]$EventLogSource,
        [Parameter(Mandatory=$false)][bool]$LogEnabled = $true
    )


    #Check for required modules 
    #Requires -Modules @{ModuleName='Yamautomate.Core';ModuleVersion='1.0.6.4'}
    <#
    #Requires -Modules @{ModuleName='MicrosoftTeams';ModuleVersion='6.5.0'}
    #>
    try {
        $requiredModules = @("MicrosoftTeams", "Yamautomate.Core")
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
        $tenantId = $config.AzureGeneral.tenantId
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

    try {
        Connect-MicrosoftTeams -TenantId $tenantId -Certificate $CertificateThumbprint -ApplicationId $appId
        Write-YcLogMessage ("Successfully connected to Teams Online using Certificate.") -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile
    }
    catch {
        Write-YcLogMessage ("Could not connect to Teams. Aborting. Error Details: "+$_.Exception.Message) Error -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $false -logDirectory $PathToLogFile
        throw ("Could not connect to Teams. Aborting. Error Details: "+$_.Exception.Message)
    }

    try {
        Write-YcLogMessage ("Trying to assign policy: "+$policyname+" to user: "+$identity) -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile

        Set-CsPhoneNumberAssignment -Identity $identity -PhoneNumber $phoneNumber -PhoneNumberType DirectRouting
        Grant-CsOnlineVoiceRoutingPolicy -Identity $identity -PolicyName $policyname 
        Grant-CsTeamsUpgradePolicy -Identity $identity -PolicyName UpgradeToTeams

        Write-YcLogMessage ("Successfully assigned policy: "+$policyname+" to user: "+$identity) -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile
    }
    catch {
        Write-YcLogMessage ("Could not connect to assign phoneNumber. Aborting. Error Details: "+$_.Exception.Message) Error -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $false -logDirectory $PathToLogFile
        throw ("Could not assign phoneNumber. Aborting. Error Details: "+$_.Exception.Message)
    }
    finally {
        Disconnect-MicrosoftTeams 
    }

    Write-YcLogMessage ("---------------------------------------------------------------") -source $EventLogSource -ToEventLog $LogToEventLog -ToLogFile $LogToLogFile -ToOutput $LogToOutput -WriteHost $LogToHost -logDirectory $PathToLogFile

}
function New-YcIAMWelcomeLetterFromTemplate {
    param (
        [Parameter(Mandatory=$true)] [string]$templatePath,        
        [Parameter(Mandatory=$true)] [string]$FirstName,           
        [Parameter(Mandatory=$true)] [string]$LastName,           
        [Parameter(Mandatory=$true)] [string]$InitialPassword,      
        [Parameter(Mandatory=$true)] [string]$location,
        [Parameter(Mandatory=$false)][string]$PathToConfig = "$env:USERPROFILE\.yc\YcIAMSampleConfig.json",
        [Parameter(Mandatory=$false)][hashtable]$CustomPlaceholders = @{}  # Custom placeholders from config or parameters
    )

    #Import config and map values to variables
    try {
        $config = Get-Content -raw -Path $PathToConfig | ConvertFrom-Json -ErrorAction Stop
        $locationForLookup = "Location-"+$location
        $TopLevelDomain = $config.$locationForLookup.TopLevelDomain
        $rawDomainName = $config.ActiveDirectory.rawDomainName
        $identity = ($firstname.ToLower())+"."+($lastname.ToLower())+"@"+$rawDomainName+$TopLevelDomain 

        Write-YcLogMessage "Successfully read config." -WriteHost $true
    }
    catch {
        throw ("Could not grab contents of ConfigFile. Aborting. Error Details: "+$_.Exception.Message)
    }

    # Check if the templatePath is a SharePoint URL
    if ($templatePath -match "^https:\/\/.*\.sharepoint\.com") {
        try {
            Write-YcLogMessage "Detected SharePoint link. Trying to download file..." -WriteHost $true

            $siteurl = $config.WelcomeLetter.SharePointSiteURL
            Connect-PnPOnline -Url $siteUrl -Thumbprint ($config.WelcomeLetter.CertificateThumbprint) -ClientId ($config.WelcomeLetter.AzureAppRegistrationClientId) -Tenant ($config.AzureGeneral.TenantId)

            # Download the file from SharePoint
            $localTemplatePath = "$env:TEMP\" + (Split-Path -Leaf $templatePath) # Store in temp folder
            Get-PnPFile -Url $templatePath -Path $localTemplatePath -FileName (Split-Path -Leaf $templatePath) -AsFile

            Write-YcLogMessage "Successfully downloaded file from SharePoint." -WriteHost $true

            # Update $templatePath to use the downloaded local file
            $templatePath = $localTemplatePath
        }
        catch {
            throw ("Failed to download the file from SharePoint. Error: " + $_.Exception.Message)
        }
    }

    # Check if the file exists
    if (-not (Test-Path -Path $templatePath)) {
        throw ("Template does not exist at specified path.")
    }

    #Create working copy
    $templateBasePath = Split-Path $templatePath
    $workingcopyPath = $templateBasePath+"\WL_"+$FirstName+"_"+$LastName+".docx"
    Copy-Item -Path $templatePath -Destination $workingcopyPath
    $templatePath = $workingcopyPath

    Write-YcLogMessage ("Path to copied item from template: "+$workingcopyPath) -WriteHost $true

    try {
        # Build the path to the DLL relative to the module base directory
        $openXmlDll = Join-Path -Path $PSScriptRoot -ChildPath "lib\DocumentFormat.OpenXml.dll"
        $openXmlFramework = Join-Path -Path $PSScriptRoot -ChildPath "lib\DocumentFormat.OpenXml.Framework.dll"

        # Load the DLLs if not already loaded
        if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.Location -eq $openXmlDll })) {
            Add-Type -Path $openXmlDll
        }
        if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.Location -eq $openXmlFramework })) {
            Add-Type -Path $openXmlFramework
        }

        Write-YcLogMessage ("Successfully loaded required DLLs from path: "+$PSScriptRoot+"\lib\") -WriteHost $true
    }
    catch {throw ("Could not load required .DLLs. Aborting. Error Details: "+$_.Exception.Message)}

    # Create the search and replace text
    # Default placeholders
    $defaultPlaceholders = @{
        'EMAIL'     = $identity
        'INITPASS'  = $InitialPassword
        'FIRSTNAME' = $FirstName
        'LASTNAME'  = $LastName
    }

    # Merge custom placeholders (from config or parameters) with default placeholders
    $placeholders = $defaultPlaceholders + $CustomPlaceholders

    try {
        # Open the Word document for editing
        Write-YcLogMessage ("Trying to open .docx file using OpenXML .DLL...") -WriteHost $true
        [Reflection.Assembly]::LoadFrom($openXmlDll) | Out-Null
        $doc = [DocumentFormat.OpenXml.Packaging.WordprocessingDocument]::Open($templatePath, $true)

        Write-YcLogMessage ("Opened file. Trying to read text..") -WriteHost $true

        # Get the main document part
        $mainPart = $doc.MainDocumentPart
        $docText = ''

        # Read the document text
        $reader = [System.IO.StreamReader]::new($mainPart.GetStream())
        try {$docText = $reader.ReadToEnd()} 
        finally {$reader.Dispose()}    
        Write-YcLogMessage ("Successfully read text from .docx") -WriteHost $true
        }
    catch {throw ("Could not read file content using System.IO.StreamReader. Aborting. Error Details: "+$_.Exception.Message)}

    try {
        # Iterate over each placeholder and replace it with the appropriate value
        foreach ($placeholder in $placeholders.GetEnumerator()) 
            {
                Write-YcLogMessage ("Processing placeholder: "+$placeholder) -WriteHost $true
                $docText = $docText -replace $placeholder.Key, $placeholder.Value
            }   
        # Write the updated text back to the document
        Write-YcLogMessage ("Writing updatet text back to working copy...") -WriteHost $true
        $writer = [System.IO.StreamWriter]::new($mainPart.GetStream([System.IO.FileMode]::Create))
        try {$writer.Write($docText)} 
        finally {$writer.Dispose()}
    }
    catch {throw ("Could not replace placeholder text using System.IO.StreamWriter. Aborting. Error Details: "+$_.Exception.Message)}
    finally {$doc.Dispose()}
}

function New-YcIAMSCIMRequest
{
    [Parameter(Mandatory=$false)][string]$PathToConfig = "$env:USERPROFILE\.yc\YcIAMSampleConfig.json"

        #Requires -Modules @{ModuleName='Microsoft.Graph.Applications';ModuleVersion='2.23.0'}

        #Import config and map values to variables
        try {
            $config = Get-Content -raw -Path $PathToConfig | ConvertFrom-Json -ErrorAction Stop
    
            $PathToMappingFile = $config.EntraAPIprovisioning.PathToMappingFile
            $PathToCsv = $config.EntraAPIprovisioning.PathToImportCSV
            $APIProv_APIAppServicePrincipalId = $config.EntraAPIprovisioning.APIAppServicePinricipalId
            $APIProv_AzureAppRegistrationClientId = $config.EntraAPIprovisioning.AzureAppRegistrationClientId
            $APIProv_CertificateThumbprint = $config.EntraAPIprovisioning.CertificateThumbprint
            $tenantId = $config.AzureGeneral.tenantId

            #Initialize Booleans with default values
            $PathToLogFile = "$env:USERPROFILE\.yc"
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
                $EventLogSource = "Yc.IAM-EntraProv-NewSCIMRequest"
            }
        }
        
        try {
            $ClientCertificate =  (Get-ChildItem Cert:\LocalMachine\My\$APIProv_CertificateThumbprint)
        }
        catch {
            throw ("Could not find/grab certificate needed for authentication. Aborting. Error Details: "+$_.Exception.Message)
        }
        
        try {
            $AttributeMapping = Import-PowerShellDataFile $PathToMappingFile
        }
        catch {
            throw ("Could not import data mapping file. Aborting. Error Details: "+$_.Exception.Message)
        }

        try {
            $script:ScimSchemas = @{
                "urn:ietf:params:scim:schemas:core:2.0:User"                 = '{"id":"urn:ietf:params:scim:schemas:core:2.0:User","name":"User","description":"User Account","attributes":[{"name":"userName","type":"string","multiValued":false,"description":"Unique identifier for the User, typically used by the user to directly authenticate to the service provider. Each User MUST include a non-empty userName value.  This identifier MUST be unique across the service provider''s entire set of Users. REQUIRED.","required":true,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"server"},{"name":"name","type":"complex","multiValued":false,"description":"The components of the user''s real name. Providers MAY return just the full name as a single string in the formatted sub-attribute, or they MAY return just the individual component attributes using the other sub-attributes, or they MAY return both.  If both variants are returned, they SHOULD be describing the same name, with the formatted name indicating how the component attributes should be combined.","required":false,"subAttributes":[{"name":"formatted","type":"string","multiValued":false,"description":"The full name, including all middle names, titles, and suffixes as appropriate, formatted for display (e.g., ''Ms. Barbara J Jensen, III'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"familyName","type":"string","multiValued":false,"description":"The family name of the User, or last name in most Western languages (e.g., ''Jensen'' given the full name ''Ms. Barbara J Jensen, III'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"givenName","type":"string","multiValued":false,"description":"The given name of the User, or first name in most Western languages (e.g., ''Barbara'' given the full name ''Ms. Barbara J Jensen, III'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"middleName","type":"string","multiValued":false,"description":"The middle name(s) of the User (e.g., ''Jane'' given the full name ''Ms. Barbara J Jensen, III'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"honorificPrefix","type":"string","multiValued":false,"description":"The honorific prefix(es) of the User, or title in most Western languages (e.g., ''Ms.'' given the full name ''Ms. Barbara J Jensen, III'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"honorificSuffix","type":"string","multiValued":false,"description":"The honorific suffix(es) of the User, or suffix in most Western languages (e.g., ''III'' given the full name ''Ms. Barbara J Jensen, III'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"}],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"displayName","type":"string","multiValued":false,"description":"The name of the User, suitable for display to end-users.  The name SHOULD be the full name of the User being described, if known.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"hiringDate","type":"string","multiValued":false,"description":"The hiring date of the user.","required":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"nickName","type":"string","multiValued":false,"description":"The casual way to address the user in real life, e.g., ''Bob'' or ''Bobby'' instead of ''Robert''.  This attribute SHOULD NOT be used to represent a User''s username (e.g., ''bjensen'' or ''mpepperidge'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"profileUrl","type":"reference","referenceTypes":["external"],"multiValued":false,"description":"A fully qualified URL pointing to a page representing the User''s online profile.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"title","type":"string","multiValued":false,"description":"The user''s title, such as \"Vice President.\"","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"userType","type":"string","multiValued":false,"description":"Used to identify the relationship between the organization and the user.  Typical values used might be ''Contractor'', ''Employee'', ''Intern'', ''Temp'', ''External'', and ''Unknown'', but any value may be used.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"preferredLanguage","type":"string","multiValued":false,"description":"Indicates the User''s preferred written or spoken language.  Generally used for selecting a localized user interface; e.g., ''en_US'' specifies the language English and country US.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"locale","type":"string","multiValued":false,"description":"Used to indicate the User''s default location for purposes of localizing items such as currency, date time format, or numerical representations.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"timezone","type":"string","multiValued":false,"description":"The User''s time zone in the ''Olson'' time zone database format, e.g., ''America/Los_Angeles''.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"active","type":"boolean","multiValued":false,"description":"A Boolean value indicating the User''s administrative status.","required":false,"mutability":"readWrite","returned":"default"},{"name":"password","type":"string","multiValued":false,"description":"The User''s cleartext password.  This attribute is intended to be used as a means to specify an initial password when creating a new User or to reset an existing User''s password.","required":false,"caseExact":false,"mutability":"writeOnly","returned":"never","uniqueness":"none"},{"name":"emails","type":"complex","multiValued":true,"description":"Email addresses for the user.  The value SHOULD be canonicalized by the service provider, e.g., ''bjensen@example.com'' instead of ''bjensen@EXAMPLE.COM''. Canonical type values of ''work'', ''home'', and ''other''.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"Email addresses for the user.  The value SHOULD be canonicalized by the service provider, e.g., ''bjensen@example.com'' instead of ''bjensen@EXAMPLE.COM''. Canonical type values of ''work'', ''home'', and ''other''.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function, e.g., ''work'' or ''home''.","required":false,"caseExact":false,"canonicalValues":["work","home","other"],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute, e.g., the preferred mailing address or primary email address.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"phoneNumbers","type":"complex","multiValued":true,"description":"Phone numbers for the User.  The value SHOULD be canonicalized by the service provider according to the format specified in RFC 3966, e.g., ''tel:+1-201-555-0123''. Canonical type values of ''work'', ''home'', ''mobile'', ''fax'', ''pager'', and ''other''.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"Phone number of the User.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function, e.g., ''work'', ''home'', ''mobile''.","required":false,"caseExact":false,"canonicalValues":["work","home","mobile","fax","pager","other"],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute, e.g., the preferred phone number or primary phone number.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default"},{"name":"ims","type":"complex","multiValued":true,"description":"Instant messaging addresses for the User.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"Instant messaging address for the User.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function, e.g., ''aim'', ''gtalk'', ''xmpp''.","required":false,"caseExact":false,"canonicalValues":["aim","gtalk","icq","xmpp","msn","skype","qq","yahoo"],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute, e.g., the preferred messenger or primary messenger.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default"},{"name":"photos","type":"complex","multiValued":true,"description":"URLs of photos of the User.","required":false,"subAttributes":[{"name":"value","type":"reference","referenceTypes":["external"],"multiValued":false,"description":"URL of a photo of the User.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function, i.e., ''photo'' or ''thumbnail''.","required":false,"caseExact":false,"canonicalValues":["photo","thumbnail"],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute, e.g., the preferred photo or thumbnail.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default"},{"name":"addresses","type":"complex","multiValued":true,"description":"A physical mailing address for this User. Canonical type values of ''work'', ''home'', and ''other''.  This attribute is a complex type with the following sub-attributes.","required":false,"subAttributes":[{"name":"formatted","type":"string","multiValued":false,"description":"The full mailing address, formatted for display or use with a mailing label.  This attribute MAY contain newlines.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"streetAddress","type":"string","multiValued":false,"description":"The full street address component, which may include house number, street name, P.O. box, and multi-line extended street address information.  This attribute MAY contain newlines.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"locality","type":"string","multiValued":false,"description":"The city or locality component.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"region","type":"string","multiValued":false,"description":"The state or region component.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"postalCode","type":"string","multiValued":false,"description":"The zip code or postal code component.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"country","type":"string","multiValued":false,"description":"The country name component.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function, e.g., ''work'' or ''home''.","required":false,"caseExact":false,"canonicalValues":["work","home","other"],"mutability":"readWrite","returned":"default","uniqueness":"none"}],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"groups","type":"complex","multiValued":true,"description":"A list of groups to which the user belongs, either through direct membership, through nested groups, or dynamically calculated.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"The identifier of the User''s group.","required":false,"caseExact":false,"mutability":"readOnly","returned":"default","uniqueness":"none"},{"name":"$ref","type":"reference","referenceTypes":["User","Group"],"multiValued":false,"description":"The URI of the corresponding ''Group'' resource to which the user belongs.","required":false,"caseExact":false,"mutability":"readOnly","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readOnly","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function, e.g., ''direct'' or ''indirect''.","required":false,"caseExact":false,"canonicalValues":["direct","indirect"],"mutability":"readOnly","returned":"default","uniqueness":"none"}],"mutability":"readOnly","returned":"default"},{"name":"entitlements","type":"complex","multiValued":true,"description":"A list of entitlements for the User that represent a thing the User has.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"The value of an entitlement.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default"},{"name":"roles","type":"complex","multiValued":true,"description":"A list of roles for the User that collectively represent who the User is, e.g., ''Student'', ''Faculty''.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"The value of a role.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function.","required":false,"caseExact":false,"canonicalValues":[],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default"},{"name":"x509Certificates","type":"complex","multiValued":true,"description":"A list of certificates issued to the User.","required":false,"caseExact":false,"subAttributes":[{"name":"value","type":"binary","multiValued":false,"description":"The value of an X.509 certificate.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function.","required":false,"caseExact":false,"canonicalValues":[],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default"}],"meta":{"resourceType":"Schema","location":"/v2/Schemas/urn:ietf:params:scim:schemas:core:2.0:User"}}' | ConvertFrom-Json
                "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = '{"id":"urn:ietf:params:scim:schemas:extension:enterprise:2.0:User","name":"EnterpriseUser","description":"Enterprise User","attributes":[{"name":"employeeNumber","type":"string","multiValued":false,"description":"Numeric or alphanumeric identifier assigned to a person, typically based on order of hire or association with anorganization.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"costCenter","type":"string","multiValued":false,"description":"Identifies the name of a cost center.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"organization","type":"string","multiValued":false,"description":"Identifies the name of an organization.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"division","type":"string","multiValued":false,"description":"Identifies the name of a division.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"hiringDate","type":"string","multiValued":false,"description":"The hiring date of the user.","required":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"department","type":"string","multiValued":false,"description":"Identifies the name of a department.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"manager","type":"complex","multiValued":false,"description":"The User''s manager. A complex type that optionally allows service providers to represent organizational hierarchy by referencing the ''id'' attribute of another User.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"The id of the SCIM resource representingthe User''s manager.  REQUIRED.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"$ref","type":"reference","referenceTypes":["User"],"multiValued":false,"description":"The URI of the SCIM resource representing the User''s manager.  REQUIRED.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"displayName","type":"string","multiValued":false,"description":"The displayName of the User''s manager. OPTIONAL and READ-ONLY.","required":false,"caseExact":false,"mutability":"readOnly","returned":"default","uniqueness":"none"}],"mutability":"readWrite","returned":"default"}],"meta":{"resourceType":"Schema","location":"/v2/Schemas/urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"}}' | ConvertFrom-Json
            }
            Test-ScimAttributeMapping $AttributeMapping -ScimSchemaNamespace 'urn:ietf:params:scim:schemas:core:2.0:User'
        }
        catch {
            throw ("Could not verify SCIM Mapping. Aborting. Error Details: "+$_.Exception.Message)
        }

        try {
            $paramConnectMgGraph = @{}
            if ($TenantId) { $paramConnectMgGraph['TenantId'] = $TenantId }
            if ($ClientCertificate) {
                $paramConnectMgGraph['ClientId'] = $APIProv_AzureAppRegistrationClientId
                $paramConnectMgGraph['Certificate'] = $ClientCertificate
            }
            elseif ($ClientId) {
                $paramConnectMgGraph['ClientId'] = $APIProv_AzureAppRegistrationClientId
                $paramConnectMgGraph['Scopes'] = 'Application.ReadWrite.All', 'AuditLog.Read.All','SynchronizationData-User.Upload' 
            }
            else {
                $paramConnectMgGraph['Scopes'] = 'Application.ReadWrite.All', 'AuditLog.Read.All','SynchronizationData-User.Upload'
            }

            Import-Module Microsoft.Graph.Applications -ErrorAction Stop
            Connect-MgGraph @paramConnectMgGraph -ErrorAction Stop | Out-Null
            $csv = Import-Csv -Path $PathToCsv 

            foreach ($item in $csv)
            {
                Write-YcLogMessage -message ("CSV for SCIM Request: "+$item) -WriteHost $true
                Write-YcLogMessage -message ("-----------------------------------------------------------------------------------------------------------------------------------------------") -WriteHost $true
            }

            $body = ConvertTo-ScimBulkPayload -ScimSchemaNamespace $ScimSchemaNamespace -AttributeMapping $AttributeMapping -InputObject $csv
            Invoke-AzureADBulkScimRequest -ServicePrincipalId $APIProv_APIAppServicePrincipalId -Body $body -ErrorAction Stop
        }
        catch {
            throw ("Could not connect and or send the API request with SCIM payload. Aborting. Error Details: "+$_.Exception.Message)
        }
        finally {
            Disconnect-MgGraph
        }
}
function Test-ScimAttributeMapping {
    [CmdletBinding()]
    param (
        # Map input properties to SCIM attributes
        [Parameter(Mandatory = $true)]
        [hashtable] $AttributeMapping,
        # SCIM schema namespace for attribute mapping
        [Parameter(Mandatory = $true)]
        [string] $ScimSchemaNamespace,
        # List of attribute names through sub-attribute names
        [Parameter(Mandatory = $false)]
        [string[]] $HierarchyPath
    )

    ## Initialize
    $result = $true

    foreach ($_PropertyMapping in $AttributeMapping.GetEnumerator()) {

        if ($_PropertyMapping.Key -in 'id', 'externalId') { continue }

        [string[]] $NewHierarchyPath = $HierarchyPath + $_PropertyMapping.Key

        if ($_PropertyMapping.Key -is [string]) {
            if ($_PropertyMapping.Key.StartsWith('urn:')) {
                if ($ScimSchemas.ContainsKey($_PropertyMapping.Key)) {
                    $nestedResult = Test-ScimAttributeMapping $_PropertyMapping.Value $_PropertyMapping.Key
                    $result = $result -and $nestedResult
                }
                else {
                    Write-Warning ('SCIM Schema Namespace [{0}] was not be validated because no schema representation has been defined.' -f $_PropertyMapping.Key)
                }
            }
            elseif ($ScimSchemas.ContainsKey($ScimSchemaNamespace)) {
                $ScimSchemaAttribute = $ScimSchemas[$ScimSchemaNamespace].attributes | Where-Object name -EQ $NewHierarchyPath[0]
                for ($i = 1; $i -lt $NewHierarchyPath.Count; $i++) {
                    $ScimSchemaAttribute = $ScimSchemaAttribute.subAttributes | Where-Object name -EQ $NewHierarchyPath[$i]
                }
                if (!$ScimSchemaAttribute) {
                    Write-Error ('Attribute [{0}] does not exist in SCIM Schema Namespace [{1}].' -f ($NewHierarchyPath -join '.'), $ScimSchemaNamespace)
                    $result = $false
                }
                else {
                    if ($ScimSchemaAttribute.multiValued -and $_PropertyMapping.Value -isnot [array]) {
                        Write-Error ('Attribute [{0}] is multivalued in SCIM Schema Namespace [{1}] and must contain an array.' -f ($NewHierarchyPath -join '.'), $ScimSchemaNamespace)
                        $result = $false
                    }
                    foreach ($_PropertyMappingValue in $_PropertyMapping.Value) {
                        if ($ScimSchemaAttribute.type -eq 'Complex' -and $_PropertyMappingValue -is [string]) {
                            Write-Error ('Attribute [{0}] of Type [{2}] in SCIM Schema Namespace [{1}] cannot have simple mapping.' -f ($NewHierarchyPath -join '.'), $ScimSchemaNamespace, $ScimSchemaAttribute.type)
                            $result = $false
                        }
                        elseif ($ScimSchemaAttribute.type -ne 'Complex' -and ($_PropertyMappingValue -is [hashtable] -or $_PropertyMappingValue -is [System.Collections.Specialized.OrderedDictionary])) {
                            Write-Error ('Attribute [{0}] of Type [{2}] in SCIM Schema Namespace [{1}] cannot have complex mapping.' -f ($NewHierarchyPath -join '.'), $ScimSchemaNamespace, $ScimSchemaAttribute.type)
                            $result = $false
                        }
                        elseif ($_PropertyMappingValue -is [hashtable] -or $_PropertyMappingValue -is [System.Collections.Specialized.OrderedDictionary]) {
                            $nestedResult = Test-ScimAttributeMapping $_PropertyMappingValue $ScimSchemaNamespace $NewHierarchyPath
                            $result = $result -and $nestedResult
                        }
                    }
                }
            }
        }
        else {
            Write-Error ('Attribute Mapping Key [{0}] is invalid.' -f $_PropertyMapping.Key)
            $result = $false
        }
    }

    return $result
}
function ConvertTo-ScimBulkPayload {
    [CmdletBinding()]
    param (
        # Resource Data
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object[]] $InputObject,
        # Map all input properties to specified custom SCIM namespace
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [Alias('Namespace')]
        [string] $ScimSchemaNamespace,
        # Map input properties to SCIM attributes
        [Parameter(Mandatory = $false)]
        [hashtable] $AttributeMapping,
        # Operations per bulk request
        [Parameter(Mandatory = $false)]
        [int] $OperationsPerRequest = 50,
        # PassThru Object
        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    begin {
        $ScimBulkObject = [PSCustomObject][ordered]@{
            "schemas"      = @("urn:ietf:params:scim:api:messages:2.0:BulkRequest")
            "Operations"   = New-Object System.Collections.Generic.List[pscustomobject]
            "failOnErrors" = $null
        }
        $paramConvertToScimPayload = @{}
        if ($AttributeMapping) { $paramConvertToScimPayload['AttributeMapping'] = $AttributeMapping }
        $ScimBulkObjectInstance = $ScimBulkObject.psobject.Copy()
    }

    process {
        foreach ($obj in $InputObject) {

            $ScimOperationObject = [PSCustomObject][ordered]@{
                "method" = "POST"
                "bulkId" = [string](New-Guid)
                "path"   = "/Users"
                "data"   = ConvertTo-ScimPayload $obj -ScimSchemaNamespace $ScimSchemaNamespace -PassThru @paramConvertToScimPayload
            }
            $ScimBulkObjectInstance.Operations.Add($ScimOperationObject)

            # Output object when max operations has been reached
            if ($OperationsPerRequest -gt 0 -and $ScimBulkObjectInstance.Operations.Count -ge $OperationsPerRequest) {
                if ($PassThru) { $ScimBulkObjectInstance }
                else { ConvertTo-Json $ScimBulkObjectInstance -Depth 10 }
                $ScimBulkObjectInstance = $ScimBulkObject.psobject.Copy()
                $ScimBulkObjectInstance.Operations = New-Object System.Collections.Generic.List[pscustomobject]
            }
        }
    }

    end {
        if ($ScimBulkObjectInstance.Operations.Count -gt 0) {
            ## Return Object with SCIM Data Structure
            if ($PassThru) { $ScimBulkObjectInstance }
            else { ConvertTo-Json $ScimBulkObjectInstance -Depth 10 }
        }
    }
}
function Invoke-AzureADBulkScimRequest {
    [CmdletBinding()]
    param (
        # SCIM JSON Payload(s)
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]] $Body,
        # Service Principal Id for the provisioning application
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $ServicePrincipalId
    )

    begin {
        ## Import Mg Modules
        Import-Module Microsoft.Graph.Applications -ErrorAction Stop

        ## Lookup Service Principal
        $ServicePrincipalId = Get-MgServicePrincipal -Filter "id eq '$ServicePrincipalId' or appId eq '$ServicePrincipalId'" -Select id | Select-Object -ExpandProperty id
        #$ServicePrincipal = Get-MgServicePrincipal -ServicePrincipalId $ServicePrincipalId -ErrorAction Stop
        $SyncJob = Get-MgServicePrincipalSynchronizationJob -ServicePrincipalId $ServicePrincipalId -ErrorAction Stop
        if ($RestartService)
        {
            Suspend-MgServicePrincipalSynchronizationJob -ServicePrincipalId $ServicePrincipalId -SynchronizationJobId $SyncJob.Id
        }
    }
    
    process {
        foreach ($_body in $Body) {
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/servicePrincipals/$ServicePrincipalId/synchronization/jobs/$($SyncJob.Id)/bulkUpload" -ContentType 'application/scim+json' -Body $_body
        }
    }

    end {
        if ($RestartService)
        {
            Start-MgServicePrincipalSynchronizationJob -ServicePrincipalId $ServicePrincipalId -SynchronizationJobId $SyncJob.Id
        }
   #     if ($previousProfile.Name -ne (Get-MgProfile).Name) {
    #        Select-MgProfile -Name $previousProfile.Name
     #   }
    }
}
function ConvertTo-ScimPayload {
    [CmdletBinding()]
    param (
        # Resource Data
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object[]] $InputObject,
        # Map all input properties to specified custom SCIM namespace
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [Alias('Namespace')]
        [string] $ScimSchemaNamespace,
        # Map input properties to SCIM attributes
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [hashtable] $AttributeMapping = @{
            "externalId" = "externalId"
            "userName"   = "userName"
            "active"     = "active"
        },
        # PassThru Object
        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    begin {
        function Resolve-ScimAttributeMapping {
            param (
                # Resource Data
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [object] $InputObject,
                # Map input properties to SCIM attributes
                [Parameter(Mandatory = $true)]
                [hashtable] $AttributeMapping,
                # Add to existing hashtable or dictionary
                [Parameter(Mandatory = $false)]
                [object] $TargetObject = @{}
            )

            foreach ($_AttributeMapping in $AttributeMapping.GetEnumerator()) {

                if ($_AttributeMapping.Key -is [string] -and $_AttributeMapping.Key.StartsWith('urn:')) {
                    if (!$TargetObject['schemas'].Contains($_AttributeMapping.Key)) { $TargetObject['schemas'] += $_AttributeMapping.Key }
                }

                if ($_AttributeMapping.Value -is [array]) {
                    ## Force array output
                    $TargetObject[$_AttributeMapping.Key] = @(Resolve-PropertyMappingValue $InputObject $_AttributeMapping.Value)
                }
                else {
                    $TargetObject[$_AttributeMapping.Key] = Resolve-PropertyMappingValue $InputObject $_AttributeMapping.Value
                }
            }

            return $TargetObject
        }

        function Resolve-PropertyMappingValue {
            param (
                # Resource Data
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [object] $InputObject,
                # Property mapping value to output
                [Parameter(Mandatory = $true)]
                [object] $PropertyMappingValue
            )

            foreach ($_PropertyMappingValue in $PropertyMappingValue) {
                if ($_PropertyMappingValue -is [scriptblock]) {
                    Invoke-Transformation $InputObject $_PropertyMappingValue
                }
                elseif ($_PropertyMappingValue -is [hashtable] -or $_PropertyMappingValue -is [System.Collections.Specialized.OrderedDictionary]) {
                    Resolve-ScimAttributeMapping $InputObject $_PropertyMappingValue
                }
                else {
                    $InputObject.($_PropertyMappingValue)
                }
            }
        }

        # function Invoke-PropertyMapping {
        #     param (
        #         # Resource Data
        #         [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        #         [object] $InputObject,
        #         # Map input properties to another
        #         [Parameter(Mandatory = $true)]
        #         [object] $PropertyMapping
        #     )

        #     foreach ($_PropertyMapping in $PropertyMapping) {
        #         if ($_PropertyMapping -is [scriptblock]) {
        #             Invoke-Transformation $InputObject $_PropertyMapping
        #         }
        #         elseif ($_PropertyMapping -is [hashtable] -or $_PropertyMapping -is [System.Collections.Specialized.OrderedDictionary]) {
        #             $TargetObject = @{}
        #             foreach ($_PropertyMapping2 in $_PropertyMapping.GetEnumerator()) {
        #                 $TargetObject[$_PropertyMapping2.Key] = Invoke-PropertyMapping2 $InputObject $_PropertyMapping2.Value
        #             }
        #             Write-Output $TargetObject
        #         }
        #         else {
        #             $InputObject.($_PropertyMapping)
        #         }
        #     }
        # }

        function Invoke-Transformation {
            param (
                # Resource Data
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [object] $InputObject,
                # Transformation Script Block
                [Parameter(Mandatory = $true)]
                [scriptblock] $ScriptBlock
            )
    
            process {
                ## Using Import-PowerShellDataFile to load a scriptblock wraps it in another scriptblock so handling that with loop
                $ScriptBlockResult = $ScriptBlock
                while ($ScriptBlockResult -is [scriptblock]) {
                    $ScriptBlockResult = ForEach-Object -InputObject $InputObject -Process $ScriptBlockResult
                }

                return $ScriptBlockResult
            }
        }
    }

    process {
        foreach ($obj in $InputObject) {
            ## Generate Core SCIM Data Structure
            $ScimObject = [ordered]@{
                schemas = [string[]]("urn:ietf:params:scim:schemas:core:2.0:User", "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User")
                #id = [string](New-Guid)
            }

            ## Add Attributes to SCIM Data Structure
            $ScimObject = Resolve-ScimAttributeMapping $obj -AttributeMapping $AttributeMapping -TargetObject $ScimObject
            if ($ScimSchemaNamespace) {
                $ScimObject[$ScimSchemaNamespace] = $obj
                $ScimObject['schemas'] += $ScimSchemaNamespace
            }

            ## Return Object with SCIM Data Structure
            #$ScimObject = [PSCustomObject]$ScimObject
            if ($PassThru) { $ScimObject }
            else { ConvertTo-Json $ScimObject -Depth 5 }
        }
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
            "WelcomeLetter" = @(
                @{
                    "PathToTemplate" = "******"
                    "SharePointSiteURL" = "*****"
                    "AzureAppRegistrationClientId" = "********-****-****-****-************"
                    "CertificateThumbprint" = "***************************"
                }
            )
            "EntraAPIprovisioning" = @(
                @{
                    "PathToMappingFile" = "******"
                    "PathToCsv" = "*****"
                    "APIAppServicePinricipalId" = "********-****-****-****-************"
                    "AzureAppRegistrationClientId" = "********-****-****-****-************" 
                    "CertificateThumbprint" = "***************************"
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

function New-YcIAMCsvFromMapping {
    param (
        [string]$AttributeMappingFilePath,
        [string]$OutputCSVPath
    )

    # Import the .psd1 attribute mapping file
    $attributeMapping = Import-PowerShellDataFile -Path $AttributeMappingFilePath

    # Initialize an array to store the headers for the CSV
    $csvHeaders = @()

    # Recursively extract all column names
    function Get-MappingColumns {
        param ($mapping, [ref]$headers)
        
        foreach ($key in $mapping.Keys) {
            $value = $mapping[$key]
            
            if ($value -is [string]) {
                # Simple key-value mapping
                $headers.Value += $value
            }
            elseif ($value -is [hashtable]) {
                # Nested hashtable (e.g. name, addresses)
                Get-MappingColumns -mapping $value -headers $headers
            }
            elseif ($value -is [array]) {
                foreach ($item in $value) {
                    if ($item -is [hashtable]) {
                        Get-MappingColumns -mapping $item -headers $headers
                    }
                }
            }
        }
    }

    # Call the recursive function to extract column headers
    Get-MappingColumns -mapping $attributeMapping -headers ([ref]$csvHeaders)

    # Convert the headers to a unique set to avoid duplicates
    $csvHeaders = $csvHeaders | Sort-Object -Unique

    # Create an empty PSObject with the headers as properties
    $emptyRow = New-Object PSObject

    foreach ($header in $csvHeaders) {
        Add-Member -InputObject $emptyRow -MemberType NoteProperty -Name $header -Value $null
    }

    # Initialize CSV content with one empty row (or populate this with actual data)
    $csvContent = @()
    $csvContent += $emptyRow

    # Export the empty CSV with the headers
    $csvContent | Export-Csv -Path $OutputCSVPath -NoTypeInformation -Force -Delimiter ','

    Write-Host "CSV with headers generated at: $OutputCSVPath"
}

function Add-YcIAMRowToImportCSV {
    param (
        [string]$CSVPath,
        [string]$FirstName,
        [string]$LastName,
        [string]$EmployeeId,
        [string]$UserName,
        [string]$JobTitle,
        [string]$CountryCode,
        [string]$OnboardingDate,
        [string]$StreetAddress,
        [string]$City,
        [string]$ZipCode,
        [string]$OfficePhone,
        [string]$TelephoneNumber,
        [string]$Company,
        [string]$Team,
        [string]$Department,
        [string]$Manager
    )

    # Create a new PSObject with the values provided
    $newRow = New-Object PSObject -Property @{
        FirstName       = $FirstName
        LastName        = $LastName
        EmployeeId      = $EmployeeId
        UserName        = $UserName
        JobTitle        = $JobTitle
        CountryCode     = $CountryCode
        OnboardingDate  = $OnboardingDate
        StreetAddress   = $StreetAddress
        City            = $City
        ZipCode         = $ZipCode
        OfficePhone     = $OfficePhone
        TelephoneNumber = $TelephoneNumber
        Company         = $Company
        Team            = $Team
        Department      = $Department
        Manager         = $Manager
    }

    # Add the new row to the existing CSV
    $newRow | Export-Csv -Path $CSVPath -Append -NoTypeInformation -Force -Delimiter ','

    Write-Host "New row added to CSV: $CSVPath"
}
