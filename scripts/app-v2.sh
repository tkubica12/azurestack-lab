apt update
apt install nginx -y
echo "v2: Hello from $HOSTNAME" >  /var/www/html/index.html