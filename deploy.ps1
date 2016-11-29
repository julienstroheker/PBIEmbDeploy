Param(
    [Parameter(Mandatory=$False)] [bool] $Prerequisites=$false,
	  [Parameter(Mandatory=$False)] [bool] $Authentication=$false,
    [Parameter(Mandatory=$True)] [string] $ResourceGroupName,
    [Parameter(Mandatory=$True)] [string] $Location,
    [Parameter(Mandatory=$True)] [string] $PrefixName,
    [Parameter(Mandatory=$True)] [string] $PrefixNameEnv
)

# Install depencies

# Way to use the CLI for now : node deploy.js A B C | Example | Mandatory or Optional
# A = Install npm prerequisites : Azure-cli and Powerbi-cli | Y : N | Optional, default No
# B = Run the authentication process for the Azure Sub | Y : N | Optional, default No
# C = Name of the resource group | "MyResourceGroup" | Mandatory
# D = Location on Azure for the deployment | "East US" | Mandatory
# E = PrefixName for the deployment | "CONTOSO" | Mandatory
# F = PrefixNameEnv for the deployment | "Dev" | Mandatory

Write-Host -BackgroundColor Black -ForegroundColor Green "Script launched"
if ($prerequisites)
{
  Write-Host -BackgroundColor Black -ForegroundColor Green "Installing the NPM Packages..."
  npm install azure-cli -g
  npm install powerbi-cli -g
}
if ($authentication)
{
  Write-Host -BackgroundColor Black -ForegroundColor Green "Authentication on Azure selected..."
  azure login
}
Write-Host -BackgroundColor Black -ForegroundColor Green "Creation of the resource group..."
azure group create -n $ResourceGroupName -l $Location

$templateParameters = '{\"PrefixName\":{\"value\":\"'+ $PrefixName + '\"},\"PrefixNameEnv\":{\"value\":\"' + $PrefixNameEnv + '\"}}'
Write-Host -BackgroundColor Black -ForegroundColor Green "Deployment of the resources..."
azure group deployment create --resource-group $ResourceGroupName --template-uri "https://raw.githubusercontent.com/julienstroheker/PBIEmbDeploy/master/template/deploy.json" -p "$templateParameters"

Write-Host -BackgroundColor Black -ForegroundColor Green "Deployment done..."

Write-Host -BackgroundColor Black -ForegroundColor Green "Getting and storing access key..."
$accesKeyPBI = azure powerbi keys list $ResourceGroupName $PrefixName-$PrefixNameEnv-PBI --json | ConvertFrom-Json

Write-Host -BackgroundColor Black -ForegroundColor Green "Creating one workspace..."
$cmdCreateWSOutput = powerbi create-workspace -c $PrefixName-$PrefixNameEnv-PBI -k $accesKeyPBI.key1

$WSguid = $cmdCreateWSOutput[3].Replace("[ powerbi ] ", "")

Write-Host -BackgroundColor Black -ForegroundColor Green "Importing the PBIX..."

$path = "./myReport/*.pbix"
$basename = gi $path | select basename, Name

powerbi import -c $PrefixName -w $WSguid -k $accesKeyPBI.key1 -n "$basename[0].BaseName" -f "./myReport/$basename[0].Name"






