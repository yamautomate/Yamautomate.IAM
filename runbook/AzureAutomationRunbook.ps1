param (
    [Parameter(Mandatory=$false)]
    [object]$WebhookData
)

function Authenticate-YcAAWebhookCall {
    param (
        $WebhookData
    )

    # Retrieve headers for authentication
    $incomingAPIKey = $WebhookData.RequestHeader.'X-APIKey'
    $incomingUserAgent = $WebhookData.RequestHeader.'User-Agent'
    $incomingClientId = $WebhookData.RequestHeader.'X-ClientId'
    $incomingTimestamp = $WebhookData.RequestHeader.'X-Timestamp'

    # Validate User-Agent
    $permittedUserAgents = (Get-AutomationVariable -Name "PermittedUserAgents").Split(",") | ForEach-Object { $_.Trim() }
    if ($permittedUserAgents -notcontains $incomingUserAgent) {
        throw "401: Unauthorized. Unknown User-Agent: $incomingUserAgent"
    }

    # Validate Timestamp (within 5 minutes to prevent replay attacks)
    $requestTimestamp = [datetime]::Parse($incomingTimestamp)
    $currentTime = Get-Date
    if (($currentTime - $requestTimestamp).TotalMinutes -gt 5) {
        throw "401: Unauthorized. Request expired. Request timestamp: $requestTimestamp"
    }
    
    # Validate Client ID
    $allowedClientIds = (Get-AutomationVariable -Name "AllowedClientIds").Split(",") | ForEach-Object { $_.Trim() }
    if ($allowedClientIds -notcontains $incomingClientId) {
        throw "401: Unauthorized. Invalid Client-ID: $incomingClientId"
    }

    # Validate API Key
    $APIKeyStored = Get-AutomationVariable -Name "APIKey"
    if ($incomingAPIKey -ne $APIKeyStored) {
        throw "401: Unauthorized. Invalid API Key."
    }

    # If all validations pass
    Write-YcLogMessage ("200: Successful authentication. User-Agent: $incomingUserAgent, Client-ID: $incomingClientId, Timestamp: $requestTimestamp") -ToOutput $true
}

function Validate-YcStrNotEmpty {
    param(
        [string]$Value,
        [string]$PropertyName
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "400: Bad Request. $PropertyName cannot be empty."
    }
}

if ($WebhookData -ne $null) {

    Authenticate-YcAAWebhookCall $WebhookData
    # Extract the webhook request body (payload)
    Write-YcLogMessage ("WebhookData.RequestBody is: "+$WebhookData.RequestBody) -source "ReadBody" -ToOutput $true

    try {
        $WebhookBody = $WebhookData.RequestBody | ConvertFrom-Json
        [string]$Firstname = $WebhookBody.Firstname
        [string]$Lastname = $WebhookBody.Lastname
        [string]$EmployeeId = $WebhookBody.EmployeeId
        [string]$UserName = $WebhookBody.UserName
        [string]$JobTitle = $WebhookBody.JobTitle
        [string]$CountryCode = $WebhookBody.CountryCode
        [string]$OnboardingDate = $WebhookBody.OnboardingDate
        [string]$StreetAddress = $WebhookBody.StreetAddress
        [string]$City = $WebhookBody.City
        [string]$ZipCode = $WebhookBody.ZipCode
        [string]$OfficePhone = $WebhookBody.OfficePhone
        [string]$TelephoneNumber = $WebhookBody.Telephone
        [string]$Company = $WebhookBody.Company
        [string]$Team = $WebhookBody.Team
        [string]$Department = $WebhookBody.Department
        [string]$Manager = $WebhookBody.Manager
        
    }
    catch {
        throw ("Could not extract RequestBody from WebhookData. Error details: " + $_.Exception.Message)
    }

    #Validate input values
    Validate-YcStrNotEmpty -Value $Firstname -PropertyName "Firstname"
    Validate-YcStrNotEmpty -Value $Lastname -PropertyName "Lastname"
    Validate-YcStrNotEmpty -Value $EmployeeId -PropertyName "EmployeeId"
    Validate-YcStrNotEmpty -Value $JobTitle -PropertyName "JobTitle"
    Validate-YcStrNotEmpty -Value $CountryCode -PropertyName "CountryCode"
    Validate-YcStrNotEmpty -Value $OnboardingDate -PropertyName "OnboardingDate"
    Validate-YcStrNotEmpty -Value $StreetAddress -PropertyName "StreetAddress"
    Validate-YcStrNotEmpty -Value $City -PropertyName "City"
    Validate-YcStrNotEmpty -Value $ZipCode -PropertyName "ZipCode"
    Validate-YcStrNotEmpty -Value $OfficePhone -PropertyName "OfficePhone"
    Validate-YcStrNotEmpty -Value $TelephoneNumber -PropertyName "TelephoneNumber"
    Validate-YcStrNotEmpty -Value $Company -PropertyName "Company"
    Validate-YcStrNotEmpty -Value $Team -PropertyName "Team"
    Validate-YcStrNotEmpty -Value $Department -PropertyName "Department"
    Validate-YcStrNotEmpty -Value $Manager -PropertyName "Manager"

    # Validate Username follows firstname.lastname pattern
    $expectedUserName = "$Firstname.$Lastname".ToLower()
    if ($UserName.ToLower() -ne $expectedUserName) {
        throw "400: Bad Request. Username must follow the format firstname.lastname. Expected: $expectedUserName Received: $UserName"
    }

    #Validate onboarding date is not in the past
    $onboardingDateParsed = [datetime]::Parse($OnboardingDate)
    $currentDate = Get-Date
    if ($onboardingDateParsed -lt $currentDate.Date) {
        throw "400: Bad Request. OnboardingDate cannot be in the past. Provided date: $OnboardingDate"
    }

    # If all validations pass, continue processing
    Write-YcLogMessage ("200: Validation of all input parameters was successful. Proceeding.") -ToOutput $true

} 

