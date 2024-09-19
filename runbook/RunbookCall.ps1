# Define the WebHook URL
$webhookUrl = "https://40d31616-3614-4b2f-ab7b-b88b27f680a7.webhook.stzn.azure-automation.net/webhooks?token=2mFGOVhupAm9Hp7xreR479XHYIXu%2bGMlllLD3iDCrfI%3d"
$APIKey = "kt+a9euHJBp-j%e2*NE*FT8WeVQcsrKnO-g--3cuDZ8w9U%7wMb-&bnBvCSQo1?W-2i2z7UN7*0dK@gWW0Zgr_W#3ReRN&5hXZElcjOWPbIuKkmN0Iu@VKsD=VDUIUnY"

# Define the payload 
$payload = @{
    "APIKey" = $APIKey
    "Company" = "Speedgoat"
    "EmployeeId" = "5634"
    "Firstname" = "Hans"
    "Lastname" = "Wurscht"
    "Username" = "hans.wurscht"
    "Department" = "Corp Dev"
    "Team" = "IT"
    "JobTitle" = "Spezi"
    "Manager" = "Yanik.Maurer"
    "onboardingDate" = "2024-09-18"
    "Telephone" = "0791901245"
    "CountryCode" = "CH"
    "City" = "Liebefeld"
    "OfficePhone" = "079123414"
    "StreetAddress" = "Strasse"
    "ZipCode" = "3762"
}

# Convert the payload to JSON
$payloadJson = $payload | ConvertTo-Json

# Send the POST request
Invoke-RestMethod -Uri $webhookUrl -Method POST -Body $payloadJson -ContentType "application/json"