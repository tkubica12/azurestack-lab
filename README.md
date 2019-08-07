# Azure Stack lab
This repo contains labs for Azure Stack with main focus on tenant capabilities and features.

Latest version tested: 1907

## Prerequisities
- Each participant need to be able to log into both Azure Stack and Azure
- Each participant to have his own subscription in Azure Stack as Owner using plan with all services enabled and unlimited quota
- Install Application Services resource provider on Azure Stack in default configuration and configure the following:
  - [Preparation](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-app-service-before-you-get-started)
  - [Install](https://docs.microsoft.com/en-us/azure-stack/operator/app-service-deploy-ha)
  - Scale number of dedicated worker nodes in Small tier to double amount of participants
  - Configure GitHub deployment according to [https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-app-service-configure-deployment-sources#configure-github](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-app-service-configure-deployment-sources#configure-github)
- Install SQL resource provider, SQL server and add SKU
- Download following items to marketplace:
  - Latest Windows 2016 Datacenter (PAYG)
  - Latest Ubuntu 16.04
  - Virtual Machine Scale Set
  - Windows and Linux script extensions
  - Join Domain extension
  - Latest Kubernetes
  - Azure Monitor, Update and Configuration Management extension for Windows and Linux
  - Azure Monitor Dependency Agent extension for Windows and Linux
  - SQL images (SQL Standard 2017 on Windows)
  - Networking appliances - lab is design for Fortinet (download image item + template item)
- Each participant to have access to **Azure** shared subscription in one Resource Group (participantname-rg) on Contributor level (or his own subscription)
- Unrestricted Internet access for each participant (no blocking of SSH or RDP)
- Install tools on participant notebook:
  - Azure CLI [download](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
  - Visual Studio Code [download](https://code.visualstudio.com/download)
  - Visual Studio Community 2019 [download](https://visualstudio.microsoft.com/thank-you-downloading-visual-studio/?sku=Community&rel=16)
  - Storage Explorer [download](https://azure.microsoft.com/cs-cz/features/storage-explorer/)
  - WinSCP [download](https://winscp.net/eng/download.php)
  - PuttyGen [download](https://www.puttygen.com/)
  - Kubectl.exe [Download](https://storage.googleapis.com/kubernetes-release/release/v1.15.0/bin/windows/amd64/kubectl.exe) and place it to folder that is in your PATH
  - SSH client such as Putty, SSH for Windows 10, WSL or Linux
- Service Principal account in AAD for each participant or one shared (will be used for Kubernetes and Fortinet)
  - [Guide to create account](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#create-an-azure-active-directory-application)
  - [Guide to generate secret for account](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#create-a-new-application-secret)
- Get trial licenses from vendors of your choice (Check Point comes with 15 trial built in, F5 does not - check how it is with Fortinet)
- Make yourself familiar with [operator documentation](https://docs.microsoft.com/en-us/azure-stack/operator/) and [user documentation](https://docs.microsoft.com/en-us/azure-stack/user/)
- Read [blog in Czech](https://www.tomaskubica.cz/tag/azurestack/)
- For administrator labs [Operator.md](./Operator.md) you need administrator access to Azure Stack

## Labs
We will split content into four training days:
- [Day 1: Infrastructure services](./InfrastructureServices.md)
- [Day 2: Application platforms](./ApplicationPlatforms.md)
- [Day 3 part 1: Data services](./DataServices.md)
- [Day 3 part 2: Advanced Networking](./AdvancedNetworking.md)
- [Day 4: Azure Stack operator training](./Operator.md)