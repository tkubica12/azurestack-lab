# Login to AzureStackCZSK subscription
az account set -s AzureStackCZSK

# Deploy monitoring
az group create -n monitoring-rg -l westeurope
az group deployment create -g monitoring-rg --template-file azure-monitoring.json

# Deploy Azure Policy for Kubernetes
az deployment sub create -l westeurope --template-file azure-kubernetes-policy.json

# Deploy records on azurepraha.com zone
az deployment group create -g domain-rg --template-file azure-dns.json