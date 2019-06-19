# Connect
az cloud register -n AzureStackUser `
    --endpoint-resource-manager "https://management.local.azurestack.external" `
    --suffix-storage-endpoint "local.azurestack.external" `
    --suffix-keyvault-dns ".vault.local.azurestack.external"
az cloud set -n AzureStackUser
az cloud update --profile 2019-03-01-hybrid
az login

# Step 2
$region = "local"   # $region = "westeurope" 
az group create -n net-rg -l $region
az network vnet create -n net -g net-rg --address-prefix 10.0.0.0/16
az network vnet subnet create -n jump `
    -g net-rg `
    --vnet-name net `
    --address-prefix 10.0.0.0/24
az network vnet subnet create -n domaincontroller `
    -g net-rg `
    --vnet-name net `
    --address-prefix 10.0.1.0/24
az network vnet subnet create -n webfarm `
    -g net-rg `
    --vnet-name net `
    --address-prefix 10.0.2.0/24
az network vnet subnet create -n backend `
    -g net-rg `
    --vnet-name net `
    --address-prefix 10.0.3.0/24

# Step 3
az group create -n jump-rg -l $region
$subnetId = $(az network vnet subnet show -g net-rg --name jump --vnet-name net --query id -o tsv)
az vm create -n jump-vm `
    -g jump-rg `
    --image Win2016Datacenter `
    --size Standard_DS1_v2 `
    --admin-username labuser `
    --admin-password Azure12345678 `
    --public-ip-address jump-ip `
    --nsg jump-nsg `
    --nsg-rule RDP `
    --subnet $subnetId

# Step 4
az group create -n ad-dc-rg -l $region
$subnetId = $(az network vnet subnet show -g net-rg --name domaincontroller --vnet-name net --query id -o tsv)
az network nsg create -n domaincontroller-nsg -g net-rg
az network nsg rule create -g net-rg `
    --nsg-name domaincontroller-nsg `
    -n DenyRDP `
    --priority 100 `
    --source-address-prefixes 10.0.0.0/24 `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 3389 `
    --access Allow `
    --protocol Tcp `
    --description "Allow RDP from jump subnet"
az network nsg rule create -g net-rg `
    --nsg-name domaincontroller-nsg `
    -n AllowRDPFromJump `
    --priority 110 `
    --source-address-prefixes '*' `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 3389 `
    --access Deny `
    --protocol Tcp `
    --description "Deny RDP traffic"
az network vnet subnet update -g net-rg `
    -n domaincontroller `
    --vnet-name net `
    --network-security-group domaincontroller-nsg
az vm create -n ad-dc-vm `
    -g ad-dc-rg `
    --image Win2016Datacenter `
    --size Standard_DS1_v2 `
    --admin-username labuser `
    --admin-password Azure12345678 `
    --public-ip-address '""' `
    --private-ip-address 10.0.1.10 `
    --nsg '""' `
    --subnet $subnetId `
    --data-disk-sizes-gb 32

## Connect to VM and use folliwing commands inside
### Format data disk
Get-Disk |
Where partitionstyle -eq raw |
Initialize-Disk -PartitionStyle MBR -PassThru |
New-Partition -AssignDriveLetter -UseMaximumSize |
Format-Volume -FileSystem NTFS -NewFileSystemLabel datadisk2 -Confirm:$false

### Install domain controller
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Import-Module ADDSDeployment
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "F:\Windows\NTDS" `
-DomainMode "Win2012R2" `
-DomainName "corp.stack.com" `
-DomainNetbiosName "CORP" `
-ForestMode "Win2012R2" `
-InstallDns:$true `
-LogPath "F:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "F:\Windows\SYSVOL" `
-Force:$true

### After VM is rebooted setup DNS forwarder to 168.63.129.16
Set-DnsServerForwarder -IPAddress "168.63.129.16" -PassThru

### Disconnect from VM. Following commands will be applied back on your notebook.

az network vnet update -g net-rg -n net --dns-servers 10.0.1.10

