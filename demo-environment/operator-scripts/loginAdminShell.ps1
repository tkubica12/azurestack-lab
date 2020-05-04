

# Register an Azure Resource Manager environment that targets your Azure Stack Hub instance. Get your Azure Resource Manager endpoint value from your service provider.
Add-AzureRMEnvironment -Name "AzureStackAdmin" -ArmEndpoint "https://adminmanagement.prghub.hpedu.cz" `
    -AzureKeyVaultDnsSuffix adminvault.prghub.hpedu.cz `
    -AzureKeyVaultServiceEndpointResourceId https://adminvault.prghub.hpedu.cz

# Set your tenant name.
$AuthEndpoint = (Get-AzureRmEnvironment -Name "AzureStackAdmin").ActiveDirectoryAuthority.TrimEnd('/')
$AADTenantName = "azurestackprg.onmicrosoft.com"
$TenantId = (invoke-restmethod "$($AuthEndpoint)/$($AADTenantName)/.well-known/openid-configuration").issuer.TrimEnd('/').Split('/')[-1]

# After signing in to your environment, Azure Stack Hub cmdlets
# can be easily targeted at your Azure Stack Hub instance.
Add-AzureRmAccount -EnvironmentName "AzureStackAdmin" -TenantId $TenantId