# Azure Stack lab - Day 3 part 2: Advanced Networking
During second half of third day we will practice:
- Advanced networking scenarios
  - Depolying enterprise-grade firewall (eg. CheckPoint or Fortinet)
  - Deploying enterprise-grade WAF (eg. F5)
  - Using Azure Stack VPN
  - Provisioning 3rd party VPN service

## Prerequisities
Check [README](./README.md)

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
```

## Step XX - native networking services including VNETs, NSGs and LBs
We will deploy VNET with following subnets:
* jump - subnet for jump VM
* web - subnet for web farm
* db - subnet for database
* fg-int - subnet for Fortinet internal NIC
* fg-ext - subnet for Fortinet external NIC
* f5 - subnet for F5

```powershell
$region = "local" 
az group create -n net-rg -l $region
az network vnet create -n net -g net-rg --address-prefix 10.0.0.0/16
az network vnet subnet create -n jump `
    -g net-rg `
    --vnet-name net `
    --address-prefix 10.0.0.0/24
az network vnet subnet create -n web `
    -g net-rg `
    --vnet-name net `
    --address-prefix 10.0.1.0/24
az network vnet subnet create -n db `
    -g net-rg `
    --vnet-name net `
    --address-prefix 10.0.2.0/24
az network vnet subnet create -n fg-int `
    -g net-rg `
    --vnet-name net `
    --address-prefix 10.0.3.0/24
az network vnet subnet create -n fg-ext `
    -g net-rg `
    --vnet-name net `
    --address-prefix 10.0.4.0/24
az network vnet subnet create -n f5 `
    -g net-rg `
    --vnet-name net `
    --address-prefix 10.0.5.0/24
```

We will configure subnet-level Network Security Groups to achieve the following:
* jump - access from Internet on port 3389+22 (management), no outbound restrictions
* web - access from Internet on port 80 (web), access from jump on port 3389+22 (management), no outbound restrictions 
* db - access from web subnet on port 1433 (SQL), access from jump on port 3389+22 (management), no outbound restrictions
* fg-int - TBD
* fg-ext - TBD
* f5 - access from Internet on port 80 and 443 (published applications), access from jump subnet on port 8443 and 22 (management), no outbound restrictions

```powershell
# Jump firewalling
$subnetId = $(az network vnet subnet show -g net-rg --name jump --vnet-name net --query id -o tsv)
az network nsg create -n jump-nsg -g net-rg
az network nsg rule create -g net-rg `
    --nsg-name jump-nsg `
    -n AllowManagementFromInternet `
    --priority 100 `
    --source-address-prefixes '*' `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 3389 22 `
    --access Allow `
    --protocol Tcp `
    --description "Allow management from Internet"
az network vnet subnet update -g net-rg `
    -n jump `
    --vnet-name net `
    --network-security-group jump-nsg

# Web firewalling
$subnetId = $(az network vnet subnet show -g net-rg --name web --vnet-name net --query id -o tsv)
az network nsg create -n web-nsg -g net-rg
az network nsg rule create -g net-rg `
    --nsg-name web-nsg `
    -n AllowManagementFromJump `
    --priority 100 `
    --source-address-prefixes 10.0.0.0/24 `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 3389 22 `
    --access Allow `
    --protocol Tcp `
    --description "Allow management from Jump subnet"
az network nsg rule create -g net-rg `
    --nsg-name web-nsg `
    -n DenyManagement `
    --priority 110 `
    --source-address-prefixes '*' `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 3389 22 `
    --access Deny `
    --protocol Tcp `
    --description "Deny management"
az network nsg rule create -g net-rg `
    --nsg-name web-nsg `
    -n AllowWebFromInternet `
    --priority 120 `
    --source-address-prefixes '*' `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 80 443 `
    --access Deny `
    --protocol Tcp `
    --description "Allow web from Internet"
az network vnet subnet update -g net-rg `
    -n web `
    --vnet-name net `
    --network-security-group web-nsg

