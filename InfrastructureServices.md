# Azure Stack lab - Day 1: Infrastructure services
During first day we will practice:
- RBAC
- Creating infrastructure using GUI and CLI
- Using VM extensions for automation
- Using domain controllers and DNS in Azure Stack
- Web farm using Virtual Machine Scale Set
- Using Azure Monitor to monitor Azure Stack
- Automating everything with ARM templates


- [Azure Stack lab - Day 1: Infrastructure services](#azure-stack-lab---day-1-infrastructure-services)
  - [Prerequisities](#prerequisities)
  - [Guidelines](#guidelines)
  - [Step 1 - RBAC](#step-1---rbac)
  - [Step 2 - basic networking](#step-2---basic-networking)
  - [Step 3 - jump VM](#step-3---jump-vm)
  - [Step 4 - create domain controller VM and install domain](#step-4---create-domain-controller-vm-and-install-domain)
  - [Step 5 - prepare image for backend](#step-5---prepare-image-for-backend)
  - [Step 6 - create app-01-vm virtual machine](#step-6---create-app-01-vm-virtual-machine)
  - [Step 7 - create app-02-vm and automatically join it to domain](#step-7---create-app-02-vm-and-automatically-join-it-to-domain)
  - [Step 8 - Linux-based balanced web farm using Virtual Machine Scale Set](#step-8---linux-based-balanced-web-farm-using-virtual-machine-scale-set)
  - [Step 9 - monitor using Azure services](#step-9---monitor-using-azure-services)
  - [Step 10 - automate networking environment using basic ARM template](#step-10---automate-networking-environment-using-basic-arm-template)
  - [Step 11 - automate jump server creation with ARM template](#step-11---automate-jump-server-creation-with-arm-template)
  - [Step 12 - automate creation of multiple app servers in Availability Set and internal load balancer with ARM template](#step-12---automate-creation-of-multiple-app-servers-in-availability-set-and-internal-load-balancer-with-arm-template)
  - [Step 13 - automate creation of web farm with VMSS, Load Balancer and OS provisioning with PowerShell DSC](#step-13---automate-creation-of-web-farm-with-vmss-load-balancer-and-os-provisioning-with-powershell-dsc)
  - [Step 14 - put everything together with master template](#step-14---put-everything-together-with-master-template)
  - [Step 15 - securing secrets with Azure Key Vault](#step-15---securing-secrets-with-azure-key-vault)
  - [Step 16 - cleanup all resources](#step-16---cleanup-all-resources)

## Prerequisities
Check [README](./README.md)

## Guidelines
Follow lab using this guide. Some tasks are accomplished via GUI, some via CLI, some with ARM templates. You will get examples of syntax so you can create commands yourself.

For your convenience there is complete set of commands available at [InfrastructureServices-scriptshelp.ps1](./InfrastructureServices-scriptshelp.ps1). This for your reference and ability to quickly recreate lab environment. Please **DO NOT use it during labs**, try work yourself and use examples to come up with right solutions.

If you have been added as Guest to AAD you will need to use domain hint when bookmarking portal URL. Eg. if you are tomas@homeaad.cz being added as guest to mystack.onmicrosoft.com you will have to access portal at something like https://portal.myregion.mystack.cz/mystack.onmicrosoft.com

## Step 1 - RBAC
For purposes of this lab make sure all resource providers are registered. Go to Subscription -> yoursubscription -> Resource Providers and register all listed.

Create Resource Group named (yourname)-shared-rg and give colleague on your left access on Reader level. Also create Resource Group (yourname)-notshared-rg with no additional RBAC configurations.

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
# First connect you laptop CLI to Azure stack
$domain = "local.azurestack.external"
az cloud register -n AzureStack `
    --endpoint-resource-manager "https://management.$domain" `
    --suffix-storage-endpoint $domain `
    --suffix-keyvault-dns ".vault.$domain" `
    --profile "2019-03-01-hybrid"
az cloud set -n AzureStack
az login
# If you are using guest account login with command az login --tenant hostingdomain.onmicrosoft.com where you specify hosting domain in which you have been added as guest


# Create subnet
az network vnet subnet create -n domaincontroller `
    -g net-rg `
    --vnet-name net `
    --address-prefix 10.0.1.0/24
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
    -n AllowRDP `
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
$subnetId = $(az network vnet subnet show -g net-rg --name domaincontroller --vnet-name net --query id -o tsv)
az vm create -n ad-dc-vm `
    -g ad-dc-rg `
    --image "MicrosoftWindowsServer:WindowsServer:2016-Datacenter:latest" `
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

Update DNS settings in VNET to point to ad-dc-vm using GUI or CLI. This how you do it with CLI:
```powershell
az network vnet update -g net-rg -n net --dns-servers 10.0.1.10
```

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
az storage account create -n $storageName `
    -g web-rg `
    --sku Standard_LRS
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
To ease setup of monitoring environment in Azure use ARM template in monitoring folder:
- In your Azure environment click + and search for Template Deployment
- Click Edit Template and copy contents of deploy.json file there
- Enter parameters such as resource group, globaly unique workspace name (eg. mynameworkspace7913) and automation account name
- Deploy template

Template will configure Log Analytics workspace, telemetry gathering, logs gathering, automation account, update management solution, inventory and change tracking, VM Health solution and dependency map.

In Azure portal click on Log Analytics workspace that has been created, go to Advance settings and write down Workspace ID and Workspace Key.

In Azure Stack add Azure Monitor extension and Dependency extension to all your VMs.

It will take some time for solution to gather details about our environment, so we will come later to check results.


## Step 10 - automate networking environment using basic ARM template
Deploy ARM template with VNET, one subnet and one NSG.

```powershell
$region = "local"
az group create -n arm-net-rg -l $region
az group deployment create -g arm-net-rg `
    --template-file networking.json
```

Modify template to add the following:
- "app" subnet with range 10.1.1.0/24
- "web" subnet with range 10.1.2.0/24
- "app-nsq" to allow RDP access only from jump subnet
- "web-nsg" to allow RDP access only from jump subnet and HTTP from anywhere

Do this step by step and always ensure template is deployable. Since template is desired state you can apply it over and over.
```powershell
az group deployment create -g arm-net-rg `
    --template-file networking.json
```

After you are done make sure you have not missed proper dependsOn configuration by deleting resource group and deploying complete solution again.
```powershell
az group delete -n arm-net-rg -y
az group create -n arm-net-rg -l $region
az group deployment create -g arm-net-rg `
    --template-file networking.json
```

## Step 11 - automate jump server creation with ARM template
Use template jump.json in arm-lab folder to deploy jump server, but there are few issues we want to fix. First let's try deployment.
```powershell
az group create -n arm-jump-rg -l $region
az group deployment create -g arm-jump-rg `
    --template-file jump.json `
    --parameters vnetName=arm-net `
    --parameters vnetResourceGroupName=arm-net-rg `
    --parameters subnetName=jump
```

There are few problems with this template. Solve it one by one:
1. Deployment fails due to error. Troubleshoot in Deployment section of GUI on Resource Group. Find reason and fix it.
2. Public IP is created, but not associated with NIC. Solve that and redeploy template. Find solution in documentation, quickstart template examples or configure association manualy in GUI and use Resource Explorer to find out, how syntax looks like (then tweek ARM template, remove association in GUI and redeploy).
3. VM username is hardcoded. Make it parameter and redeploy (submit the same name of labuser as changing name via ARM template is not possible without deleting resource first).
4. VM size is hardcoded, make it parameter, but do not allow for any VM size - allow just Standard_DS1_v2 and Standard_DS2_v2 and redeploy.

In fix for problem number 2 have you used dependsOn so deployment does not fail when running from scratch?

Check how it looks when you would deploy template via GUI.

## Step 12 - automate creation of multiple app servers in Availability Set and internal load balancer with ARM template

We will use template in arm-lab folder called app.json to deploy multiple servers in Availability Set and behind load balancer with private IP. Template is designed to deploy any number of servers using copy loops with count being parameter.

```powershell
az group create -n arm-app-rg -l $region
az group deployment create -g arm-app-rg `
    --template-file app.json `
    --parameters vnetName=arm-net `
    --parameters vnetResourceGroupName=arm-net-rg `
    --parameters subnetName=app `
    --parameters adminUsername=labuser `
    --parameters adminPassword=Azure12345678 `
    --parameters vmSize=Standard_DS1_v2 `
    --parameters count=2
```

Again there are few problems with this template:
1. Deployment fails. Investigate what is going on and fix it.
2. Load balancer is created, but there is no VM in backend pool. Fix it.

Let's now redeploy final template with increased count of VMs. We expect existing VMs will not be touched, but one additional will be created in availability set and added to load balancing pool.

```powershell
az group deployment create -g arm-app-rg `
    --template-file app.json `
    --parameters vnetName=arm-net `
    --parameters vnetResourceGroupName=arm-net-rg `
    --parameters subnetName=app `
    --parameters adminUsername=labuser `
    --parameters adminPassword=Azure12345678 `
    --parameters vmSize=Standard_DS1_v2 `
    --parameters count=3
```

Investigate what happens if we now redeploy with lower count.

```powershell
az group deployment create -g arm-app-rg `
    --template-file app.json `
    --parameters vnetName=arm-net `
    --parameters vnetResourceGroupName=arm-net-rg `
    --parameters subnetName=app `
    --parameters adminUsername=labuser `
    --parameters adminPassword=Azure12345678 `
    --parameters vmSize=Standard_DS1_v2 `
    --parameters count=2
```

As you will shorty ARM have not removed 3rd server. This is because default deployment command is using Incremental mode to prevent beginners to accidentaly delete resources they have not intended to. But we know what we are doing so will run this in pure desired state mode (Complete) where resources that exist in Azure, but are not covered by template, are going to be deleted.

```powershell
az group deployment create -g arm-app-rg `
    --template-file app.json `
    --parameters vnetName=arm-net `
    --parameters vnetResourceGroupName=arm-net-rg `
    --parameters subnetName=app `
    --parameters adminUsername=labuser `
    --parameters adminPassword=Azure12345678 `
    --parameters vmSize=Standard_DS1_v2 `
    --parameters count=2 `
    --mode Complete
```

Be careful with mode Complete. It is powerful and pure desired state, but can be risky for beginners.

## Step 13 - automate creation of web farm with VMSS, Load Balancer and OS provisioning with PowerShell DSC

Web farm will consist of set of identical servers and in order to easily upgrade we will use Virtual Machine Scale Set. This time we use Windows OS and PowerShell DSC to automate installation of web server (IIS).

For installation see IIS.ps1. We need to zip it and store in storage account so deployment process can access it. Let's prepare deployment repository, upload files and get read only token.

```powershell
# Create Resource Group
az group create -n arm-repo-rg -l $region

# Create Storage Account and get connection string
$storageName = "tomasuniquename123"
az storage account create -g arm-repo-rg -l $region -n $storageName
$storageConnectionString = $(az storage account show-connection-string -g arm-repo-rg -n $storageName -o tsv)

# Create storage container
az storage container create -n deploy --connection-string $storageConnectionString

# Package IIS.ps1 to zip file
Compress-Archive -Path IIS.ps1 -DestinationPath IIS.zip

# Upload zip file to storage container
az storage blob upload -f IIS.zip `
    -c deploy `
    -n IIS.zip `
    --connection-string $storageConnectionString
```

Template contains quite a lot of parameters so let them store in parameters file rather than inside CLI command. Make sure you update web.parameters.json with your values for baseUrl and generate storage token with this command:

```powershell
az storage container generate-sas -n deploy `
    --connection-string $storageConnectionString `
    --https-only `
    --permissions r `
    --expiry "2030-1-1T00:00Z" `
    -o tsv
```

We have not specified adminPassword in file. It is not good practice to store sensitive values in deployment files so we will assign adminPassword via CLI (note storageToken might be also considered sensitive, but we will solve that later).

```powershell
az group create -n arm-web-rg -l $region
az group deployment create -g arm-web-rg `
    --template-file web.json `
    --parameters "@web.parameters.json" `
    --parameters adminPassword=Azure12345678
```

## Step 14 - put everything together with master template
At this point we have automated a lot of task to build our solution, but each component is separate template and we need to run them in correct order. In this step we will automate even that by creating master template.

In previous step we have created deployment repo in arm-deploy resource group. We will use our storage account to store templates we have prepared so far.

```powershell
$storageConnectionString = $(az storage account show-connection-string -g arm-repo-rg -n $storageName -o tsv)

az storage blob upload -f web.json `
    -c deploy `
    -n web.json `
    --connection-string $storageConnectionString
az storage blob upload -f networking.json `
    -c deploy `
    -n networking.json `
    --connection-string $storageConnectionString
az storage blob upload -f jump.json `
    -c deploy `
    -n jump.json `
    --connection-string $storageConnectionString
az storage blob upload -f app.json `
    -c deploy `
    -n app.json `
    --connection-string $storageConnectionString
```

Master template will call linked templates in storage. Make sure web, jump and app are deployed in parallel, but all depend on networking. Master template will have all parameters and will pass them to linked templates.

First let's create resource groups for new environment.

```powershell
$resourceGroupPrefix = "arm2"
az group create -n $resourceGroupPrefix-web-rg -l $region
az group create -n $resourceGroupPrefix-app-rg -l $region
az group create -n $resourceGroupPrefix-jump-rg -l $region
az group create -n $resourceGroupPrefix-net-rg -l $region
```

Modify master.parameters.json with your storage account URL and token as we did in previous step. Let's deploy master template.

```powershell
az group deployment create -g $resourceGroupPrefix-net-rg `
    --template-file master.json `
    --parameters "@master.parameters.json" `
    --parameters adminPassword=Azure12345678
```

Note that template currently covers only networking, jump and app, but not web.json template. **Fix it.**

## Step 15 - securing secrets with Azure Key Vault
Last point we want to solve is more secure way of managing secrets such as adminPassword and storageToken. We will store those in Azure Key Vault to provide strong security, RBAC, separated secrets management and ability to access secrets, keys and certificaties not only during deployment, but also from applications directly.

In arm-repo-rg resource group we will create Key Vault, enable access to it from ARM deployment process and store adminPassword there.

```powershell
# Create Key Vault and store secret
$keyVaultName = "tomasuniquevault123"
az keyvault create -l $region `
    -n $keyVaultName `
    -g arm-repo-rg `
     --enabled-for-template-deployment
az keyvault secret set -n mojeHeslo `
    --vault-name $keyVaultName `
    --value Azure12345678

# Get Key Vault ID
az keyvault show -n $keyVaultName `
    -g arm-repo-rg `
    --query id `
    -o tsv
```

Modify master.parameters.json to add adminPassword as reference to your Key Vault.

```json
        "adminPassword": {
            "reference": {
              "keyVault": {
                "id": "/subscriptions/mysubscriptionid/resourceGroups/arm-repo-rg/providers/Microsoft.KeyVault/vaults/tomasuniquevault123"
              },
              "secretName": "mojeHeslo"
            }
        }
```

Deploy template.

```powershell
az group deployment create -g $resourceGroupPrefix-net-rg `
    --template-file master.json `
    --parameters "@master.parameters.json"
```

Do the same for storageToken.

## Step 16 - cleanup all resources
Delete all resources created today.

```powershell
az group delete -n ad-dc-rg -y --no-wait
az group delete -n images-rg -y --no-wait
az group delete -n jump-rg -y --no-wait
az group delete -n app-rg -y --no-wait
az group delete -n web-rg -y --no-wait
az group delete -n arm-repo-rg -y --no-wait
az group delete -n arm-jump-rg -y --no-wait
az group delete -n arm-app-rg -y --no-wait
az group delete -n arm-web-rg -y --no-wait
az group delete -n arm2-jump-rg -y --no-wait
az group delete -n arm2-app-rg -y --no-wait
az group delete -n arm2-web-rg -y --no-wait

## Wait for all previous resource groups to be deleted and then destroy networking
az group delete -n net-rg -y --no-wait
az group delete -n arm-net-rg -y --no-wait
az group delete -n arm2-net-rg -y --no-wait
```