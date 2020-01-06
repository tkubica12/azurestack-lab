# Set your region name
$region = "yourregionname"

# We will store quotas, plans and offers in single Resource Group
New-AzureRMResourceGroup -Location $region -Name portfolio

# Storage quotas
New-AzsStorageQuota -Name "q-storage-128GB" -CapacityInGb 128 -NumberOfStorageAccounts 100 
New-AzsStorageQuota -Name "q-storage-1TB" -CapacityInGb 1024 -NumberOfStorageAccounts 100 
New-AzsStorageQuota -Name "q-storage-10TB" -CapacityInGb 10240 -NumberOfStorageAccounts 100 

# Compute vCore quotas
New-AzsComputeQuota -Name "q-cores-2" -AvailabilitySetCount 2 -CoresCount 2 -VmScaleSetCount 2 -VirtualMachineCount 2 -StandardManagedDiskAndSnapshotSize 0 -PremiumManagedDiskAndSnapshotSize 0
New-AzsComputeQuota -Name "q-cores-10" -AvailabilitySetCount 10 -CoresCount 10 -VmScaleSetCount 10 -VirtualMachineCount 10 -StandardManagedDiskAndSnapshotSize 0 -PremiumManagedDiskAndSnapshotSize 0
New-AzsComputeQuota -Name "q-cores-50" -AvailabilitySetCount 50 -CoresCount 50 -VmScaleSetCount 50 -VirtualMachineCount 50 -StandardManagedDiskAndSnapshotSize 0 -PremiumManagedDiskAndSnapshotSize 0

# Compute Disk storage quotas
New-AzsComputeQuota -Name "q-disks-512GB" -AvailabilitySetCount 0 -CoresCount 0 -VmScaleSetCount 0 -VirtualMachineCount 0 -StandardManagedDiskAndSnapshotSize 512 -PremiumManagedDiskAndSnapshotSize 512
New-AzsComputeQuota -Name "q-disks-5TB" -AvailabilitySetCount 0 -CoresCount 0 -VmScaleSetCount 0 -VirtualMachineCount 0 -StandardManagedDiskAndSnapshotSize 5120 -PremiumManagedDiskAndSnapshotSize 5120
New-AzsComputeQuota -Name "q-disks-50TB" -AvailabilitySetCount 0 -CoresCount 0 -VmScaleSetCount 0 -VirtualMachineCount 0 -StandardManagedDiskAndSnapshotSize 51200 -PremiumManagedDiskAndSnapshotSize 51200

# Network quotas
New-AzsNetworkQuota -Name "q-net-1ip" -MaxPublicIpsPerSubscription "1"
New-AzsNetworkQuota -Name "q-net-5ip" -MaxPublicIpsPerSubscription "5"
New-AzsNetworkQuota -Name "q-net-10ip" -MaxPublicIpsPerSubscription "10"
New-AzsNetworkQuota -Name "q-net-50ip" -MaxPublicIpsPerSubscription "50"

