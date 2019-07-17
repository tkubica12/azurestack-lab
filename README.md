# Azure Stack lab

## Prerequisities
- Each participant need to be able to log into both Azure Stack and Azure
- Each participant to have his own subscription in Azure Stack as Owner using plan with all services enabled and unlimited quota
- Install Application Services resource provider on Azure Stack in default configuration and configure the following:
  - [Preparation](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-app-service-before-you-get-started)
  - [Install](https://docs.microsoft.com/en-us/azure-stack/operator/app-service-deploy-ha)
  - Scale number of dedicated worker nodes in Small tier to double amount of participants
  - Configure GitHub deployment according to [https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-app-service-configure-deployment-sources#configure-github](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-app-service-configure-deployment-sources#configure-github)
- For Day 3 install SQL resource provider
- Download following items to marketplace:
  - Latest Windows 2016 Datacenter (PAYG)
  - Latest Ubuntu 16.04
  - Virtual Machine Scale Set
  - Windows and Linux script extensions
  - Join Domain extension
  - Latest Kubernetes
  - Azure Monitor, Update and Configuration Management extension for Windows and Linux
  - Azure Monitor Dependency Agent extension for Windows and Linux
  - For Day 3 download SQL images (SQL Standard 2017 on Windows)
  - For Day 3 deploy additional components:
    - CheckPoint and Fortigate
    - F5
- Each participant to have access to Azure shared subscription in one Resource Group (participantname-rg) on Contributor level
- Unrestricted Internet access for each participant
- Install tools on participant notebook:
  - Azure CLI [download](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
  - Visual Studio Code [download](https://code.visualstudio.com/download)
  - Visual Studio Community 2019 [download](https://visualstudio.microsoft.com/thank-you-downloading-visual-studio/?sku=Community&rel=16)
  - Storage Explorer [download](https://azure.microsoft.com/cs-cz/features/storage-explorer/)
  - WinSCP [download](https://winscp.net/eng/download.php)
  - PuttyGen [download](https://www.puttygen.com/)
  - Kubectl.exe [Download](https://storage.googleapis.com/kubernetes-release/release/v1.15.0/bin/windows/amd64/kubectl.exe) and place it to folder that is in your PATH
- Additional requirements for Day 2:
  - Service Principal account in AAD for each participant or one shared
    - [Guide to create account](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#create-an-azure-active-directory-application)
    - [Guide to generate secret for account](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#create-a-new-application-secret)
- Additional requirements for Day 3:
  - Get trial licenses from vendors of your choice (Check Point comes with 15 trial built in, F5 does not - check how it is with Fortinet)
  - Administrator access to Azure Stack to configure SQL provider and create custom marketplace items
- Make yourself familiar with [operator documentation](https://docs.microsoft.com/en-us/azure-stack/operator/) and [user documentation](https://docs.microsoft.com/en-us/azure-stack/user/)
- Read [blog in Czech](https://www.tomaskubica.cz/tag/azurestack/)

## Labs
We will split content into four training days:
- [Day 1: Infrastructure services](./InfrastructureServices.md)
- [Day 2: Application platforms](./ApplicationPlatforms.md)
- [Day 3 part 1: Data services](./DataServices.md)
- [Day 3 part 2: Advanced Networking](./AdvancedNetworking.md)
- [Day 4: Azure Stack operator training](./Operator.md)