# Step 5
## NSG
az network nsg create -n app-nsg -g net-rg
az network nsg rule create -g net-rg `
    --nsg-name app-nsg `
    -n DenyRDP `
    --priority 100 `
    --source-address-prefixes 10.0.0.0/24 `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 3389 `
    --access Allow `
    --protocol Tcp `
    --description "Allow RDP from jump subnet"
az network nsg rule create -g net-rg `
    --nsg-name app-nsg `
    -n AllowRDPFromJump `
    --priority 110 `
    --source-address-prefixes '*' `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 3389 `
    --access Deny `
    --protocol Tcp `
    --description "Deny RDP traffic"
az network vnet subnet update -g net-rg `
    -n backend `
    --vnet-name net `
    --network-security-group app-nsg

## Resource Groups
az group create -n imageprepare-rg -l $region
az group create -n images-rg -l $region

## Create VM
$subnetId = $(az network vnet subnet show -g net-rg --name backend --vnet-name net --query id -o tsv)
az vm create -n appimage-vm `
    -g imageprepare-rg `
    --image Win2016Datacenter `
    --size Standard_DS1_v2 `
    --admin-username labuser `
    --admin-password Azure12345678 `
    --public-ip-address '""' `
    --private-ip-address 10.0.3.100 `
    --nsg '""' `
    --subnet $subnetId

## Connect to VM and install Azure Data Studio
Invoke-WebRequest https://go.microsoft.com/fwlink/?linkid=2094200 -OutFile datastudio.exe
.\datastudio.exe /SILENT

## Use sysprep to generalize OS
C:\Windows\system32\Sysprep\sysprep.exe /oobe /shutdown /generalize

## Capture and store image
az vm deallocate -g imageprepare-rg -n appimage-vm
az vm generalize -g imageprepare-rg -n appimage-vm
az image create -g images-rg `
    -n app-image `
    --source $(az vm show -g imageprepare-rg -n appimage-vm --query id -o tsv)
az group delete -n imageprepare-rg -y --no-wait

# Step 6
az group create -n app-rg -l $region
az vm availability-set create -n app-as -g app-rg

az vm create -n app-01-vm `
    -g app-rg `
    --image $(az image show -g images-rg -n app-image --query id -o tsv) `
    --size Standard_DS1_v2 `
    --admin-username labuser `
    --admin-password Azure12345678 `
    --public-ip-address '""' `
    --nsg '""' `
    --subnet --subnet
    --availability-set app-as

## Connect to VM and use PowerShell to join it to domain
Add-Computer -DomainName corp.stack.com -Restart

# Step 7
az vm create -n app-02-vm `
    -g app-rg `
    --image $(az image show -g images-rg -n app-image --query id -o tsv) `
    --size Standard_DS1_v2 `
    --admin-username labuser `
    --admin-password Azure12345678 `
    --public-ip-address '""' `
    --nsg '""' `
    --subnet $(az network vnet subnet show -g net-rg --name backend --vnet-name net --query id -o tsv) `
    --availability-set app-as

## Use VM Extension to automatically join domain
az vm extension set -n JsonADDomainExtension `
    --publisher "Microsoft.Compute" `
    --version "1.3" `
    --vm-name app-02-vm `
    -g app-rg `
    --settings '{\"Name\":\"corp.stack.com\", \"User\":\"labuser@corp.stack.com\", \"Restart\":\"true\", \"OUPath\":\"\", \"Options\":3}' `
    --protected-settings '{\"Password\":\"Azure12345678\"}'

# Step 8
## Create and apply NSG
az network nsg create -n web-nsg -g net-rg
az network nsg rule create -g net-rg `
    --nsg-name web-nsg `
    -n DenyRDP `
    --priority 100 `
    --source-address-prefixes 10.0.0.0/24 `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 3389 `
    --access Allow `
    --protocol Tcp `
    --description "Allow RDP from jump subnet"
az network nsg rule create -g net-rg `
    --nsg-name web-nsg `
    -n AllowRDPFromJump `
    --priority 110 `
    --source-address-prefixes '*' `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 3389 `
    --access Deny `
    --protocol Tcp `
    --description "Deny RDP traffic"
az network nsg rule create -g net-rg `
    --nsg-name web-nsg `
    -n AllowHttp `
    --priority 120 `
    --source-address-prefixes '*' `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 80 `
    --access Allow `
    --protocol Tcp `
    --description "Allow HTTP from jump subnet"
az network vnet subnet update -g net-rg `
    -n webfarm `
    --vnet-name net `
    --network-security-group web-nsg

