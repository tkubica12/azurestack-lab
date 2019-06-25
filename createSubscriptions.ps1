# Check you have correct versions of PowerShell modules for 1905
Get-Module -Name AzureRM -ListAvailable # Should be 2.5.0
Get-Module -Name AzureStackM -ListAvailable # Should be 1.7.

# Update modules if needed
Get-Module -Name Azs.* -ListAvailable | Uninstall-Module -Force -Verbose
Get-Module -Name Azure* -ListAvailable | Uninstall-Module -Force -Verbose
Install-Module -Name AzureRM -RequiredVersion 2.5.0
Install-Module -Name AzureStack -RequiredVersion 1.7.2

# Connect as Azure Stack Administrator
$ArmEndpoint = "https://adminmanagement.local.azurestack.external"
$KeyVault = "https://adminvault.local.azurestack.external"
Add-AzureRMEnvironment -Name "AzureStackAdmin" -ArmEndpoint $ArmEndpoint `
    -AzureKeyVaultDnsSuffix adminvault.local.azurestack.external `
    -AzureKeyVaultServiceEndpointResourceId $KeyVault

$AuthEndpoint = (Get-AzureRmEnvironment -Name "AzureStackAdmin").ActiveDirectoryAuthority.TrimEnd('/')
$AADTenantName = "<myDirectoryTenantName>.onmicrosoft.com"
$TenantId = (invoke-restmethod "$($AuthEndpoint)/$($AADTenantName)/.well-known/openid-configuration").issuer.TrimEnd('/').Split('/')[-1]

Add-AzureRmAccount -EnvironmentName "AzureStackAdmin" -TenantId $TenantId

# Create subscriptions
Get-AzsManagedOffer -Name offer -ResourceGroupName offerrg
$OfferId = ""
$Owners = @(
    "me@domain.cz",
    "you@domain.cz"
)

foreach ($Owner in $Owners) {
    New-AzsUserSubscription -Owner $Owner -OfferId $OfferId -DisplayName $Owner -TenantId $TenantId
}
