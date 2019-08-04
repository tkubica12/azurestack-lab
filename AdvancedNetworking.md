# Azure Stack lab - Day 3 part 2: Advanced Networking
During second half of third day we will practice:
- Advanced networking scenarios
  - Depolying enterprise-grade firewall (eg. CheckPoint or Fortinet)
  - Deploying enterprise-grade WAF (eg. proxy)
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

## Step 1 - virtual networks
We will deploy VNET with following subnets:
* jump - subnet for jump VM
* web - subnet for web farm
* db - subnet for database
* fg-int - subnet for Fortinet internal NIC
* fg-ext - subnet for Fortinet external NIC
* proxy - subnet for reverse proxy

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
az network vnet subnet create -n proxy `
    -g net-rg `
    --vnet-name net `
    --address-prefix 10.0.5.0/24
```

## Step 2 - segmentation with Network Security Groups

We will configure subnet-level Network Security Groups to achieve the following:
* jump - access from Internet on port 3389+22 (management), no outbound restrictions
* web - access from Internet on port 80 (web), access from jump on port 3389+22 (management), no outbound restrictions 
* db - access from web subnet on port 1433 (SQL), access from jump on port 3389+22 (management), no outbound restrictions
* fg-int - TBD
* fg-ext - TBD
* proxy - access from Internet on port 80 and 443 (published applications), access from jump subnet on port 8443 and 22 (management), no outbound restrictions

Note NSG can also be applied on individual VMs.

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
    -n AllowWebFromJump `
    --priority 120 `
    --source-address-prefixes "10.0.0.0/24" `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 80 443 `
    --access Allow `
    --protocol Tcp `
    --description "Allow web from Jump"
az network nsg rule create -g net-rg `
    --nsg-name web-nsg `
    -n AllowWebFromProxy `
    --priority 130 `
    --source-address-prefixes "10.0.5.0/24" `
    --source-port-ranges '*' `
    --destination-address-prefixes '*' `
    --destination-port-ranges 80 443 `
    --access Allow `
    --protocol Tcp `
    --description "Allow web from Proxy"
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

# Proxy firewalling
$subnetId = $(az network vnet subnet show -g net-rg --name proxy --vnet-name net --query id -o tsv)
az network nsg create -n proxy-nsg -g net-rg
az network nsg rule create -g net-rg `
    --nsg-name proxy-nsg `
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
    --nsg-name proxy-nsg `
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
    --nsg-name proxy-nsg `
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
    -n proxy `
    --vnet-name net `
    --network-security-group proxy-nsg
```

## Step 3 - deploy servers
We will now create resource groups for each tier and deploy servers.

```powershell
# Store image name as variable
$image = "Canonical:UbuntuServer:16.04-LTS:16.04.20180831"

# Deploy jump server with public IP
az group create -n jump-rg -l $region

az vm create -n "jump-vm" `
    -g jump-rg `
    --image $image `
    --authentication-type password `
    --admin-username azureuser `
    --admin-password Azure12345678 `
    --public-ip-address jump-ip `
    --nsg '""' `
    --size Standard_DS1_v2 `
    --subnet "$(az network vnet subnet show -g net-rg --name jump --vnet-name net --query id -o tsv)" `
    --no-wait

# Deploy 2 web servers in Availability Set with no public IP
az group create -n web-rg -l $region

az vm availability-set create -n web-as -g web-rg

az vm create -n "web-vm-01" `
    -g web-rg `
    --image $image `
    --authentication-type password `
    --admin-username azureuser `
    --admin-password Azure12345678 `
    --public-ip-address '""' `
    --nsg '""' `
    --size Standard_DS1_v2 `
    --availability-set web-as `
    --subnet "$(az network vnet subnet show -g net-rg --name web --vnet-name net --query id -o tsv)" `
    --no-wait

az vm create -n "web-vm-02" `
    -g web-rg `
    --image $image `
    --authentication-type password `
    --admin-username azureuser `
    --admin-password Azure12345678 `
    --public-ip-address '""' `
    --nsg '""' `
    --size Standard_DS1_v2 `
    --availability-set web-as `
    --subnet "$(az network vnet subnet show -g net-rg --name web --vnet-name net --query id -o tsv)" `
    --no-wait

# Deploy database server with no public IP
az group create -n db-rg -l $region

