# Linux Re-Ip Script

The reip.ps1 script was created to allow re-ip of linux VMs, which is currently not supported by Veeam.

Use of this script is at your own risk.

## Requirements for this script:
- VMware PowerCli Module installed in VBR, for more information:

https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.esxi.install.doc/GUID-F02D0C2D-B226-4908-9E5C-2E783D41FE2D.html

- CredentialManager module installed in VBR (Necessary to save credentials in Windows vault), for more information:

https://www.powershellgallery.com/packages/CredentialManager/2.0
- vCenter and Guest Default Credentials are mandatory, please use the auxiliar script  "./Manage-ReipCred.ps1"

## Step by Step:
- Install VMWare Powercli on VBR Server:
```powershell
Install-Module VMware.PowerCLI -Scope AllUsers -SkipPublisherCheck -Force
```

- Install CredencialManager on VBR Server:
```powershell
Install-Module -Name CredentialManager -Force
```

- Create a vCenter Credential to the reip script interact with vCenter
```powershell
.\Manage-ReipCred.ps1 -Action Add -Type v -Username administrator@vsphere.local -Password P@ssw0rd!
```

- Create a Default Guest credential to the reip script interact with VIX on Guest O.S (Invoke-VMScript).
```powershell
.\Manage-ReipCred.ps1 -Action Add -Type d -Username root -Password P@ssw0rd!
```

- Create adicional customs credentials to specific VMs with not use the default guest credential.
```powershell
.\Manage-ReipCred.ps1 -Action Add -Type c -Username root -Password P@ssw0rd! -ItemName DR-VM2 #VMware VM Name
```

- Ajust the parameters in the reip.ps1:
$vi_srv = the vCenter FQDN
$rep_sufix  = Suffix used in replica jobs
$LogPath = This script generate a log for troubleshooting proprose, so set the path for this logs.

- Associate this script (reip.ps1) with yours Failover Plans OP:
Explanation: The script will automatically discover the Failover Plan and VMs associated with this FP, if there are Windows VMs they will be ignored (because it is natively supported by Veeam)

![alt text](https://github.com/magnunscheffer/veeam/blob/main/linux-reip/failoverplan-example.png?raw=true)
