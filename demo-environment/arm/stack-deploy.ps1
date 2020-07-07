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

# Setup deployment environment and secrets
az group create -n artefacts-rg -l $region
az keyvault create -n deployment-secrets -l $region -g artefacts-rg --enabled-for-template-deployment
az keyvault secret set -n adminPassword --vault-name deployment-secrets --value $password
az keyvault secret set -n sqlPassword --vault-name deployment-secrets --value $password
az keyvault secret set -n workspaceKey --vault-name deployment-secrets --value $workspaceKey

# Deploy networking
az group create -n networking-rg -l $region
az group deployment create -g networking-rg --template-file stack-networking.json

# Prepare Arc resource group
az group create -n arc-azurestack-rg -l $region

# Deploy Linux router VM
az group create -n router-rg -l $region
az group deployment create -g router-rg --template-file stack-router.json --parameters @stack-router.parameters.json

# Deploy Active Directory VM
az group create -n ad-rg -l $region
az group deployment create -g ad-rg --template-file stack-ad.json --parameters @stack-ad.parameters.json

# Configure router
ssh stackuser@azurepraha.com
sudo apt update
sudo apt install iptables-persistent nginx -y
echo net.ipv4.ip_forward=1 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
sudo iptables -t nat -F
sudo iptables -t nat -A PREROUTING -p tcp --dport 9001 -j DNAT --to-destination 10.1.1.100:3389 # AD RDP
sudo iptables -t nat -A POSTROUTING -p tcp --destination 10.1.1.100 --dport 3389 -j MASQUERADE # AD RDP
sudo iptables -t nat -A PREROUTING -p tcp --dport 9002 -j DNAT --to-destination 10.1.2.100:80 # web-win lb
sudo iptables -t nat -A POSTROUTING -p tcp --destination 10.1.2.100 --dport 80 -j MASQUERADE # web-win lb
sudo iptables -t nat -A PREROUTING -p tcp --dport 9003 -j DNAT --to-destination 10.1.2.200:80 # web-linux  lb
sudo iptables -t nat -A POSTROUTING -p tcp --destination 10.1.2.200 --dport 80 -j MASQUERADE # web-linux  lb
sudo iptables -t nat -A PREROUTING -p tcp --dport 9004 -j DNAT --to-destination 10.1.3.100:80 # win arm demo
sudo iptables -t nat -A POSTROUTING -p tcp --destination 10.1.3.100 --dport 80 -j MASQUERADE # win arm demo
sudo iptables -t nat -A PREROUTING -p tcp --dport 9005 -j DNAT --to-destination 10.1.2.250:3389 # SQL RDP
sudo iptables -t nat -A POSTROUTING -p tcp --destination 10.1.2.250 --dport 3389 -j MASQUERADE # SQL RDP
sudo /etc/init.d/netfilter-persistent save

echo "<H1>Azure Stack demo Prague</H1>" | sudo tee /var/www/html/index.html
cat << EOF | sudo tee /etc/nginx/conf.d/windows.demo.conf
server {
    listen 80;
    listen [::]:80;
  
    server_name windows.demo.azurepraha.com;
  
    location / {
        proxy_pass http://10.1.2.100/;
    }
  }
EOF

cat << EOF | sudo tee /etc/nginx/conf.d/linux.demo.conf
server {
    listen 80;
    listen [::]:80;
  
    server_name linux.demo.azurepraha.com;
  
    location / {
        proxy_pass http://10.1.2.200/;
    }
  }
EOF

cat << EOF | sudo tee /etc/nginx/conf.d/arm.demo.conf
server {
    listen 80;
    listen [::]:80;
  
    server_name arm.demo.azurepraha.com;
  
    location / {
        proxy_pass http://10.1.3.100/;
    }
  }
EOF

sudo nginx -s reload

# Configure AD
install-windowsfeature AD-Domain-Services -IncludeManagementTools  
Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "Win2012R2" `
    -DomainName "azurepraha.com" `
    -DomainNetbiosName "AZUREPRAHA" `
    -ForestMode "Win2012R2" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$false `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true

$password = ""
New-ADGroup -Name "stackusers" -GroupCategory Security -GroupScope Global
New-ADUser -Name "user1" `
 -SamAccountName  "user1" `
 -AccountPassword (ConvertTo-SecureString $password -AsPlainText -force) `
 -Enabled $true `
 -PasswordNeverExpires  $true
Add-ADGroupMember -Identity stackusers -Members user1

# Deploy apps
az group create -n windows-web-rg -l $region
az group deployment create -g windows-web-rg `
    --template-file stack-windows-web.json `
    --parameters @stack-windows-web.parameters.json `
    --parameters appVersion=v1

az group create -n sql-web-rg -l $region
az group deployment create -g sql-web-rg --template-file stack-sql-web.json --parameters @stack-sql-web.parameters.json

az group create -n linux-web-rg -l $region
az group deployment create -g linux-web-rg --template-file stack-linux-web.json --parameters @stack-linux-web.parameters.json


az group deployment create -g linux-web-rg --template-file stack-linux-web.json --parameters @stack-linux-web.parameters.json --parameters appVersion=v1
