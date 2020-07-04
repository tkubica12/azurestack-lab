# 1. create azure2stack VGW via azure-vpn.json
# 2. create stack2azure VGW via stack-vpn.json
# 3. get the azure VGW public IP and fill it to variable bellow

$azure2stackvgwip = "13.80.112.237"

# 4. make a connection with following:

$domain = "prghub.hpedu.cz"


az cloud register -n AzureStack `
    --endpoint-resource-manager "https://management.$domain" `
    --suffix-storage-endpoint $domain `
    --suffix-keyvault-dns ".vault.$domain" `
    --profile "2019-03-01-hybrid"
    
az cloud set -n AzureStack
az login --tenant azurestackprg.onmicrosoft.com
az account set -s 15e626dc-8071-4dcd-b478-887d1e7fc792

az network local-gateway create -g networking-rg -n stack2azure-lgw --gateway-ip-address $azure2stackvgwip  --local-address-prefixes 10.2.0.0/16
az network vpn-connection create -n stack2azure-vgw-cn -g networking-rg --vnet-gateway1 stack2azure-vgw --local-gateway2 stack2azure-lgw --shared-key AzureStack2020demo

# 5. now the stack2azure-vgw-ip should appear in the Azure Stack, so store it in the following variable

$stack2azurevgwip = "62.168.63.130"

# 6. Connect to Azure and create the connection to Azure Stack VGW

az cloud set -n AzureCloud
az login
az account set -s AzureStackCZSK
az network local-gateway create -g networking-rg -l westeurope -n azure2stack-lgw --gateway-ip-address $stack2azurevgwip  --local-address-prefixes 10.1.0.0/16
az network vpn-connection create -n azure2stack-vgw-cn -g networking-rg -l westeurope --vnet-gateway1 azure2stack-vgw --local-gateway2 azure2stack-lgw --shared-key AzureStack2020demo
