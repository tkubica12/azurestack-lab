param (
    [Parameter(Mandatory=$true)]
    [string]$InFile,
    [Parameter(Mandatory=$true)]
    [string]$OutFile,
    [parameter()]
    [ValidateSet("CSV", "JSON")]
    [String]$FileType = "CSV"
)

$meterTable = @{ 
    "f271a8a388c44d93956a063e1d2fa80b" = "Static IP Address Usage";
    "9e2739ba86744796b465f64674b822ba" = "Dynamic IP Address Usage";
    "b4438d5d-453b-4ee1-b42a-dc72e377f1e4" = "TableCapacity";
    "b5c15376-6c94-4fdd-b655-1a69d138aca3" = "PageBlobCapacity";
    "b03c6ae7-b080-4bfa-84a3-22c800f315c6" = "QueueCapacity";
    "09f8879e-87e9-4305-a572-4b7be209f857" = "BlockBlobCapacity";
    "b9ff3cd0-28aa-4762-84bb-ff8fbaea6a90" = "TableTransactions";
    "50a1aeaf-8eca-48a0-8973-a5b3077fee0d" = "TableDataTransIn";
    "1b8c1dec-ee42-414b-aa36-6229cf199370" = "TableDataTransOut";
    "43daf82b-4618-444a-b994-40c23f7cd438" = "BlobTransactions";
    "9764f92c-e44a-498e-8dc1-aad66587a810" = "BlobDataTransIn";
    "3023fef4-eca5-4d7b-87b3-cfbc061931e8" = "BlobDataTransOut";
    "eb43dd12-1aa6-4c4b-872c-faf15a6785ea" = "QueueTransactions";
    "e518e809-e369-4a45-9274-2017b29fff25" = "QueueDataTransIn";
    "dd0a10ba-a5d6-4cb6-88c0-7d585cef9fc2" = "QueueDataTransOut";
    "fab6eb84-500b-4a09-a8ca-7358f8bbaea5" = "Base VM Size Hours";
    "9cd92d4c-bafd-4492-b278-bedc2de8232a" = "Windows VM Size Hours";
    "6dab500f-a4fd-49c4-956d-229bb9c8c793" = "VM size hours";
    "380874f9-300c-48e0-95a0-d2d9a21ade8f" = "S4";
    "1b77d90f-427b-4435-b4f1-d78adec53222" = "S6";
    "d5f7731b-f639-404a-89d0-e46186e22c8d" = "S10";
    "ff85ef31-da5b-4eac-95dd-a69d6f97b18a" = "S15";
    "88ea9228-457a-4091-adc9-ad5194f30b6e" = "S20";
    "5b1db88a-8596-4002-8052-347947c26940" = "S30";
    "7660b45b-b29d-49cb-b816-59f30fbab011" = "P4";
    "817007fd-a077-477f-bc01-b876f27205fd" = "P6";
    "e554b6bc-96cd-4938-a5b5-0da990278519" = "P10";
    "cdc0f53a-62a9-4472-a06c-e99a23b02907" = "P15";
    "b9cb2d1a-84c2-4275-aa8b-70d2145d59aa" = "P20";
    "06bde724-9f94-43c0-84c3-d0fc54538369" = "P30";
    "7ba084ec-ef9c-4d64-a179-7732c6cb5e28" = "ActualStandardDiskSize";
    "daef389a-06e5-4684-a7f7-8813d9f792d5" = "ActualPremiumDiskSize";
    "108fa95b-be0d-4cd9-96e8-5b0d59505df1" = "ActualStandardSnapshotSize";
    "578ae51d-4ef9-42f9-85ae-42b52d3d83ac" = "ActualPremiumSnapshotSize";
    "cbcfef9a-b91f-4597-a4d3-01fe334bed82" = "DatabaseSizeHourSqlMeter";
    "e6d8cfcd-7734-495e-b1cc-5ab0b9c24bd3" = "DatabaseSizeHourMySqlMeter";
    "ebf13b9f-b3ea-46fe-bf54-396e93d48ab4" = "Key Vault transactions";
    "2c354225-b2fe-42e5-ad89-14f0ea302c87" = "Advanced keys transactions";
    "190c935e-9ada-48ff-9ab8-56ea1cf9adaa" = "App Service";
    "67cc4afc-0691-48e1-a4b8-d744d1fedbde" = "Functions Requests";
    "d1d04836-075c-4f27-bf65-0a1130ec60ed" = "Functions - Compute";
    "957e9f36-2c14-45a1-b6a1-1723ef71a01d" = "Shared App Service Hours";
    "539cdec7-b4f5-49f6-aac4-1f15cff0eda9" = "Free App Service Hours";
    "88039d51-a206-3a89-e9de-c5117e2d10a6" = "Small Standard App Service Hours";
    "83a2a13e-4788-78dd-5d55-2831b68ed825" = "Medium Standard App Service Hours";
    "1083b9db-e9bb-24be-a5e9-d6fdd0ddefe6" = "Large Standard App Service Hours";
    "264acb47-ad38-47f8-add3-47f01dc4f473" = "SNI SSL";
    "60b42d72-dc1c-472c-9895-6c516277edb4" = "IP SSL";
    "73215a6c-fa54-4284-b9c1-7e8ec871cc5b" = "Web Process";
    "5887d39b-0253-4e12-83c7-03e1a93dffd9" = "External Egress Bandwidth";
}

