try { 
    $null = Get-AzureADTenantDetail
} 
catch { 
    Connect-AzureAD
}

. ./Ltwlf.PowerApps.ps1

$defaultEnv = Get-AdminPowerAppEnvironment | Where-Object { $_.IsDefault -eq $true }

$policy = Import-DlpPolicy -path "default-policy.json"
$policy = Add-PowerAppsCustomConnectorsToBlocked -policy $policy

Get-PowerAppsAffectedByPolicy -Policy $policy -EnvironmentName  $defaultEnv.EnvironmentName