## Create Virtual Machine Scale Set
az group create -n web-rg -l $region

az vmss create -n webscaleset `
    -g web-rg `
    --image UbuntuLTS `
    --instance-count 2 `
    --vm-sku Standard_DS1_v2 `
    --admin-username labuser `
    --admin-password Azure12345678 `
    --authentication-type password `
    --public-ip-address web-lb-ip `
    --subnet $(az network vnet subnet show -g net-rg --name webfarm --vnet-name net --query id -o tsv) `
    --lb web-lb

## Create storage account and upload scripts
$storageName = "myuniquename1919"
az storage account create -n $storageName `
    -g web-rg `
    --sku Standard_LRS
az storage container create -n deploy `
    --connection-string $(az storage account show-connection-string -n $storageName -g web-rg -o tsv)
az storage blob upload -f scripts/app-v1.sh `
    -c deploy `
    -n app-v1.sh `
    --connection-string $(az storage account show-connection-string -n $storageName -g web-rg -o tsv)
az storage blob upload -f scripts/app-v2.sh `
    -c deploy `
    -n app-v2.sh `
    --connection-string $(az storage account show-connection-string -n $storageName -g web-rg -o tsv)

$v1Uri = $(az storage blob generate-sas -c deploy `
    -n app-v1.sh `
    --permissions r `
    --expiry "2030-01-01" `
    --https-only `
    --full-uri `
    --connection-string $(az storage account show-connection-string -n $storageName -g web-rg -o tsv) `
    -o tsv )
$v2Uri = $(az storage blob generate-sas -c deploy `
    -n app-v2.sh `
    --permissions r `
    --expiry "2030-01-01" `
    --https-only `
    --full-uri `
    --connection-string $(az storage account show-connection-string -n $storageName -g web-rg -o tsv) `
    -o tsv )

## Update VMSS model for v1 script and upgrade
$v1Settings = '{"fileUris": ["' + $v1Uri + '"]}'
$v1Settings | Out-File v1Settings.json
az vmss extension set --vmss-name webscaleset `
    --name CustomScript `
    -g web-rg `
    --version 2.0 `
    --publisher Microsoft.Azure.Extensions `
    --protected-settings '{\"commandToExecute\": \"bash app-v1.sh\"}' `
    --settings v1Settings.json

az vmss update-instances --instance-ids '*' `
    -n webscaleset `
    -g web-rg

## Update VMSS model for v2 script and upgrade
$v2Settings = '{"fileUris": ["' + $v2Uri + '"]}'
$v2Settings | Out-File v2Settings.json
az vmss extension set --vmss-name webscaleset `
    --name CustomScript `
    -g web-rg `
    --version 2.0 `
    --publisher Microsoft.Azure.Extensions `
    --protected-settings '{\"commandToExecute\": \"bash app-v2.sh\"}' `
    --settings v2Settings.json

az vmss update-instances --instance-ids '*' `
    -n webscaleset `
    -g web-rg

# Step 21 - cleanup
az group delete -n ad-dc-rg -y --no-wait
az group delete -n images-rg -y --no-wait
az group delete -n jump-rg -y --no-wait
az group delete -n app-rg -y --no-wait
az group delete -n web-rg -y --no-wait
az group delete -n arm-jump-rg -y --no-wait
az group delete -n arm-app-rg -y --no-wait
az group delete -n arm-web-rg -y --no-wait
az group delete -n arm2-jump-rg -y --no-wait
az group delete -n arm2-app-rg -y --no-wait
az group delete -n arm2-web-rg -y --no-wait

## Wait for all previous resource groups to be deleted and then destroy net-rg
az group delete -n net-rg -y --no-wait
az group delete -n arm-net-rg -y --no-wait
az group delete -n arm2-net-rg -y --no-wait