az vm create -n "db-vm" `
    -g db-rg `
    --image $image `
    --authentication-type password `
    --admin-username azureuser `
    --admin-password Azure12345678 `
    --public-ip-address '""' `
    --nsg '""' `
    --size Standard_DS1_v2 `
    --subnet $(az network vnet subnet show -g net-rg --name db --vnet-name net --query id -o tsv) `
    --no-wait
```

We will now test connectivity. Get public IP of jump server and SSH to it (eg. use Putty or install WIndows SSH client in Windows 10).

```powershell
az network public-ip show -n jump-ip -g jump-rg --query ipAddress -o tsv
```

Check IP on jump VM ("ip a") and note it is from private network (Azure Stack does 1:1 IP NAT when traffic goes out or in Azure Stack). Also check that internal DNS works, eg. ping web-vm-01.

Make sure you can connect to both web and db servers from jump on port 22 (SSH).

```powershell
ssh azureuser@web-vm-01
    exit
ssh azureuser@db-vm
    exit
```

To check our NSGs make sure you cannot SSH from web VM to DB VM.
```powershell
ssh azureuser@web-vm-01
    ssh azureuser@db-vm
```

## Step 4 - internal load balancer

Azure Stack comes with software-defined load balancer. We can configure LB with public IP or LB with internal IP. In this demo we will use internal VIP.

First we will install simple static web. Connect to jump VM and from it to web-vm-01 a install web service. THan connect to web-vm-02 and install web service. Make sure you can see both webs from jump server.

```powershell
ssh azureuser@web-vm-01
    sudo apt update && sudo apt install nginx -y
    echo "v1: Hi from $HOSTNAME" | sudo tee /var/www/html/index.html
    exit
ssh azureuser@web-vm-02
    sudo apt update && sudo apt install nginx -y
    echo "v1: Hi from $HOSTNAME" | sudo tee /var/www/html/index.html
    exit
curl web-vm-01
curl web-vm-02
```

Configure load balancer

```powershell
# Create Load Balancer
az network lb create -n mylb `
    -g web-rg `
    --subnet "$(az network vnet subnet show -g net-rg --name web --vnet-name net --query id -o tsv)" `
    --public-ip-address '""' `
    --private-ip-address 10.0.1.100 `
    --frontend-ip-name front `
    --backend-pool-name pool

# Create health probe
az network lb probe create -n myprobe `
    -g web-rg `
    --lb-name mylb `
    --protocol tcp `
    --port 80

# Create rule
az network lb rule create -n webrule `
    -g web-rg `
    --lb-name mylb `
    --protocol tcp `
    --frontend-port 80 `
    --backend-port 80 `
    --frontend-ip-name front `
    --backend-pool-name pool `
    --probe-name myprobe

# Add web VM NICs to backend pool
az network nic ip-config update --nic-name web-vm-01VMNic `
    -n ipconfigweb-vm-01 `
    -g web-rg `
    --lb-name mylb `
    --lb-address-pools pool

az network nic ip-config update --nic-name web-vm-02VMNic `
    -n ipconfigweb-vm-02 `
    -g web-rg `
    --lb-name mylb `
    --lb-address-pools pool
```

Connect to jump-vm and from it access private VIP.

```powershell
curl 10.0.1.100
```

## Step 5 - deploy reverse proxy
**Notes:**
_When using F5 it currently offers GUI deployment model only for basic non-HA and manual setup. More automated (autoconfiguration of license and Azure Stack connector) or clustered deployments are being developed by proxy on their [GitHub](https://github.com/proxyNetworks/proxy-azure-stack-arm-templates). Please consult with proxy on their roadmap and supported scenarios for Azure Stack._

_F5 supports advanced topologies in Azure including auto-scaling group (VMSS), provisioning via Big IQ, proxy cluster behind Azure LB managed by proxy (allows for multiple public IPs in automated way), per-app proxy and multi-NIC configurations. For Azure Stack they currently support single-VM single-NIC basic deployments._

As alternative to simple built-in L4 balancer we will now deploy 3rd party reverse proxy such as F5. In our demo we will use Linux machinw with NGINX.

Deploy Linux VM in proxy subnet including public IP.

```powershell
az group create -n proxy-rg -l $region

