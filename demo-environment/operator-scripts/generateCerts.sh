# Install certbot
sudo add-apt-repository ppa:certbot/certbot
sudo apt install python-certbot-apache

# Generate certificate using hook scripts to create and remove DNS records in Azure DNS for acme challange
export domain="stack.azurepraha.com"

## Azure Stack cert for management and PaaS
sudo certbot certonly --manual \
    --manual-auth-hook ./certbotAzureDns.sh \
    --manual-cleanup-hook ./certbotAzureClean.sh \
    --preferred-challenges dns --agree-tos \
    -d "portal.$domain" \
    -d "adminportal.$domain" \
    -d "management.$domain" \
    -d "adminmanagement.$domain" \
    -d "*.blob.$domain" \
    -d "*.table.$domain" \
    -d "*.queue.$domain" \
    -d "*.vault.$domain" \
    -d "*.adminvault.$domain" \
    -d "*.adminhosting.$domain" \
    -d "*.hosting.$domain" \
    -d "*.dbadapter.$domain" \
    -d "*.appservice.$domain" \
    -d "*.scm.appservice.$domain" \
    -d "*.sso.appservice.$domain"
    
## App Service cert for ftp, api and sso
sudo certbot certonly --manual \
    --manual-auth-hook ./certbotAzureDns.sh \
    --manual-cleanup-hook ./certbotAzureClean.sh \
    --preferred-challenges dns --agree-tos \
    -d "api.appservice.$domain" \
    -d "ftp.appservice.$domain" \
    -d "sso.appservice.$domain"

# Export as PFX
sudo openssl pkcs12 -export \
    -out ./azurestack.pfx \
    -inkey /etc/letsencrypt/live/portal.stack.azurepraha.com/privkey.pem \
    -in /etc/letsencrypt/live/portal.stack.azurepraha.com/cert.pem \
    -certfile /etc/letsencrypt/live/portal.stack.azurepraha.com/chain.pem

sudo openssl pkcs12 -export \
    -out ./azurestack-apiftpsso.pfx \
    -inkey /etc/letsencrypt/live/api.appservice.stack.azurepraha.com/privkey.pem \
    -in /etc/letsencrypt/live/api.appservice.stack.azurepraha.com/cert.pem \
    -certfile /etc/letsencrypt/live/api.appservice.stack.azurepraha.com/chain.pem
