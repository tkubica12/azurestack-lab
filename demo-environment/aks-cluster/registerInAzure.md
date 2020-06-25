# Onboard AKS engine cluster to Azure Arc for Kubernetes

Connect to AKS cluster master node.

Get kubeconfig information and save it as file locally.

```bash
kubectl config view --raw
```

Connect to Kubernetes remotely.

```bash
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
```

Install Helm on your local machine by download binary for your OS ![here](https://github.com/helm/helm/releases)

Target your Azure subscription and install CLI extensions.

```bash
az login 
az account set -s "AzureStackCZSK"
az extension add --name connectedk8s
az extension add --name k8sconfiguration
```

Connect cluster.

```bash
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