# Define the WebHook URL
$webhookUrl = "" #Webhhook URL of Runbook
$APIKey = "" #Defined as var in Azure Automation account

# Define the payload 
$payload = @{
    "APIKey" = $APIKey
    "Company" = "MyCompany"
    "EmployeeId" = "5634"
    "Firstname" = "Hans"
    "Lastname" = "Wurscht"
    "Username" = "hans.wurscht"
    "Department" = "Corp Dev"
    "Team" = "IT"
    "JobTitle" = "Spezi"
    "Manager" = "hans.peter"
    "onboardingDate" = "2024-09-18"
    "Telephone" = "1827839"
    "CountryCode" = "CH"
    "City" = "SoemCity"
    "OfficePhone" = "891327823"
    "StreetAddress" = "Street"
    "ZipCode" = "XXXX"
}

# Convert the payload to JSON
$payloadJson = $payload | ConvertTo-Json

# Send the POST request
Invoke-RestMethod -Uri $webhookUrl -Method POST -Body $payloadJson -ContentType "application/json"
