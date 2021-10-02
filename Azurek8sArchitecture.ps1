#vars
$azAccountId = $(az account show --query id --output tsv)
$adTenantId = $(az account show --query tenantId --output tsv)

$azureLocation = "southcentralus"

$rgServicesName = "rg_yovoydelivery_services_scus"
$rgStorageName = "rg_yovoydelivery_storage_scus"
$rgDataName = "rg_yovoydelivery_data_scus"
$rgDevOpsName = "rg_yovoydelivery_devops_scus"

$vnetServicesName = "vnet_services_scus"
$subnetServicesName = "subnet_services"
$nsgServicesName = "nsg_services"

$akvName = "akvyovoydeliveryscus"

$asaName = "asayovoydeliveryscus"

$acrName = "acryovoydeliveryscus"
$acrLoginServer = "https://acryovoydeliveryscus.azurecr.io"

$lawsName = "lawsyovoydeliveryscus"

$aaiName = "aaiyovoydeliveryscus"

$aapName = "aapyovoydeliveryscus"

$spName = "spaksyovoydeliveryscus"
$spCertName = "spaksyovoydeliveryscuscert"

$aksName = "aksyovoydeliveryscus"
$aksClusterVMSKU = "Standard_B2s"
$aksNodeCount = 1


$aadDomainName = "yovoydelivery.com"

$asqlName = "sqlyovoydeliveryscus"
$asqlAdmin = ""
$asqlPassword = ""
$devSQLDbGeneralParams = "Dev-YoVoyDelivery-GeneralParams"

#Resource Groups

az group create --name $rgServicesName --location $azureLocation
az group create --name $rgStorageName --location $azureLocation
az group create --name $rgDataName --location $azureLocation
az group create --name $rgDevOpsName --location $azureLocation

#azure keyvault

az keyvault create --name $akvName --resource-group $rgStorageName --location $azureLocation --default-action deny --enabled-for-disk-encryption true --enabled-for-deployment true --enabled-for-template-deployment true --sku standard --tags 'ResourceType=AzureKeyVault' 'Region=SouthCentralUS'

#azure storage account 

az storage account create --name $asaName --resource-group $rgStorageName --location $azureLocation --kind StorageV2 --sku Standard_LRS --access-tier Cool --domain-name $aadDomainName --tags 'ResourceType=AzureStorageAccount' 'Region=SouthCentralUS'

#azure container registry

az acr create --name $acrName --resource-group $rgStorageName --sku Basic --location $azureLocation --tags 'ResourceType=AzureContainerRegistry' 'Region=SouthCentralUS'

$acrId = $(az acr show --resource-group $rgStorageName --name $acrName --query "id" --output tsv)

#azure Log-Analytics WorkSpace

$lawsId = $(az monitor log-analytics workspace create --workspace-name $lawsName --resource-group $rgStorageName --sku "PerGB2018" --query "id" --output tsv --tags 'ResourceType=AzureLogsAnalyticsWorkSpace' 'Region=SouthCentralUS')

#azure Application Insights

az extension add -n application-insights

az monitor app-insights component create --app $appInsName --location $azureLocation --resource-group $rgServicesName --workspace $lawsId --tags 'ResourceType=ApplicationInsights' 'Region=SouthCentralUS'

#Azure App Configuration

az appconfig create --name $aapName --resource-group $rgServicesName --location $azureLocation --sku "Standard" #--tags 'ResourceType=AzureApplicationInsights' 'Region=SouthCentralUS'

#Service Principal

#For reset service principal
#$spAppId = $(az ad sp list --spn http://$spName --query "[].appId" -o tsv)

#az ad sp delete --id $spAppId

az ad sp create-for-rbac --skip-assignment --name $spName --role Reader --scopes $acrID --keyvault $akvName --cert $spCert --create-cert

$spAppId = $(az ad sp list --spn http://$spName --query "[].appId" -o tsv)

$spSecret = $(az ad sp create-for-rbac --skip-assignment --name http://$spName --query password --output tsv)

#Virtual Network

az network vnet create --resource-group $rgServicesName --name $vnetServicesName --address-prefix 10.1.0.0/16 --ddos-protection false --tags 'ResourceType=VirtualNetwork' 'Region=SouthCentralUS'

#create a ddos plan and attach it to your vnet
#--ddos-protection-plan <your ddos plan name>

#Service subnet creation with network security group

az network nsg create --resource-group $rgServicesName --name $nsgServicesName --tags 'ResourceType=AzureNetworkSecurityGroup' 'Region=SouthCentralUS'

az network nsg rule create --resource-group $rgServicesName --name "Internet" --nsg-name $nsgServicesName --priority 100 --access Allow --description "Internet Inbound" --source-address-prefixes "Internet" --source-port-ranges * --destination-address-prefixes 10.1.1.0/24 --destination-port-ranges 443 --direction Inbound --protocol *

az network vnet subnet create --resource-group $rgServicesName --vnet-name $vnetServicesName --name $subnetServicesName --address-prefixes 10.1.0.0/24 #--network-security-group $nsgServicesName

#adding network-contributor and reader role  to the service principal

$vnetId = $(az network vnet show --resource-group $rgServicesName --name $vnetServicesName --query id -o tsv)
$subnetId = $(az network vnet subnet show --resource-group $rgServicesName --vnet-name $vnetServicesName --name $subnetServicesName --query id -o tsv)

az role assignment create --assignee $spAppId --scope $vnetId --role "Network Contributor"

az role assignment create --assignee $spAppId --scope $acrId --role Reader

#Kubernetes cluster
#https://aka.ms/supported-version-list
az aks create --resource-group $rgServicesName --name $aksName --service-principal $spAppId --client-secret $spSecret --node-count $aksNodeCount --node-vm-size $aksClusterVMSKU --network-plugin kubenet --network-policy calico --service-cidr 10.2.0.0/16 --dns-service-ip 10.2.0.10 --pod-cidr 10.20.0.0/16 --docker-bridge-address 192.168.99.100/24 --vnet-subnet-id $subnetId --generate-ssh-keys --kubernetes-version 1.21.2 --attach-acr $acrName --tags 'ResourceType=AzureKubernetesServices' 'Region=SouthCentralUS'

az aks show --resource-group $rgServicesName --name $aksName --output table

az aks get-credentials --resource-group $rgName --name $aksName

#Azure Sql Server

az sql server create --location $azureLocation --resource-group $rgDataName --name $asqlName -u $asqlAdmin -p $asqlPassword

az sql db create --resource-group $rgDataName --server $asqlName --name $devSQLDbGeneralParams --edition Basic --capacity 5 --max-size "100MB" --zone-redundant false # zone redundancy is only supported on premium and business critical service tiers

#DNS Zone

az network dns zone create --resource-group $rgServicesName --name $aadDomainName