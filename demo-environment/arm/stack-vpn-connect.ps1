# 1. create stack2azure VGW

$domain = "prghub.hpedu.cz"

az cloud register -n AzureStack `
    --endpoint-resource-manager "https://management.$domain" `
    --suffix-storage-endpoint $domain `
    --suffix-keyvault-dns ".vault.$domain" `
    --profile "2019-03-01-hybrid"
    
az cloud set -n AzureStack
az login --tenant azurestackprg.onmicrosoft.com
az account set -s 15e626dc-8071-4dcd-b478-887d1e7fc792

az network public-ip create -n stack2azure-vgw-ip  `
    -g networking-rg `
    --allocation-method Dynamic
    
az network vnet-gateway create -n stack2azure-vgw `
    -l prghub `
    --public-ip-address stack2azure-vgw-ip `
    -g networking-rg `
    --vnet demo-net `
    --gateway-type Vpn `
    --sku Standard `
    --vpn-type RouteBased `
    --asn 65020 

# 2. create azure2stack VGW 

az cloud set -n AzureCloud
az login
az account set -s AzureStackCZSK

az network public-ip create -n azure2stack-vgw-ip  `
    -l westeurope `
    -g networking-rg `
    --allocation-method Dynamic
    
az network vnet-gateway create -n azure2stack-vgw `
    -l westeurope `
    --public-ip-address azure2stack-vgw-ip `
    -g networking-rg `
    --vnet azure-demo-net `
    --gateway-type Vpn `
    --sku Standard `
    --vpn-type RouteBased `
    --asn 65010 
    
# 3. store the azure VGW public IP and BGP IP address

$azure2stackvgwip = az network public-ip show -g networking-rg  --name azure2stack-vgw-ip --query 'ipAddress' -o tsv
$azure2stackBgpIp = az network vnet-gateway show -g networking-rg --name azure2stack-vgw  --query 'bgpSettings.bgpPeeringAddress' -o tsv

# 4. create the local network gateway and make the Stack2Azure connection with following:

az cloud set -n AzureStack

az network local-gateway create -g networking-rg `
    -n stack2azure-lgw `
    --gateway-ip-address $azure2stackvgwip `
    --local-address-prefixes 10.2.0.0/16 `
    --asn 65010 `
    --bgp-peering-address $azure2stackBgpIp
    
az network vpn-connection create -n stack2azure-vgw-cn `
    -g networking-rg `
    --vnet-gateway1 stack2azure-vgw `
    --local-gateway2 stack2azure-lgw `
    --enable-bgp `
    --shared-key <presharedKey>

az network vpn-connection ipsec-policy add --connection-name stack2azure-vgw-cn `
    -g networking-rg `
    --ike-encryption AES256 `
    --ike-integrity SHA384 `
    --dh-group ECP384 `
    --ipsec-encryption GCMAES256 `
    --ipsec-integrity GCMAES256 `
    --pfs-group ECP384 `
    --sa-lifetime 27000 `
    --sa-max-size 102400000

# 5. now the stack2azure-vgw-ip should appear in the Azure Stack, store it as variable, store also BGP IP address

$stack2azurevgwip = az network public-ip show -g networking-rg  --name stack2azure-vgw-ip --query 'ipAddress' -o tsv
$stack2azureBgpIp = az network vnet-gateway show -g networking-rg --name stack2azure-vgw  --query 'bgpSettings.bgpPeeringAddress' -o tsv

# 6. Connect to Azure and create the connection to Azure Stack VGW

az cloud set -n AzureCloud
az account set -s AzureStackCZSK

az network local-gateway create -g networking-rg `
    -l westeurope `
    -n azure2stack-lgw `
    --gateway-ip-address $stack2azurevgwip `
    --local-address-prefixes 10.1.0.0/16 `
    --asn 65020 `
    --bgp-peering-address $stack2azureBgpIp

az network vpn-connection create -n azure2stack-vgw-cn `
    -g networking-rg `
    -l westeurope `
    --vnet-gateway1 azure2stack-vgw `
    --local-gateway2 azure2stack-lgw `
    --enable-bgp `
    --shared-key <presharedKey>

az network vpn-connection ipsec-policy add --connection-name azure2stack-vgw-cn `
    -g networking-rg `
    --ike-encryption AES256 `
    --ike-integrity SHA384 `
    --dh-group ECP384 `
    --ipsec-encryption GCMAES256 `
    --ipsec-integrity GCMAES256 `
    --pfs-group ECP384 `
    --sa-lifetime 27000 `
    --sa-max-size 102400000
