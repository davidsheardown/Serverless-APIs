#!/bin/bash
set -euo pipefail

IFS=$'\n\t'

ECHO "Logging into your account"
az login
ECHO

subscriptionId=$(az account show --query 'id' -o tsv)

while getopts ":s:" arg; do
    case "${arg}" in
        s)
            subscriptionId=${OPTARG}
        ;;
    esac
done

if [[ -z "$subscriptionId" ]]; then
    echo "Enter the Subscription ID:"
    read subscriptionId
    [[ "${subscriptionId:?}" ]] 
fi

location="uksouth" 
rand=$(awk -v min=100000 -v max=999999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
storageAccountName="serverlesssample$rand"
appInsightsName="serverless-sample$rand"
productsFunctionName="serverless-sample-products$rand"
reviewsFunctionName="serverless-sample-reviews$rand"
resourceGroup="serverless-sample$rand"
functionsRuntimeVersion=$(func --version > version && cut -c1 version)

green=`tput setaf 2`
red=`tput setaf 1`
reset=`tput sgr0`
ECHO $green'==========================================================' 
ECHO
ECHO   $red'WELCOME TO THE API MANAGEMENT AND AZURE FUNCTIONS WORKSHOP'
ECHO 
ECHO "Setting Subscription Id to: " $red$subscriptionId$reset
az account set --subscription $subscriptionId
ECHO
ECHO
ECHO $green'=========================================================='  
ECHO
ECHO 'LETS START'$green':)'$reset 
ECHO 
ECHO 'Output results will be saved to '$red'serverless-apim-setup.log'$reset' file ...'
ECHO
ECHO '- Creating Resource Group '$red$resourceGroup$reset'...'
az group create -n $resourceGroup -l $location --output json > serverless-apim-setup.log

ECHO '- Creating '$red$storageAccountName$reset' Storage Account ...' 
az storage account create -n $storageAccountName -l $location -g $resourceGroup --sku Standard_LRS --output json >> serverless-apim-setup.log

ECHO '- Creating '$red$appInsightsName$reset' Application Insights Service ...'
appInsightsInstrumentationKey=$(az resource create -g $resourceGroup -n $appInsightsName --resource-type "Microsoft.Insights/components" --properties '{"Application_Type":"web"}'  --query 'properties.InstrumentationKey')
ECHO '- Application Insights Instrumentation Key: '$red$appInsightsInstrumentationKey$reset

ECHO '- Creating '$red$productsFunctionName$reset' Function App ...' 
az functionapp create -n $productsFunctionName --storage-account $storageAccountName --consumption-plan-location $location --app-insights $appInsightsName --app-insights-key $appInsightsInstrumentationKey  -g $resourceGroup --runtime dotnet --functions-version $functionsRuntimeVersion  >> serverless-apim-setup.log

ECHO '- Creating '$red$reviewsFunctionName$reset' Function App ...'
az functionapp create -n $reviewsFunctionName --storage-account $storageAccountName --consumption-plan-location $location --app-insights $appInsightsName  -g $resourceGroup  --functions-version $functionsRuntimeVersion --runtime node >> serverless-apim-setup.log

ECHO '- Deploying '$red$productsFunctionName$reset' to '$red$productsFunctionName$reset' Function App ...'
cd apis/Products
func azure functionapp publish  $productsFunctionName --csharp --output json >> ../../serverless-apim-setup.log

ECHO '- Deploying '$red$reviewsFunctionName$reset' to '$red$reviewsFunctionName$reset' Function App ...'
cd ../Reviews
func azure functionapp publish $reviewsFunctionName --typescript --output json >> ../../serverless-apim-setup.log
cd ../..

ECHO $green'=============================================================='
ECHO
ECHO   $red'Done! Check your log information on serverless-apim-setup.log.'
ECHO
ECHO $green'=============================================================='