# Create empty base plan
New-AzsPlan -Name "p-base" `
    -ResourceGroupName portfolio `
    -DisplayName "p-base" `
    -Description "Base plan with no IaaS/PaaaS resources" `
    -Location $region `
    -SkuIds @("Microsoft.KeyVault", "Microsoft.Subscriptions") `
    -QuotaIds $((Get-AzsSubscriptionsQuota -Name delegatedProviderQuota).Id), `
    $((Get-AzsKeyVaultQuota).Id)

# Create plans with compute, storage and networking quotas
New-AzsPlan -Name "p-cores-2" `
    -ResourceGroupName portfolio `
    -DisplayName "p-cores-2" `
    -Description "Addon plan with 2 cores" `
    -Location $region `
    -SkuIds @("Microsoft.Compute") `
    -QuotaIds $((Get-AzsComputeQuota -Name "q-cores-2").Id)

New-AzsPlan -Name "p-cores-10" `
    -ResourceGroupName portfolio `
    -DisplayName "p-cores-10" `
    -Description "Addon plan with 10 cores" `
    -Location $region `
    -SkuIds @("Microsoft.Compute") `
    -QuotaIds $((Get-AzsComputeQuota -Name "q-cores-10").Id)

New-AzsPlan -Name "p-cores-50" `
    -ResourceGroupName portfolio `
    -DisplayName "p-cores-50" `
    -Description "Addon plan with 50 cores" `
    -Location $region `
    -SkuIds @("Microsoft.Compute") `
    -QuotaIds $((Get-AzsComputeQuota -Name "q-cores-50").Id)

New-AzsPlan -Name "p-disks-512GB" `
    -ResourceGroupName portfolio `
    -DisplayName "p-disks-512GB" `
    -Description "Addon plan with 512GB disk capacity" `
    -Location $region `
    -SkuIds @("Microsoft.Compute") `
    -QuotaIds $((Get-AzsComputeQuota -Name "q-disks-512GB").Id)

New-AzsPlan -Name "p-disks-5TB" `
    -ResourceGroupName portfolio `
    -DisplayName "p-disks-5TB" `
    -Description "Addon plan with 5TB disk capacity" `
    -Location $region `
    -SkuIds @("Microsoft.Compute") `
    -QuotaIds $((Get-AzsComputeQuota -Name "q-disks-5TB").Id)

New-AzsPlan -Name "p-disks-50TB" `
    -ResourceGroupName portfolio `
    -DisplayName "p-disks-50TB" `
    -Description "Addon plan with 50TB disk capacity" `
    -Location $region `
    -SkuIds @("Microsoft.Compute") `
    -QuotaIds $((Get-AzsComputeQuota -Name "q-disks-50TB").Id)

New-AzsPlan -Name "p-storage-128GB" `
    -ResourceGroupName portfolio `
    -DisplayName "p-storage-128GB" `
    -Description "Addon plan with 128GB blob/table/queue storage capacity" `
    -Location $region `
    -SkuIds @("Microsoft.Storage") `
    -QuotaIds $((Get-AzsStorageQuota -Name "q-storage-128GB").Id)

New-AzsPlan -Name "p-storage-1TB" `
    -ResourceGroupName portfolio `
    -DisplayName "p-storage-1TB" `
    -Description "Addon plan with 1TB blob/table/queue storage capacity" `
    -Location $region `
    -SkuIds @("Microsoft.Storage") `
    -QuotaIds $((Get-AzsStorageQuota -Name "q-storage-1TB").Id)

New-AzsPlan -Name "p-storage-10TB" `
    -ResourceGroupName portfolio `
    -DisplayName "p-storage-10TB" `
    -Description "Addon plan with 10TB blob/table/queue storage capacity" `
    -Location $region `
    -SkuIds @("Microsoft.Storage") `
    -QuotaIds $((Get-AzsStorageQuota -Name "q-storage-10TB").Id)

New-AzsPlan -Name "p-net-1ip" `
    -ResourceGroupName portfolio `
    -DisplayName "p-net-1ip" `
    -Description "Addon plan with 1 public IP" `
    -Location $region `
    -SkuIds @("Microsoft.Network") `
    -QuotaIds $((Get-AzsNetworkQuota -Name "q-net-1ip").Id)

New-AzsPlan -Name "p-net-5ip" `
    -ResourceGroupName portfolio `
    -DisplayName "p-net-5ip" `
    -Description "Addon plan with 5 public IP" `
    -Location $region `
    -SkuIds @("Microsoft.Network") `
    -QuotaIds $((Get-AzsNetworkQuota -Name "q-net-5ip").Id)

New-AzsPlan -Name "p-net-10ip" `
    -ResourceGroupName portfolio `
    -DisplayName "p-net-10ip" `
    -Description "Addon plan with 10 public IP" `
    -Location $region `
    -SkuIds @("Microsoft.Network") `
    -QuotaIds $((Get-AzsNetworkQuota -Name "q-net-10ip").Id)

New-AzsPlan -Name "p-net-50ip" `
    -ResourceGroupName portfolio `
    -DisplayName "p-net-50ip" `
    -Description "Addon plan with 50 public IP" `
    -Location $region `
    -SkuIds @("Microsoft.Network") `
    -QuotaIds $((Get-AzsNetworkQuota -Name "q-net-50ip").Id)

# Create standard demo offer
New-AzsOffer -Name "demo-offer" `
    -DisplayName "demo-offer" `
    -ResourceGroupName portfolio `
    -State Private  `
    -BasePlanIds $(Get-AzsPlan -Name "p-base" -ResourceGroupName portfolio).Id, `
    $(Get-AzsPlan -Name "p-cores-10" -ResourceGroupName portfolio).Id, `
    $(Get-AzsPlan -Name "p-disks-5TB" -ResourceGroupName portfolio).Id, `
    $(Get-AzsPlan -Name "p-storage-1TB" -ResourceGroupName portfolio).Id, `
    $(Get-AzsPlan -Name "p-net-5ip" -ResourceGroupName portfolio).Id