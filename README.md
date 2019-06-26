# Azure Stack lab

## Prerequisities
- Each participant need to be able to log into both Azure Stack and Azure
- Each participant to have his own subscription in Azure Stack as Owner using plan with all services enabled and unlimited quota
- Install Application Services resource provider on Azure Stack in default configuration and configure the following:
  - Scale number of dedicated worker nodes in Small tier to double amount of participants
  - Configure GitHub deployment according to [https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-app-service-configure-deployment-sources#configure-github](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-app-service-configure-deployment-sources#configure-github)
- For Day 2 install SQL resource provider
- Download following items to marketplace:
  - Latest Windows 2016 Datacenter (PAYG)
  - Latest Ubuntu 16.04
  - Virtual Machine Scale Set
  - Windows and Linux script extensions
  - Join Domain extension
  - Latest Kubernetes
  - Azure Monitor, Update and Configuration Management extension for Windows and Linux
  - Azure Monitor Dependency Agent extension for Windows and Linux
  - For Day 2 download SQL images (SQL Standard 2017 on Windows)
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
- Additional requirements for Day 2:
  - Administrator access to Azure Stack to configure SQL provider and create custom marketplace items
  - Service Principal account in AAD for each participant
- Additional requirements for Day 3:
  - Get trial licenses from vendors of your choice (Check Point comes with 15 trial built in, F5 does not - check how it is with Fortinet)
- Make yourself familiar with [operator documentation](https://docs.microsoft.com/en-us/azure-stack/operator/) and [user documentation](https://docs.microsoft.com/en-us/azure-stack/user/)
- Read [blog in Czech](https://www.tomaskubica.cz/tag/azurestack/)

## Labs
We will split content into three training days:
- [Day 1](./Day1.md)
- [Day 2](./Day2.md)
- [Day 3](./Day3.md)