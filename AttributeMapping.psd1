@{
    externalId   = 'EmployeeId'
    name         = @{
        familyName = 'LastName'
        givenName  = 'FirstName'
    }
    userName     = 'userName'
    title        = 'JobTitle'
    locale        = 'CountryCode'
    timezone = 'onboardingDate'
    addresses    = @(
        @{
            type          = { 'work' }
            streetAddress = 'StreetAddress'
            locality      = 'City'
            postalCode    = 'ZipCode'
            country       = 'CountryCode'
        }
    )
    phoneNumbers = @(
        @{
            type  = { 'other' }
            value = 'OfficePhone'
        },
        @{
            type  = { 'work' }
            value = 'telephoneNumber'
        }
    )
    "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = @{
        employeeNumber = 'EmployeeId'
        organization   = 'Company'
        division       = 'Team'
        department     = 'Department'
        manager        = @{
            value = 'Manager'
        }
    }
}