else {
    throw "WebhookData is null. No payload was received."
}

#Map Azure Automation Variables
try {
    $PathToMappingFile = Get-AutomationVariable -Name "PathToMappingFile"
    $PathToCsv = Get-AutomationVariable -Name "PathToCsv" 
    $OutputCSVPath =  Get-AutomationVariable -Name "OutputCSVPath"

    $APIProv_APIAppServicePrincipalId = Get-AutomationVariable -Name "APIProv_APIAppServicePrincipalId" 
    $APIProv_AzureAppRegistrationClientId = Get-AutomationVariable -Name "APIProv_AzureAppRegistrationClientId" 
    $APIProv_CertificateThumbprint = Get-AutomationVariable -Name "APIProv_CertificateThumbprint" 
    $tenantId = Get-AutomationVariable -Name "tenantId" 
}
catch {
    throw ("Could not read Azure Automation Variables. Error details: " + $_.Exception.Message)
}

#Create CSV from mapping
try {
    Write-YcLogMessage ("Creating .csv from mapping in: "+$PathToMappingFile) -ToOutput $true -Source "CreateCSVforSCIM"
    New-YcIAMCsvFromMapping -AttributeMappingFilePath $PathToMappingFile -OutputCSVPath $OutputCSVPath
    Write-YcLogMessage ("Successfully created empty .csv from mapping") -Source "CreateCSVforSCIM"
}
catch {
    throw ("Could not create .csv from mapping. Error details: " + $_.Exception.Message)
}

#Add user info from request to created csv
try {
    Write-YcLogMessage ("Adding user info to .csv.. ") -ToOutput $true
    Add-YcIAMRowToImportCSV -csvPath $OutputCSVPath -Firstname $Firstname -LastName $lastname -EmployeeId $employeeId -UserName $username -JobTitle $jobtitle -CountryCode $CountryCode -OnboardingDate $OnboardingDate -StreetAddress $StreetAddress -City $City -ZipCode $ZipCode -OfficePhone $OfficePhone -TelephoneNumber $TelephoneNumber -Company $Company -Team $team -Department $department -Manager $manager
    Write-YcLogMessage ("Successfully added user info to .csv") -ToOutput $true
}
catch {
    throw ("Could not add user info to .csv. Error Details: " + $_.Exception.Message)
}

#Wrap csv into SCIM request and send that off to Entra ID provisioning API
try {
    Write-YcLogMessage ("Sending SCIM Body as POST request to EntraID provisioning API...") -ToOutput $true
    New-YcIAMSCIMRequest -UseConfig $false -PathToCsv $OutputCSVPath -PathToMappingFile $PathToMappingFile -APIProv_APIAppServicePrincipalId $APIProv_APIAppServicePrincipalId -APIProv_AzureAppRegistrationClientId $APIProv_AzureAppRegistrationClientId -APIProv_CertificateThumbprint $APIProv_CertificateThumbprint -tenantId $tenantId
    Write-YcLogMessage ("Successfully sent SCIM Body as POST request to EntraID provisioning API. Check provisioning logs from here.") -ToOutput $true
}
catch {
    throw ("Could not send off SCIM Request. Error Details: " + $_.Exception.Message)
}
