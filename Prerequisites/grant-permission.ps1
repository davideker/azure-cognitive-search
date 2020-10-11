#https://docs.microsoft.com/en-us/powershell/module/azuread/new-azureadserviceapproleassignment?view=azureadps-2.0
$Text = Get-Date -Format "dddd MM/dd/yyyy HH:mm K"
$MD5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$UTF8 = new-object -TypeName System.Text.UTF8Encoding
$Hash = [System.BitConverter]::ToString($md5.ComputeHash($UTF8.GetBytes($Text)))
$Hash = $Hash.ToLower() -replace '-', ''
$Name =  'powershellAutomation' + $Hash
$RGName = 'powershell-automation-' + $Hash

$TenantId = Read-Host 'Enter Your TenantId' 
$Region = Read-Host 'Enter Your Region' 
Connect-AzureAD -TenantId $TenantId

New-AzResourceGroup -Name $RGName -Location $Region #EastUS
$ADObject = New-AzUserAssignedIdentity -Name $Name -ResourceGroupName $RGName 
Write-Debug $ADObject

# Windows Azure Active Directory
$GraphAppId = "00000002-0000-0000-c000-000000000000" 
$GraphServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$GraphAppId'"

$PermissionName = "Application.ReadWrite.OwnedBy"
$AppRole = $GraphServicePrincipal.AppRoles  `
       | Where-Object {$_.Value -eq $PermissionName `
       -and $_.AllowedMemberTypes -contains "Application"}


Write-Debug $AppRole  

Start-Sleep -S 30

New-AzRoleAssignment -ObjectId $ADObject.PrincipalId -RoleDefinitionName 'Owner' -ResourceGroupName $RGName
New-AzureADServiceAppRoleAssignment `
    -ObjectId $ADObject.PrincipalId `
    -PrincipalId $ADObject.PrincipalId  `
    -ResourceId $GraphServicePrincipal.ObjectId `
    -Id $AppRole.Id 

$Hash
