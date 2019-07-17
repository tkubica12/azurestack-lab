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

## Step 1 - deploy Storage Account and connect Storage Explorer
First we will deploy storage account. You may use GUI, CLI, PowerShell or ARM template to achive that.

In our lab we will use [Storage Explorer](https://azure.microsoft.com/en-us/features/storage-explorer/) to connect and manage our storage account. Open it.

Go to Edit menu a select Target Azure Stack APIs.

There are multiple ways how you can authenticate. With AAD login you will be able to see all your accounts, but you can allso use Connection string method to add accounts one by one (you do not have to own that resource in Azure Stack, having Connection string is enough). Click electricty plug icon, select Add Azure Account add select Add environment. Your Azure Stack ARM endpoint is in format https://management.yourdomain. Click connect to get in.

You should now see your storage account in explorer.

## Step 2 - using Blob Storage with Azure Storage Explorer
Blob storage is object store for objects such as documents, images, video content or generic files. It is organized with containers.

Use storage explorer to create two containers - mypublic and myprivate. 

By default container is set as private so authentication is required to access files. For our mypublic we will change it to public access so no authentication will be needed to access files (eg. for content used by public web site). Right click mypublic, select  Set container public access level and choose Public read access for container and blobs.

Get some JPEG image file and upload it to both mypublic and myprivate containers.

Right-click image in mypublic folder, select Properties and copy object Uri. Open internet browser and place Uri there - you should see picture. Note it is automatically interpretted by browser as image rather than file so is displayed directly. If you upload content such as video file, your browser will start streaming it and you can jump in time etc.

Use the same to get Uri of object in your myprivate folder. Open Uri in browser and this should fail, because myprivate container requires authnetication. To enebla that let's create SAS token that will get time limited access to file and also be limited for Read operations only. Right click object and select Share Access Signature. Keep Access Policy in None (more on this later) Set start time an hour in past and limit endtime validity (eg. next day token will expire). Make sure you only allow Read priviledge and click Create. Copy URL and place it in browser - this time picture will load. Note you can generate as many tokens as you want and tokens can be based on individual objects or full container or even full storage account.

There is one limitation with standard SAS token in scenario when you need to revoke access. Only way to do that is to regenerate (change) storage account key, but this will invalidate all SAS tokens for everybody. When you need more granularity you may use Access Policy and generate token for it. 
1. Right-click on myprivate container and select Manage Access Policies and add new one. 
2. Right-click on object and create new Shared Access Signature, but this time select your Access Policy.
3. Copy URL and make sure image can be loaded.
4. Go back to Managed Access Policies and remove your policy.
5. Refresh your browser - image should no longer be accessible.

## Step 3 - automating blob operations with AzCopy
Storage explorer is convenient, but you might use Blob in your applications directly as API is supported by many 3rd party tools (backup systems, applications such as Wordpress etc.). You may also use AzCopy utility in your scripts.

Make sure you have downloaded [AzCopy](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10) for your OS and copy azcopy.exe to some location that is in your PATH. To authenticate create SAS token for your container myprivate - right-click on container in storage explorer and generate SAS token with full permissions.

```powershell
# Create folder
New-Item -Path "." -Name "myfiles" -ItemType "directory"

# Container URL with token
$container = "https://yourstorageaccount.azurestackdomainz/myprivate?tokenparams" # replace with yours

# Configure AzCopy to use proper API version for Azure Stack
$env:AZCOPY_DEFAULT_SERVICE_API_VERSION="2017-11-09"

# Sync cloud files with local folder
azcopy sync $container ".\myfiles" --recursive
```

Make sure your myfiles folder now contains you image.

Copy some other files to this local folder.

We will now sync your local folder with Blob container. Be careful with --delete-destination flag. When set to true, azcopy will delete files in Blob container that are not in your local folder.

```powershell
azcopy sync ".\myfiles"  $container --recursive --delete-destination false
```

## Step 4 - using Table Storage
Since this is not programming class we will observe Table storage via [Azure Storage Explorer](https://www.storageexplorer.com/).

1. Use Storage Explorer to connect to storage account.
2. Create new table.
3. Use import button and select [data/zoopraha.csv](data/zoopraha.csv) data file.
4. Observe table structure.
5. Filter by PartitionKey (region), eg. Evropa.
6. Further filter by biotop, eg. hory

There are SDKs to multiple programming languages available. Also querying table can be done using HTTP interface with standard OData filtering syntax.

In storage explorer right click on table to generate access token (SAS). Note you can define different tokens with different restrictions including query, add, delete, update. You can do time restriction (limited validity) or even restrict to particular PartitionKey or RowKey ranges (eg. get access to)

## Step 5 - using SQL Resource Provider

## Step 6 - native networking services including VNETs, NSGs and LBs

## Step 7 - deploying Fortinet inside tenant environment

## Step 8 - deploying enterprise-grade reverse proxy / Web Application Firewall

## Step 9 - using Azure Stack VPN

## Step 10 - automated provisioning of 3rd party VPN connector