try { 
    $null = Get-AzureADTenantDetail
} 
catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] { 
    Connect-AzureAD
}

. ./Get-PowerAppsAffectedByPolicy -Policy $policy -EnvironmentName  $defaultEnv.EnvironmentName

$defaultEnv = Get-AdminPowerAppEnvironment | Where-Object { $_.IsDefault -eq $true }

$policy = Import-DlpPolicy -path .\default-policy.json

Get-PowerAppsAffectedByPolicy -Policy $policy -EnvironmentName  $defaultEnv.EnvironmentName