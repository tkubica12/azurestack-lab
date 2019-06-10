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

## Step 3 - jump VM
Create Resource Group named jump-rg.

Create VM jump-vm in jump-rg in subnet jump using Windows and size Standard_DS2 with Public IP. On firewall open port 3389 (RDP) only.

Make sure you can connect to this VM.

## Step 4 - create domain controller VM and install domain
Create Resource Group names ad-dc-rg.

Use CLI to create VM ad-dc-vm in ad-dc-rg in subnet domaincontroller with Windows with no Public IP and static Private IP 10.0.1.10. Create Network Security Group that will deny RDP traffic except from jump subnet and allow all other traffic within VNET. Add additional data disk.

Make sure you can connect to ad-dc-vm from jump-vm.

Format additional data disk and install Domain Controller on ad-dc-vm and setup DNS server.

Update DNS settings in VNET to point to ad-dc-vm.

## Step 5 - prepare image for backend
Use CLI to prepare Network Security Group for backend subnet. Deny all RDP traffic except from jump subnet. 

Create Resource Group named imageprepare-rg and images-rg.

Use CLI to create VM named appimage-vm in imageprepare-rg in backend subnet using Windows base image.

Connect to VM and install Chrome. Use sysprep, capture image and store it in images-rg. Delete Resource Group imageprepare-rg.

## Step 6 - create app-01-vm virtual machine
Create Availability Set names app-as.

Create VM app-01-vm using your custom image in backend subnet, images-rg Resource Group and place in app-as using GUI.

Connect to VM and join it to domain.

## Step 7 - create app-02-vm and automatically join it to domain
Create VM app-03-vm using your custom image in backend subnet, images-rg Resource Group and place in app-as using CLI.

Use Join VM extension to automatically join VM to domain.

## Step 8 - Linux-based balanced web farm using Virtual Machine Scale Set
Prepare Network Security Group. Deny all SSH traffic except from jump subnet. Allow http (80) from any location.

Use VMSS to create web farm with following attributes:
- Use Azure LB with public IP
- Use Ubuntu 16.04 image
- Use Linux script extension to automatically install NGINX and static web
- Create farm with 3 replicas

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