# DB firewalling
$subnetId = $(az network vnet subnet show -g net-rg --name db --vnet-name net --query id -o tsv)
az network nsg create -n db-nsg -g net-rg
az network nsg rule create -g net-rg `
    --nsg-name db-nsg `
    -n AllowManagementFromJump `
    --priority 100 `
    --source-address-prefixes 10.0.0.0/24 `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 3389 22 `
    --access Allow `
    --protocol Tcp `
    --description "Allow management from Jump subnet"
az network nsg rule create -g net-rg `
    --nsg-name db-nsg `
    -n DenyManagement `
    --priority 110 `
    --source-address-prefixes '*' `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 3389 22 `
    --access Deny `
    --protocol Tcp `
    --description "Deny management"
az network nsg rule create -g net-rg `
    --nsg-name db-nsg `
    -n AllowDbFromWeb `
    --priority 120 `
    --source-address-prefixes 10.0.2.0/24 `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 1433 `
    --access Allow `
    --protocol Tcp `
    --description "Allow DB from web subnet"
az network vnet subnet update -g net-rg `
    -n db `
    --vnet-name net `
    --network-security-group db-nsg

# F5 firewalling
$subnetId = $(az network vnet subnet show -g net-rg --name f5 --vnet-name net --query id -o tsv)
az network nsg create -n f5-nsg -g net-rg
az network nsg rule create -g net-rg `
    --nsg-name f5-nsg `
    -n AllowManagementFromJump `
    --priority 100 `
    --source-address-prefixes 10.0.0.0/24 `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 8443 22 `
    --access Allow `
    --protocol Tcp `
    --description "Allow management from Jump subnet"
az network nsg rule create -g net-rg `
    --nsg-name f5-nsg `
    -n DenyManagement `
    --priority 110 `
    --source-address-prefixes '*' `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 8443 22 `
    --access Deny `
    --protocol Tcp `
    --description "Deny management"
az network nsg rule create -g net-rg `
    --nsg-name f5-nsg `
    -n AllowWebFromInternet `
    --priority 120 `
    --source-address-prefixes '*' `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 80 443 `
    --access Allow `
    --protocol Tcp `
    --description "Allow web from web Internet"
az network vnet subnet update -g net-rg `
    -n f5 `
    --vnet-name net `
    --network-security-group f5-nsg

```


## Step XX - deploying Fortinet inside tenant environment
Note Fortinet currenly offers GUI deployment model only for basic non-HA setup. Clustered deployments are being developed by Fortinet on their [GitHub](https://github.com/fortinetsolutions/Azure-Templates). Please consult with Fortinet on their roadmap and supported scenarios for Azure Stack.

Fortinet supports advanced topologies in Azure including active/passive HA (deployments requiring VPN services) and active/active HA (NGFW deployments) including auto-scaling capabilities (VMSS). For Azure Stack they currently support single-VM basic deployments.

Fortinet has released [Azure Stack SDN Fabric Connector](https://docs.fortinet.com/document/fortigate/6.2.0/cookbook/633088) to ready dynamic objects from IaaS platform to ease configuration of Fortinet policies.

## Step XX - deploying enterprise-grade reverse proxy / Web Application Firewall with F5
Note F5 currently offers GUI deployment model only for basic non-HA and manual setup. More automated (autoconfiguration of license and Azure Stack connector) or clustered deployments are being developed by F5 on their [GitHub](https://github.com/F5Networks/f5-azure-stack-arm-templates). Please consult with F5 on their roadmap and supported scenarios for Azure Stack.

F5 supports advanced topologies in Azure including auto-scaling group (VMSS), provisioning via Big IQ, F5 cluster behind Azure LB managed by F5 (allows for multiple public IPs in automated way), per-app F5 and multi-NIC configurations. For Azure Stack they currently support single-VM single-NIC basic deployments.


## Step XX - using Azure Stack VPN

## Step XX - automated provisioning of 3rd party VPN connector