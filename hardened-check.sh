#!/bin/bash


#Autor: Magnun Scheffer | Contact: mfs_@outlook.com
#Version: 0.2
#Download: 'curl -O https://raw.githubusercontent.com/magnunscheffer/veeam/main/hardened-check.sh  && chmod +x hardened-check.sh'
#Run: './hardened-check.sh /mnt/repo01/backups'
# The parameter '/mnt/repo01/backups' is the folder visible on VBR console --> Backup Infrastructure --> Backup Repositories --> Path
#Disclaimer:If you are considering using this script, be aware that you are doing so at your own risk.
#Plataform tested: RedHat/CentOS 7 & 8 / Ubunto 20.04


#Configuring terminal colors
terminalColorClear='\033[0m'
terminalColorInfo='\033[0;32m'
terminalColorWarning='\033[0;33m' 
terminalColorBanner='\033[0;41m'
#Regular Color
echoD() {
    echo -e "${terminalColorClear}$1${terminalColorClear}"
} 
#Information Color (Green)
echoI() {
    echo -e "${terminalColorInfo}$1${terminalColorClear}"
}
#Warning Color (Orange)
 echoW() {
    echo -e "${terminalColorWarning}$1${terminalColorClear}"
}
#Banner Color (Red)
 echoB() {
    echo -e "${terminalColorBanner}$1${terminalColorClear}"
} 

#Defaul Status for terms.
terms="N"
echoB "
-----------------------------------------------------------------------------------------------------------------------------------------------
| This script is independently produced and has no direct link to Veeam Software. It just checks the recommendations related to the user guide|
| article and Veeam Write Paper *Protect against Ransomware with Immutable Backups*:                                                          |
| - https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository.html?ver=110                                                         |
| - https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                                  |
|                                                                                                                                             |
| By using this script you are at your own risk. Do you accept these terms? [Y=YES or N=NO]:                                                  |
-----------------------------------------------------------------------------------------------------------------------------------------------"
read terms
#Testing if the terms were accepted.
if [ -z "$terms" ] || [ ${terms^^} != "Y" ] 
then 
	echoI
	echoI "You didn't accept the terms! Ending the script now ..."
	exit
fi

#Log Path under construction... 
log="/tmp/log_$HOSTNAME.txt"

#Start of script
echoD "-------------------Starting at $(date) ------------------"
echoD "- Setting repo path: $1 ..."
repo=$1

#Looking for Ubuntu, because the diferent name of SSH service and firewall...
distr=$(uname -a | grep -o Ubuntu)
if [ -z "$distr" ]
then #others_dist	   
   service="sshd"
   fwstate=$(firewall-cmd --state 2>&1)
   fwconfig="firewall-cmd --list-all"
   permok="drwx------."
else #ubuntu   
   service="ssh"
   fwstate=$(sudo ufw status verbose | grep -oP '(?<=Status: )[^ ]*')
   fwconfig="sudo ufw status verbose | grep Action -A 999999"
   permok="drwx------"		
fi

echoD
echoD "- Checking the folder owner for '$repo' and the veeamtransport service user ..."
#Geting information about service account 
svcuser=$(ps axo user:20,pid,start,time,cmd | grep "veeamtransport --run-service" | head -n1 | awk '{print $1;}')

#Geting information about dir owner 
dirowner=$(ls -ld $repo | awk '{print $3}')

#Testing if the dir owner is correct.
if [ "$dirowner" == "$svcuser" ]
then 
    echoI "
    Info: The service user '$svcuser' and the dir owner '$dirowner' are set correctly!

    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-1--prepare-directory-on-linux-server-for-backups
    Reference: 'Both owner and group can be the account that you plan to use to connect to the Linux server.'"
else 
    echoW "
    Warning: The user: $svcuser is different from the folder owner: $dirowner !, Please connect the repository to veeam using single-use credentials account $dirowner.
    
    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-1--prepare-directory-on-linux-server-for-backups
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-2--add-linux-server-to-backup-infrastructure
    Reference: 'Use temporary credentials to avoid storing the credentials in the Veeam Backup & Replication configuration database. 
    To do that, click Add and select Single-use credentials for hardened repository'"
fi

echoD
echoD "- Checking the folder permissions for '$repo' ..."
#Geting information about the permissions.
permission=$(ls -ld $repo | awk '{print $1}')
#echo $permission

#Comparing the permissions with the right value: 700
if [ "$permission" == "$permok" ]
then 
    echoI "
    Info: The repository '$repo' is configured with the correct permission '$permission'(700)

    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-1--prepare-directory-on-linux-server-for-backups
    Reference: 'To allow access to the folder only for its owner and root account: chmod 700 <folder_path>'"
