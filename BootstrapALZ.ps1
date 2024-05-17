##### Requires the following permissions: #####
#####   New-AzRoleAssignment -ObjectId (Get-AzADServicePrincipal -DisplayName "id-alz-bootstrap").Id -Scope /providers/Microsoft.Subscription -RoleDefinitionName "Contributor" #####
param (
    [String] $BillingScope,
    [String] $StorageAccountName,
    [String] $ResourceGroupName = "rg-alz-state",
    [String] $BootstrapSubscriptionName = "alz-state",
    [String] $Location = "uksouth",
    [String] $NetworkResourceGroupName = "rg-state-networking",
    [String] $VirtualNetworkName = "vnet-state",
    [String] $AddressPrefix = "172.28.2.32/28",
    [String] $VirtualHubVnetConnectionName = "vhc-alzstate-vnetstate",
    [bool] $Bootstrap = $false
)

$ErrorActionPreference = "Stop"
Install-Module Az.Subscription -Scope CurrentUser -Force -RequiredVersion 0.11.0
Import-Module Az.Subscription -Force

$tags = @{BusinessCriticality = "Mission-critical"; BusinessUnit = "Platform Operations"; DataClassification = "General"; OperationsTeam = "Platform Operations"; WorkloadName = "ALZ.Bootstrap"}

    Write-Host "Bootstrap mode: $Bootstrap"
    Write-Host "##[section]Subscription Creation"
    $alzStateSubscription = Get-AzSubscriptionAlias -AliasName $BootstrapSubscriptionName -ErrorAction SilentlyContinue
    if (!$alzStateSubscription) {
        Write-Host "Creating subscription $BootstrapSubscriptionName"
        $alzStateSubscription = New-AzSubscriptionAlias -AliasName $BootstrapSubscriptionName -SubscriptionName $BootstrapSubscriptionName -BillingScope $BillingScope -Workload Production
        Write-Host "Pause for 1 minute to allow subscription to complete provisioning"
        Start-Sleep -s 60
    }

    Write-Host "Subscription set to $($alzStateSubscription.AliasName)"
    $azureContext = Set-AzContext -Subscription $alzStateSubscription.SubscriptionId

    Write-Host "##[section]Resource Group Creation"
    $ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (!$ResourceGroup) {
        Write-Host "Creating resource group $ResourceGroupName"
        $ResourceGroup = New-AzResourceGroup -Name $ResourceGroupName `
            -Location $Location `
            -Tag $tags
    }

    Write-Host "##[section]Register Microsoft.Storage resource provider"
    $resourceProvider = Get-AzResourceProvider -ProviderNamespace Microsoft.Storage | Where-Object RegistrationState -eq "Registered"
    if (!$resourceProvider) {
        Write-Host "Registering Microsoft.Storage resource provider"
        $resourceProvider = Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
    }

    Write-Host "##[section]Storage account creation"
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
    if (!$storageAccount) {
        Write-Host "Creating storage account $StorageAccountName"
        $storageAccount = New-AzStorageAccount `
            -ResourceGroupName $ResourceGroupName `
            -Name $StorageAccountName `
            -Location $Location `
            -SkuName "Standard_LRS" `
            -Kind StorageV2 `
            -MinimumTlsVersion TLS1_2 `
            -EnableHttpsTrafficOnly $true `
            -AllowSharedKeyAccess $false `
            -AllowBlobPublicAccess $false `
            -Tag $tags

        Write-Host "Creating storage account access policy"
        $currentUserObjectId = (Get-AzADServicePrincipal -DisplayName id-alz-bootstrap).Id
        Write-Host "Creating storage account access policy for $currentUserObjectId"
        $assignment = New-AzRoleAssignment -RoleDefinitionName "Storage Blob Data Contributor" -Scope $storageAccount.Id -ObjectId $currentUserObjectId -PrincipalType ServicePrincipal
        $context = New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -UseConnectedAccount
        Write-Host "Creating storage account container"
        $container = New-AzStorageContainer -Name "tfstate" -Permission Off -Context $context
    }

    if (!$Bootstrap) {
        Write-Host "##[section]Register Microsoft.Network resource provider"
        $resourceProvider = Get-AzResourceProvider -ProviderNamespace Microsoft.Network | Where-Object RegistrationState -eq "Registered"
        if (!$resourceProvider) {
            Write-Host "Registering Microsoft.Network resource provider"
            $resourceProvider = Register-AzResourceProvider -ProviderNamespace Microsoft.Network
            Write-Host "Pause for 1 minute to allow resource provider to complete registration"
            Start-Sleep -s 60
        }

        Write-Host "##[section]Network Resource Group Creation"
        $NetworkResourceGroup = Get-AzResourceGroup -Name $NetworkResourceGroupName -ErrorAction SilentlyContinue
        if (!$NetworkResourceGroup) {
            Write-Host "Creating resource group $NetworkResourceGroupName"
            $NetworkResourceGroup = New-AzResourceGroup -Name $NetworkResourceGroupName `
                -Location $Location `
                -Tag $tags
        }

        Write-Host "##[section]Virtual Network Creation"
        $VirtualNetwork = Get-AzVirtualNetwork `
            -Name $VirtualNetworkName `
            -ResourceGroupName $NetworkResourceGroupName `
            -ErrorAction SilentlyContinue
        if (!$VirtualNetwork) {
            $NetworkSecurityGroup = Get-AzNetworkSecurityGroup `
                -Name "nsg-state-pe" `
                -ResourceGroupName $NetworkResourceGroupName `
                -ErrorAction SilentlyContinue
            if (!$NetworkSecurityGroup) {
                Write-Host "Creating NSG"
                $NetworkSecurityGroup = New-AzNetworkSecurityGroup `
                    -Name "nsg-state-pe" `
                    -ResourceGroupName $NetworkResourceGroupName `
                    -Location $Location `
                    -Tag $tags
            }
            Write-Host "Creating virtual network $VirtualNetworkName"
            $Subnet = New-AzVirtualNetworkSubnetConfig `
                -Name "state-subnet" `
                -AddressPrefix $AddressPrefix `
                -NetworkSecurityGroup $NetworkSecurityGroup
            $VirtualNetwork = New-AzVirtualNetwork -Name $VirtualNetworkName `
                -ResourceGroupName $NetworkResourceGroupName `
                -Location $Location `
                -AddressPrefix $AddressPrefix `
                -Subnet $Subnet `
                -Tag $tags
        }
        # set subnet details in pipeline variables
        $Subnet = Get-AzVirtualNetworkSubnetConfig -Name "state-subnet" -VirtualNetwork $VirtualNetwork
        Write-Host "##vso[task.setvariable variable=alzSubnetName;isOutput=true]$($Subnet.Id)"
    
        Write-Host "##[section]Virtual Hub Connection Creation"
        Write-Host "Subscription set to alz-connectivity"
        $azureContext = Set-AzContext "alz-connectivity"

        $HubResourceGroupName = "alz-connectivity"
        $HubName = "alz-hub-$Location"
        $VirtualHubVnetConnection = Get-AzVirtualHubVnetConnection `
            -ResourceGroupName $HubResourceGroupName `
            -VirtualHubName $HubName `
            -Name $VirtualHubVnetConnectionName `
            -ErrorAction SilentlyContinue
        if (!$VirtualHubVnetConnection) {
            Write-Host "Creating virtual hub connection"
            $VirtualHubVnetConnection = New-AzVirtualHubVnetConnection `
                -ResourceGroupName $HubResourceGroupName `
                -VirtualHubName $HubName `
                -Name $VirtualHubVnetConnectionName `
                -RemoteVirtualNetwork $VirtualNetwork `
                -EnableInternetSecurityFlag $true
        }
        Write-Host "Subscription set to $($alzStateSubscription.AliasName)"
        $azureContext = Set-AzContext -Subscription $alzStateSubscription.SubscriptionId

        Write-Host "##[section]Private endpoint creation"
        $privateEndpointName = "pend-$StorageAccountName-st"
        $privateEndpoint = Get-AzPrivateEndpoint -Name $privateEndpointName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        if (!$privateEndpoint) {
            Write-Host "Creating private link service connection"
            $privateLinkServiceConnection = New-AzPrivateLinkServiceConnection `
                -Name "plsc-$StorageAccountName-blob"`
                -PrivateLinkServiceId $storageAccount.Id `
                -GroupId "blob"
        
            Write-Host "Creating private endpoint"
            $privateEndpoint = New-AzPrivateEndpoint `
                -Name $privateEndpointName `
                -ResourceGroupName $ResourceGroupName `
                -Location $Location `
                -Subnet $Subnet `
                -PrivateLinkServiceConnection $privateLinkServiceConnection `
                -Tag $tags

            Write-Host "Pause for 10 minutes to allow private DNS policy to apply"
            Start-Sleep -s 600
        }

        Write-Host "##[section]Configure storage account network rules"
        Write-Host "Updating storage account network rule set with default action Deny"
        $ruleSet = Update-AzStorageAccountNetworkRuleSet `
            -Name $StorageAccountName `
            -ResourceGroupName $ResourceGroupName `
            -DefaultAction Deny
        Write-Host "Configuring storage account to only allow access from private endpoint"
        $storageAccount = Set-AzStorageAccount `
            -Name $StorageAccountName `
            -ResourceGroupName $ResourceGroupName `
            -PublicNetworkAccess Disabled
    }

    # set subscription details in pipeline variables
    Write-Host "##vso[task.setvariable variable=alzStateSubscriptionId;isOutput=true]$($alzStateSubscription.SubscriptionId)"
    Write-Output "alz-state-subscription-id=$($alzStateSubscription.SubscriptionId)" >> $Env:GITHUB_OUTPUT
    # set storage account details in pipeline variables
    Write-Host "##vso[task.setvariable variable=alzStateStorageAccountName;isOutput=true]$($storageAccount.StorageAccountName)"
    Write-Output "alz-state-storage-account-name=$($storageAccount.StorageAccountName)" >> $Env:GITHUB_OUTPUT
    # set billing scope details in pipeline variables
    Write-Host "##vso[task.setvariable variable=billingScopeId;isOutput=true]${BillingScope}"
    Write-Output "billing-scope-id=${BillingScope}" >> $Env:GITHUB_OUTPUT