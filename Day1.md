# Azure Stack lab - Day 1
During first day we will practice:
- RBAC
- Creating infrastructure using GUI and CLI
- Using VM extensions for automation
- Using domain controllers and DNS in Azure Stack
- Web farm using Virtual Machine Scale Set
- Using Azure Monitor to monitor Azure Stack
- Using Application Services (PaaS) to deploy and manage applications
- Using serverless in Azure Stack
- Automating everything with ARM templates

## Prerequisities
Check [README](./README.md)

## Guidelines
Follow lab using this guide. Some tasks are accomplished via GUI, some via CLI, some with ARM templates. You will get examples of syntax so you can create commands yourself.

For your convenience there is complete set of commands available at [day1-scriptshelp.ps1](./day1-scriptshelp.ps1). This for your reference and ability to quickly recreate lab environment. Please ** DO NOT use it during labs **, try work yourself and use examples to come up with right solutions.

## Step 1 - RBAC
Create Resource Group named <yourname>-shared-rg and give colleague on your left access on Reader level. Also create Resource Group <yourname>-notshared-rg with no additional RBAC configurations.

Check you can see subscription of one of your colleagues and you can his Resource Group there.

## Step 2 - basic networking
Create Resource Group named net-rg.
Create VNET named net and range 10.0.0.0/16.
Create subnet named jump with range 10.0.0.0/24

Use CLI to create additional subnets:
- domaincontroller (10.0.1.0/24)
- webfarm (10.0.2.0/24)
- backend (10.0.3.0/24)

Example:
```powershell
az network vnet subnet create -n domaincontroller `
    -g net-rg `
    --vnet-name net `
    --address-prefixes 10.0.1.0/24
```

## Step 3 - jump VM
Create Resource Group named jump-rg.

Create VM jump-vm in jump-rg in subnet jump using Windows and size Standard_DS2 with Public IP. On firewall open port 3389 (RDP).

Make sure you can connect to this VM.

## Step 4 - create domain controller VM and install domain
Create Resource Group names ad-dc-rg.

Use CLI to create VM ad-dc-vm in ad-dc-rg in subnet domaincontroller with Windows with no Public IP and static Private IP 10.0.1.10. Create Network Security Group in net-rg resource group that will deny RDP traffic except from jump subnet and allow all other traffic within VNET. Assign NSG to subnet domaincontroller, not to VM directly. Add additional data disk.

Example for creating NSG and assigning to subnet (only Allow is listed, complete with Deny rule for RDP):
```powershell
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
az network vnet subnet update -g net-rg `
    -n domaincontroller `
    --vnet-name net `
    --network-security-group domaincontroller-nsg
```

This how you can create VM:
```powershell
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
```

Make sure you can connect to ad-dc-vm from jump-vm.

Format additional data disk and install Domain Controller on ad-dc-vm and setup DNS server. You can run following script inside of VM. After role is installed server will reboot. Reconnect and continue with setting up DNS forwarder.

```powershell
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
```

Update DNS settings in VNET to point to ad-dc-vm using GUI or CLI.

## Step 5 - prepare image for backend
Use CLI to prepare Network Security Group app-nsg for backend subnet. Deny all RDP traffic except from jump subnet. 

Create Resource Group named imageprepare-rg and images-rg.

Use CLI to create VM named appimage-vm in imageprepare-rg in backend subnet using Windows base image.

