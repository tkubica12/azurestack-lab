# Azure Stack lab - Day 4: Azure Stack Operator
During third day we will practice:
- Managing quotas, plans, offers and subscriptions
- Creating custom marketplace items
- Billing

## Prerequisities
Check [README](./README.md)

## Step XX - Connect to Azure Stack Administration via PowerShell
Install PowerShell modules according to [documentation](https://docs.microsoft.com/cs-cz/azure-stack/operator/azure-stack-powershell-install)

Connect
```powershell
$baseDomain = "local.azurestack.external"
$arm = "adminmanagement"
$vault = "adminvault"
$AADTenantName = "<myDirectoryTenantName>.onmicrosoft.com"

$armEndpoint = "https://$arm.$baseDomain"
$vaultDns = "$vault.$baseDomain" 
$vaultEndpoint = "https://$vault.$baseDomain" 

Add-AzureRMEnvironment -Name "AzureStackAdmin" -ArmEndpoint $endpoint `
    -AzureKeyVaultDnsSuffix $vaultDns `
    -AzureKeyVaultServiceEndpointResourceId $vaultEndpoint

$AuthEndpoint = (Get-AzureRmEnvironment -Name "AzureStackAdmin").ActiveDirectoryAuthority.TrimEnd('/')
$TenantId = (invoke-restmethod "$($AuthEndpoint)/$($AADTenantName)/.well-known/openid-configuration").issuer.TrimEnd('/').Split('/')[-1]

Add-AzureRmAccount -EnvironmentName "AzureStackAdmin" -TenantId $TenantId
```

Test you can access admin information, eg.:
```powershell
Get-AzsScaleUnitNode
```

## Step XX - prepare tools for custom marketplace items
Structure of required files is documented [here](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-create-and-publish-marketplace-item). Packaging tool is in marketplaceItems folder, but you may want to check whether there is new version available [here](https://www.aka.ms/azurestackmarketplaceitem).

## Step XX - custom marketplace item using VM image
## Step XX - custom marketplace item using ARM template and default GUI
We will use example in netDemo folder which is based on ARM template we built in previous labs. Look into file structure - DeploymentTemplate store ARM templates, Icons store icons in various resolutions, strings folder defines item name and description. In root folder there is Manifest.json with basic links and UIDefinition.json which in our case does not introduce any specific GUI elements, rather just referencing ARM deployment GUI.

You can package this item like this:

```powershell
cd marketplaceItems
./AzureGalleryPackager.exe package -m netDemo/Manifest.json -o .\packages\
```
## Step XX - custom marketplace item using custom GUI components




