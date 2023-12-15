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
![alt text](https://helpcenter.veeam.com/docs/vro/userguide/images/add_creds.png =713x358)  
- If you have more than one Linux Admin credential, repeat the process and place a reference in the Description Field to locate this credential in the next steps.

## Creating the Custom Script 
- Download the script from git hub, [download link](https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/VRO-LinuxReIP.ps1)
- Go to Administration --> Plan Steps --> Add --> Put a Name for your custom step, ex: "LinuxReIP" and click Next.
(![alt text](https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Step1.png?raw=true)
- Load the script using the buttom browser --> Click Next
(![alt text](https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Step2.png?raw=true)
- On Scopes click Next and Summary screem click Finish to end the wizard.
(![alt text](https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Step3.png?raw=true)
- After this edit the script to add the mandatory parameters, select your script and click edit:
(![alt text](https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Step4.png?raw=true)
- Go to Parameters tab and Add the follow parameters:
  
| Name          | Type          | Default Value    | Description                                                                                  |
| ------------- | ------------- | ---------------- | -------------------------------------------------------------------------------------------- |
| VcenterCred   | Credentials   | vCenter Account  | Your vCenter account to connect to PowerCli.                                                 | 
| VmCred        | Credentials   | Linux Root User  | Account to interact with linux VM and replace network configuration inside the Guest OS.     |
| SourceVmName  | Text          | %source_vm_name% | This variable will get the source VM NAME from currently phase inside the plan.              |
| SourceVmIp    | Text          | %source_vm_ip%   | This variable will get the source VM IP Address from currently phase inside the plan.        |
| TargetVmName  | Text          | %target_vm_name% | This variable will get the Target (Replica)VM Name from currently phase inside the plan.     |
| VCenterFQDN   | Text          | vCenter FQDN     | Put your vcenter FQDN to script connect during powercli execution.Ex: "vcenter.domain.local" |

- Credential Example:
(![alt text](https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Cred.png?raw=true)
- Variable Example:
(![alt text](https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Var.png?raw=true)
- vCenter Example:
(![alt text](https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/vCenter.png?raw=true)


## Associating this Your Failover Plan at Plans Steps during the Plan Creation or Editing the currently Plan:

![alt text](https://github.com/magnunscheffer/veeam/blob/main/vro-linuxreip/img/Step1.png?raw=true)

> Note: How it Works: 
> 
> The script will automatically discover the Failover Plan and VMs associated with this FP, if there are Windows VMs they will be ignored. 

## Script Logic Summary:


![alt text](https://github.com/magnunscheffer/veeam/blob/main/linux-reip/img/Re-IP.png?raw=true)
