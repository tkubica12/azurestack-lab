param (
    [string]$OwnersFile
)

# Read owners file and create subscriptions for users listed there
foreach($owner in Get-Content $OwnersFile) {
    $name = -join($owner.split('@')[0], "-training")
    Write-Output "Creating subscription $name"
    New-AzsUserSubscription -Owner $owner `
        -OfferId $((Get-AzsManagedOffer -Name "training-offer" -ResourceGroupName portfolio).Id) `
        -DisplayName $name
}

# Get all subscriptions with -training suffix and delete all not listed in owners file
# TBD