$content = Get-Content -Raw -Path $InFile | ConvertFrom-Json

$records = $content | Select SubscriptionId, UsageStartTime, UsageEndTime, Quantity, MeterId

[System.StringComparison]::CurrentCultureIgnoreCase
for ($i=0; $i -le $records.Count-1; $i++) {
    "Processing record " + ($i+1) + " of " + $records.Count
    $records[$i] | Add-Member -MemberType NoteProperty -Name 'meterName' -Value $meterTable[$records[$i].MeterId.ToLower()] -PassThru | Out-Null
    $instanceData = $content.InstanceData[$i] | ConvertFrom-Json | select -Expand "Microsoft.Resources"
    $records[$i] | Add-Member -MemberType NoteProperty -Name 'resourceUri' -Value $instanceData.resourceUri -PassThru | Out-Null
    $records[$i] | Add-Member -MemberType NoteProperty -Name 'location' -Value $instanceData.location -PassThru | Out-Null
    $records[$i] | Add-Member -MemberType NoteProperty -Name 'tags' -Value $instanceData.tags -PassThru | Out-Null

    $startIndex = $records[$i].resourceUri.IndexOf('/resourceGroups/')+16
    $length = $records[$i].resourceUri.IndexOf('/', $startIndex)-$startIndex
    $resourceGroup = $records[$i].resourceUri.Substring($startIndex, $length)
    $records[$i] | Add-Member -MemberType NoteProperty -Name 'resourceGroup' -Value $resourceGroup -PassThru | Out-Null

    if ($instanceData.additionalInfo.IndexOf('}') -gt 0) {
        $additionalInfo = $instanceData.additionalInfo | ConvertFrom-Json
    } else {
        $additionalInfo = ""
    }
    
    $records[$i] | Add-Member -MemberType NoteProperty -Name 'ServiceType' -Value $additionalInfo.ServiceType -PassThru | Out-Null
    $records[$i] | Add-Member -MemberType NoteProperty -Name 'Publisher' -Value $additionalInfo.Publisher -PassThru | Out-Null
    $records[$i] | Add-Member -MemberType NoteProperty -Name 'Offer' -Value $additionalInfo.Offer -PassThru | Out-Null
    $records[$i] | Add-Member -MemberType NoteProperty -Name 'Sku' -Value $additionalInfo.Sku -PassThru | Out-Null
}

if ($FileType -eq "CSV") {
    $records | ConvertTo-Csv | Out-File $OutFile
} else {
    $records | ConvertTo-Json | Out-File $OutFile
}

