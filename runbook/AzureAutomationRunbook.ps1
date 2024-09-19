param (
    [Parameter(Mandatory=$false)]
    [object]$WebhookData
)

if ($WebhookData -ne $null) {
    # Extract the webhook request body (payload)
    $WebhookBody = $WebhookData.RequestBody | ConvertFrom-Json
    [string]$APIKeyRequest = $WebhookBody.APIKey
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
    [string]$TelephoneNumber = $WebhookBody.TelephoneNumber
    [string]$Company = $WebhookBody.Company
    [string]$Team = $WebhookBody.Team
    [string]$Department = $WebhookBody.Department
    [string]$Manager = $WebhookBody.Manager

    $APIKeyStored = Get-AutomationVariable -Name "APIKey"
    If (!($APIKeyRequest -eq $APIKeyStored))
    {
        throw "401: Unauthorized. Unknown API Key."
    }
    else
    {
        Write-YcLogMessage ("200: Successful authentication.") -ToOutput $true
    }
} else {
    Write-YcLogMessage ("WebhookData is null. No payload was received.") -ToOutput $true
}

$PathToMappingFile = Get-AutomationVariable -Name "PathToMappingFile"
$PathToCsv = Get-AutomationVariable -Name "PathToCsv" 
$OutputCSVPath =  Get-AutomationVariable -Name "OutputCSVPath"

$APIProv_APIAppServicePrincipalId = Get-AutomationVariable -Name "APIProv_APIAppServicePrincipalId" 
$APIProv_AzureAppRegistrationClientId = Get-AutomationVariable -Name "APIProv_AzureAppRegistrationClientId" 
$APIProv_CertificateThumbprint = Get-AutomationVariable -Name "APIProv_CertificateThumbprint" 
$tenantId = Get-AutomationVariable -Name "tenantId" 

Write-YcLogMessage ("Path to mapping file is: "+$PathToMappingFile) -ToOutput $true
Write-YcLogMessage ("PathToCsv is: "+$PathToCsv) -ToOutput $true
Write-YcLogMessage ("OutputCSVPath is: "+$OutputCSVPath) -ToOutput $true
Write-YcLogMessage ("APIProv_APIAppServicePrincipalId is: "+$APIProv_APIAppServicePrincipalId) -ToOutput $true
Write-YcLogMessage ("APIProv_AzureAppRegistrationClientId is: "+$APIProv_AzureAppRegistrationClientId) -ToOutput $true
Write-YcLogMessage ("APIProv_CertificateThumbprint is: "+$APIProv_CertificateThumbprint) -ToOutput $true
Write-YcLogMessage ("tenantId: "+$tenantId) -ToOutput $true

Write-YcLogMessage "Done reading config." -ToOutput $true
Write-YCLogMessage "----------------------------------------------------------------" -ToOutput $true

try {
    Write-YcLogMessage ("Creating .csv from mapping in: "+$PathToMappingFile) -ToOutput $true
    New-YcIAMCsvFromMapping -AttributeMappingFilePath $PathToMappingFile -OutputCSVPath $OutputCSVPath
    Write-YcLogMessage ("Successfully created empty .csv from mapping")
}
catch {
    throw ("Could not create .csv from mapping. Error details: " + $_.Exception.Message)
}

try {
    Write-YcLogMessage ("Adding user info to .csv.. ") -ToOutput $true
    Add-YcIAMRowToImportCSV -csvPath $OutputCSVPath -Firstname $Firstname -LastName $lastname -EmployeeId $employeeId -UserName $username -JobTitle $jobtitle -CountryCode $CountryCode -OnboardingDate $OnboardingDate -StreetAddress $StreetAddress -City $City -ZipCode $ZipCode -OfficePhone $OfficePhone -TelephoneNumber $TelephoneNumber -Company $Company -Team $team -Department $department -Manager $manager
    Write-YcLogMessage ("Successfully added user info to .csv") -ToOutput $true
}
catch {
    throw ("Could not add user info to .csv. Error Details: " + $_.Exception.Message)
}

try {
    Write-YcLogMessage ("Sending SCIM Body as POST request to EntraID provisioning API...") -ToOutput $true
    New-YcIAMSCIMRequest -UseConfig $false -PathToCsv $OutputCSVPath -PathToMappingFile $PathToMappingFile -APIProv_APIAppServicePrincipalId $APIProv_APIAppServicePrincipalId -APIProv_AzureAppRegistrationClientId $APIProv_AzureAppRegistrationClientId -APIProv_CertificateThumbprint $APIProv_CertificateThumbprint -tenantId $tenantId
    Write-YcLogMessage ("Successfully sent SCIM Body as POST request to EntraID provisioning API. Check provisoning logs from here.") -ToOutput $true
}
catch {
    throw ("Could not send off SCIM Request. Error Details: " + $_.Exception.Message)
}