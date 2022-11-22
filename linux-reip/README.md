# Linux Re-Ip Script

The reip.ps1 script was created to allow re-ip of linux VMs, which is currently not supported by Veeam.

Use of this script is at your own risk.

## Requirements for this script:
- VMware PowerCli Module installed in VBR, for more information:

https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.esxi.install.doc/GUID-F02D0C2D-B226-4908-9E5C-2E783D41FE2D.html

- CredentialManager Powershell module installed in VBR (to interact with Windows 'Credential Manager'), for more information:

https://www.powershellgallery.com/packages/CredentialManager/2.0
- _"vCenter"_ and _"Default"_ credentials are mandatory!. Please read the step by step guide to know how to configure that.
- If you have VMs running CentOs/RHEL (5-6). It is necessary run this code inside each vm before replicating it. This command will prevent the NIC from being renamed after a failover (because of MAC address change):
```bash
sudo ln -s /dev/null /etc/udev/rules.d/75-persistent-net-generator.rules
sudo rm -f /etc/udev/rules.d/70-persistent-net.rules
```
## Installing the requirements, Step by Step:
- Install VMWare Powercli on VBR Server:
```powershell
Install-Module VMware.PowerCLI -Scope AllUsers -SkipPublisherCheck -Force
```

- Install CredencialManager on VBR Server:
```powershell
Install-Module -Name CredentialManager -Force
```

## Creating the credentials.
  - Some important informations before start:
    - This script needs some credentials to interact with vCenter and Guest OS Linux, we are using Windows Credential Manager (Windows Vault) to store these credentials. If you prefer to use another way to store the credentials. Just remember to change the references inside the script.
    - This csv will be used to load the first credentials for the Windows Vault (Credential Manager). After that, the csv content will be cleaned up, to prevent passwords from being exposed.
    - Download the csv file _"creds.csv"_ and place it in the same directory as the _"reip.ps1"_ script, download link: https://raw.githubusercontent.com/magnunscheffer/veeam/main/linux-reip/creds.csv. 
    - Whenever you need to add or remove credentials, just populate the csv again and the credentials will be created in the next script run.

  ### Creating Default/vCenter credentials example:
  
  - Fill out the csv like the example, change only the columns _Username_ and _Password_ :
  
  ![alt text](https://github.com/magnunscheffer/veeam/blob/main/linux-reip/csv-example.PNG?raw=true)
  
  ### Creating default credentials with aditionals credentials example:    
  - If you need to create additional credentials for guest VMs (Example: VMs with another username or password), follow the example below:
  
  ![alt text](https://github.com/magnunscheffer/veeam/blob/main/linux-reip/csv-example-plus.PNG?raw=true)      
  
  > Note: The profile name must be exactly the name of the VMware VM (replica source). If the script has a custom credential for the VM, the "Default" credential will be ignored.
        
### To delete a credential from Windows Credential Manager just fillout like this:

![alt text](https://github.com/magnunscheffer/veeam/blob/main/linux-reip/csv-example-delete.PNG?raw=true)  

## Parameters configurations:
- Set the parameters in the reip.ps1:
  - $vi_srv = The vCenter FQDN, _Example: "vcenter.domain.local"_
  - $rep_sufix  = Suffix used in replica jobs, _Example:  "\_replica"_
  - $LogPath = This script generate a log for troubleshooting, so set the path for this log, _Example: "C:\logs\"._

- Associate this script "reip.ps1" with yours Failover Plans (Post Failover Script) :

_Explanation: The script will automatically discover the Failover Plan and VMs associated with this FP, if there are Windows VMs they will be ignored (because it is natively supported by Veeam)._

![alt text](https://github.com/magnunscheffer/veeam/blob/main/linux-reip/failoverplan-example.png?raw=true)
