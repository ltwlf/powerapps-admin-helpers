#requires -version 5.1
<#
.SYNOPSIS
  PowerApps helper functions
.DESCRIPTION
Helps to verify which PowerApps and Flows would be affected by a DLP policy. The 

.NOTES
  Version:        0.1
  Author:         Christian Glessner
  Creation Date:  2020-07-05
  Blog: https://blog.leitwolf.io
  
.EXAMPLE
  Connect-AzureAD
  Add-PowerAppsAccount
  
  $defaultEnv = Get-AdminPowerAppEnvironment | ? { $_.IsDefault -eq $true }
  $policy = GetDlpPolicy -PolicyName 9029b241-055a-4242-8262-5700504c6171#

  Get-PowerAppsAffectedByPolicy -Policy $policy -EnvironmentName  $defaultEnv.EnvironmentName

#>

if (!(Get-Module -Name "AzureAD")) {
    Install-Module -Name AzureAD -ErrorAction Continue
}
# Connect-AzureAD
if (!(Get-Module -Name "Microsoft.PowerApps.Administration.PowerShell")) {
    Install-Module -Name Microsoft.PowerApps.Administration.PowerShell
}
if (!(Get-Module -Name "Microsoft.PowerApps.PowerShell")) {
    Install-Module -Name Microsoft.PowerApps.PowerShell -AllowClobber
}

function global:Export-DlpPolicy{
    param (
        [Parameter(Mandatory = $true)][String]$policyName,
        [Parameter(Mandatory = $false)][String]$path = $policyName + ".json"
    )

    $policy = Get-DlpPolicy -PolicyName $policyName

    $policy | ConvertTo-Json -Depth 10 | Out-File -FilePath $path
}

function global:Import-DlpPolicy{
    param (
        [Parameter(Mandatory = $true)][String]$path
    )

    $policy = Get-Content -Path $path | ConvertFrom-Json

    return $policy
}

function global:Add-PowerAppsCustomConnectorsToBlocked {
    param (
        [Parameter(Mandatory = $true)][PSObject]$policy
    )
    $custom_connectors = Get-AdminPowerAppConnector | Select-Object @{n = 'id'; e = { $_.ConnectorId } }, @{n = 'name'; e = { $_.ConnectorName } }, @{n = 'type'; e = { 'Microsoft.PowerApps/apis' } }

    # block all custom connectors
    $policy.connectorGroups[2].connectors = $policy.connectorGroups[2].connectors + $custom_connectors 

    return $policy
}

function global:Get-PowerAppsAffectedByPolicy {
    param (
        [Parameter(Mandatory = $true)][PSCustomObject]$policy,
        [Parameter(Mandatory = $true)][String]$environmentName
    )

    try { 
        $null = Get-AzureADTenantDetail
    } 
    catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] { 
        Write-Host "You're not connected to AzureAD";  
        Write-Host "Make sure you have AzureAD mudule available on this system then use Connect-AzureAD to establish connection";  
        exit;
    }

    # get custom connectors

    $businessConnectors = $policy.connectorGroups[0].connectors | Select-Object -ExpandProperty id | ForEach-Object { $_.ToLower() }
    $nonBusinessConnectors = $policy.connectorGroups[1].connectors  | Select-Object -ExpandProperty id | ForEach-Object { $_.ToLower() }
    $blockedConnectors = $policy.connectorGroups[2].connectors  | Select-Object -ExpandProperty id | ForEach-Object { $_.ToLower() }

    $affectedItems = [System.Collections.ArrayList]@()

    
    function Add-AffectedItems($items, $appType) {
        $items | ForEach-Object {
            $item = $_
            $businessAffectedCount = 0
            $businessAffectedConnectors = [System.Collections.ArrayList]@()
            $nonBusinessAffectedCount = 0
            $nonBusinessAffectedConnectors = [System.Collections.ArrayList]@()
            $blockAffectedCount = 0
            $blockedAffectedConnectors = [System.Collections.ArrayList]@()
            $groupCount = 0
    
            $_.Internal.properties.connectionReferences.PSObject.Properties `
            | Select-Object -ExpandProperty value `
            | ForEach-Object { 
                if ($businessConnectors.Contains($_.id.ToLower())) {
                    $businessAffectedCount += 1
                    [void]$businessAffectedConnectors.Add($_)
                }
                if ($nonBusinessConnectors.Contains($_.id.ToLower())) {
                    $nonBusinessAffectedCount += 1
                    [void]$nonBusinessAffectedConnectors.Add($_)
                }
                if ($blockedConnectors.Contains($_.id.ToLower())) {
                    $blockAffectedCount += 1
                    [void]$blockedAffectedConnectors.Add($_)
                }
            }
            if ($businessAffectedCount -gt 0) {
                $groupCount++
            }
            if ($nonBusinessAffectedCount -gt 0) {
                $groupCount++
            }
            if ($blockAffectedCount -gt 0) {
                $groupCount++
            }

            $props = $_.Internal.properties
            $appItem = $item | Select-Object `
                DisplayName,
                AppName,
                @{ n = 'AppType'; e = { $appType } }, 
                @{ n = 'Owner'; e = { if ($null -ne $props.owner) { $props.owner.Email } else { Get-AzureADUser -ObjectId $props.creator.userId | Select-Object -ExpandProperty Mail } } }, 
                @{ n = 'BusinessCount'; e = { $businessAffectedCount } }, 
                @{ n = 'BusinessConnectors'; e = { ( $businessAffectedConnectors | Select-Object -ExpandProperty displayName ) -join ','  } }, 
                @{ n = 'NonBusinessCount'; e = { $nonBusinessAffectedCount } }, 
                @{ n = 'NonBusinessConnectors'; e = { ( $nonBusinessAffectedConnectors | Select-Object -ExpandProperty displayName ) -join ','  } }, 
                @{ n = 'BlockedCount'; e = { $blockAffectedCount } }, 
                @{ n = 'BlockedConnectors'; e = { ( $blockedAffectedConnectors | Select-Object -ExpandProperty displayName ) -join ',' } }, 
                @{ n = 'Affected'; e = { 
                        if ($groupCount -gt 1 -or $blockAffectedCount -gt 0) { $true } else { $false } } 
                }
            [void]$affectedItems.Add($appItem)
        }
    }


    $flows = Get-Flow -EnvironmentName $environmentName
    $flows | Add-Member -MemberType AliasProperty -Name AppName -Value FlowName

    Add-AffectedItems $flows "Flow"

    # HACK: when I filter the environent directly not all apps will be returned. Result can vary and props can vary with different params => Cmdlets are in peview
    $apps = Get-PowerApp | Where-Object { $_.EnvironmentName -eq $environmentName } 
    Add-AffectedItems $apps "App"

    # Write-Output affectedItems | Format-Table

    return $affectedItems
    
}






