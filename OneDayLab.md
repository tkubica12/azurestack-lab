# One-day Lab

- [One-day Lab](#one-day-lab)
- [Guidelines](#guidelines)
- [Infrastructure](#infrastructure)
  - [Step 1 - RBAC](#step-1---rbac)
  - [Step 2 - basic networking](#step-2---basic-networking)
  - [Step 3 - jump VM](#step-3---jump-vm)
  - [Step 4 - create domain controller VM and install domain](#step-4---create-domain-controller-vm-and-install-domain)
  - [Step 5 - prepare IIS image for backend](#step-5---prepare-iis-image-for-backend)
  - [Step 6 - create app-01-vm virtual machine](#step-6---create-app-01-vm-virtual-machine)
  - [Step 7 - create app-02-vm and automatically join it to domain](#step-7---create-app-02-vm-and-automatically-join-it-to-domain)
  - [Step 8 - create Load Balancer with private IP and balance traffic to both nodes](#step-8---create-load-balancer-with-private-ip-and-balance-traffic-to-both-nodes)
  - [Step 9 (optional) - Linux-based balanced web farm using Virtual Machine Scale Set](#step-9-optional---linux-based-balanced-web-farm-using-virtual-machine-scale-set)
  - [Step 10 - onboard to Azure Monitor via Azure Arc](#step-10---onboard-to-azure-monitor-via-azure-arc)
- [Application Platforms](#application-platforms)
  - [Step 1 - create and scale WebApp using PaaS and use Deployment Slots to manage versions](#step-1---create-and-scale-webapp-using-paas-and-use-deployment-slots-to-manage-versions)
  - [Step 2 - deploy application via Azure DevOps CI/CD pipeline](#step-2---deploy-application-via-azure-devops-cicd-pipeline)
  - [Step 3 - use serverless to expose API endpoint and store messages in Queue](#step-3---use-serverless-to-expose-api-endpoint-and-store-messages-in-queue)
  - [Step 4 - use serverless to react on message in Queue and create file in Blob storage](#step-4---use-serverless-to-react-on-message-in-queue-and-create-file-in-blob-storage)
  - [Step 5 - create Kuberetes cluster with AKS Engine](#step-5---create-kuberetes-cluster-with-aks-engine)

# Guidelines
Follow lab using this guide. Some tasks are accomplished via GUI, some via CLI, some with ARM templates. You will get examples of syntax so you can create commands yourself.

For your convenience there is complete set of commands available at [InfrastructureServices-scriptshelp.ps1](./InfrastructureServices-scriptshelp.ps1). This for your reference and ability to quickly recreate lab environment. Please **DO NOT use it during labs**, try work yourself and use examples to come up with right solutions.

If you have been added as Guest to AAD you will need to use domain hint when bookmarking portal URL. Eg. if you are tomas@homeaad.cz being added as guest to mystack.onmicrosoft.com you will have to access portal at something like https://portal.myregion.mystack.cz/mystack.onmicrosoft.com

# Infrastructure

## Step 1 - RBAC
For purposes of this lab make sure all resource providers are registered. Go to Subscription -> yoursubscription -> Resource Providers and register all listed.

Create Resource Group named (yourname)-shared-rg and give colleague on your left access on Reader level. Also create Resource Group (yourname)-notshared-rg with no additional RBAC configurations.

Check you can see subscription of one of your colleagues and you can his Resource Group there.

## Step 2 - basic networking
Use GUI to do following tasks:
1. Create Resource Group named net-rg.
2. Create VNET named net and range 10.0.0.0/16.
3. Create subnet named jump with range 10.0.0.0/24

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

## Step 5 - prepare IIS image for backend
Use CLI to prepare Network Security Group app-nsg for backend subnet. Deny all RDP traffic except from jump subnet. 

Create Resource Group named imageprepare-rg and images-rg.

Use CLI to create VM named appimage-vm in imageprepare-rg in backend subnet using Windows base image.

Connect to VM and install IIS. Use sysprep, capture image and store it in images-rg. Delete Resource Group imageprepare-rg.

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

## Step 8 - create Load Balancer with private IP and balance traffic to both nodes
TBD

## Step 9 (optional) - Linux-based balanced web farm using Virtual Machine Scale Set
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

## Step 10 - onboard to Azure Monitor via Azure Arc
TBD

# Application Platforms

## Step 1 - create and scale WebApp using PaaS and use Deployment Slots to manage versions
Usign GUI create Web App named (yourname)-app1 on new Service Plan on Production tier S1. Open Web App page and click on URL - you should see dafult page of your future application.

Go to App Service Editor (Preview) and in WWWROOT folder use right click to create file index.html with "My great app" inthere. Refresh URL of your application - you should see you static web up and running.

Let's now see how you can create additional environments and easily test and release new versions of your application. Go to Deployment slots and click Add Slot. Call it "test" and Do not clone settings.

Click on new slot and go to App Service Editor (Preview) and create index.html with content "New version of my great app".

In Overview section find URL of your test version and open it. You next-version application is running fine.

Go back to deployment slots and configure 20% of users to hit test version and click Save. Now 20% of users will go to new version. In order for single user to not switch randomly platform 2q cookie-based session persistence and browser is holding it. In order to test probability of hitting new version use PowerShell command to access page as it ignores cookies by default:

```powershell
Invoke-WebRequest https://tomas-app1.appservice.local.azurestack.external/
```

Try multiple times and you should see about 20% of responses comming from new version.

After sime time we feel confident with new version, let's swap the slots and release to production. What was test before will become production and previous production will be in test (so you can easily switch back if something goes wrong). Go to Deploment Slots and select Swap. After operation is complete you should see only new version.

You application is now very popular and you need more performance to handle load. Add additional application node by going to Scale out (App Service plan) and increase number to 2. There are now additional steps required, after couple of minutes you have dobled your performance. You also scale back to 1 and because reverse proxy which is part of PaaS holds connections there should be no impact on availability. 

## Step 2 - deploy application via Azure DevOps CI/CD pipeline
TBD

## Step 3 - use serverless to expose API endpoint and store messages in Queue
We will create new Function App (serverless) via GUI. We can use Consumption hosting plan (running in shared plan), but as we already purchased App Service plan dedicated, let's run it there. Use .NET as language and let wizard create storage account.

When environment is ready open it and click on + sign in Functions. Use wizard to select Webhook + API. There is sample code (you do not have to understand it at this point) that takes name as argument and responds with Hello (name). Use Get function URL and copy it to clipboard. Open web browser and paste it in and add "&name=Tomas". Full URL might look something like this:

```
https://mojefunkce.appservice.local.azurestack.external/api/HttpTriggerCSharp1?code=aoBmARujcdaoUgaLIApy8KQOs1QzskpuDmIoKB7BtjV0KP5x/SM5Pg==&name=Tomas
```

This is our first working serverless function. No server to manage, no framework, no need to compile code.

We will now want to create message in queue. There is PaaS service for that which is part of Storage account. We will reuse one already created for our Function. Note that in standard code you would need to authenticate against it and solve how to pass token etc. This will be handled by serverless platform, so we do not have to worry about that. Click on Integrate and + New Output. Select Azure Queue Storage and click Select. On next page we can modify names, but let's keep everything on defaults and click Save.

Go back to HttpTriggerCSharp1 to open code. We will make simple modification to output name to queue. Replace existing code with this one:

```
using System.Net;

public static async Task<HttpResponseMessage> Run(HttpRequestMessage req, TraceWriter log, ICollector<string> outputQueueItem)
{
    log.Info("C# HTTP trigger function processed a request.");

    // parse query parameter
    string name = req.GetQueryNameValuePairs()
        .FirstOrDefault(q => string.Compare(q.Key, "name", true) == 0)
        .Value;

    if (name == null)
    {
        // Get request body
        dynamic data = await req.Content.ReadAsAsync<object>();
        name = data?.name;
    }

    outputQueueItem.Add("Name passed to the function: " + name);

    return name == null
        ? req.CreateResponse(HttpStatusCode.BadRequest, "Please pass a name on the query string or in the request body")
        : req.CreateResponse(HttpStatusCode.OK, "Hello " + name);
}
```

Generate some call as before via browser. Open your Storage Account, go to Queues and you should see messages there.

## Step 4 - use serverless to react on message in Queue and create file in Blob storage
So far we have use HTTP call as trigger and sent output to Queue. We can also run TImer trigger or data related triggers run running code whenever there is new file in blob storage (eg. to run code to resize JPG) or react on message in queue. That is what we will try now.

On Functions click on + sign and this time select Create your own function to select Queue Trigger using C# (click on C# in that box). As queue name type outqueue and click Save. There is sample code that will get message and write to log. Let's test it. Click on logs and keep Window open. You will probably see logs of existing messages being consumed. Go to browser and call our first function again. That will trigger first function that writes message to queue and new message will trigger our second function.

Go to Integrate and click + New Output and this time select Azure Blob Storage, keep everything on defaults and click Save. Replace existing code with this one:

```
using System;

public static void Run(string myQueueItem, TraceWriter log, out string outputBlob)
{
    log.Info($"C# Queue trigger function processed: {myQueueItem}");
    outputBlob = myQueueItem;
}
```

Generate new request for first function via browser. Open Storage Account, go to Blobs and you should see new file stored in outcontainer.

Think about interesting scenarios with Azure Functions:
* Wait for new JPG to be stored in Blob storage and resize to multiple sizes for different screens
* Get requests from application and store in queue, so application can continue on other tasks. Have queue trigger to run background task to process message (eg. create order etc.)
* Upload CSV files to Blob storage and have it trigger Function to process CSV and store in database or do filtering.
* Have IoT sensor messages come to queue (or in future Event Hub) and use Function to process messages (parsing, conversion etc.)
* Think about hybrid scenarios - for example you can collect messages in Azure Stack and trigger function to filter interesting events and send them to Azure Blob Storage for advanced processing in public cloud. Or you can user public cloud Azure to build IoT platform and use Functions in public cloud to process RAW data, but send converted data to Azure Stack Queue, where you trigger Azure Stack Functions to process it and store in local database in Azure Stack.

## Step 5 - create Kuberetes cluster with AKS Engine
TBD