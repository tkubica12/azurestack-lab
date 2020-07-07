# Connect to Kubernetes from router VM
Connect to AKS cluster master node using SSH from router VM.

Get kubeconfig information and tranfer it to router VM file ~/.kube/config.

```bash
kubectl config view --raw
```

On Router VM install kubectl and connect to Kubernetes remotely.

```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

kubectl get nodes
```

Install Helm on your local machine by download binary for your OS ![here](https://github.com/helm/helm/releases)

Install Azure CLI.

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg -y
curl -sL https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get update
sudo apt-get install azure-cli -y
```

Target your Azure subscription and install CLI extensions.

```bash
az login 
az account set -s "AzureStackCZSK"
```

# Store Kubernetes Secrets
We will prepare secrets in cluster such as Application Insights key.

```bash
export ai_key=$(az resource show -g monitoring-rg -n appinsightsazurestackczsk-ot --resource-type Microsoft.Insights/components --query properties.InstrumentationKey -o tsv)
kubectl create secret generic applicationinsights --from-literal=key=$ai_key
```

# Onboard AKS engine cluster to Azure Arc for Kubernetes
Install CLI extensions and connect cluster.

```bash
az extension add --name connectedk8s
az extension add --name k8sconfiguration

az connectedk8s connect --name aks-azure-stack --resource-group arc-azurestack-rg
```

# Onboard AKS engine cluster to Azure Monitor for Containers

Download installer

```bash
curl -o enable-monitoring.sh -L https://aka.ms/enable-monitoring-bash-script
```

Gather IDs of Arc cluster (as deployed in previous step) and Log Analytics workspace (as deployed previously with ARM templates).

```bash
export azureArcClusterResourceId=$(az connectedk8s show -n aks-azure-stack -g arc-azurestack-rg --query id -o tsv)
export logAnalyticsWorkspaceResourceId=$(az monitor log-analytics workspace show -n workspaceazurestackczsk -g monitoring-rg --query id -o tsv)
```

Onboard cluster

```bash
bash enable-monitoring.sh --resource-id $azureArcClusterResourceId --workspace-id $logAnalyticsWorkspaceResourceId
```

# Configure GitOps to control cluster state and deploy apps

```bash
az k8sconfiguration create \
    --name gitops-aks-state \
    --cluster-name aks-azure-stack \
    --resource-group arc-azurestack-rg \
    --operator-instance-name cluster-config \
    --operator-namespace default \
    --repository-url https://github.com/tkubica12/azurestack-lab \
    --scope cluster \
    --cluster-type connectedClusters \
    --operator-params='--git-readonly --git-path=demo-environment/gitops-aks-state' \
    --enable-helm-operator \
    --helm-operator-version='0.6.0' \
    --helm-operator-params='--set helm.versions=v3'
```