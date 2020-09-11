# Create Service Principal in target account

```bash
az login --tenant azurestackprg.onmicrosoft.com
az ad sp create-for-rbac --skip-assignment --name AzureStack_AKS
```

# Store appId and password from previous command. Also store SP object ID.

```bash
az ad sp show --id "http://AzureStack_AKS" --query objectId
```

# Assign Contributor role to AKS SP in Azure Stack subscription

```bash
export domain="prghub.hpedu.cz"
az cloud register -n AzureStack \
    --endpoint-resource-manager "https://management.$domain" \
    --suffix-storage-endpoint $domain \
    --suffix-keyvault-dns ".vault.$domain" \
    --profile "2019-03-01-hybrid"
az cloud set -n AzureStack
az login --tenant azurestackprg.onmicrosoft.com
az account set -s "demo"

az role assignment create --assignee-object-id $aksSpObjectId --scope "/subscriptions/$(az account show -s demo --query id -o tsv)" --role Contributor
```

# We will install AKS engine on router-vm

```bash
ssh stackuser@azurepraha.com

curl -o get-akse.sh https://raw.githubusercontent.com/Azure/aks-engine/master/scripts/get-akse.sh
chmod 700 get-akse.sh
./get-akse.sh --version v0.55.0

sudo cp /var/lib/waagent/Certificates.pem /usr/local/share/ca-certificates/azurestackca.crt 
sudo update-ca-certificates
```

# Generate SSH keys

```bash
ssh-keygen -t rsa
```

# Cluster definition
Use file cluster-definition.json and add key from ~/.ssh/id_rsa.pub and SP client secret you stored previously. 

Make sure other parameters such as VNET ID and last IP for master fit.

# Install cluster

```bash
aks-engine deploy -f \
    --azure-env AzureStackCloud \
    --location prghub \
    --resource-group kubernetes-rg \
    --api-model ./cluster-definition.json \
    --output-directory kubernetes-rg \
    --client-id $aksSpClient \
    --client-secret $aksSpSecret \
    --subscription-id $(az account show -s demo --query id -o tsv)
```

Installation is complete. Continue by registering it in Azure and deploying basic environment on top in [registerInAzure.md](registerInAzure.md)

