# Login to Azure Stack
$domain = "prghub.hpedu.cz"
az cloud register -n AzureStack `
    --endpoint-resource-manager "https://management.$domain" `
    --suffix-storage-endpoint $domain `
    --suffix-keyvault-dns ".vault.$domain" `
    --profile "2019-03-01-hybrid"
az cloud set -n AzureStack
az login --tenant azurestackprg.onmicrosoft.com

az account set -s "demo"

# Set parameters
$region = "prghub" 
$password = ""
$workspaceKey = ""

# Deploy networking
az group create -n networking-rg -l $region
az group deployment create -g networking-rg --template-file stack-networking.json

# Deploy Linux router VM
az group create -n router-rg -l $region
az group deployment create -g router-rg --template-file stack-router.json `
    --parameters adminPassword=$password `
    --parameters workspaceKey=$workspaceKey

# Deploy Active Directory VM
az group create -n ad-rg -l $region
az group deployment create -g ad-rg --template-file stack-ad.json `
    --parameters adminPassword=$password `
    --parameters workspaceKey=$workspaceKey

# Configure router
ssh stackuser@$routerIp
sudo apt update
sudo apt install iptables-persistent -y
echo net.ipv4.ip_forward=1 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
sudo iptables -t nat -F
sudo iptables -t nat -A PREROUTING -p tcp --dport 9001 -j DNAT --to-destination 10.1.1.100:3389 # AD RDP
sudo iptables -t nat -A POSTROUTING -p tcp --destination 10.1.1.100 --dport 3389 -j MASQUERADE # AD RDP
sudo /etc/init.d/netfilter-persistent save

# Configure AD
