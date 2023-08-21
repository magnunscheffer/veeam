# Forcing Tenant Job configs to be defined by Template Job for [EM. vSphere Self Portal](https://helpcenter.veeam.com/docs/backup/em/em_working_with_vsphere_portal.html?ver=120) 


The [SelfJobEntMgr-ForceTemplateValues.ps1](https://github.com/magnunscheffer/veeam/blob/main/selfportalem-forcetemplate/SelfJobEntMgr-ForceTemplateValues.ps1) script was created to force Tenants use settings from template job [Copy from during the Tenant creation]. For more details about Tenant creation on EM, go to: [ Step 15-c](https://helpcenter.veeam.com/docs/backup/em/em_adding_tenant_accounts.html?ver=120) on EM User Guide.

Use of this script is at your own risk.

## Requirements for this script:
- This script must to be loaded to VBR Server
- VBR/EM must to be V12 [maybe can work on early versions but not was tested]

# Step by Step:
## Create Your Template Job as usual.
- After Create the Job template load this script to Storage --> Advanced Settings --> Scripts
```powershell
Install-Module VMware.PowerCLI -Scope AllUsers -SkipPublisherCheck -Force
```

### Creating a Tenant and Using the template 


## After the First run the script will setup the tenant job with Template configs/schedule settings.

## Before any Tenant Job Execution the parameters will be reinforced. 

![alt text](https://github.com/magnunscheffer/veeam/blob/main/linux-reip/img/failoverplan-example.png?raw=true)

