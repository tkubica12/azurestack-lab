apt update
apt install nginx -y
echo "v1: Hi from $HOSTNAME" >  /var/www/html/index.html