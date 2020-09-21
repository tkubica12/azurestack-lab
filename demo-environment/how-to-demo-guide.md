# Demo architecture
External access:
- Windows web on VMSS: [http://windows.demo.azurepraha.com/info.aspx](http://windows.demo.azurepraha.com/info.aspx)
- Linux todo web on VMSS: [http://linux.demo.azurepraha.com/](http://linux.demo.azurepraha.com/)
- SSH to router: stackuser@demo.azurepraha.com
- RDP to AD: demo.azurepraha.com
- RDP to SQL VM: demo.azurepraha.com:9005
- VMSS ARM automation demo: [http://arm.demo.azurepraha.com/info.aspx](http://arm.demo.azurepraha.com/info.aspx)

# Monitoring
All VMs are configured with VM Extensions to provision agents to be monitored from Azure including Azure Monitor agent and Dependency agent

- Show VM Extensions on Windows and Linux machines
- In Azure open Azure Monitor and show VM Insights including Map and telemetry
- In Azure open Azure Monitor Logs and search for logs from all monitored VMs - Syslog, Events, Update, WindowsFirewall, ConfigurationData
- Open Security Center, show vulnerabilities, updates missing etc. on sql-vm and others
- Open Azure Sentinel and show connectors and incidents
- In Azure open Azure Monitor Applications and show appinsightsazurestackczsk-ot
    - Application Map and click on instances and calls
    - Search and click on some Request item to show distributed application tracing (calls between various components)
    - Performance and show characteristics of various API calls
    - Metrics - show built-in and custom metrics

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

# Virtual Machine Scale Set
There are two apps - one Windows and one Linux deployed as VMSS. This solution automatically creates VMs and use VM Extensions to configure application. Use Scale to quickly increase number of Web VMs behind load-balancer.

External IPs:
- Linux web: [http://linux.demo.azurepraha.com/](http://linux.demo.azurepraha.com/)
- Windows web: [http://windows.demo.azurepraha.com](http://windows.demo.azurepraha.com) and [http://windows.demo.azurepraha.com/info.aspx](http://windows.demo.azurepraha.com/info.aspx)

Windows app is simple web page returning node ID. Use curl (or disable cookie session persistance) to show how requests are balanced. Via GUI increase or decrease VM count.

Linux app is simple Todo application using SQL in IaaS VM as backend.

All installations are automatic using ARM templates to provision infrastructure and VM extensions to install SQL, applications, Arc management, monitoring agents and also join Windows VMs to domain.

Now lets upgrade Windows app. Use template to run v2 installer on farm of virtual machines.

```powershell
az group deployment create -g windows-web-rg `
    --template-file stack-windows-web.json `
    --parameters @stack-windows-web.parameters.json `
    --parameters appVersion=v2
```

Note you still see v1 in output of our app:

```powershell
curl http://windows.demo.azurepraha.com/info.aspx
```

Go to GUI of VMSS and see Instances are not running on latest model (meaning latest versions of images, DSC scripts etc.). Upgrade one of VMs and use curl to see, that we get balanced betwwen two VMs - one running v1, one v2. Once you are satisfied, upgrade all instances to new model and everything runs on v2.

To bring demo to its initial state, deploy v1 and upgrade all instances.

```powershell
az group deployment create -g windows-web-rg `
    --template-file stack-windows-web.json `
    --parameters @stack-windows-web.parameters.json `
    --parameters appVersion=v1
```


# Automation - ARM template deployment
Showcase templates used to build Linux web, Windows web a SQL server.

Deploy Windows web farm template with v1 of application

```powershell
az group create -n armdemo-web-rg -l $region
az group deployment create -g armdemo-web-rg --template-file stack-windows-web.json `
     --parameters @stack-windows-web.parameters.json `
     --parameters name=demo1 `
     --parameters lbIp="10.1.3.100" `
     --parameters subnetName=armdemo-subnet `
     --parameters appVersion=v1
```

In meantime show existing deployment to explain its components and VM Extension used to configure monitoring, install apps or SQL server.

Now lets upgrade Windows app. Use template to run v2 installer on farm of virtual machines.

```powershell
az group deployment create -g armdemo-web-rg --template-file stack-windows-web.json `
     --parameters @stack-windows-web.parameters.json `
     --parameters name=demo1 `
     --parameters lbIp="10.1.3.100" `
     --parameters subnetName=armdemo-subnet `
     --parameters appVersion=v2
```

Note you still see v1 in output of our app:

```powershell
curl http://arm.demo.azurepraha.com/info.aspx
```

Go to GUI of VMSS and see Instances are not running on latest model (meaning latest versions of images, DSC scripts etc.). Upgrade one of VMs and use curl to see, that we get balanced betwwen two VMs - one running v1, one v2. Once you are satisfied, upgrade all instances to new model and everything runs on v2.

Also check monitoring in Azure works.

Destroy demo environment.

```powershell
az group delete -n armdemo-web-rg -y
```

# Kubernetes
Show Azure Arc for Kubernetes in AzureStackCZSK subscription arc-azurestack-rg resource group.

Go to Configuration section and explain, that complete state of cluster (deployed applications, reverse proxy and other components) is managed in declarative manner in this repo demo-environment/gitops-aks-state and demo-environment/helm folders using GitOps principles (Arc periodicaly downloads desired state and is making sure Kubernetes is configured accordingly and apps are deployed).

Vote is accessible at http://vote.aks.azurepraha.com

There is also opentelemetry application with traffic generator. There is no specific GUI for this app, but it exports data using Open Telemetry to Azure Monitor Application Insights for visualization, distributed tracing and Metrics collection.


