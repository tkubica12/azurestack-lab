# Demo architecture
External access:
- Windows web on VMSS: http://azurepraha:9002
- Linux todo web on VMSS: http://azurepraha:9003
- SSH to router: azurepraha.com:22
- RDP to AD: azurepraha:9001
- VMSS ARM automation demo: http://azurepraha:9004/info.aspx

# Monitoring
All VMs are configured with VM Extensions to provision agents to be monitored from Azure including Azure Monitor agent, Dependency agent and onboarding to Azure Arc for Servers.

- Show VM Extensions on Windows and Linux machines
- In Azure open arc-azurestack-rg and showcase Azure Arc for Servers
- In Azure open Azure Monitor and show VM Insights including Map and telemetry
- In Azure open Azure Monitor Logs and search for logs from all monitored VMs

# Virtual Machine Scale Set
There are two apps - one Windows and one Linux deployed as VMSS. This solution automatically creates VMs and use VM Extensions to configure application. Use Scale to quickly increase number of Web VMs behind load-balancer.

External IPs:
- Linux web: http://azurepraha:9003
- Windows web: http://azurepraha:9002 and http://azurepraha:9002/info.aspx

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
curl http://azurepraha:9002/info.aspx
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
curl http://azurepraha:9002/info.aspx
```

Go to GUI of VMSS and see Instances are not running on latest model (meaning latest versions of images, DSC scripts etc.). Upgrade one of VMs and use curl to see, that we get balanced betwwen two VMs - one running v1, one v2. Once you are satisfied, upgrade all instances to new model and everything runs on v2.

Also check monitoring in Azure works.

Destroy demo environment.

```powershell
az group delete -n armdemo-web-rg -l $region
```