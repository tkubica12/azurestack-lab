# Demo architecture
TBD

# Monitoring
All VMs are configured with VM Extensions to provision agents to be monitored from Azure including Azure Monitor agent, Dependency agent and onboarding to Azure Arc for Servers.

- Show VM Extensions on Windows and Linux machines
- In Azure open arc-azurestack-rg and showcase Azure Arc for Servers
- In Azure open Azure Monitor and show VM Insights including Map and telemetry
- In Azure open Azure Monitor Logs and search for logs from all monitored VMs

# Virtual Machine Scale Set
There are two apps - one Windows and one Linux deployed as VMSS. This solution automatically creates VMs and use VM Extensions to configure application. Use Scale to quickly increase number of Web VMs behind load-balancer.

External IPs:
- Linux web: azurepraha.com:9004
- Windows web: azurepraha:9001

# Automation - ARM template deployment
Showcase templates used to build Linux web, Windows web a SQL server.

Deploy templates (TBD)

In meantime show existing deployment to explain its components and VM Extension used to configure monitoring, install apps or SQL server.

