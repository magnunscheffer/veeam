# Forcing Tenant Job configs to be defined by Template Job for [EM. vSphere Self Portal](https://helpcenter.veeam.com/docs/backup/em/em_working_with_vsphere_portal.html?ver=120) 

Due to the limitations that exist on what you can restrict when creating Tenant Jobs. We created this script [SelfJobEntMgr-ForceTemplateValues.ps1](https://github.com/magnunscheffer/veeam/blob/main/selfportalem-forcetemplate/SelfJobEntMgr-ForceTemplateValues.ps1)] to force the application of the Job Options and also customize the scheduling.

For example you need to force a retention or force a specific schedule for the Job. You can define these parameters in an example job [Template] and this script will apply these values in the Tenant job. Even if the user changes any value, in the next backup run the template values will be applied again.

> Please note that this script will override settings made by the end user.
##### For more details about Tenant creation on EM, go to: [ Step 15-c](https://helpcenter.veeam.com/docs/backup/em/em_adding_tenant_accounts.html?ver=120) on EM User Guide.

**Use of this script is at your own risk.**

## Requirements for this script:
- This script must to be loaded to VBR Server
- VBR/EM must to be V12 [may work on older versions but has not been tested]

## Step by Step setup:
### Create Your Template Job as usual and after that do the followings steps:
- 1: Select the Job and  on Top Ribbon Click on **Edit**.
- 2: Go To **Storage** Session.
- 3: Click on **Advanced**.
- 4: Enable the checkbox for **Script BEFORE the Job** and select the path of this script.  
![alt text](https://github.com/magnunscheffer/veeam/blob/main/selfportalem-forcetemplate/TemplateJobScript.png?raw=true)
> The path must include the **-Template Name** for the script to find the correct template job. 
```Powershell
C:\Scripts\SelfJobEntMgr-ForceTemplateValues.ps1  -TemplateName "Template_ForceSettings-SelfEntMgr"
```

### How to Associate the Template to the Tenant profile.
#### Login to Enterprise Manager as Admin, go to **Settings** and follow the steps below:
- 1: Click on **Self-Service**
- 2: Click **Add** to create a new Tenant, populate all default settins as usual. 
![alt text](https://github.com/magnunscheffer/veeam/blob/main/selfportalem-forcetemplate/SelfServiceSettings.png?raw=true)
- 3: Click on Show **Advanced Job Settings** and select your template job (with the script associated), and than click on **Apply**.
![alt text](https://github.com/magnunscheffer/veeam/blob/main/selfportalem-forcetemplate/EMJob-Example.png?raw=true)
> As you can see above, the Tenant Job will inherit the custom script from the assigned template.



## Before each the tenant job execution, the parameters will be read from the template job and enforced!

![alt text](https://github.com/magnunscheffer/veeam/blob/main/selfportalem-forcetemplate/ScriptForcingTemplateSettings.png?raw=true)

> If you need to keep some user-defined attributes in Options or Programming, use this script session to customize your needs.
![alt text](https://github.com/magnunscheffer/veeam/blob/main/selfportalem-forcetemplate/PreserveSomeValues.png?raw=true)
