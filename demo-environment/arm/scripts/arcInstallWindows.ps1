$secret=$args[0]

# Download the package
function download() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi}
download

# Install the package
msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

# Run connect command
& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
  --service-principal-id "aa1f2f11-cda1-477e-8aa6-c96f5ced80aa" `
  --service-principal-secret $secret `
  --resource-group "arc-azurestack-rg" `
  --tenant-id "72f988bf-86f1-41af-91ab-2d7cd011db47" `
  --location "westeurope" `
  --subscription-id "bd4b6767-6bbe-4cdd-9a33-9a6bd737afc2"