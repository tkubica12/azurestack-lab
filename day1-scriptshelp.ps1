# Connect
az login
az account set --subscription tokubica

# Step 2
$region = "local"   # $region = "westeurope" 
az group create -n net-rg -l $region
az network vnet create -n net -g net-rg --address-prefix 10.0.0.0/16
az network vnet subnet create -n jump `
    -g net-rg `
    --vnet-name net `
    --address-prefixes 10.0.0.0/24
az network vnet subnet create -n domaincontroller `
    -g net-rg `
    --vnet-name net `
    --address-prefixes 10.0.1.0/24
az network vnet subnet create -n webfarm `
    -g net-rg `
    --vnet-name net `
    --address-prefixes 10.0.2.0/24
az network vnet subnet create -n backend `
    -g net-rg `
    --vnet-name net `
    --address-prefixes 10.0.3.0/24

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
    --subnet $(az network vnet subnet show -g net-rg --name backend --vnet-name net --query id -o tsv) `
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
