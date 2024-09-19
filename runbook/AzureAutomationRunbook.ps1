param (
    [Parameter(Mandatory=$false)]
    [object]$WebhookData
)

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
        [string]$TelephoneNumber = $WebhookBody.Telephone
        [string]$Company = $WebhookBody.Company
        [string]$Team = $WebhookBody.Team
        [string]$Department = $WebhookBody.Department
        [string]$Manager = $WebhookBody.Manager
        # [string]$StreetAddress = $WebhookBody.StreetAddress
        # [string]$City = $WebhookBody.City
        # [string]$ZipCode = $WebhookBody.ZipCode
        # [string]$OfficePhone = $WebhookBody.OfficePhone
        
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
    Validate-YcStrNotEmpty -Value $TelephoneNumber -PropertyName "TelephoneNumber"
    Validate-YcStrNotEmpty -Value $Company -PropertyName "Company"
    Validate-YcStrNotEmpty -Value $Team -PropertyName "Team"
    Validate-YcStrNotEmpty -Value $Department -PropertyName "Department"
    Validate-YcStrNotEmpty -Value $Manager -PropertyName "Manager"

    #Validate-YcStrNotEmpty -Value $StreetAddress -PropertyName "StreetAddress"
    #Validate-YcStrNotEmpty -Value $City -PropertyName "City"
    #Validate-YcStrNotEmpty -Value $ZipCode -PropertyName "ZipCode"
    #Validate-YcStrNotEmpty -Value $OfficePhone -PropertyName "OfficePhone"

    <# Validate Username follows firstname.lastname pattern
    $expectedUserName = "$Firstname.$Lastname".ToLower()
    if ($UserName.ToLower() -ne $expectedUserName) {
        throw "400: Bad Request. Username must follow the format firstname.lastname. Expected: $expectedUserName Received: $UserName"
    }
    #>

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
    $OutputCSVPath =  Get-AutomationVariable -Name "OutputCSVPath"

    $APIProv_APIAppServicePrincipalId = Get-AutomationVariable -Name "APIProv_APIAppServicePrincipalId" 
    $APIProv_AzureAppRegistrationClientId = Get-AutomationVariable -Name "APIProv_AzureAppRegistrationClientId" 
    $APIProv_CertificateThumbprint = Get-AutomationVariable -Name "APIProv_CertificateThumbprint" 
    $APIProv_AutomationCertificateName = Get-AutomationVariable -Name "APIProv_AutomationCertificateName" 
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

#Building Properties
try {
    # Build the username
    $userName = "$Firstname.$Lastname".ToLower()
    # Switch on CountryCode and dynamically retrieve values from Azure Automation Variables
    switch ($CountryCode) {
        "CH" {  # Switzerland
            $StreetAddress = Get-AutomationVariable -Name "CH_StreetAddress"
            $City = Get-AutomationVariable -Name "CH_City"
            $ZipCode = Get-AutomationVariable -Name "CH_ZipCode"
            $OfficePhone = Get-AutomationVariable -Name "CH_OfficePhone"
        }
        "DE" {  # Germany
            $StreetAddress = Get-AutomationVariable -Name "DE_StreetAddress"
            $City = Get-AutomationVariable -Name "DE_City"
            $ZipCode = Get-AutomationVariable -Name "DE_ZipCode"
            $OfficePhone = Get-AutomationVariable -Name "DE_OfficePhone"
        }
        "US" {  # United States
            $StreetAddress = Get-AutomationVariable -Name "US_StreetAddress"
            $City = Get-AutomationVariable -Name "US_City"
            $ZipCode = Get-AutomationVariable -Name "US_ZipCode"
            $OfficePhone = Get-AutomationVariable -Name "US_OfficePhone"
        }
        Default {  # Default case for other countries or if CountryCode is not recognized
            throw "Unsupported CountryCode: $CountryCode"
        }
    }
}
catch {
    Write-Host "An error occurred: $($_.Exception.Message)"
}

#Add user info from request to created csv
try {
    Write-YcLogMessage ("Adding user info to .csv.. ") -ToOutput $true
    Add-YcIAMRowToImportCSV -csvPath $OutputCSVPath -Firstname $Firstname -LastName $lastname -EmployeeId $employeeId -UserName $username -JobTitle $jobtitle -CountryCode $CountryCode -OnboardingDate $OnboardingDate -StreetAddress $StreetAddress -City $City -ZipCode $ZipCode -OfficePhone $OfficePhone -TelephoneNumber $TelephoneNumber -Company $Company -Team $team -Department $department -Manager $manager
    Write-YcLogMessage ("Successfully added user info to .csv") -ToOutput $true
}
catch {
    Remove-Item -Path $OutputCSVPath -Force
    throw ("Could not add user info to .csv. Error Details: " + $_.Exception.Message)
}

#Wrap csv into SCIM request and send that off to Entra ID provisioning API
try {
    Write-YcLogMessage ("Sending SCIM Body as POST request to EntraID provisioning API...") -ToOutput $true
    New-YcIAMSCIMRequest -UseConfig $false -PathToCsv $OutputCSVPath -PathToMappingFile $PathToMappingFile -APIProv_APIAppServicePrincipalId $APIProv_APIAppServicePrincipalId -APIProv_AzureAppRegistrationClientId $APIProv_AzureAppRegistrationClientId -APIProv_CertificateThumbprint $APIProv_CertificateThumbprint -tenantId $tenantId -UseAACertificate $true -APIProv_AutomationCertificateName $APIProv_AutomationCertificateName
    Write-YcLogMessage ("Successfully sent SCIM Body as POST request to EntraID provisioning API. Check provisioning logs from here.") -ToOutput $true
}
catch {
    throw ("Could not send off SCIM Request. Error Details: " + $_.Exception.Message)
}
finally {
    Remove-Item -Path $OutputCSVPath -Force
}