az vm create -n "proxy-vm" `
    -g proxy-rg `
    --image $image `
    --authentication-type password `
    --admin-username azureuser `
    --admin-password Azure12345678 `
    --public-ip-address proxy-ip `
    --nsg '""' `
    --size Standard_DS1_v2 `
    --subnet "$(az network vnet subnet show -g net-rg --name proxy --vnet-name net --query id -o tsv)"
```

Get proxy public IP and make sure NSG do not allow SSH access from Internet while it is accessible from jump-vm.

```powershell
az network public-ip show -n proxy-ip -g proxy-rg --query ipAddress -o tsv

# SSH directly to proxy-vm via public IP - this should fail because of our NSG rules

# Connect from jump-vm
ssh azureuser@proxy-vm
```

Now let's install NGINX and configure reverse proxy in proxy-vm. For simplicity we will point nginx to load balancer we have configured previously, but if you need things like cookie session persistence, you may create upstream object a balance on NGINX directly.

```powershell
ssh azureuser@proxy-vm
    sudo -i
    apt update 
    apt install nginx -y
    rm /etc/nginx/sites-enabled/default

    # Paste this as block
cat << EOF > /etc/nginx/conf.d/myapp.conf
server {

    root /var/www/html;

    index index.html index.htm;

    server_name _;

    listen 80 default_server;

    location / {
        proxy_pass http://10.0.1.100/;
    }
}
EOF
    # End of block

    nginx -s reload
```


