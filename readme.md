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
DisplayName : My Flow 1
AppName     : 08df3012-4477-4d0d-85eb-662e326540b5
AppType     : Flow
Owner       : cg@hololux.com
Business    : 2
NonBusiness : 0
Blocked     : 0
Affected    : False

DisplayName : My Canvas App 2
AppName     : 227d1609-6e11-436e-aad0-aa18f8s303ef
AppType     : App
Owner       : cg@hololux.com
Business    : 1
NonBusiness : 0
Blocked     : 1
Affected    : true
...

```

## Blog
https://blog.leitwolf.io