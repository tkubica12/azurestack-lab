sudo mkdir /app
sudo wget -P /app https://github.com/tkubica12/dotnetcore-sqldb-tutorial/raw/master/linuxrelease-v1.tar
sudo tar -xvf /app/linuxrelease-v1.tar -C /app
wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo add-apt-repository universe
sudo apt-get install -y apt-transport-https
sudo apt-get update
sudo apt-get install -y dotnet-sdk-2.1

export db="Server=tcp:$1,1433;Initial Catalog=todo;Persist Security Info=False;User ID=$2;Password=$3;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

cat > app.service << EOF
[Unit]
Description=Moje aplikace

[Service]
WorkingDirectory=/app
ExecStart = /usr/bin/dotnet /app/DotNetCoreSqlDb.dll
Restart=always
Environment=SQLCONNSTR_mojeDB="$db"
Environment=ASPNETCORE_ENVIRONMENT=Development
Environment=ASPNETCORE_URLS="http://0.0.0.0:80"

[Install]
WantedBy=multi-user.target
EOF

sudo cp app.service /etc/systemd/system/app.service
sudo systemctl daemon-reload
sudo systemctl stop app
sudo systemctl start app
