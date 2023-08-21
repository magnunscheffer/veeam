# Forcing Tenant Job configs to be defined by Template Job for [EM. vSphere Self Portal](https://helpcenter.veeam.com/docs/backup/em/em_working_with_vsphere_portal.html?ver=120) 

The [SelfJobEntMgr-ForceTemplateValues.ps1](https://github.com/magnunscheffer/veeam/blob/main/selfportalem-forcetemplate/SelfJobEntMgr-ForceTemplateValues.ps1) script was created to force Tenants use settings from template job [Copy from during the Tenant creation]. For more details about Tenant creation on EM, go to: [ Step 15-c](https://helpcenter.veeam.com/docs/backup/em/em_adding_tenant_accounts.html?ver=120) on EM User Guide.

Use of this script is at your own risk.

## Requirements for this script:
- This script must to be loaded to VBR Server
- VBR/EM must to be V12 [maybe can work on early versions but not was tested]

# Step by Step:
## Create Your Template Job as usual and after that do the followings steps:
- 1: Select the Job and Click on Ribbon on **Edit** button.
- 2: Go To **Storage** Session.
- 3: Click on **Advanced**.
- 4: Enable the checkbox for **Script BEFORE the Job** and select the path of this script.  
![alt text](https://github.com/magnunscheffer/veeam/blob/main/selfportalem-forcetemplate/TemplateJobScript.png?raw=true)
  >The script path must to include the Parameter **-TemplateName** to script knows where it needs to read the values from:
  
  >*Tip: Always use the Template job Name as value for TemplateName*
  
```Powershell
C:\Scripts\SelfJobEntMgr-ForceTemplateValues.ps1  -TemplateName "Template_ForceSettings-SelfEntMgr"
```

## How to Associate the Template to Tenant
### Do login on Enterprise manager as Admin and follow and do the follings steps:
- 1: Go to Settings Session 
- 2: 
![alt text](https://github.com/magnunscheffer/veeam/blob/main/selfportalem-forcetemplate/TemplateJobScript.png?raw=true)

## After the First run the script will setup the tenant job with Template configs/schedule settings.

## Before any Tenant Job Execution the parameters will be reinforced. 

![alt text](https://github.com/magnunscheffer/veeam/blob/main/selfportalem-forcetemplate/TemplateJobScript.png?raw=true)

