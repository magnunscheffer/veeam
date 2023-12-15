# Veeam Recovery Orchestrator Linux Re-Ip Script

The [VRO-LinuxReIP.ps1](https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/VRO-LinuxReIP.ps1) script was created to allow re-ip of linux VMs during VRO Execution Plan, which are currently not supported by Veeam.

Use of this script is at your own risk.

## OS Guest list that should work:
- Centos [5-8]
- RedHat [5-8]
- Oracle Linux [5-8]
- Ubuntu 
- Debian
- Suse Linux [12-15]

## Requirements for this script:
- Guest VM needs to have VMware Tools installed
- VMware PowerCli Module installed in VBR [Production], for more information [click here.](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.esxi.install.doc/GUID-F02D0C2D-B226-4908-9E5C-2E783D41FE2D.html):
- A vCenter user with read and invoke-vmscript permission.
- Root account for RHEL/CentOS/OEL and SUDO user for Ubuntu/Debian/Suse Linux, it is necessary to inject the new network configs inside of VM using [Invoke-VMScript](https://developer.vmware.com/docs/powercli/latest/vmware.vimautomation.core/commands/invoke-vmscript/#Default).
- If you have VMs running CentOs/RHEL (5-6). It is necessary run this code inside each vm before replicating it. This command will prevent the NIC from being renamed after a failover (because of MAC address change):
```bash
sudo ln -s /dev/null /etc/udev/rules.d/75-persistent-net-generator.rules
sudo rm -f /etc/udev/rules.d/70-persistent-net.rules
```
# Step by Step:
## Installing the requirements: 
- Install VMWare Powercli on VBR Server {Production Server / Not on VRO EMBEDDED VBR]:
```powershell
Install-Module VMware.PowerCLI -Scope AllUsers -SkipPublisherCheck -Force
```

## Managing Credentials:
Its is necessary add vCenter and guests credencials to VRO, please visit the official guide if you don't have experience it this step:
[Add VRO Credentials](https://helpcenter.veeam.com/docs/vro/userguide/adding_credentials_manually.html?ver=70)

<img src="https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/AddCred.png?raw=true" width="713" height="358">

> Note: If you have more than one Linux Admin credential, repeat the process each additional credencial.

## Creating the Custom Script 
- Download the script from git hub, [download link](https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/VRO-LinuxReIP.ps1)
- Go to Administration --> Plan Steps --> Add --> Put a Name for your custom step, ex: "LinuxReIP" and click Next.

<img src="https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Step1.png?raw=true" width="628" height="525">

- Load the script using the buttom browser --> Click Next

<img src="https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Step2.png?raw=true" width="628" height="525">

- On Scopes click Next and Summary screem click Finish to end the wizard.

<img src="https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Step3.png?raw=true" width="628" height="525">

- After this edit the script to add the mandatory parameters, select your script and click edit:

<img src="https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Step4.png?raw=true" width="567" height="299">

- Go to Parameters tab and first set the Execution Location to "Veeam Backup Server":

<img src="https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Step5.png?raw=true" width="628" height="525">

- Click "Add" and create all the parameters listed below:

  
| Name          | Type          | Default Value    | Description                                                                                  |
| ------------- | ------------- | ---------------- | -------------------------------------------------------------------------------------------- |
| VcenterCred   | Credentials   | vCenter Account  | Your vCenter account to connect to PowerCli.                                                 | 
| VmCred        | Credentials   | Linux Root User  | Account to interact with linux VM and replace network configuration inside the Guest OS.     |
| SourceVmName  | Text          | %source_vm_name% | This variable will get the source VM NAME from currently phase inside the plan.              |
| SourceVmIp    | Text          | %source_vm_ip%   | This variable will get the source VM IP Address from currently phase inside the plan.        |
| TargetVmName  | Text          | %target_vm_name% | This variable will get the Target (Replica)VM Name from currently phase inside the plan.     |
| VCenterFQDN   | Text          | vCenter FQDN     | Put your vcenter FQDN to script connect during powercli execution.Ex: "vcenter.domain.local" |

Parameters Examples:
<img src="https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/parameters.png?raw=true" width="1207" height="453">



## Associating this script to yours Replica Plans
> This script currently works only with Replica Plans. Use this script as a regular step on your Replica Plans, example:

<img src="https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Plan.png?raw=true" width="979" height="768">

> If you have more than one Linux credential, remember to change this on each VM that is using a specific credential. More details [here](https://helpcenter.veeam.com/docs/vro/userguide/configuring_vms.html?ver=70).


# Execution Example:

<img src="https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/exec1.png?raw=true">
<img src="https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/exec2.png?raw=true">

> Info: If you try to associate this script with a Windows VM, it will be ignored with a warning event:
<img src="https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/exec3.png?raw=true">

Full detailed report example avaliable bellow:
[embed]https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Report.pdf[/embed]