## Step 6 - deploy Fortinet inside tenant environment
**Notes:**
_Fortinet currenly offers GUI deployment model only for basic non-HA setup. Clustered deployments are being developed by Fortinet on their [GitHub](https://github.com/fortinetsolutions/Azure-Templates). Please consult with Fortinet on their roadmap and supported scenarios for Azure Stack._

_Fortinet supports advanced topologies in Azure including active/passive HA (deployments requiring VPN services) and active/active HA (NGFW deployments) including auto-scaling capabilities (VMSS). For Azure Stack they currently support single-VM basic deployments._

_Fortinet has released [Azure Stack SDN Fabric Connector](https://docs.fortinet.com/document/fortigate/6.2.0/cookbook/633088) to ready dynamic objects from IaaS platform to ease configuration of Fortinet policies._

Use Portal to install Fortigate. Specify ngfw-int and ngfw-ext subnets we created before. After Fortinet boots connect to it using credentials you used in wizard and upload your license file.

Configure Fortigate:
* Set IP on Port 2 (internal network) eg. by switching to DHCP mode
* Configure routing:
  * 0.0.0.0/0 should leave via port 1 (nexthop 10.0.4.1)
  * 10.0.0.0/16 (our VNET) should leave via port 2 (nexthop 10.0.3.1)
* Configure policy from port2 to port1 with NAT enabled
* Look at FortiView All sessions - there will be no traffic going throw

From jump-vm connect to db-vm and access something on Internet. We have not blocked such traffic with NSG so it will work, but default routing is handled by Azure, not Fortinet.

```powershell
ssh azureuser@db-vm
    curl https://www.tomaskubica.cz
```

Now we need to configure routing in Azure Stack SDN so traffic goes via Fortigate. Suppose we want all internal traffic in VNET to be routed by Azure a filtered with NSG, but for downloads from Internet we want to go throw NGFW. Let's do this.

```powershell
# Create routing table set
az network route-table create -g net-rg -n db-routing

# Create default route with Fortigate private IP as next hop
az network route-table route create -g net-rg `
    --route-table-name db-routing `
    -n internetViaNgfw `
    --next-hop-type VirtualAppliance `
    --address-prefix "0.0.0.0/0" `
    --next-hop-ip-address "10.0.3.4"

# Apply routing rules to db subnet
az network vnet subnet update -n db `
    --vnet-name net `
    -g net-rg `
    --route-table db-routing
```

At time of this writing Azure Stack (version 1906) does not support printing effective routes on per-NIC basis. Following command works in Azure and might be ported to Azure Stack at some point.

```powershell
az network nic show-effective-route-table -g db-rg -n db-vmVMNic -o table
```

You should source Default (system configured) on 0.0.0.0/0 showing Invalid meaning it is replaced by source User (user defined) inserting Fortigate in path.

Switch to db-vm a curl some page. Go back to Fortigate FortiView and you should see our traffic there.

## Step 7 - using Fortinet to inspect selected internal traffic
So far we have used Fortigate to manage Internet acess, but with that setup we can easily add destination NAT (opening internal IPs) or building VPNs.

What about using Fortigate to protect internal tenant traffic in Azure Stack? For simplicity, latency and costs you should prefer doing segmentation with subnets and NSGs, but sometimes you might want to leverage Fortigate to bring more features. Eg. it is not good idea to put Fortigate between application and its database, but if you host multiple different projects you might want to put Fortigate between them in case you cannot isolate them to different VNETs (because you require some communication on APIs etc.), but at the same time projects do not trust each other and need more than L4 security between them.

In next section we will want to put Fortinet on traffic between proxy-vm and web subnet.

We can start configure Fortigate using IP addresses and subnets, but let's use fabric connector for Azure and Azure Stack so Fortigate can dynamicaly obtain low-level details by polling metadata.

Create new configuration in Security Fabric -> Security Connectors -> Azure.

Fortigate now gathers data from Azure or Azure Stack and understand IP addresses of resources including:
* VNETs
* subnets
* virtual machines
* objects with IP address contained in resource group
* Kubernetes objects and labels
* custom grouping based on Azure Stack tags (you can create any structure of key/value pairs on each resource)

Go to Policy & Objects -> Addresses and add new. Use type Fabric Connector and investigate what options are available. As and example create address object called proxy and add Vm=proxy-vm.

Suppose we need to have objects will all web VMs, but not load balancer IP or other VMs in the same subnet. How to do that in a way that we can easily add additional web server without need to modify Fortigate policies? One option would be selecting by resource group, but in our case Azure LB lives there also and we do not want it as part of object. Let's use tagging.

Configure tags in Azure on web-vms.

```powershell
az resource tag --tags fortinetobject=web `
    -g web-rg `
    -n web-vm-01 `
    --resource-type "Microsoft.Compute/virtualMachines"

az resource tag --tags fortinetobject=web `
    -g web-rg `
    -n web-vm-02 `
    --resource-type "Microsoft.Compute/virtualMachines"
```

Go to Fortigate and create object web-nodes identified by this tag.

Also create object web-subnet identified by whole subnet. Note currently Fortigate adds only VM objects from Azure, not Azure LB address. 

Therefore create another object web-lb with manual configuration of IP 10.0.1.100.

We will now want traffic between proxy and web LB to go via appliance, but not traffic from proxy to Internet (we want to go directly there).

Configure rules on Fortigate to allow traffic from proxy object to web-lb object on port 80. Not in and out port is both Port2.

Now we need to modify routing in Azure to force traffic via firewall:
* For web subnet configure rule 0.0.0.0/0 via Fortigate (traffic go outside of VNET), but also route 10.0.5.0/24 (proxy subnet). Why? Routing is using longest prefix match and default rule sends VNET traffic directly so we need to create more specific rule for proxy subnet.
* For proxy subnet configure rule 10.0.1.0/24 (web subnet) via Fortigate

```powershell
# Create routing table sets
az network route-table create -g net-rg -n web-routing
az network route-table create -g net-rg -n proxy-routing

# Create rules for web-routing
az network route-table route create -g net-rg `
    --route-table-name web-routing `
    -n internetViaNgfw `
    --next-hop-type VirtualAppliance `
    --address-prefix "0.0.0.0/0" `
    --next-hop-ip-address "10.0.3.4"

az network route-table route create -g net-rg `
    --route-table-name web-routing `
    -n proxyViaNgfw `
    --next-hop-type VirtualAppliance `
    --address-prefix "10.0.5.0/24" `
    --next-hop-ip-address "10.0.3.4"

# Create rules for proxy-routing
az network route-table route create -g net-rg `
    --route-table-name proxy-routing `
    -n webViaNgfw `
    --next-hop-type VirtualAppliance `
    --address-prefix "10.0.1.0/24" `
    --next-hop-ip-address "10.0.3.4"

# Apply routing rules to subnets
az network vnet subnet update -n web `
    --vnet-name net `
    -g net-rg `
    --route-table web-routing

az network vnet subnet update -n proxy `
    --vnet-name net `
    -g net-rg `
    --route-table proxy-routing
```

Check things out. Via jump-vm SSH to proxy-vm and communication to 10.0.1.100 should work while connection to individual web-vms should be blocked.

```powershell
ssh azureuser@proxy-vm
    curl 10.0.1.100
    curl web-vm-01
```

## Step 8 - using Azure Stack VPN
To get private connectivity you can use Azure Stack VPN (native component) or 3rd party applicance such as Fortinet we deployed previously. To test both options we will now create VPN connection between Azure Stack VPN and Fortinet. We will create new VNET (entity completely isolated from our previous VNET) and use Azure Stack VPN on its side to connect to our first VNET with Fortigate VPN on that side.

First create new VNET with test server.

```powershell
$region = "local"

# Create resource group
az group create -n newnet-rg -l $region

# Create VNET with test subnet and GatewaySubnet
az network vnet create -n newnet -g newnet-rg --address-prefix 10.1.0.0/16
az network vnet subnet create -n test `
    -g newnet-rg `
    --vnet-name newnet `
    --address-prefix 10.1.0.0/24
az network vnet subnet create -n GatewaySubnet `
    -g newnet-rg `
    --vnet-name newnet `
    --address-prefix 10.1.1.0/24

# Create test vm
$image = "Canonical:UbuntuServer:16.04-LTS:16.04.20180831"

az vm create -n "test-vm" `
    -g newnet-rg `
    --image $image `
    --authentication-type password `
    --admin-username azureuser `
    --admin-password Azure12345678 `
    --public-ip-address '""' `
    --nsg '""' `
    --size Standard_DS1_v2 `
    --vnet-name newnet `
    --subnet test `
    --no-wait
```

Configure Azure Stack VPN

```powershell
# Store Fortinet public IP
$fortinetip = "1.2.3.4"

# Create public IP for Azure Stack VPN
az network public-ip create -n vpn-ip -g newnet-rg

# Create VPN gateway
az network vnet-gateway create -n vpn `
  -l $region `
  --public-ip-address vpn-ip `
  -g newnet-rg `
  --vnet newnet `
  --gateway-type Vpn `
  --sku Basic `
  --vpn-type RouteBased `
  --no-wait

# Add peer configuration
az network local-gateway create -n myFortinet `
    --gateway-ip-address $fortinetip `
    -g newnet-rg `
    --local-address-prefixes 10.0.0.0/16

# Add connection
az network vpn-connection create -n toFortinet `
    -g newnet-rg `
    --vnet-gateway1 vpn `
    -l $region `
    --shared-key Azure12345678 `
    --local-gateway2 myFortinet

# Get Azure Stack VPN public IP
az network public-ip show -n vpn-ip -g newnet-rg --query ipAddress -o tsv
```

Azure Stack VPN supports only route-based VPN type, not policy-based. Therefore we need to create virtual IPSec interface in Fortigate.

In Fortinet we will use VPN -> IPSec Wizard
* Use custom template type
* Configure IPSec
  * Use remote IP of Azure Stack VPN
  * Select Port1
  * Disable NAT Traversal
  * Configure Dead Peer Detection On Idle
  * Configure pre-shared key Azure12345678
  * Use IKEv2
  * Use Diffie-Hellman Group 2
  * Key lifetime 28800
  * Go to advanced settings of phase 2
    * Disable PFS which is currently not supported in Azure Stack (it is in Azure so this might change in future)
    * Configure key life time to Both
      * 27000 seconds
      * 33553408 KB

Now we need to add routes in Network -> Static Routes
* 10.1.0.0/16 -> toAzureStack (virtual IPSec interface)

Add policy in Policies & Objects -> IPv4 Policy
* From Port2 to toAzureStack
* Source and Destination to All
* Service SSH
* Disable NAT

You should now see tunnel up in Azure Stack portal (on Connection) and in Fortigate Monitor -> IPSec Monitor

To test things out go to jump VM (note we are not able to get to remote side from it as we are not routing jump subnet via Fortigate) and connect to db-vm (which is routed via Fortigate). Try to SSH to remote site.

```powershell
ssh azureuser@db-vm
    ssh azureuser@10.1.0.4
```

## Step 9 - Cleanup

```powershell
az group delete -n web-rg --no-wait -y
az group delete -n jump-rg --no-wait -y
az group delete -n db-rg --no-wait -y
az group delete -n proxy-rg --no-wait -y
az group delete -n fortinet-rg --no-wait -y
az group delete -n newnet-rg --no-wait -y

# When VM resources are deleted, destroy network
az group delete -n net-rg --no-wait -y 
```