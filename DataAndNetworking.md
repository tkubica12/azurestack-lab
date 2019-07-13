# Azure Stack lab - Day 3: Data and networking services
During third day we will practice:
- Data services
  - Using Azure Stack storage services
  - Using SQL Resource Provider
- Advanced networking scenarios
  - Depolying enterprise-grade firewall (eg. CheckPoint or Fortinet)
  - Deploying enterprise-grade WAF (eg. F5)
  - Using Azure Stack VPN
  - Provisioning 3rd party VPN service

## Prerequisities
Check [README](./README.md)

## Step 1 - using Blob Storage

## Step 2 - using Table Storage
Since this is not programming class we will observe Table storage via [Azure Storage Explorer](https://www.storageexplorer.com/) and simple REST query.

1. Use Storage Explorer to connect to storage account.
2. Create new table.
3. Use import button and select [data/zoopraha.csv](data/zoopraha.csv) data file.
4. Observe table structure.
5. Filter by PartitionKey (region), eg. Evropa.
6. Further filter by biotop, eg. hory

There are SDKs to multiple programming languages available. Also querying table can be done using HTTP interface with standard OData filtering syntax.

In storage explorer right click on table to generate access token (SAS). Note you can define different tokens with different restrinctions including query, add, delete, update. You can do time restriction (limited validity) or even restrict to particular PartitionKey or RowKey ranges (eg. get access to animals in Europe only). Generate token and get full URL. You can now access full table via REST API (browser, PowerShell, curl, ...).

```powershell
# Store full URL with SAS token
$url = "https://youraccount.table.core.windows.net/zoo?st=2019-07-13T18%3A07%3A17Z&se=2019-07-14T18%3A07%3A17Z&sp=raud&sv=2018-03-28&tn=zoo&sig=somethingsomething"

# Prepare headers to get JSON output without metadata
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", 'application/json;odata=nometadata')

# Read full table and print results
(Invoke-RestMethod "$url" -Headers $headers).value

# Use OData select command to get just title column
(Invoke-RestMethod "$url&`$select=title" -Headers $headers).value

# Use OData filter command to get only animals in Europe
(Invoke-RestMethod "$url&`$select=title,PartitionKey&`$filter=PartitionKey%20eq%20'Evropa'" -Headers $headers).value

# Store results of your query in CSV file
(Invoke-RestMethod "$url&`$select=title,PartitionKey&`$filter=PartitionKey%20eq%20'Evropa'" -Headers $headers).value | ConvertTo-Csv | Out-File results.csv
```

## Step 3 - using SQL Resource Provider

## Step 4 - native networking services including VNETs, NSGs and LBs

## Step 5 - deploying Fortinet inside tenant environment

## Step 6 - deploying enterprise-grade reverse proxy / Web Application Firewall

## Step 7 - using Azure Stack VPN

## Step 8 - automated provisioning of 3rd party VPN connector