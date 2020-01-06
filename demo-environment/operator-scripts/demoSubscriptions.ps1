param (
    [string]$OwnersFile
)

# Read owners file and create subscriptions for users listed there
foreach($owner in Get-Content $OwnersFile) {
    $name = -join($owner.split('@')[0], "-demo")
    Write-Output "Creating subscription $name"
    New-AzsUserSubscription -Owner $owner `
        -OfferId $((Get-AzsManagedOffer -Name "demo-offer" -ResourceGroupName portfolio).Id) `
        -DisplayName $name
}

# Get all subscriptions with -demo suffix and delete all not listed in owners file
# TBD


