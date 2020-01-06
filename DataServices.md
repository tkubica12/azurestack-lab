# Azure Stack lab - Day 3 part 1: Data services
During first half of third day we will practice:
- Data services
  - Using Azure Stack storage services
  - Using SQL Resource Provider (PaaS shared style)
  - Deploying SQL server from template (IaaS dedicated style)


- [Azure Stack lab - Day 3 part 1: Data services](#azure-stack-lab---day-3-part-1-data-services)
  - [Prerequisities](#prerequisities)
  - [Step 1 - deploy Storage Account and connect Storage Explorer](#step-1---deploy-storage-account-and-connect-storage-explorer)
  - [Step 2 - using Blob Storage with Azure Storage Explorer](#step-2---using-blob-storage-with-azure-storage-explorer)
  - [Step 3 - automating blob operations with AzCopy](#step-3---automating-blob-operations-with-azcopy)
  - [Step 4 - using Table Storage](#step-4---using-table-storage)
  - [Step 5 - Using SQL Resource Provider (PaaS shared style)](#step-5---using-sql-resource-provider-paas-shared-style)
  - [Step 6 - Provisioning dedicated SQL Server (IaaS dedicated style)](#step-6---provisioning-dedicated-sql-server-iaas-dedicated-style)

## Prerequisities
Check [README](./README.md)

## Step 1 - deploy Storage Account and connect Storage Explorer
First we will deploy storage account. You may use GUI, CLI, PowerShell or ARM template to achive that.

In our lab we will use [Storage Explorer](https://azure.microsoft.com/en-us/features/storage-explorer/) to connect and manage our storage account. Open it.

Go to Edit menu a select Target Azure Stack APIs.

There are multiple ways how you can authenticate. With AAD login you will be able to see all your accounts, but you can allso use Connection string method to add accounts one by one (you do not have to own that resource in Azure Stack, having Connection string is enough). Click electricty plug icon, select Add Azure Account add select Add environment. Your Azure Stack ARM endpoint is in format https://management.yourdomain. Click connect to get in.

You should now see your storage account in explorer.

**Note:** As of version 1.9 AAD login is not supported for Azure Stack when using Guest accounts. Reason is that as opposed to Azure guest accounts cannot look for proper tokens only in their home AAD, but that process needs to be initiated via hosting domain. That is reason why we are using --tenant on az login to point to right hosting domain and the same for portal access with domain hint (portalurl/hostingdomain.onmicrosoft.com). Storage Explorer currently does not support specifying this and always go to domain based on UPN so fails for guest accounts. This is planned for fix in 1.11. As workaround use other authentication methods such as connection string, storage key or SAS token.

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

## Step 5 - Using SQL Resource Provider (PaaS shared style)
Make sure [Azure Data Studio](https://docs.microsoft.com/en-us/sql/azure-data-studio/download?view=sql-server-2017) is installed on your notebook.

Use GUI to get provider-managed SQL database. Use yourname-db as database name and select one of available SKUs. Create new login and than create database.

Open your Azure Data Studio and connect to your database using connection string you copy to clipboard from GUI of your database (and provide password).

We can create table and fill some values and than query.

```sql
CREATE TABLE Customers (
  CustomerId int NOT NULL PRIMARY KEY,
  CustomerName nvarchar(255) NOT NULL
);

INSERT INTO Customers
VALUES  (1, 'Tomas'),
        (2, 'Karel');

SELECT * FROM Customers;
```

Open servers and check you can only see your own database and tables.

Note that this is Database as a Service so you do not own SQL Server. You cannot create new DATABASE using T-SQL commands. Try this query:

```sql
CREATE DATABASE tomas2;
```

## Step 6 - Provisioning dedicated SQL Server (IaaS dedicated style)
Use Portal to install compute template such as SQL Server 2017 Standard on Windows Server 2016. In step 3 do not use NSG for now (in advanced click None). Note in step 4 wizard asks for SQL specific configurations and will install single-VM SQL Server. Make SQL Server public. 

When VM is created and SQL Server automatically configured get its public IP and connect to it using Azure Data Studio. Since now you own whole server we can create multiple databases.

```sql
CREATE DATABASE app1;
GO

USE app1;

CREATE TABLE Customers (
  CustomerId int NOT NULL PRIMARY KEY,
  CustomerName nvarchar(255) NOT NULL
);

INSERT INTO Customers
VALUES  (1, 'Tomas'),
        (2, 'Karel');

GO

CREATE DATABASE app2;
GO

USE app2;

CREATE TABLE People (
  PersonId int NOT NULL PRIMARY KEY,
  PersonName nvarchar(255) NOT NULL
);

INSERT INTO People
VALUES  (1, 'Tomas'),
        (2, 'Karel');

CREATE TABLE Animals (
  AnimalId int NOT NULL PRIMARY KEY,
  AnimalName nvarchar(255) NOT NULL
);

INSERT INTO Animals
VALUES  (1, 'Certik'),
        (2, 'Vlocka');

GO
```

Open your SQL VM in Azure Stack portal and check SQL server configuration page from which you can do basic monitoring and setup things like patching or backup.