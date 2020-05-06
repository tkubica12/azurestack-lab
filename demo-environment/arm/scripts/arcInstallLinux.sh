# Download the installation package
wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh

# Install the hybrid agent
bash ~/install_linux_azcmagent.sh

# Run connect command
azcmagent connect \
  --service-principal-id "aa1f2f11-cda1-477e-8aa6-c96f5ced80aa" \
  --service-principal-secret $1 \
  --resource-group "arc-azurestack-rg" \
  --tenant-id "72f988bf-86f1-41af-91ab-2d7cd011db47" \
  --location "westeurope" \
  --subscription-id "bd4b6767-6bbe-4cdd-9a33-9a6bd737afc2"