#https://docs.microsoft.com/en-us/powershell/module/azuread/enable-azureaddirectoryrole?view=azureadps-2.0
$TenantId = Read-Host 'Enter Your TenantId' 

 Connect-AzureAD -TenantId $TenantId
# Get Guest Inviter directory role template
$roleTemplate = Get-AzureADDirectoryRoleTemplate | ? { $_.DisplayName -eq "Application Administrator" }

# Enable an instance of the DirectoryRole template
Enable-AzureADDirectoryRole -RoleTemplateId $roleTemplate.ObjectId

Get-AzureADDirectoryRole | ? { $_.DisplayName -eq "Application Administrator" }