Connect to VM and install [Azure Data Studio](https://go.microsoft.com/fwlink/?linkid=2094200). Use sysprep, capture image and store it in images-rg. Delete Resource Group imageprepare-rg.

## Step 6 - create app-01-vm virtual machine
Create Resource Group app-rg.

Create Availability Set named app-as.

Create VM app-01-vm using your custom image in backend subnet, app-rg Resource Group and place in app-as using GUI.

Connect to VM and join it to domain.

## Step 7 - create app-02-vm and automatically join it to domain
Use CLI to create VM app-02-vm using your custom image in backend subnet, app-rg Resource Group and place in app-as using CLI.

Command might look like this:
```powershell
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
```

Use Join Domain extension to automatically join VM to domain. When using CLI in PowerShell we need to use literal string, but still escape double quotes (note in bash this would look a little different):
```powershell
az vm extension set -n JsonADDomainExtension `
    --publisher "Microsoft.Compute" `
    --version "1.3" `
    --vm-name app-02-vm `
    -g app-rg `
    --settings '{\"Name\":\"corp.stack.com\", \"User\":\"labuser@corp.stack.com\", \"Restart\":\"true\", \"OUPath\":\"\", \"Options\":3}' `
    --protected-settings '{\"Password\":\"Azure12345678\"}'
```

## Step 8 - Linux-based balanced web farm using Virtual Machine Scale Set
Prepare Network Security Group web-nsg. Deny all SSH traffic except from jump subnet. Allow http (80) from any location. Apply NSG on web subnet.

Use VMSS to create web farm with following attributes using GUI:
- Place it in resource group web-rg
- Use webfarm subnet in net VNET
- Name it webscaleset
- Use Azure LB with public IP named web-lb-ip
- Select globaly unique DNS name
- Use Ubuntu 16.04 image
- Create farm with 2 replicas

Your web farm is running, but there is now web service installed. We will use VM Extensions Custom Linux Script to automatically install web server (NGINX) and create simple static page.

Use GUI and go to Extensions and add Custom Script for Linux extension. When asked for script file, use app-v1.sh that you download from [here](scripts/app-v1.sh). Use command bash app-v1.sh that should be run.

With this we have updated VMSS model (that includes things like extensions, VM size, image, ...), but existing VMSS is still running on previous configuration. Go to VMSS in GUI, click Instances, select all and click Upgrade. Check web content v1 is served and load balanced.

We will now upgrade model again by modifying extension to call different script that will install v2 version of our "application". GUI has created blob storage account for us and uploaded file. This time we will do this manually and all via CLI.

Create Storage Account (make sure name is globally unique), create Blob container, upload app-v2.sh.

```powershell
$storageName = "myuniquename1919"
az storage account create -n $storageName -g web-rg
az storage container create -n deploy `
    --connection-string $(az storage account show-connection-string -n $storageName -g web-rg -o tsv)

az storage blob upload -f scripts/app-v2.sh `
    -c deploy `
    -n app-v2.sh `
    --connection-string $(az storage account show-connection-string -n $storageName -g web-rg -o tsv)

$v2Uri = $(az storage blob generate-sas -c deploy `
    -n app-v2.sh `
    --permissions r `
    --expiry "2030-01-01" `
    --https-only `
    --full-uri `
    --connection-string $(az storage account show-connection-string -n $storageName -g web-rg -o tsv) `
    -o tsv )
```

Update VMSS model and upgrade it.
```powershell
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
```

## Step 9 - monitor using Azure services
Open Azure portal and prepare monitoring environment:
- Create Log Analytics workspace and write down workspace ID and key
- Configure gathering syslog and Event logs
- Configure gathering telemetry for Windows and Linux
- Create Automation Account
- Enable Update Management, Inventory and Change Tracking in automation account
- Onboard to VM Health solution

In Azure Stack add Azure Monitor extension and Dependency extension to all your VMs.

It will take some time for solution to gather details about our environment, so we will come later to check results.

## Step 10 - create and scale WebApp using PaaS

## Step 11 - enable application monitoring with Application Insights in Azure

## Step 12 - add testing environment and canary release using Deployment Slots

## Step 13 - use serverless to process objects in Blob Storage

## Step 14 - use serverless to react on message in Queue

## Step 15 - automate environment using basic ARM template

## Step 16 - more advanced example of using ARM to automate everything

## Step 17 - learn how to use Azure Monitor with Azure Stack