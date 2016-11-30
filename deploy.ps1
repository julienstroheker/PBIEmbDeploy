####### https://github.com/julienstroheker/PBIEmbDeploy #######

Param(
  # Install npm prerequisites : Azure-cli and Powerbi-cli | Y : N | Optional, default No
  [Parameter(Mandatory=$False)] [bool] $Prerequisites=$false,
  # Run the authentication process for the Azure Sub | Y : N | Optional, default No
  [Parameter(Mandatory=$False)] [bool] $Authentication=$false,
  # Name of the resource group | Ex : "MyResourceGroup" | Mandatory
  [Parameter(Mandatory=$True)] [string] $ResourceGroupName,
  # Location on Azure for the deployment | Ex : "West US" | Mandatory
  [Parameter(Mandatory=$True)] [string] $Location,
  # PrefixName for the deployment | Ex : "CONTOSO" | Mandatory
  [Parameter(Mandatory=$True)] [string] $PrefixName,
  # PrefixNameEnv for the deployment | Ex : "Dev" | Mandatory
  [Parameter(Mandatory=$True)] [string] $PrefixNameEnv
)
cls
Write-Host -BackgroundColor Black -ForegroundColor Green "##### Script launched ###### "
if ($prerequisites)
{
  Write-Host -BackgroundColor Black -ForegroundColor Yellow "Installing the NPM Packages..."
  Write-Host -BackgroundColor Black -ForegroundColor Yellow "Installing Azure-CLI"
  $output = npm install azure-cli -g
  Write-Host -BackgroundColor Black -ForegroundColor Green "Azure-CLI Installed"
  Write-Host -BackgroundColor Black -ForegroundColor Yellow "Installing PowerBI-CLI"
  $output = npm install powerbi-cli -g
  Write-Host -BackgroundColor Black -ForegroundColor Green "PowerBI-CLI Installed"
}
if ($authentication)
{
  Write-Host -BackgroundColor Black -ForegroundColor Yellow "Authentication on Azure selected..."
  azure login
  Write-Host -BackgroundColor Black -ForegroundColor Green "Authentication on Azure done"
}

try {
  Write-Host -BackgroundColor Black -ForegroundColor Yellow "Creation of the resource group..."
  azure group create -n $ResourceGroupName -l $Location >> outputLogs.txt
  Write-Host -BackgroundColor Black -ForegroundColor Green "Resource group : $ResourceGroupName created in $Location"

  $templateParameters = '{\"PrefixName\":{\"value\":\"'+ $PrefixName + '\"},\"PrefixNameEnv\":{\"value\":\"' + $PrefixNameEnv + '\"}}'
  Write-Host -BackgroundColor Black -ForegroundColor Yellow "Deployment of the resources on Azure..."
  azure group deployment create --resource-group $ResourceGroupName --template-uri "https://raw.githubusercontent.com/julienstroheker/PBIEmbDeploy/master/template/deploy.json" -p "$templateParameters"
  Write-Host -BackgroundColor Black -ForegroundColor Green "Deployment of $PrefixName-$PrefixNameEnv-PBI done..."

  Write-Host -BackgroundColor Black -ForegroundColor Yellow "Getting and storing access key..."
  $CollectionName = $PrefixName + "-" + $PrefixNameEnv + "-PBI"
  $accesKeyPBIJSON = azure powerbi keys list $ResourceGroupName $CollectionName --json
  $accesKeyPBIJSON = $accesKeyPBIJSON | ConvertFrom-Json
  $accesKeyPBI = $accesKeyPBIJSON.key1
  Write-Host -BackgroundColor Black -ForegroundColor Green "Acces Key stored : $accesKeyPBI"
  
  Write-Host -BackgroundColor Black -ForegroundColor Yellow "Creating of the workspace..."
  $cmdCreateWSOutput = powerbi create-workspace -c $CollectionName -k $accesKeyPBI
  $WSguid = $cmdCreateWSOutput.Replace("[ powerbi ] Workspace created: ", "")
  Write-Host -BackgroundColor Black -ForegroundColor Green "Workspace with the following GUID created : $WSguid"

  Write-Host -BackgroundColor Black -ForegroundColor Yellow "Importing the PBIX..."

  $path = "./myReport/*.pbix"
  $basename = gi $path | select basename, Name
  $filePath = "./myReport/" + $basename[0].Name
  $fileName = $basename[0].BaseName

  $output = powerbi import -c $PrefixName-$PrefixNameEnv-PBI -w $WSguid -k $accesKeyPBI -n "$fileName" -f "$filePath"
  Write-Host -BackgroundColor Black -ForegroundColor Green "PBIX Imported : $fileName"

  Write-Host -BackgroundColor Black -ForegroundColor Yellow "Creating the WebApp and applying the parameters for the PBIX..."
  
  $powerbiAccessKey = $accesKeyPBI
  $powerbiWorkspaceCollection = $CollectionName
  $powerbiWorkspaceId = $WSguid

  $templateParametersWebApp = '{\"PrefixName\":{\"value\":\"'+ $PrefixName + '\"},\"PrefixNameEnv\":{\"value\":\"' + $PrefixNameEnv + '\"},\"powerbiAccessKey\":{\"value\":\"' + $powerbiAccessKey + '\"},\"powerbiWorkspaceCollection\":{\"value\":\"' + $powerbiWorkspaceCollection + '\"},\"powerbiWorkspaceId\":{\"value\":\"' + $powerbiWorkspaceId + '\"}}'

  azure group deployment create --resource-group $ResourceGroupName --template-uri "https://raw.githubusercontent.com/julienstroheker/PBIEmbDeploy/master/template/deployWebApp.json" -p "$templateParametersWebApp"
  # We need to re-deploy twice for some reasons about the app settings.
  azure group deployment create --resource-group $ResourceGroupName --template-uri "https://raw.githubusercontent.com/julienstroheker/PBIEmbDeploy/master/template/deployWebApp.json" -p "$templateParametersWebApp"

  Write-Host -BackgroundColor Black -ForegroundColor Green "WebApp Created : https://$PrefixName-$PrefixNameEnv-site.azurewebsites.net"

  Write-Host -BackgroundColor Black -ForegroundColor Green "###### Script done ######"
}
catch {
  Write-Host $Error[0] -ForegroundColor 'Red'
}
