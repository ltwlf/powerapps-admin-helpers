# PowerApps PowerShell Admin Helpers

Some PowerApps admin helper scripts e.g. simualte which PowerApps and Flows would be affected by a policy, assign all custom connectors to the blocked group, export and import policies.

**WARNING: HTTP connectors will currently not be found. This seems to be a PowerApps issue**


## Example 

### Get a list of PowerApps & Flows that would be affected by a policy

```PowerShell
. .\Ltwlf.PowerApps.Helpers.ps1

Connect-AzureAD
Add-PowerAppsAccount

$defaultEnv = Get-AdminPowerAppEnvironment | ? { $_.IsDefault -eq $true }
$policy = GetDlpPolicy -PolicyName "9029b241-055a-4242-8262-5700504c6171"

Get-PowerAppsAffectedByPolicy -Policy $policy -EnvironmentName  $defaultEnv.EnvironmentName

```
Output:
```
DisplayName           : Flow 123
AppName               : a5c34385-ca1d-4c03-9d7a-5c9b71ea8ec0
AppType               : App
Owner                 : chris@xyz.com
BusinessCount         : 0
BusinessConnectors    :
NonBusinessCount      : 0
NonBusinessConnectors :
BlockedCount          : 0
BlockedConnectors     :
Affected              : False

DisplayName           : Canvas App 77
AppName               : bfa50eb2-ce03-4700-930d-e4e234c72f6f
AppType               : App
Owner                 : lars@xyz.com
BusinessCount         : 1
BusinessConnectors    : SharePoint
NonBusinessCount      : 2
NonBusinessConnectors : Twitter, LinkedIn
BlockedCount          : 0
BlockedConnectors     :
Affected              : True

...

```

## Blog
https://blog.leitwolf.io