else 
    echoW "
    Warning: Permission of repository '$repo' is wrong! ($permission), please set it to '$permok'(Ex: 'chmod 700 $repo')!

    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-1--prepare-directory-on-linux-server-for-backups
    Reference: 'To allow access to the folder only for its owner and root account: chmod 700 <folder_path>'"
fi

echoD 
echoD "- Checking the SUDO rights ..."
#Default message for a user without SUDO rights. 
messagenosudo=`echo "User $svcuser is not allowed to run sudo on $HOSTNAME."`

#Geting info about sudo for the service user account.
sudoresult=$(sudo -l -U $svcuser)

#Comparing with the no sudo message.
if [ "$sudoresult" == "$messagenosudo" ]
then 
    echoI "
    Info: The user $svcuser doesn't have SUDO access, this is a good practice!

    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-2--add-linux-server-to-backup-infrastructure
    Reference: 'After the user will have temporary root- or sudo-permissions you must remove the user from the sudo group after the server is added.'"

else 
    echoW "
    Warning: Possible security breach!, user: $svcuser has SUDO rights, please disable the SUDO!

    More details:      
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-2--add-linux-server-to-backup-infrastructure
    Reference: 'After the user will have temporary root- or sudo-permissions you must remove the user from the sudo group after the server is added.'"
fi

echoD
echoD "- Cheking the LISTEN ports ..."
echoD "
    --------------------------------------------------------------------------------"
#Geting all ports in listen mode, except for the loopback.    
array=($(ss -lntu | grep LISTEN | grep -v 127.0.0 | awk '{print $5} ' | sed 's/.*://' | sort | uniq))

#Testing each port if is a veeam port
for i in "${array[@]}"
do
   : 
   #Testing each port if is a veeam port
   if ([ $i -lt 2500 ] || [ $i -gt 3300 ] && [ $i != "6162" ] )
   then
        echoW "
        Warning: $i is not a veeam service port, please disable it!"
   else 
	echoI "
        Info: $i is a veeam service/transport port."    
   fi
done
echoD 	"
    --------------------------------------------------------------------------------"

echoD 	"
    More details:
    https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html

    Reference: (Page 17): '8. Only run the Veeam transport service available on the network (SSH can be an exception).           
    There should especially be no third-party network services running with root permissions.                                   
    If an attacker can gain root access via a third-party software on the Hardened Repository, then they can delete all data.'"

echoD
echoD "- Cheking the SSH Service status ..."

#Testing SSH Service status
sshstatus=`systemctl status $service | grep running`

if [ -z "$sshstatus" ]
then 
   echoI "
    Info: SSH service is not running, this is a good practice!

    More details:
    https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                    
    Reference: (Page 17): '6. Secure access to the operating system. Use state-of-the-art multi-factor authentication. 
    If acceptable, disable the SSH Server completely and leave server access to the local physical console alone'"	
   
else 
    echoW "
    Warning: Is not recommend keep SSH service enabled in Veeam Hardened Repository!, please disable it!"
    echoD "
    Service Status: $sshstatus"	
    echoW "

    More details:
    https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                    
    Reference: (Page 17): '6. Secure access to the operating system. Use state-of-the-art multi-factor authentication. 
    If acceptable, disable the SSH Server completely and leave server access to the local physical console alone'"	

fi

echoD
echoD "- Cheking the Firewall status.... $fwstate"

#Testing if the FW is enable.
if [ "$fwstate" == "active" ] || [ "$fwstate" == "running" ]
then 
   echoI "
   Info: The firewall is enabled, but remember that only veeam service ports should be kept open: [6162, 2500-3300].

   More details:
   https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                    
   Reference: (Page 8): 'During installation, Veeam configures the Linux firewall and allows incoming traffic to port 6162. 
   Iptables rules for dynamic ports (2500–3300 per default) are configured automatically during the job run. 
   All these firewall rules are removed automatically after the job finishes execution'"

   echoD "
   Current firewall rules:"
   echoD "--------------------------------------------------------------------------------"
   #$fwconfig

   $fwconfig
else
   echoW "
   Warning: Please enable Firewall and keep only veeam ports allowed [6162, 2500-3000]!

   More details:
   https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                    
   Reference: (Page 8): 'During installation, Veeam configures the Linux firewall and allows incoming traffic to port 6162. 
   Iptables rules for dynamic ports (2500–3300 per default) are configured automatically during the job run. 
   All these firewall rules are removed automatically after the job finishes execution'"
fi

echoD "-------------------Finishing at $(date) ---------------"
