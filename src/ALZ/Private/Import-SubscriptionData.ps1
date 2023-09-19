function Import-SubscriptionData {
    <#

    #>
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $starterModuleConfiguration,
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $bootstrapConfiguration
    )

    $subscriptions = $starterModuleConfiguration.PsObject.Properties | Where-Object { $_.Value.Validator -eq "azure_subscription_id" }
    $subscriptionIds = @()
    foreach($subscription in $subscriptions) {
        $subscriptionIds += $subscription.Value.Value
    }

    $subscriptionIdsJoined = $subscriptionIds -join ","
    $subscriptionsObject = $bootstrapConfiguration.PsObject.Properties | Where-Object { $_.Value.Validator -eq "hidden_azure_subscription_ids" }
    $subscriptionsObject.Value.Value = $subscriptionIdsJoined
}