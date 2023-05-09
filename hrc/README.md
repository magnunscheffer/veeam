
# Hardened Repository Check

The hr-check.sh script was created to highlight possible configuration errors in the hardened repository, they are basic checks based on official Veeam guides:

- https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository.html?ver=120

- https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html?wpty

This script does not replace any type of hardened that you should apply in yours REPOs, for a more accurate hardened you should consult the your security team, in addition to the operating system vendor.

- Path: https://github.com/magnunscheffer/veeam/blob/main/hrc/hr-check.sh

## How to:
- Download and grant execute permission to the script directly on the repository server:

```bash
curl -O https://raw.githubusercontent.com/magnunscheffer/veeam/main/hrc/hr-check.sh && chmod +x hr-check.sh
```
Example with short url:
```bash
curl -OL --max-redirs 5 https://vee.am/hrc22 && mv hrc22 hr-check.sh  && chmod +x hr-check.sh
```

- Run the script passing the Repo path as a parameter, like this example:
 
```bash
./hr-check.sh /mnt/repo01/backups
```


### Download & Run example:
![alt text](https://github.com/magnunscheffer/veeam/blob/main/hrc/download-example.png?raw=true)


-----------------------------------------------------------------
> TIP: Use the VBR Files menu to download the log file from the hardened repository. // I assume ssh is disabled :)

### Result Examples:
Log file: https://raw.githubusercontent.com/magnunscheffer/veeam/main/hrc/Log-rep-09052023_151629.txt
```bash
-----------------------------------------------------------------------------------------------------------------------------------------------
|This script is independently produced and has no direct link to Veeam Software. It just checks the recommendations related to the user guide |
|article and Veeam Write Paper *Protect against Ransomware with Immutable Backups*:                                                           |
|- https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository.html?ver=120                                                          |
|- https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                                   |
|                                                                                                                                             |
|By using this script you are at your own risk. Do you accept these terms? [YES=Y or NO=N]:                                                   |
-----------------------------------------------------------------------------------------------------------------------------------------------
INPUT='Y'

-------------------Starting at Tue 09 May 2023 03:16:33 PM -03 ------------------

- Repository path: /backups/SOBR-Ext1/backups/ ...

- Is a Ubuntu Distro?
   YES | Distr: Linux rep 5.4.0-113-generic #127-Ubuntu SMP Wed May 18 14:30:56 UTC 2022 x86_64 x86_64 x86_64 GNU/Linux

- Checking the veeamtransport service user and folder owner for '/backups/SOBR-Ext1/backups/'...

    Info: The service user 'veeamrepo' and the dir owner 'veeamrepo' are the same!

    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_prepare.html?ver=120
    Reference: 'Both owner and group can be the account that you plan to use to connect to the Linux server.'

- Checking the folder permissions for '/backups/SOBR-Ext1/backups/' ...
drwx------

    Info: The repository '/backups/SOBR-Ext1/backups/' is configured with the correct permission 'drwx------'(700)

    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-1--prepare-directory-on-linux-server-for-backups
    Reference: 'To allow access to the folder only for its owner and root account: chmod 700 <folder_path>'

- Checking the SUDO rights ...

    Info: The user veeamrepo doesn't have SUDO access, this is a good practice!

    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repo_specify_server.html?ver=120
    Reference: 'If you added the user account to the sudoers file, you do not need to select the Use su if sudo fails check box and specify the root password. But after the server is added, you must remove the user account from the file.'

- Cheking the LISTEN ports ...
    --------------------------------------------------------------------------------

    Info: 2507 is a veeam service/transport port.

    Info: 2510 is a veeam service/transport port.

    Info: 2511 is a veeam service/transport port.

    Info: 2516 is a veeam service/transport port.

    Info: 2517 is a veeam service/transport port.

    Info: 2518 is a veeam service/transport port.

    Info: 6160 is a veeam service/transport port.

    Info: 6162 is a veeam service/transport port.

    --------------------------------------------------------------------------------

    More details:
    https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html

    Reference: (Page 17): '8. Only run the Veeam transport service available on the network (SSH can be an exception).           
    There should especially be no third-party network services running with root permissions.                                   
    If an attacker can gain root access via a third-party software on the Hardened Repository, then they can delete all data.'

- Cheking the SSH Service status ...

    Info: SSH service is not running, this is a good practice!

    More details:
    https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                    
    Reference: (Page 17): '6. Secure access to the operating system. Use state-of-the-art multi-factor authentication. 
    If acceptable, disable the SSH Server completely and leave server access to the local physical console alone'

- Cheking the Firewall status.... active

   Info: The firewall is enabled, but remember that only veeam service ports should be kept open: [6162, 2500-3300].

   More details:
   https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                    
   Reference: (Page 8): 'During installation, Veeam configures the Linux firewall and allows incoming traffic to port 6162. 
   Iptables rules for dynamic ports (2500–3300 per default) are configured automatically during the job run. 
   All these firewall rules are removed automatically after the job finishes execution'


   Current firewall rules:

   --------------------------------------------------------------------------------

Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere                  
6162/tcp                   ALLOW IN    Anywhere                   # Veeam transport rule
6160/tcp                   ALLOW IN    Anywhere                   # Veeam deployment rule
2510/tcp                   ALLOW IN    Anywhere                   # Veeam rule 800aea0e-e8df-4841-aaa1-a5fedd7dc05a
2511/tcp                   ALLOW IN    Anywhere                   # Veeam rule 800aea0e-e8df-4841-aaa1-a5fedd7dc05a
2518/tcp                   ALLOW IN    Anywhere                   # Veeam rule 800aea0e-e8df-4841-aaa1-a5fedd7dc05a
2516/tcp                   ALLOW IN    Anywhere                   # Veeam rule 800aea0e-e8df-4841-aaa1-a5fedd7dc05a
2507/tcp                   ALLOW IN    Anywhere                   # Veeam rule 800aea0e-e8df-4841-aaa1-a5fedd7dc05a
2517/tcp                   ALLOW IN    Anywhere                   # Veeam rule 800aea0e-e8df-4841-aaa1-a5fedd7dc05a
22/tcp (v6)                ALLOW IN    Anywhere (v6)             
6160/tcp (v6)              ALLOW IN    Anywhere (v6)              # Veeam deployment rule
2510/tcp (v6)              ALLOW IN    Anywhere (v6)              # Veeam rule 800aea0e-e8df-4841-aaa1-a5fedd7dc05a
2511/tcp (v6)              ALLOW IN    Anywhere (v6)              # Veeam rule 800aea0e-e8df-4841-aaa1-a5fedd7dc05a
2518/tcp (v6)              ALLOW IN    Anywhere (v6)              # Veeam rule 800aea0e-e8df-4841-aaa1-a5fedd7dc05a
2516/tcp (v6)              ALLOW IN    Anywhere (v6)              # Veeam rule 800aea0e-e8df-4841-aaa1-a5fedd7dc05a
2507/tcp (v6)              ALLOW IN    Anywhere (v6)              # Veeam rule 800aea0e-e8df-4841-aaa1-a5fedd7dc05a
2517/tcp (v6)              ALLOW IN    Anywhere (v6)              # Veeam rule 800aea0e-e8df-4841-aaa1-a5fedd7dc05a

6162/tcp                   ALLOW OUT   Anywhere                   # Veeam transport rule

-------------------Finishing at Tue 09 May 2023 03:16:33 PM -03 ---------------
```
PrintScreen Example:
![alt text](https://github.com/magnunscheffer/veeam/blob/main/hrc/run-example1.png?raw=true)
