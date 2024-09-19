# Define the WebHook URL
$webhookUrl = ""
$userAgent = ""
$clientId = "" 
$APIKey = ""

# Define the payload 
$payload = @{
    "Company" = "Company"
    "EmployeeId" = "5634"
    "Firstname" = "Hans"
    "Lastname" = "Wurscht"
    "Username" = "hans.wurscht"
    "Department" = "testdept"
    "Team" = "IT"
    "JobTitle" = "Spezi"
    "Manager" = "peter.wurscht"
    "onboardingDate" = "2024-09-20"
    "Telephone" = "1234525"
    "CountryCode" = "CH"
    "City" = "City"
    "OfficePhone" = "1231312"
    "StreetAddress" = "Street"
    "ZipCode" = "12334"
}

$payloadJson = $payload | ConvertTo-Json

# Define custom headers
$headers = @{
    "X-APIKey" = $APIKey   
    "X-Timestamp" = ((Get-Date).ToString("o"))  # ISO 8601 format
    "X-ClientId" = $clientId            
    "User-Agent" = $userAgent                  
}

# Send the POST request with custom headers
Invoke-RestMethod -Uri $webhookUrl -Method POST -Body $payloadJson -ContentType "application/json" -Headers $headers

