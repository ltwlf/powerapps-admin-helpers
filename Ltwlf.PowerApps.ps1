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

  # load the script
  . ./Ltwlf.PowerApps.ps1
  
  $defaultEnv = Get-AdminPowerAppEnvironment | ? { $_.IsDefault -eq $true }
  # import policy  
  $policy = Import-DlpPolicy -path ./default-policy.json

  ## or load online DLP policy
  # $policy = Get-DlpPolicy | ?{ $_.value.displayName -eq "Default" } | Select -ExpandProperty value
  ## Add custom connectors to policy (Confidential, General, Blocked)
  # $policy = Add-DlpCustomConnectors -policy $policy -groupName "Blocked"

  ## simulate policy
  Get-PowerAppsAffectedByPolicy -Policy $policy -EnvironmentName  $defaultEnv.EnvironmentName

#>


if (!(Get-Module -Name "AzureAD")) {
    Install-Module -Name AzureAD -Scope CurrentUser
}
if (!(Get-Module -Name "Microsoft.PowerApps.Administration.PowerShell")) {
    Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser
}

function global:Export-DlpPolicy {
    param (
        [Parameter(Mandatory = $true)][String]$policyName,
        [Parameter(Mandatory = $false)][String]$path = $policyName + ".json"
    )

    $policy = Get-DlpPolicy -PolicyName $policyName

    $policy | ConvertTo-Json -Depth 10 | Out-File -FilePath $path
}

function global:Import-DlpPolicy {
    param (
        [Parameter(Mandatory = $true)][String]$path
    )

    $policy = Get-Content -Path $path | ConvertFrom-Json

    return $policy
}

function global:Add-DlpCustomConnectors{
    param (
        [Parameter(Mandatory = $true)][PSObject]$policy,
        [Parameter(Mandatory = $true)][string]$groupName
    )
    $custom_connectors = Get-AdminPowerAppConnector | Select-Object @{n = 'id'; e = { $_.ConnectorId } }, @{n = 'name'; e = { $_.ConnectorName } }, @{n = 'type'; e = { 'Microsoft.PowerApps/apis' } }

    $group = $policy.connectorGroups | Where-Object{ $_.classification -eq $groupName} 
    $group.connectors = $group.connectors + $custom_connectors 

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
    catch { 
        Write-Host "You're not connected to AzureAD";  
        Connect-AzureAD
    }

    # get custom connectors
    $businessConnectors = $policy.connectorGroups[0].connectors | Select-Object -ExpandProperty name 
    $nonBusinessConnectors = $policy.connectorGroups[1].connectors  | Select-Object -ExpandProperty name 
    $blockedConnectors = $policy.connectorGroups[2].connectors  | Select-Object -ExpandProperty name
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

            $props = $_.Internal.properties

            # Hack to find Http Connectors
            if ($appType -eq "Flow" -and $props.definitionSummary.actions -match "Http") {
                $props.connectionReferences | Add-Member -Name "HTTP" -MemberType NoteProperty -Value $(New-Object -TypeName psobject -Property @{ DisplayName = "HTTP" })
            }
    
            $props.connectionReferences.PSObject.Properties `
            | Select-Object -ExpandProperty value `
            | ForEach-Object { 
                if ($businessConnectors.Contains($_.DisplayName)) {
                    $businessAffectedCount += 1
                    [void]$businessAffectedConnectors.Add($_)
                }
                if ($nonBusinessConnectors.Contains($_.DisplayName)) {
                    $nonBusinessAffectedCount += 1
                    [void]$nonBusinessAffectedConnectors.Add($_)
                }
                if ($blockedConnectors.Contains($_.DisplayName)) {
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

            $appItem = $item | Select-Object `
                DisplayName,
                AppName,
                @{ n = 'AppType'; e = { $appType } }, 
                @{ n = 'Owner'; e = { if ($null -ne $props.owner) { $props.owner.Email } else { Get-AzureADUser -ObjectId $props.creator.userId | Select-Object -ExpandProperty Mail } } }, 
                @{ n = 'BusinessCount'; e = { $businessAffectedCount } }, 
                @{ n = 'BusinessConnectors'; e = { ( $businessAffectedConnectors | Select-Object -ExpandProperty displayName ) -join ',' } }, 
                @{ n = 'NonBusinessCount'; e = { $nonBusinessAffectedCount } }, 
                @{ n = 'NonBusinessConnectors'; e = { ( $nonBusinessAffectedConnectors | Select-Object -ExpandProperty displayName ) -join ',' } }, 
                @{ n = 'BlockedCount'; e = { $blockAffectedCount } }, 
                @{ n = 'BlockedConnectors'; e = { ( $blockedAffectedConnectors | Select-Object -ExpandProperty displayName ) -join ',' } }, 
                @{ n = 'Affected'; e = { 
                        if ($groupCount -gt 1 -or $blockAffectedCount -gt 0) { $true } else { $false } } 
                }
            [void]$affectedItems.Add($appItem)
        }
    }

    $flows = Get-AdminFlow -EnvironmentName $environmentName | ForEach-Object { Get-AdminFlow -FlowName $_.FlowName }
    $flows | Add-Member -MemberType AliasProperty -Name AppName -Value FlowName

    Add-AffectedItems $flows "Flow"

    $apps = Get-AdminPowerApp -EnvironmentName $environmentName | Get-AdminPowerApp
    Add-AffectedItems $apps "App"

    return $affectedItems
    
}






