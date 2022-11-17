#!/bin/bash
terminalColorClear='\033[0m'
terminalColorInfo='\033[0;32m'
terminalColorWarning='\033[0;33m' 
terminalColorError='\033[0;41m'
echoD() {
    echo -e "${terminalColorClear}$1${terminalColorClear}"
} 
echoI() {
    echo -e "${terminalColorInfo}$1${terminalColorClear}"
}
 echoW() {
    echo -e "${terminalColorWarning}$1${terminalColorClear}"
}
 echoE() {
    echo -e "${terminalColorError}$1${terminalColorClear}"
} 
terms="N"
echoE "
-----------------------------------------------------------------------------------------------------------------------------------------------
| This script is independently produced and has no direct link to Veeam Software. It just checks the recommendations related to the user guide|
| article and Veeam Write Paper "Protect against Ransomware with Immutable Backups":                                                          |
| - https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository.html?ver=110                                                         |
| - https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                                  |
|                                                                                                                                             |
| By using this script you are at your own risk. Do you accept these terms? [Y=YES or N=NO]:                                                  |
-----------------------------------------------------------------------------------------------------------------------------------------------"
read terms

if [ -z "$terms" ] || [ ${terms^^} != "Y" ] 
then 
	echoI
	echoI "You didn't accept the terms! Ending the script now..."
	exit
fi

log="/tmp/log_$HOSTNAME.txt"
echoD "-------------------Starting at $(date) ------------------"
echoD "Setting repo path: $1"
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
echoD "Checking the folder owner for '$repo' and the veeamtransport service user...."

svcuser=$(ps axo user:20,pid,start,time,cmd | grep "veeamtransport --run-service" | head -n1 | awk '{print $1;}')
dirowner=$(ls -ld $repo | awk '{print $3}')
#echo $dirowner $svcuser

if [ "$dirowner" == "$svcuser" ]
then 
    echoI "
    Info: The service user '$svcuser' and the dir owner '$dirowner' are set correctly!

    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-1--prepare-directory-on-linux-server-for-backups
    Reference: 'Both owner and group can be the account that you plan to use to connect to the Linux server.'
    "
else 
    echoW "Warning: The user: $svcuser is different from the folder owner: $dirowner !, Please connect the repository to veeam using single-use credentials account $dirowner.
    
    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-1--prepare-directory-on-linux-server-for-backups
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-2--add-linux-server-to-backup-infrastructure
    Reference: 'Use temporary credentials to avoid storing the credentials in the Veeam Backup & Replication configuration database. To do that, click Add and select Single-use credentials for hardened repository'"
fi

echoD
echoD "Checking the folder permissions for '$repo'...."
permission=$(ls -ld $repo | awk '{print $1}')
#echo $permission

if [ "$permission" == "$permok" ]
then 
    echoI "Info: The repository '$repo' is configured with the correct permission '$permission'(700)

    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-1--prepare-directory-on-linux-server-for-backups
    Reference: 'To allow access to the folder only for its owner and root account: chmod 700 <folder_path>'"
else 
    echoW "Warning: Permission of repository '$repo' is wrong! ($permission), please set it to '$permok'(Ex: 'chmod 700 $repo')!

    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-1--prepare-directory-on-linux-server-for-backups
    Reference: 'To allow access to the folder only for its owner and root account: chmod 700 <folder_path>'"
fi

echoD 
echoD "Checking the SUDO rights...."
messagenosudo=`echo "User $svcuser is not allowed to run sudo on $HOSTNAME."`
#echo $messagenosudo
sudoresult=$(sudo -l -U $svcuser)

if [ "$sudoresult" == "$messagenosudo" ]
then 
    echoI "Info: The user $svcuser doesn't have SUDO access, this is a good practice!

    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-2--add-linux-server-to-backup-infrastructure
    Reference: 'After the user will have temporary root- or sudo-permissions you must remove the user from the sudo group after the server is added.'"

else 
    echoW "Warning: Possible security breach!, user: $svcuser has SUDO rights, please disable the SUDO!
      
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-2--add-linux-server-to-backup-infrastructure
    Reference: 'After the user will have temporary root- or sudo-permissions you must remove the user from the sudo group after the server is added.'"
fi

echoD
echoD "Cheking the LISTEN ports...."
echoD "--------------------------------------------------------------------------------"
array=($(ss -lntu | grep LISTEN | grep -v 127.0.0 | awk '{print $5} ' | sed 's/.*://' | sort | uniq))

for i in "${array[@]}"
do
   : 
   if ([ $i -lt 2500 ] || [ $i -gt 3300 ] && [ $i != "6162" ] )
   then
        echoW "Warning: $i is not a veeam service port, please disable it!"
   else 
	echoI "Info: $i is a veeam service/transport port."    
   fi
done

echoD 	""
echoD 	"https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                    
        Reference: (Page 17): 
        '8. Only run the Veeam transport service available on the network (SSH can be an exception).           
        There should especially be no third-party network services running with root permissions.                                   
        If an attacker can gain root access via a third-party software on the Hardened Repository, then they can delete all data.'"
echoD 	"--------------------------------------------------------------------------------"
echoD

echoD "Cheking the SSH Service status...."

sshstatus=`systemctl status $service | grep running`

if [ -z "$sshstatus" ]
then 
   echoI "Info: SSH service is not running, this is a good practice!"	
   
else 
   echoW "Warning: Is not recommend keep SSH service enabled in Veeam Hardened Repository!, please disable it!"
   echoD "Service Status: $sshstatus"	
fi

echoD
echoD "Cheking the Firewall status.... $fwstate"

if [ "$fwstate" == "active" ] || [ "$fwstate" == "running" ]
then 
   echoI "Info: The firewall is enabled, but remember that only veeam service ports should be kept open: [6162, 2500-3300]"
   echoD "Current firewall rules:"
   echoD "--------------------------------------------------------------------------------"
   $fwconfig
else
   echoW "Warning: Please enable Firewall and keep only veeam ports allowed [6162, 2500-3000]!"
fi

echoD "-------------------Finishing at $(date) ---------------"
