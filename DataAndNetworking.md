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
Since this is not programming class we will observe Table storage via [Azure Storage Explorer](https://www.storageexplorer.com/).

1. Use Storage Explorer to connect to storage account.
2. Create new table.
3. Use import button and select [data/zoopraha.csv](data/zoopraha.csv) data file.
4. Observe table structure.
5. Filter by PartitionKey (region), eg. Evropa.
6. Further filter by biotop, eg. hory

There are SDKs to multiple programming languages available. Also querying table can be done using HTTP interface with standard OData filtering syntax.

## Step 3 - using SQL Resource Provider

## Step 4 - native networking services including VNETs, NSGs and LBs

## Step 5 - deploying Fortinet inside tenant environment

## Step 6 - deploying enterprise-grade reverse proxy / Web Application Firewall

## Step 7 - using Azure Stack VPN

## Step 8 - automated provisioning of 3rd party VPN connector