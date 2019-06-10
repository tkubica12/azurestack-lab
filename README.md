# Azure Stack lab

## Prerequisities
- Each participant need to be able to log into both Azure Stack and Azure
- Each participant to have his own subscription in Azure Stack as Owner using plan with all services enabled and unlimited quota
- Install Application Services resource provider on Azure Stack in default configuration and scale number of dedicated worker nodes in Small tier to double amount of participants
- Download following items to marketplace:
  - Latest Windows 2016 Datacenter (PAYG)
  - Latest Ubuntu 16.04
  - Virtual Machine Scale Set
  - Windows and Linux script extensions
  - Join Domain extension
  - Latest Kubernetes
  - Azure Monitor, Update and Configuration Management extension for Windows and Linux
  - Azure Monitor Dependency Agent extension for Windows and Linux
- Each participant to have access to Azure shared subscription in one Resource Group (participantname-rg) on Contributor level
- Unrestricted Internet access for each participant
- Install tools on participant notebook:
  - Azure CLI
  - Visual Studio Code
  - Storage Explorer

## Labs
We will split content into three training days:
- [Day 1](./Day1.md)
- [Day 2](./Day2.md)
- [Day 3](./Day3.md)